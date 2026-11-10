# Mia Legilo — Technical Architecture

**Version:** 2.6  
**Status:** Architecture baseline; operational contracts specified; Foliate-js device validation and CWNG API verification pending  
**Date:** 2026-11-10  
**Product contract:** `SPEC.md` v1.3  
**Implementation plan:** maintained separately

## 1. Scope and architectural invariants

Mia Legilo is an Android-first, offline-first Flutter EPUB reader. CWNG is the first remote catalog and download provider, not a dependency of the reader or domain model. The initial release reads reflowable EPUB 2/3. No Mia Legilo backend is required.

1. Reading must remain functional with no server or network connection.
2. Continuous vertical scrolling is book-wide, seamless across EPUB spine items, bidirectional, and momentum-preserving. Render a bounded window, not the whole DOM/book at once.
3. Reading position, reading status, download state, and metadata are distinct domains.
4. Locally committed user state must survive process death and provider disconnection.
5. Remote identities are scoped to provider instances; never match books solely by title/author.
6. Sync is capability-gated, field-specific, and cannot silently overwrite ambiguous concurrent edits.
7. EPUB content is immutable; reading data resides outside the book file.
8. Foliate-js is the primary renderer per ADR-001. Its Flutter/WebView integration must satisfy the Reader Lab release gates; selecting it does not establish unmeasured device performance.
9. Provider-specific DTOs and authentication cannot leak into application, domain, or reader interfaces.
10. P0/P1 priorities are governed by SPEC.md v1.3, not by older architecture drafts.

## 2. Technology baseline

| Concern | Baseline | Constraint |
|---|---|---|
| Application | Flutter/Dart, Android | Adaptive phone/tablet layouts; no Play Services dependency for reading |
| Presentation | Material 3 with E Ink-aware variants | Respect accessibility and device refresh characteristics |
| State/DI | Riverpod | Async state, feature isolation and testability |
| Navigation | go_router | Preserve reader state on route transitions |
| Persistence | Drift / SQLite | Transactional, migratable, indexed, reactive |
| HTTP | Dio or equivalent, selected by spike | Cancellation, streaming, timeouts, TLS verification |
| Credentials | Android Keystore-backed secure storage | Never persist secrets in SQLite or diagnostics |
| Files | Application-private EPUB storage + SAF import/export | No broad filesystem permission |
| Rendering | Foliate-js in Android WebView behind `ReaderEngine` | Primary implementation selected; device benchmarks and bounded-memory behavior still require validation |
| Integration | `LibraryProvider` with CWNG adapter | Explicit capability discovery |
| Synchronization | Transactional outbox + pull/reconcile coordinator | Field-specific merges and safe retries |
| Background execution | Android scheduled work where appropriate | Opportunistic; foreground sync and local saves are primary |

Dependencies flow inward: UI → application → domain/contracts; adapters implement contracts. No domain package imports Flutter widgets, Drift, Dio, CWNG models, or renderer internals.

## 3. Module layout

```text
lib/
  app/                         # bootstrap, routing, adaptive theme
  core/
    database/                  # Drift tables, indexes, migrations
    files/                     # atomic file store, SAF, hashing
    networking/                # HTTP, TLS, retries
    security/                  # secure credentials
    diagnostics/               # redacted logs and measurements
  domain/
    books/                     # book, editions, bindings, metadata
    library_queries/           # typed sort/filter/group/view models
    reading/                   # locator, progress, status, bookmarks
    synchronization/           # revisions, conflicts, outbox
    providers/                 # capabilities and provider contracts
  features/
    onboarding/
    library/
    reader/
    shelves/
    downloads/
    bookmarks/
    synchronization/
    settings/
    accessibility/
  integrations/
    contracts/
    cwng/                      # authentication, DTOs, mapping, transport
    local_import/              # SAF EPUB import source
  reader_engines/
    contracts/
    foliate_js/               # primary WebView adapter and typed JS bridge
    candidates/                # benchmark/fallback implementations
  main.dart
```

Avoid ceremonial per-feature layers. Use application/presentation/data subdivisions only where they clarify dependencies.

## 4. Domain and identity model

**Book** has immutable local `BookId` (UUID), metadata, optional series/index, authors, source availability, and a local metadata revision. **ProviderInstance** has stable `ProviderInstanceId`, endpoint, authenticated account identity (when known), and a capability snapshot. **RemoteBookBinding** maps `(ProviderInstanceId, RemoteBookId)` uniquely to `BookId`; retain bindings independently of connection state. Local SAF imports use a distinct local source type and never impersonate remote books.

**ReadingState** contains `BookId`, explicit `ReadingStatus` (`unread`, `wantToRead`, `reading`, `completed`, `onHold`, `abandoned`), semantic `ReadingLocator`, approximate whole-book progression, optional chapter progression, last-read/completed timestamps, local revision, and status provenance (`user`, `automatic`, `remote`). Progress cannot itself imply Completed. Opening/reading can transition Unread → Reading by product policy; explicit user status takes precedence, and reaching the end prompts rather than silently completing.

**ReadingLocator** includes a stable spine identifier/href, locator scheme (`epubCfi`, verified engine anchor, or approximate fallback), value, optional text context, book-content fingerprint, renderer version, and precision (`exact` or `approximate`). Store chapter-relative and book-relative progression only as fallbacks. Never treat pixel offset or percentage as an exact anchor. Preserve the original locator during engine migration; convert only with verified mappings.

**Bookmark** is a first-class entity with UUID, BookId, semantic locator, optional label, creation time, tombstone/deletion revision, and sync provenance. P0 bookmark operations do not depend on P1 highlight/note support. **Annotation** is a separate extensible model for P1 highlights/notes.

**Download** tracks source URL identity, local private path, state, expected/actual size, checksum where available, ETag/Last-Modified, partial bytes, retry metadata, and validation result. **Shelf** represents system status views or custom shelves, with optional verified remote binding. Download state is never used as reading status.

**LibraryViewDefinition** stores query, filters, ordered sort keys, grouping keys, view mode, and scope. **LibraryViewPreference** stores per-view collapsed groups, display choices and last-used configuration. P0 persists standard views and selections; P1 adds user-named saved views, nested grouping, multi-key sorting and discovered custom-column operations.

**OutboxOperation** stores operation UUID, provider instance, local/remote book IDs, field/type, serialized payload, local revision, observed remote revision/ETag, created timestamp, attempts, next retry and state. **SyncConflict** stores both candidate values and their provenance, versions and resolution status (`unresolved`, `deferred`, `resolved`).

## 5. Library query architecture

### 5.1 Query contract

The library must expose a typed, composable query model independent of CWNG:

```dart
class LibraryQuery {
  final String? searchText;
  final List<LibraryFilter> filters;
  final List<LibrarySort> sorts;
  final List<LibraryGroup> groups;
  final LibraryScope scope;
  final LibraryViewMode viewMode;
  const LibraryQuery({
    this.searchText,
    this.filters = const [],
    this.sorts = const [],
    this.groups = const [],
    required this.scope,
    required this.viewMode,
  });
}

abstract interface class LibraryQueryRepository {
  Stream<LibraryQueryResult> WatchAsync(LibraryQuery query);
  Future<LibraryQueryPage> GetPageAsync(
    LibraryQuery query,
    LibraryPageCursor? cursor,
  );
}
```

The example uses Fluent-style operation naming; actual Dart API names should follow repository lint conventions consistently.

### 5.2 Query semantics

- Search combines title, author and series fields at P0; tokenize/normalize case and diacritics consistently. Avoid provider network requests for every keystroke.
- Filters compose with **AND** across filter clauses and **OR** within a multi-select value set unless a filter explicitly declares otherwise. Include reading status, download availability, source, author, series and supported metadata fields.
- Sorting must support ascending/descending order, explicit null placement, stable deterministic ties (`BookId` last), locale-aware display ordering where practical, and numeric series indexes (never lexicographic `1, 10, 2`).
- Grouping is computed after filtering and uses the same normalized field semantics as sorting. Groups have stable keys, counts, deterministic ordering, and an explicit `Unknown`/`Unspecified` bucket. P0 groups are collapsible; collapse state persists per view.
- Grouping and sorting are independent: sort groups by a group comparator, then sort books within each group. Avoid grouping by rendered labels as identity.
- P0 supports composable single-key sort/group and combined filters; P1 adds ordered multi-key sorts, nested grouping, named saved views, and Calibre custom-column discovery/querying.
- Missing or unsupported provider fields are not presented as working controls. Preserve view definitions across temporary capability loss but mark unsupported clauses inactive and visible in configuration rather than silently producing misleading results.
- Query execution is local-first against Drift indexes, with paged/lazy loading. Server filtering may optimize ingestion but never define inconsistent local semantics.
- Cache derived grouping keys where justified by profiling; invalidate on metadata, reading status, shelf membership, and provider capability changes.

### 5.3 Data storage and indexing

Normalize authors, series, provider bindings, shelves and memberships. Store metadata fields with explicit type information and provenance; use typed tables for core fields and a typed extension-value table for discovered custom columns. Index `(status, lastReadAt)`, `(seriesId, seriesIndex)`, normalized title/author sort keys, provider bindings, shelf memberships and download state. Evaluate SQLite FTS5 for title/author/series search; maintain FTS transactionally. Use keyset pagination for large stable result sets where possible; invalidated cursors restart deterministically. Do not load the entire library into Flutter widgets to sort/group/filter.

## 6. Reader engine contract and Reader Lab

```dart
abstract interface class ReaderEngine {
  Future<void> OpenAsync(ReaderBookSource source, ReaderSettings settings);
  Stream<VisibleReadingAnchor> WatchVisibleAnchor();
  Future<LocatorRestoreResult> NavigateToAsync(ReadingLocator locator);
  Future<ReadingLocator> GetVisibleAnchorAsync();
  Future<void> SetReadingModeAsync(ReadingMode mode);
  Future<void> ApplySettingsAsync(ReaderSettings settings);
  Future<void> CloseAsync();
}

abstract interface class BookmarkRepository {
  Stream<List<Bookmark>> WatchForBookAsync(BookId bookId);
  Future<BookmarkToggleResult> ToggleBookmarkAtVisibleAnchorAsync(
    BookId bookId,
    ReadingLocator visibleAnchor,
  );
  Future<void> UndoToggleAsync(BookmarkToggleResult result);
}
```

The UI provides one-tap bookmark toggle with immediate visual feedback and undo. Bookmark writes commit to SQLite before optional network work; do not use an approximate viewport percentage as bookmark identity. Use an anchor equivalence policy that avoids duplicate bookmarks at the same semantic passage despite small CFI offsets.

### 6.1 Primary renderer: Foliate-js (ADR-001)

The **MIT-licensed Readest fork of Foliate-js** is the selected primary EPUB rendering source, subject to verifying the exact pinned fork revision and its complete dependency license inventory. It is embedded in an Android WebView and accessed exclusively through a Flutter `ReaderEngine` adapter. This is a selection decision, **not** a claim that outstanding Reader Lab performance gates have passed. The earlier widget tests and source inspection are preliminary evidence; actual Android WebView behavior must be measured.

- Bundle a pinned, auditable Foliate-js build as application assets; no runtime CDN or remote JavaScript is required. Track the exact Readest fork commit, upstream lineage, dependency versions, required copyright/license notices, local patches and build reproducibility. Preserve the Mia Legilo MIT license and include all required third-party notices; audit the fork and bundled dependencies before distribution. Do not assume that the license of the fork covers every bundled dependency.
- Load EPUBs from application-private storage through a restricted local-origin mechanism. Deny arbitrary remote navigation and network requests from book content; validate EPUB paths, resource sizes and MIME types. Never expose authentication tokens to JavaScript.
- Implement a **versioned, typed Dart–JavaScript bridge** with explicit request IDs, success/error envelopes, timeouts and cancellation. Commands include `open`, `close`, `navigate`, `getVisibleAnchor`, `setReadingMode`, `applySettings`, `search`, and TOC navigation. Events include `ready`, `visibleAnchorChanged`, `chapterChanged`, `navigationCompleted`, `selectionChanged`, `error` and `diagnostics`. Only allowlisted message handlers are accepted; sanitize untrusted book-derived payloads.
- Normalize Foliate-js positions into `ReadingLocator` with EPUB CFI where reliable, plus spine href, text context, content fingerprint and precision. Engine-specific locators must not escape the adapter. Restoration after reflow, restart, orientation change and process death remains an acceptance gate.
- Implement **continuous, bidirectional, book-wide vertical scrolling** as a seamless *logical* surface across spine items, including upward and downward chapter transitions. Foliate-js's default loading strategy may retain the entire EPUB in WebView memory; **bounded DOM/resource residency is a required engineering objective, not an existing verified capability**. Measure first, then implement windowing/resource eviction or reconsider the renderer if hard limits cannot be met. No visible reset or loss of momentum at chapter boundaries.
- Keep all bookmarks, reading status, progress, annotations and sync data in local persistence; Foliate-js is not the authoritative state store. One-tap bookmark toggling commits locally and uses a semantic anchor returned by the bridge.
- Provide explicit WebView lifecycle handling (pause/resume, renderer crash, process recreation), safe teardown and reload, and fallback to the last durable locator. E Ink modes reduce transitions and animation in both Flutter and WebView CSS; vendor refresh hooks remain optional.
- Horizontal pagination, cross-spine search, accessible EPUB text and TalkBack navigation must be verified against the authoritative product priorities. Unsupported behavior must not be silently claimed.

**Reader Lab remaining gates:** instrument on named Android devices/emulators for bidirectional cross-spine scrolling, memory residency and repeated transitions, frame pacing, battery, locator restoration drift, typography/theme changes, search/TOC, bookmark latency, WebView renderer death and recovery, TalkBack, and E Ink refresh characteristics. Document measured results and mitigation. If a hard requirement is not achievable with Foliate-js, reopen ADR-001 explicitly rather than weakening the requirement.

**Fallback policy:** Keep `ReaderEngine` provider-neutral and renderer-neutral; retain alternative engine prototypes only as test/fallback candidates. Do not implement an automatic runtime engine switch until locator compatibility and state migration have been validated.

Horizontal pagination retains its priority only as specified in the authoritative SPEC.md; resolve any conflicting older draft before release planning.

### 6.2 Position and navigation semantics

Persist the most precise available semantic locator on meaningful movement and on lifecycle transitions, with debounced writes during continuous scroll. Commit position on pause/background/route exit when possible, but correctness cannot depend on lifecycle callbacks firing. Restore by exact anchor first; fall back to spine + text context, then chapter progression, then book progression. Report precision to sync and UX layers. Back navigation after TOC/search uses a separate transient navigation stack; it must not overwrite the durable reading position with an incidental search result.

Whole-book percentage is calculated from a documented book-wide progression model, not the current chapter's viewport fraction. Current chapter is derived from the visible anchor and EPUB navigation metadata. Changes to typography or reading mode preserve the same semantic passage. For history and TTS (P1), expose reading-location events and optional text-range access without coupling the core engine to a specific speech provider.

## 7. Provider-neutral integration

Separate catalog, content acquisition and state capabilities:

```dart
enum ProviderAccess { unknown, unsupported, readOnly, writeOnly, readWrite }

enum ProviderFeature {
  catalog, downloads, progress, readingStatus,
  shelves, bookmarks, annotations, customColumns,
}

abstract interface class LibraryProvider {
  Future<ProviderIdentity> GetIdentityAsync();
  Future<ProviderCapabilities> GetCapabilitiesAsync();
  Future<CatalogPage> GetCatalogPageAsync(CatalogCursor? cursor);
  Future<BookContentStream> DownloadBookAsync(RemoteBookId id);
}
```

Actual API signatures must accommodate cancellation, streaming and provider-specific pagination without leaking DTOs. CWNG API endpoints, authentication flow, custom-column availability and write semantics must be verified against a real server and recorded in a capability matrix. `unknown` is not `readWrite`. Unsupported sync remains local-only with visible explanation. Never assume OPDS alone supports reading-state writes. Provider disconnect revokes credentials and stops remote jobs but retains downloaded books, local reading state, bookmarks and stable bindings unless the user separately chooses deletion.

## 8. Persistence, file lifecycle and downloads

Use Drift migrations with foreign keys, referential constraints and rollback tests. Reading state, bookmark toggle and outbox insertion (where eligible) must be a single transaction. Keep EPUB files in private storage and persist only paths/metadata in SQLite. Write downloads to temporary files; validate EPUB ZIP structure and required container/package data before atomic rename and availability publication. Where the server supports Range requests and validators, resume only if the remote representation is unchanged; otherwise restart safely. Handle storage exhaustion, cancellation, process death, corrupt partial files, and checksum mismatch explicitly.

Distinguish three destructive actions: **remove download** (delete local EPUB bytes, retain catalog and reading data), **remove from library** (remove local catalog association subject to provider reimport semantics, preserve or explicitly handle user data), and **delete reading data** (explicit confirmation for status, progress, bookmarks, notes/history). Never cascade from a metadata refresh or provider disconnect into deletion of user-owned state. Implement a clear retention/tombstone policy for orphaned state and remote rebinding.

## 9. Synchronization and conflict policy

Maintain independent metadata/catalog and reading-state pipelines. Sync cycle: authenticate and verify provider identity → refresh capability snapshot → pull paged/delta metadata → merge remote-authoritative metadata without touching local user state → pull verified state endpoints → reconcile each field → push eligible durable outbox operations with preconditions → acknowledge/retry/conflict → publish diagnostics.

Outbox operations are UUID-addressed and transactionally recorded; retries use exponential backoff with jitter and bounded attempts. Exactly-once network execution cannot be assumed: prefer remote idempotency keys or conditional writes; where unavailable, reconcile observed remote state before retrying non-idempotent operations. Never infer cross-device causality from device clocks alone.

Field policies:

| Field | Authority and conflict behavior |
|---|---|
| Catalog metadata | Remote authoritative for provider-owned fields; local overrides explicitly scoped |
| Download | Local device state; no reading-status inference |
| Progress | Prefer verified revision/ETag; do not use max-progress-wins; preserve both ambiguous positions |
| Reading status | Explicit manual choice outranks local automation; concurrent remote/manual edits require version evidence or conflict |
| Shelves | Local authoritative unless verified mapped remote collection semantics |
| Bookmarks/annotations | Local durable; remote write only with compatible IDs/anchors and verified API |
| Custom columns | Remote metadata unless a provider-specific write capability is explicitly verified |

Conflicts are persisted, visible, and can be resolved by choosing local or remote values or deferred. Deferral does not block reading or unrelated fields. Unknown/unsupported capabilities must never cause optimistic claims of synchronization. Remote approximate positions must not be silently promoted to exact EPUB CFI.

## 10. E Ink, accessibility and Android lifecycle

Use a presentation profile with optional reduced animations, high contrast, larger controls, and configurable refresh behavior when device/vendor APIs are supported. Feature-detect refresh APIs and degrade gracefully on conventional Android devices. Avoid full-screen redraws on every scroll tick; benchmark partial updates and ghosting without sacrificing anchor correctness.

All controls require semantic labels, predictable focus order and touch targets of at least 48 logical pixels. Reader Lab must verify TalkBack reading order, heading/landmark navigation and text accessibility inside rendered EPUB, not just Flutter chrome. Support system font scaling where compatible with the book layout. Handle rotation, background/foreground, low-memory termination and Android back navigation without position loss. Keep reading functional without Google Play Services.

## 11. Diagnostics, testing and quality gates

- Unit/property tests for sort/filter/group algebra, missing-value ordering, deterministic ties, series numeric order and view persistence.
- Migration and index tests with large libraries, metadata changes, custom-column types and provider disconnection.
- Reader corpus tests for EPUB2/3, long books, images, links, footnotes, malformed files, cross-chapter scrolling, search, TOC, bookmarks and exact/approximate restoration.
- Fault injection for app termination, offline writes, partial downloads, expired credentials, duplicate retries and simultaneous edits.
- Accessibility testing with TalkBack, tablet layouts and E Ink profiles.
- Measure reader reopening, scroll frame pacing, memory growth, chapter transition and locator drift on identified reference devices; retain provisional performance targets from the existing release contract until benchmark evidence supersedes them.
- Never log credentials, auth headers, book text or sensitive annotation content. TLS validation is mandatory outside explicit development configuration.

## 12. Architecture decisions and unresolved items

**Accepted:** MIT-licensed Readest fork of Foliate-js as primary renderer (ADR-001; exact revision and bundled licenses to be audited); Flutter Android; EPUB-first; Riverpod; Drift/SQLite; provider-neutral CWNG adapter; offline-first local authority; independent metadata/state synchronization; durable outbox; stable book bindings; exact/approximate locators; book-wide virtualized vertical scrolling; one-tap bookmarks; typed composable library queries; e-ink-aware presentation.

**ADR-001 — Selected, validation open:** The Readest fork of Foliate-js is the primary Android WebView renderer behind `ReaderEngine`, communicating through a typed Dart–JavaScript bridge. The typed bridge and security boundaries are architectural requirements; device-measured memory, lifecycle, accessibility, scrolling and locator fidelity remain release gates. Reopen ADR-001 if hard gates fail.

**Discovery pending:** CWNG authentication/API and status/collection/custom-column support; verified idempotent write paths; Android E Ink vendor hooks; appropriate FTS/index strategy under realistic library sizes.

**Specification alignment check:** The v2.2 architecture treats horizontal pagination as P1, whereas the older available SPEC.md v1.0 copy lists it as P0. Confirm the authoritative v1.3 priority before assigning the release gate. Do not silently change either document.

### ADR-001 decision record — explicit implementation commitments

| Area | Accepted decision | Verification / implementation constraint |
|---|---|---|
| Primary renderer | Foliate-js, using the MIT-licensed Readest fork | Pin and audit the exact fork revision and dependencies; retain `ReaderEngine` abstraction |
| Flutter integration | Android WebView with a Dart–JavaScript bridge | Typed, versioned bridge; restricted local origin and hardened content loading |
| Scrolling | Continuous, bidirectional, book-wide vertical scrolling | Seamless upward/downward spine transitions; benchmark momentum and restoration |
| Reading locations | EPUB CFI as preferred exact locator | Preserve precision and fallback anchors; never treat percentages as exact |
| Bookmarks | One-tap, local-first persistence | Commit semantic anchors transactionally before any remote sync |
| Offline support | EPUB resources available entirely offline | Bundle renderer assets and store complete downloaded/imported EPUBs locally; no CDN requirement |
| Memory management | Initial implementation followed by profiling and optimization | Measure actual WebView/DOM usage first; implement bounded windowing as needed to satisfy release gates |
| E Ink | Reduced-motion and high-contrast presentation | Apply settings in Flutter and WebView CSS; optional vendor refresh integration |
| Licensing | Preserve MIT license and required third-party notices | Audit fork, upstream attribution, bundled dependencies and distributable notices |

## 13. Security and trust boundaries (G-01, G-06, G-16)

### 13.1 Trust model and WebView isolation

Treat the Flutter host and pinned, bundled Foliate-js runtime as trusted application components; treat every EPUB, its XHTML/CSS/SVG, metadata, hyperlinks and imported filename as untrusted input. **No EPUB-supplied script may execute with bridge privileges.** Use a controlled app-local HTTPS origin (for example, Android WebViewAssetLoader where suitable) for application assets; expose EPUB resources through an explicitly scoped, read-only resolver. Avoid `file://` access and universal file URL access; disable file/content URL access except for a narrowly justified, tested mechanism. Deny mixed content, third-party cookies, unexpected permission requests, popups and navigation outside an explicit allowlist. External links must be handed to the Android intent handler only after scheme validation and user action. No credentials or server authentication headers enter the WebView.

Prefer EPUB script disabling and resource sanitization, with separate isolated contexts for trusted renderer logic and untrusted book documents. Do **not** rely on Content Security Policy alone to isolate a JavaScript interface exposed to every frame. The bridge must be available only to an authenticated trusted renderer frame/origin, with explicit origin checks and an application-generated per-session capability token inaccessible to EPUB documents. If the chosen WebView integration cannot enforce that boundary, the design must change before accepting untrusted EPUBs. Sanitize archive paths (`..`, absolute paths, symlinks), reject ZIP bombs via compressed/uncompressed size and entry-count limits, validate resource MIME/type and reject remote subresources by default. Allow no network access from book content. EPUB HTML sanitization must not destroy legitimate reading semantics; validate against the test corpus.

### 13.2 Bridge validation

Every message has `{protocolVersion, sessionId, requestId, type, payload}` and a strict schema. Reject unknown types, oversized payloads, invalid session/origin, unexpected response IDs and stale generations. Bound outstanding requests, define timeouts and cancellation, and never deserialize messages directly into privileged filesystem or provider operations. Host commands are allowlisted and book-derived strings are always treated as data. Record bridge errors without book text. Test hostile EPUB payloads, crafted origins, malicious hyperlinks and oversized messages.

### 13.3 Provider account and endpoint identity

`ProviderInstanceId` is a stable local UUID distinct from `EndpointUrl`, `ServerIdentity`, `LibraryIdentity` and `AccountIdentity`. Verify each identity using documented server evidence when available; otherwise mark identity confidence as `unverified` and require confirmation before rebinding or merging. Endpoint relocation updates connection configuration, not book identity. Authentication secrets live only in Android Keystore-backed storage and are keyed by provider instance and account. Handle token expiry/refresh with a single-flight refresh coordinator; on 401, refresh once where supported, then require reauthentication. Reject invalid TLS certificates and redirects that could leak credentials. Account switching isolates bindings, pending mutations and capability snapshots. Logging and exported diagnostics must redact URLs containing secrets, tokens, cookies and user-entered content.

### 13.4 Supply-chain policy

Pin Flutter/Dart, Android Gradle dependencies, the Readest Foliate-js fork by immutable commit, JS lockfile and reproducible build tooling. Use dependency and license scans in CI, publish a third-party notices manifest and SBOM for releases, and triage known vulnerabilities before release. Apply security updates via reviewed, tested version bumps; never pull renderer code from a CDN at runtime. Maintain a patch ledger for the fork. MIT licensing of the application does not override third-party license obligations.

## 14. Identity, content revisions and data integrity (G-02, G-03, G-07, G-09)

### 14.1 Content revisions and anchor safety

Introduce `BookAsset` with `assetId`, `bookId`, `sourceBinding?`, `sha256`, `byteSize`, `format`, `importedAt`, `contentRevision`, `validationState` and `storagePath`. A book may have multiple revisions; at most one is the active readable revision. `ReadingLocator` and bookmarks reference `assetId`/fingerprint as well as the local `BookId`. A changed EPUB hash is a new content revision even if the remote ID is unchanged. Keep prior locators and prior asset metadata until a migration is verified. On revision change: try exact CFI on the new content only when its target can be validated; then spine/href plus text-context matching; otherwise mark `needsReview` and preserve original anchors. Never silently translate a percentage into an exact locator or overwrite an unmigrated bookmark.

A SHA-256 match is evidence of identical bytes, not a basis for automatically merging unrelated books. Duplicate detection may propose a user-confirmed association; remote binding identity remains authoritative for server-backed books.

### 14.2 Filesystem/SQLite consistency

Filesystem and SQLite changes are not a distributed transaction. Use a **durable file-operation journal** with operation UUID, kind (`import`, `download`, `replace`, `delete`), asset ID, temporary/final path, expected hash, phase and timestamps. For imports/downloads: reserve DB record and journal entry → stream to private temporary file → validate ZIP/EPUB and hash → flush and atomically rename within the same filesystem → commit active asset and operation completion in SQLite. For deletion: mark deletion intent → detach active references transactionally → delete bytes idempotently → mark completed. Startup and periodic reconciliation replay incomplete operations, remove stale temporary files only after a retention window, detect missing/corrupt assets and surface recoverable errors. Never delete the sole readable copy while a replacement is unverified. All file paths are generated internally; never trust remote filenames as paths.

### 14.3 Database migrations and metadata provenance

Use monotonically versioned Drift migrations, schema snapshots and migration tests from every supported prior schema to current. Enable foreign keys; check integrity after migration and on suspected corruption. Before a destructive migration, create a recoverable backup when storage permits; use SQLite transactional DDL where supported. On failed migration, do not open the database writable with an unknown schema: retain the original, offer retry/recovery/export and fail safely. Downgrade to an older app with a newer schema is unsupported; detect and explain rather than rewriting data. Core user-owned reading data must never be silently dropped.

For each mutable metadata field, store `value`, `origin` (`provider`, `userOverride`, `derived`), `providerRevision?` and `updatedAt`. Provider refresh updates only provider-owned values; local overrides remain intact until explicitly cleared. Unknown custom-column types are retained losslessly as raw typed payloads and displayed conservatively; no guessed write-back. Search/index projections can be rebuilt from canonical records.

## 15. Runtime and synchronization state machines (G-04, G-05, G-12, G-13)

### 15.1 Reader session

Model `ReaderSession` states: `created → initializing → ready → restoring → active → suspended → disposed`, with `failed` reachable from any non-disposed state. Only `active` sessions emit authoritative visible-anchor updates. Each WebView creation increments a `sessionGeneration`; responses/events from prior generations are discarded. Initialization and restoration are idempotent within a generation. On renderer termination: mark session failed, preserve last committed semantic locator, recreate the WebView once using bounded backoff, restore by exact locator/fallback sequence and show a recoverable error if repeated attempts fail. No automatic infinite restart loop. Debounce scrolling writes (default 1 second after movement settles) and checkpoint on meaningful navigation and background events; never rely exclusively on `onPause` or process-shutdown callbacks. A bookmark request must resolve a current-generation semantic anchor before the local transaction commits.

### 15.2 Durable outbox and conflict states

Per `(ProviderInstanceId, BookId, field)` maintain monotonically increasing **local revision** and optional observed remote revision/ETag. Outbox transitions: `pending → inFlight → acknowledged`, `inFlight → retryPending → inFlight`, or `inFlight → conflicted/blocked`; `blocked` is also used when capability/authentication is unavailable. `deferred` applies to persisted user conflict resolution, not to network operation success. Commit local state change and outbox mutation in the same SQLite transaction. Never run two writes concurrently for the same provider/book/field; independent fields may proceed in parallel.

Coalesce only **unsent, replaceable** state updates (such as latest reading position) while preserving revision history/audit sufficient to recover; do not coalesce bookmark add/delete operations unless their remote semantics are verified. Once an operation is in flight, later edits create a newer revision and cannot mutate its payload. If an acknowledgement is lost, query remote state or use a provider-supported idempotency key/conditional write before replay. If neither is possible for a non-idempotent mutation, block and request reconciliation rather than risking duplication. Server `409/412` or incompatible remote revisions create a `SyncConflict` with both candidates; never auto-select greatest progress or newest device clock. Resolving a conflict records a new local revision and (if supported) a new conditional outbox operation. Deferral preserves both values and does not block unrelated fields.

Classify failures: transient network/5xx/429 → capped exponential backoff with full jitter and `Retry-After` when valid; 401 → reauthenticate; 403 → blocked capability/permission; 404 binding mismatch → identity review; validation 4xx → terminal error; version conflict → conflict. Use finite per-run attempt budgets, but retain durable operations for explicit later retry; do not discard unacknowledged user state. Sync worker leases expire and recover after process death.

### 15.3 Capability changes and downloads

Capability snapshots record source, discovery time, provider version and per-field access (`unknown`, `unsupported`, `readOnly`, `writeOnly`, `readWrite`). Reprobe on new connection, account change, provider version change, authentication recovery and before a previously unverified write. Treat stale/unknown access as non-writable until verified. When write support disappears, move eligible operations to `blocked` without deleting them; notify the user and resume only after re-verification.

Use a bounded download queue (default two simultaneous transfers, configurable after profiling), prioritizing user-opened books over background prefetch. Deduplicate by `(ProviderInstanceId, RemoteBookId, remote content revision)` and share progress among callers. Cancellation releases network resources but retains a resumable partial only when validators support safe resume. On restart, recover queued jobs and verify partial files before resuming. Apply per-host throttling and honor metered-network/battery policies where supported. Download progress is derived from transferred bytes, not catalog state.

## 16. Operational contracts (G-08, G-10, G-11, G-14, G-15)

### 16.1 Large-library query behavior

Queries execute in SQLite, not by loading the full catalog into widget memory. Use deterministic normalized sort keys plus `BookId` as final tie-breaker; keyset pagination where sort keys support it, otherwise bounded offset paging. Invalidate stale cursors when filters, sort, scope or relevant dataset revision changes. Index core sort/filter combinations and use FTS5 for text search where benchmarked beneficial. Benchmark at 1k, 10k and 50k books on a reference Android device; provisional target is first visible page within 500 ms for warm local queries, with instrumentation rather than a universal guarantee. Group counts are computed by database queries and lazily expanded.

### 16.2 Progress semantics

The exact `ReadingLocator` is authoritative; percentage is a display/sync approximation. Define whole-book progression over the EPUB reading-order spine, excluding items marked non-linear where appropriate. Prefer cumulative normalized text-length weights per spine item; include a documented fallback for image-only/empty items and expose calculation version (`progressAlgorithmVersion`). Chapter progress uses current spine item independently. Recompute percentages after content revision or algorithm changes, but do not change the stored semantic position. Clamp displayed progress to 0–100%; never infer `completed` status from 100%. Provider percentages are translated only as approximate remote candidates, not exact CFI.

### 16.3 Storage pressure and retention

Downloaded EPUBs are user-managed durable assets, not disposable cache. Use separate quotas/policies for covers, extracted resources, temporary files and diagnostics; LRU eviction applies only to regenerable cache, never to EPUB downloads or user-owned state without explicit consent. Before starting a download, estimate available storage and reserve headroom; on ENOSPC, stop safely, retain existing readable files and present cleanup choices. Remove abandoned temporary files after reconciliation and a configurable retention period (default seven days), never while an operation is active. Removing a download preserves reading state, bookmarks and catalog identity.

### 16.4 E Ink and accessibility verification

Reduced-motion and high-contrast modes are deterministic theme/settings profiles, not vendor-specific assumptions. Suppress nonessential animations, avoid continuous full-screen invalidation and throttle decorative UI updates. Measure scroll latency, partial/full refresh behavior and visible ghosting on named E Ink devices; document vendor APIs as optional adapters and provide safe no-op fallback. Verify TalkBack traversal, headings, links, selection and reading order inside EPUB content, plus 48dp minimum controls in Flutter UI. Treat inaccessible rendered text as a release-gate failure where required by SPEC.md.

### 16.5 Diagnostics and privacy

Use structured events with event name, monotonic duration, session/operation correlation IDs, component, error category and sanitized provider identity. Default logs exclude EPUB body text, search terms, notes, credentials, cookies, access tokens and full local paths. Keep a bounded local diagnostic ring buffer (default seven days or 10 MB, whichever is reached first); exports require explicit user action and redaction preview. No third-party telemetry or crash upload is required for core operation. Include database schema, app, renderer fork commit and capability-snapshot versions in diagnostics without revealing secrets.

## 17. Data portability and recovery (G-17)

Treat local user-owned data as exportable independently of CWNG. Define a versioned portable JSON manifest for books (local UUID and optional provider binding metadata), status, reading locators (including precision and content fingerprint), bookmarks, custom shelves, and settings. Do not include credentials, tokens or EPUB contents in the state-only export. Support explicit EPUB-file export through Android SAF as a separate user action. Imports validate schema, IDs, sizes and referential integrity, show a dry-run summary, and never merge by title/author alone. Match by verified provider binding or content hash only with user confirmation; preserve unresolved locator conflicts. Import writes are transactional where possible and recoverable across filesystem changes. Full import/export UI can be scheduled post-v1 unless SPEC.md requires earlier, but the persistence model must not preclude it.

## 18. Cross-document impacts (informational only)

**SPEC.md:** No changes made. The implementation must honor v1.3 query composition, persistence, lifecycle, bookmark, conflict and accessibility acceptance criteria. Verify horizontal pagination priority against its latest text.

**IMPLEMENTATION.md:** No changes made. Add implementation/test work for G-01–G-17, including hostile EPUB security tests, asset revisions and journal recovery, renderer session generations, sync state-machine fault injection, large-library performance, storage pressure, E Ink measurements, diagnostics retention and export schema.  Its task breakdown should add library query engine/indexes, saved view persistence, custom-column discovery, status provenance, deletion flows, resumable downloads, conflict deferral and TalkBack EPUB tests. Align ADR references to ADR-001 (older plans mention ADR-004), mark renderer selection complete, and retain Reader Lab as the device-validation and release gate. Add Readest fork revision pinning and license/notice audit, Foliate-js asset build, bridge contract tests, WebView security and lifecycle tests, and memory/windowing investigations.
