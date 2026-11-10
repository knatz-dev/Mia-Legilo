# Mia Legilo — Product and Functional Specification

**Version:** 1.4  
**Status:** Product specification freeze candidate; primary renderer selected, production validation pending  
**Date:** 2026-11-10  
**Repository:** https://github.com/knatz-dev/Mia-Legilo  
**License:** MIT  
**Alignment:** Architecture v2.2 baseline plus subsequent Foliate-js primary-renderer decision

## 1. Product vision

Mia Legilo is an open-source, offline-first Flutter EPUB reader for Android, designed for personal reading and integration with self-hosted Calibre-Web NextGen (CWNG) libraries. It provides a high-quality, book-wide continuous reading experience and reliable local reading state. CWNG is the initial remote authority for available catalog metadata and book files; synchronization is conditional on verified provider capabilities.

### 1.1 Fixed decisions

- Android first, including phones, tablets and Android E Ink devices.
- Flutter/Dart; MIT license.
- EPUB-only initial format; EPUB 2/3 reflowable content in scope.
- CWNG first, with provider-neutral catalog and download behavior and future provider extensibility.
- Book-wide continuous vertical scrolling is mandatory, including seamless bidirectional chapter transitions.
- Single-tap, offline-capable bookmarking is mandatory.
- **Foliate-js is the selected primary EPUB renderer**, based on comparative debug APK testing; production-mode Reader Lab validation and the renderer ADR remain required. The renderer is an implementation choice, not permission to weaken product acceptance criteria.
- Local reading works without a configured server or active connection.
- Library organization supports composable sorting, grouping and filtering; provider-exposed Calibre custom columns are supported as optional P1 dimensions.

### 1.2 Non-goals for v1

Full Calibre metadata editing, replacing Calibre Desktop, running a library server on-device, PDF/CBZ/CBR/MOBI/AZW support, DRM circumvention, social reading, Goodreads integration, subscriptions, mandatory external accounts, iOS/desktop binaries, and unsupported remote synchronization guarantees.

## 2. Personas and journeys

1. **Connected reader:** Connect to CWNG, browse/search books, download an EPUB, read offline, and synchronize supported state.
2. **Offline reader:** Import or open an EPUB, scroll through the entire book, bookmark with one tap, and retain changes through restarts without connectivity.
3. **Library organizer:** Browse by author, series, reading status and shelves; change status independently of download state; distinguish local and synchronized changes.
4. **E Ink reader:** Use readable high-contrast layouts, minimal animation, stable scrolling and device-compatible refresh settings.
5. **Local-file reader:** Import EPUB through Android's file picker and read without a server; local import is a source of books, not a network provider.

## 3. Requirement conventions

Requirement identifiers are stable. **P0** = initial usable release; **P1** = subsequent release; **P2** = later evaluation. Acceptance criteria describe observable behavior, not an implementation technology. Where provider capability or hardware support is conditional, the UI must communicate the limitation rather than claim success.

### 3.1 Onboarding and connections

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| CON-001 | P0 | Add/edit CWNG connection | User enters HTTPS server URL and credentials; connection test distinguishes authentication, TLS, network and incompatible-server errors. |
| CON-002 | P0 | Secure credentials | Credentials never appear in diagnostics, logs or plaintext local databases. |
| CON-003 | P0 | No-server reading | User can import and open EPUB through Android file picker without configuring CWNG. |
| CON-004 | P0 | Provider capability disclosure | Unsupported, read-only, writable and unknown operations are distinguishable; unsupported writes are never reported as synced. |
| CON-005 | P1 | Multiple server profiles | Switching profiles preserves stable provider-specific identities without merging unrelated books. |

### 3.2 Library and downloads

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| LIB-001 | P0 | Cover grid and detailed list | User can switch library views; preference persists after restart. |
| LIB-002 | P0 | Search and sort | Search title, author and series; sort by title, author, recently added and last read with deterministic ties. |
| LIB-003 | P0 | Book details | Show available title, authors, cover, series/index, description, formats, source and download availability. |
| LIB-004 | P0 | Reading statuses | Support Unread, Want to Read, Reading, Completed, On Hold and Abandoned independently of progress and downloads. |
| LIB-005 | P0 | Status shelves | Dedicated status views, including Currently Reading and Completed, update immediately offline. |
| LIB-006 | P0 | Download management | Download/remove EPUBs; show progress, failure, offline availability and relevant storage information. |
| LIB-007 | P0 | Series navigation | Order by numeric series index; handle missing indices consistently. |
| LIB-008 | P1 | Custom shelves | Create, rename and delete local shelves; remote mapping only where verified. |
| LIB-009 | P1 | Bulk operations | Apply status, shelf and download actions to multiple selected books. |
| LIB-010 | P1 | Metadata refresh | Remote metadata updates cannot silently erase local state or remove downloaded files. |
| LIB-011 | P0 | Stable source binding | A book retains its local identity and its provider-instance/remote-book association across refreshes and restarts; title/author similarity alone never silently merges books. |
| LIB-012 | P0 | Provider-neutral browsing | Library and download behavior remains consistent regardless of provider-specific field names; missing provider features degrade visibly. |

### 3.2.1 Library organization and discovery

Sorting, grouping and filtering are independent, composable operations over locally cached metadata. They must not require network connectivity once the relevant catalog data has been cached. The same semantics apply to grid and list views, status shelves and search results.

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| LIB-013 | P0 | Standard sorting | Ascending/descending sorting by title, author, series name, series index, date added, last read, reading progress and reading status; deterministic ties and missing values. |
| LIB-014 | P0 | Composable filters | Filter by reading status, download availability, author, series membership, shelf and source where applicable; AND across dimensions, OR across selected values within a dimension; clearing filters restores the full scope. |
| LIB-015 | P0 | Standard grouping | Group by author, series or reading status, with collapsible sections and counts that reflect active filters; ungrouped view remains available. |
| LIB-016 | P0 | Persistent organization preferences | Selected sort, direction, group and filter settings persist across restart and remain usable offline; status changes immediately update affected results and counts. |
| LIB-017 | P1 | Multi-key sorting | User can configure ordered sort keys, e.g. author → series → numeric series index; stable tie-breaking and missing-value ordering are documented. |
| LIB-018 | P1 | Nested grouping | Support at least two group levels, e.g. author → series, with independently collapsible sections and persistent expansion state. |
| LIB-019 | P1 | Saved library views | Save, rename, select and delete named combinations of search scope, filters, sorting and grouping; views function offline using cached data. |
| LIB-020 | P1 | Calibre custom-column discovery | When a provider exposes custom columns, show their display names, value types and availability; do not invent or assume unsupported fields. |
| LIB-021 | P1 | Custom-column sorting | Exposed, sortable custom columns can be used as sort keys with type-appropriate ordering (numeric, date, boolean, text) and deterministic missing-value behavior. |
| LIB-022 | P1 | Custom-column filtering | Exposed custom columns can be filtered with type-appropriate operators, including multi-value matching where applicable; unsupported operators are hidden or disabled. |
| LIB-023 | P1 | Custom-column grouping | Exposed, groupable custom columns can be selected as grouping dimensions; empty and multi-valued fields are presented consistently. |
| LIB-024 | P1 | Metadata provenance and refresh | Distinguish standard, provider-supplied custom and locally maintained fields; provider refresh preserves local user-owned state, updates available custom values, and gracefully handles removed or renamed fields in saved views. |
| LIB-025 | P1 | Extended standard sort fields | Publication date, file size and user rating are offered where data exists; unavailable fields are not represented as complete or authoritative. |
| LIB-026 | P2 | Advanced query builder | Evaluate a user-facing expression builder for nested AND/OR conditions beyond the standard composable filter UI. |

**Custom-column policy:** Calibre custom columns are a confirmed product requirement, not a guarantee that CWNG exposes every column or supports remote querying. Mia Legilo must use fields actually returned or otherwise verified through the provider. Sorting, grouping and filtering over cached values are local operations; they do not imply server-side custom-column editing or synchronization. A missing field must not cause an existing saved view to fail or silently apply an unrelated field.

**Library interaction rules:** Filtering, grouping and sorting may be active simultaneously. Groups show counts after filtering. Search narrows the current library scope before organization is applied. Multi-author and multi-valued fields require explicit, consistent membership rules; a book may appear in more than one group, but aggregate unique-book totals must not double-count it. Missing metadata is shown in a predictable “Unknown” or “Unassigned” group when relevant. All settings and saved views are local-first.

### 3.3 EPUB reading and navigation

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| RDR-001 | P0 | Book-wide continuous vertical scrolling | The EPUB behaves as one continuous reading surface from the first to the final chapter, with seamless forward and backward scrolling across spine/chapter boundaries; no manual next-chapter action, forced page turn, unexplained jump or scroll reset. |
| RDR-002 | P0 | Optional horizontal pagination | If offered, switching modes retains the same semantic reading location; continuous vertical mode always remains available. |
| RDR-003 | P0 | Reflowable EPUB 2/3 | Representative EPUB 2/3 content renders in correct reading order, including XHTML/CSS, images, internal links and navigation. |
| RDR-004 | P0 | Typography | Configure font family/size, line height, margins, paragraph spacing and alignment without losing semantic position. |
| RDR-005 | P0 | Themes | Light, dark and sepia; brightness control where Android permits. |
| RDR-006 | P0 | Exact reading locator | Store a durable semantic anchor (EPUB CFI where supported or a documented equivalent) and a separately identified approximate fallback; percentages and pixel offsets are never treated as exact. |
| RDR-007 | P0 | Table of contents | Navigate to chapter/section location; Back returns to the prior reading location. |
| RDR-008 | P0 | In-book search | Search across spine items, navigate between matches and return to the prior reading position. |
| RDR-009 | P0 | Bookmark management | Create, list, revisit and delete bookmarks offline; one tap in reading view creates a bookmark at the current exact semantic location without interrupting reading. |
| RDR-010 | P0 | Precise resume | Reopen, process restart, orientation change, font change and theme change restore the same passage (within one paragraph where technically possible), not merely the same percentage. |
| RDR-011 | P0 | Robust failures | Invalid EPUBs, missing files and unsupported content show actionable errors without crashing or corrupting local state. |
| RDR-012 | P1 | Highlights and notes | Selection-based annotations persist offline and remain anchored to semantic locations. |
| RDR-013 | P1 | E Ink optimizations | Optional reduced animation, high-contrast controls and supported refresh preferences; unsupported vendor-specific refresh controls fail safely. |
| RDR-014 | P2 | Advanced EPUB features | Evaluate fixed-layout, media overlays and interactive EPUB separately. |
| RDR-015 | P0 | Cross-chapter scroll continuity | Chapter boundaries preserve visual continuity, natural touch/drag/fling momentum and reverse scrolling; chapter transitions require no separate confirmation or navigation control. |
| RDR-016 | P0 | Long-book stability | Scrolling through many chapters does not exhibit progressively increasing memory use, recurring freezes or visibly repeated chapter loading interruptions on reference devices. |
| RDR-017 | P0 | Scroll-aware loading | Content ahead of and behind the current viewport becomes available in time for normal reading; content virtualization or preloading must not cause jumps, duplicate text, missing passages or bookmark drift. |
| RDR-018 | P0 | Bookmark feedback and deduplication | A single tap produces accessible, unobtrusive confirmation; repeated taps at the same semantic anchor do not accidentally create indistinguishable duplicates; bookmarked passages remain reachable after reopening. |
| RDR-019 | P0 | Final-position persistence | Leaving the reader, backgrounding, switching books or terminating/restarting the app preserves the most recent committed reading location; routine save delays do not discard the final position. |
| RDR-020 | P0 | Location precision disclosure | Exact, converted and approximate restoration are distinguishable when necessary; if an exact anchor cannot be resolved, the reader uses a documented fallback and never silently represents it as exact. |

**Renderer alignment:** Foliate-js is the primary renderer. Its integration must satisfy every P0 reading requirement, including continuous cross-spine scrolling, semantic anchors, search, accessibility and offline reading. If a capability requires adaptation, it remains a release gate rather than becoming optional. Reader Lab validation must use profile/release builds; prior debug APK comparisons are selection evidence, not final performance certification.

**Reader interaction rule:** The entire book must *feel* continuous even if the renderer internally loads or virtualizes separate chapters. The specification does not require a single giant DOM, WebView or widget tree. The chosen renderer must pass these behaviors; a package that supports only chapter-local scrolling does not satisfy RDR-001.

### 3.4 Offline-first state and synchronization

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| SYN-001 | P0 | Local-first changes | Progress, status and bookmarks are saved locally without waiting for network. |
| SYN-002 | P0 | Durable pending changes | Eligible remote changes survive process termination and can be retried. |
| SYN-003 | P0 | Safe retries | Repeated attempts do not produce duplicate logical local mutations; remote delivery guarantees are never overstated. |
| SYN-004 | P0 | Capability gating | Unsupported writes remain local-only and are visibly labeled; unknown capability never implies success. |
| SYN-005 | P0 | Position sync | Sync only through verified compatible remote position APIs and location mappings; otherwise retain locally. |
| SYN-006 | P0 | Status sync | Map only equivalent supported remote status values; preserve unsupported local values. |
| SYN-007 | P0 | Conflict handling | Resolve fields independently using trustworthy revision evidence; ambiguous concurrent edits are preserved and surfaced. |
| SYN-008 | P0 | Connectivity resilience | Offline reading and writes continue; retries after reconnect do not erase local state. |
| SYN-009 | P1 | Custom shelf sync | Only sync shelves where remote read/write and membership semantics are verified. |
| SYN-010 | P1 | Annotation sync | Sync only with verified durable compatible APIs. |
| SYN-011 | P1 | Sync diagnostics | Show last synchronization, pending changes, errors, capability information and manual retry. |
| SYN-012 | P0 | Independent sync domains | Catalog/metadata synchronization and reading-position synchronization have separate success/failure outcomes; one failing does not block the other's local functionality. |
| SYN-013 | P0 | Position conflict safety | Do not select the numerically greatest percentage as winner; preserve intentional backward movement, rereading and both competing locators when unresolved. |
| SYN-014 | P0 | Durable state under interruption | App backgrounding, unexpected termination and temporary server failure cannot erase previously committed local progress, status or bookmarks. |
| SYN-015 | P0 | Stable identity during reconciliation | Remote catalog changes never silently rebind a local reading state to a different remote book; uncertain mappings require explicit resolution. |
| SYN-016 | P0 | Precision-safe exchange | Exact semantic locators are never fabricated from remote percentages or other approximate positions; incompatible remote positions remain marked approximate. |

### 3.5 Accessibility and Android behavior

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| ACC-001 | P0 | Accessible controls | Reader and library controls have meaningful screen-reader labels and touch targets of at least 48 logical pixels. |
| ACC-002 | P0 | Text and layout adaptation | Reader supports suitable text scaling, portrait/landscape, phone/tablet layouts and Android Back behavior. |
| ACC-003 | P0 | Offline access | Downloaded EPUBs remain readable without token refresh, network access or Google Play Services. |
| ACC-004 | P0 | Minimal storage permissions | File import/export uses Android's document access mechanisms without broad storage permission. |
| ACC-005 | P0 | Reading interaction accessibility | Bookmark control is discoverable and operable by touch and accessibility services, with nonintrusive confirmation. |
| ACC-006 | P0 | E Ink-friendly baseline | Reading remains usable on Android E Ink devices without vendor SDKs; user can select readable high-contrast appearance and avoid unnecessary motion. |
| ACC-007 | P1 | Extended E Ink controls | Optional refresh tuning and animation reduction are exposed only when effective or clearly explained as device-dependent. |

## 4. Behavioral invariants

1. A local book ID is distinct from `(ProviderInstanceId, RemoteBookId)`; title/author matching alone cannot establish identity.
2. Reading status, reading position and download availability are separate states.
3. The reading surface is continuous across the complete spine, not reset per chapter.
4. A bookmark points to a semantic passage, not a viewport pixel or unqualified percentage.
5. A user can deliberately reread or move backward; synchronization must not undo that choice by using maximum progress.
6. Local state is durable and cannot be erased by catalog refresh or unsupported remote operations.
7. EPUB book files are not rewritten merely to store progress or annotations.
8. Provider-specific limitations do not change the fundamental local reader UX.
9. Exact and approximate positions must never be silently conflated.
10. Optional vendor-specific E Ink functionality cannot be required for basic reading.
11. Sorting, grouping and filtering are composable, deterministic and available offline for cached fields.
12. Provider custom fields remain capability-dependent and cannot be confused with local metadata or inferred from unsupported endpoints.

## 5. Product-level synchronization contract

### 5.1 Capabilities

Provider capabilities are independently identified for catalog browsing, downloads, reading position, reading status, shelves, bookmarks and annotations. Capability states are `unknown`, `unsupported`, `readOnly`, `writeOnly` and `readWrite`. A feature may be locally available while remotely unsupported.

### 5.2 Distinct synchronization outcomes

Catalog metadata refresh and reading-position synchronization are independently observable. A successful metadata refresh must not be shown as successful progress synchronization. A failed progress push must not block reading or overwrite the local position. Supported changes are retained until acknowledged or explicitly resolved.

### 5.3 Merge policies

- **Provider-owned metadata:** remote authoritative; preserve user-owned local state.
- **Reading status:** merge with verified revisions when possible; preserve conflicting concurrent edits for resolution.
- **Reading position:** preserve exact locators and precision metadata; never use max percentage as a merge policy; ask for a choice if authoritative ordering cannot be established.
- **Shelves:** local-only unless remote semantics are verified; avoid wholesale replacement of memberships.
- **Bookmarks and annotations:** locally durable; remote synchronization conditional on verified compatible capabilities.

### 5.4 Book identity

Each remote binding is scoped to its provider instance and remote ID. Server refresh, metadata changes and file redownload must not silently attach an existing reading state to an unrelated book.

### 5.5 Position semantics

An **exact** locator identifies a semantic passage and is validated against the book content. An **approximate** locator (for example percentage through the book) may be used only as a fallback, visibly distinguished when restoration accuracy matters. Engine-specific anchors require documented conversion behavior; a failed conversion must not silently claim precision.

## 6. Release acceptance gates

- **P0 completeness:** Every P0 requirement passes automated or documented manual acceptance tests.
- **Book-wide scroll:** Representative EPUB 2/3 books scroll in both directions across 30 consecutive chapter boundaries without forced chapter actions, missing/duplicated text, visible position jumps or interrupted momentum.
- **Bookmarking:** One tap creates a locally durable exact-anchor bookmark while offline; the reader stays in place; reopening and navigating to the bookmark restores the correct passage.
- **Resume:** At least 100 restoration trials spanning app restart, orientation, typography and chapter boundaries; each exact restoration returns to the same passage within one paragraph where technically possible, and any approximate fallback is explicitly identified.
- **Offline durability:** Airplane-mode reading, bookmark/status edits, app termination and subsequent reconnect complete without local data loss.
- **Sync separation:** Simulated catalog success with position-sync failure, and the reverse, report independent outcomes; ambiguous position conflicts preserve both candidates.
- **Identity:** Metadata refresh, server changes and similar titles do not cross-bind local reading states.
- **Reader corpus:** At least 30 EPUBs spanning EPUB 2/3, long books, images, footnotes, Unicode, RTL samples, varied CSS and malformed files are exercised.
- **Performance (provisional):** On named reference hardware, cached typical EPUB reopen p95 ≤ 2 seconds; at least 95% of measured scroll frames meet the device refresh budget; no recurring unbounded memory growth over 30 consecutive chapter transitions. Adjust targets only against documented benchmarks.
- **E Ink:** Core reading and bookmarking work on available Android E Ink hardware without vendor-specific integration; optional refresh controls degrade safely.
- **Security:** No credential exposure in logs or untrusted EPUB content; invalid TLS certificates rejected by default; no unrestricted EPUB script execution.
- **Provider verification:** CWNG capability claims and supported mutations are validated against a real test instance; no unverified two-way synchronization promises.

## 7. Open product questions and validation dependencies

1. **Foliate-js is the chosen primary renderer.** Reader Lab must verify its integration against book-wide cross-chapter scrolling, locator precision, offline operation, performance, security and accessibility gates on representative production-mode Android builds. Selection does not constitute acceptance; failed hard gates require remediation and an explicit architectural decision before release.
2. CWNG API verification must establish which metadata, reading-status, progress, shelf and bookmark operations are actually supported for read/write.
3. Exact cross-engine locator portability and remote approximate-to-exact conversion require evidence before claiming interoperability.
4. Android E Ink refresh support is device-dependent; baseline functionality must remain independent of proprietary SDKs.
5. Optional horizontal pagination remains secondary and must not compromise mandatory continuous scrolling.

## 8. Gap-closure requirements and conventional defaults (v1.3, retained in v1.4)

The following requirements refine existing product behavior. Existing IDs and priorities remain unchanged. These defaults are product decisions, not implementation mandates.

### 8.1 Reader interactions and progress

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| RDR-021 | P0 | Predictable gestures | A single tap on noninteractive central reading content toggles controls; vertical drag/fling scrolls; text links and selection take precedence over control toggling. No edge-tap page turns in continuous mode. Controls can be reopened without obscuring or moving the current passage. |
| RDR-022 | P0 | One-tap bookmark toggle | A visible, accessibility-labeled bookmark action creates a bookmark at the current reading anchor on first tap and removes that same anchor's bookmark on a subsequent deliberate tap; confirmation is unobtrusive and undo is available after removal. It never scrolls the document. |
| RDR-023 | P0 | Bookmark navigation and stale anchors | Bookmark list shows book, chapter/section where available and a short text excerpt where permitted; selecting one returns to its anchor. If an updated EPUB invalidates the anchor, show a clearly labeled approximate fallback or an unresolved bookmark; never silently relocate it as exact. |
| RDR-024 | P0 | Progress display | Reader can show whole-book approximate percentage and current chapter/section where known; values update without blocking scrolling. Percentages are explicitly informational, not canonical locators. |
| RDR-025 | P0 | EPUB replacement behavior | When a book file changes, retain reading state and bookmarks; try exact anchors against the new edition, then documented approximate fallbacks. Report unresolved positions without overwriting original anchors. |
| RDR-026 | P1 | Reading history | Optional local session history records start/end and elapsed active reading time; pauses/background time do not count as active reading. History can be cleared independently of current progress. |
| RDR-027 | P1 | Reading estimates | Optional chapter/book time remaining is labeled as an estimate, based on observed reading pace, and hidden when insufficient data exists. |

**Gesture convention:** On the default continuous reading surface, vertical gestures belong to scrolling. A long press may initiate selection when supported; selecting text or activating links must not accidentally create bookmarks. The bookmark control remains accessible through a single tap after controls are visible, and may be exposed persistently through a user preference. No gesture is the sole path to a critical action.

### 8.2 Reading-status lifecycle

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| LIB-027 | P0 | Conventional automatic status transitions | Default: first meaningful reading activity changes Unread or Want to Read to Reading; opening book details or merely previewing a book does not. Reaching the final passage prompts to mark Completed rather than silently changing status. |
| LIB-028 | P0 | Manual status authority | Manual status changes always take precedence over automatic rules. On Hold, Abandoned and Completed are not automatically reset by reopening; user can change status explicitly at any time. |
| LIB-029 | P0 | Status automation preference | User can disable automatic start transitions in Settings; choice persists offline. Completion prompts can be dismissed without changing status and do not recur on every revisit to the same ending. |

### 8.3 Library and provider lifecycle

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| LIB-030 | P0 | Distinct removal actions | “Remove download” deletes only the local EPUB copy, preserving library entry and reading state. “Remove local import” removes its library entry after confirmation; user is offered an explicit choice to retain or delete associated local state. No action implicitly deletes a remote CWNG book. |
| LIB-031 | P0 | Provider disconnect and reconnect | Disconnecting a provider warns about credentials, cached catalog and downloads; default is to retain downloaded files and local reading state, with an explicit optional data purge. Reconnecting the same verified provider/account restores bindings; a different account never silently inherits them. |
| LIB-032 | P0 | Incomplete metadata and empty states | Missing cover uses a readable placeholder; missing author/series is labeled Unknown/Unassigned; filters and groups handle absent values consistently. Empty library, empty group, no filter matches and offline unavailable catalog show distinct messages and relevant recovery actions. |
| LIB-033 | P0 | Large-library responsiveness | Search, filter, grouping and sorting remain operable on a seeded 5,000-book local catalog without requiring a network call; no UI freeze exceeding 500 ms for a single interaction on the named reference tablet, subject to documented hardware baseline. |
| LIB-034 | P1 | Duplicate edition handling | Local import and remote copy remain distinct until user explicitly links or chooses a preferred edition; candidate matches are suggestions only. Linking cannot silently discard either reading state or annotation set. |
| LIB-035 | P1 | Saved-view invalidation | If a provider or custom metadata field disappears, the saved view remains editable, shows the missing criterion, and never silently broadens its results; user can remove or replace the invalid criterion. |
| LIB-036 | P0 | Multi-valued metadata behavior | A book with multiple authors or multi-valued fields matches any selected value within the dimension, appears in each applicable group when grouping by that field, and is counted once in overall result totals. |

### 8.4 Downloads and synchronization experience

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| LIB-037 | P0 | Download integrity | Incomplete, corrupt or unvalidated EPUBs are never marked Available. Validate basic EPUB structure and expected transfer size/checksum when provided; on failure retain any previously valid copy and present Retry. |
| LIB-038 | P0 | Interrupted download recovery | Interrupted downloads are retryable; resume from partial bytes only if the server supports safe range requests and content identity verification, otherwise restart safely. Storage exhaustion gives a clear error without deleting other books or corrupting state. |
| SYN-017 | P0 | Conflict resolution UX | An unresolved position conflict displays both candidates with available source/device, timestamp, chapter and approximate progress, clearly indicating unknown information. User may choose one or defer; deferral preserves both. No automatic max-percentage winner. |
| SYN-018 | P0 | Initial indexing and refresh feedback | Initial catalog fetch shows incremental progress or indeterminate activity; subsequent refresh leaves cached books accessible. Offline and authentication-expired states show specific recovery actions; neither implies the cached library is lost. |
| SYN-019 | P0 | Independent sync status presentation | Metadata and reading-position sync show separate last-success, pending and error states; failure of one never labels the other failed or successful incorrectly. |

### 8.5 EPUB content accessibility

| ID | Priority | Requirement | Acceptance criteria |
|---|---|---|---|
| ACC-008 | P0 | Accessible book content | EPUB reading order, headings, paragraphs and links are exposed to Android accessibility services where supported by the chosen engine. Reader Lab must test this with TalkBack; limitations must be documented before engine approval. |
| ACC-009 | P0 | Accessible content navigation | Users can traverse links and text in logical order, operate TOC and bookmarks without precision gestures, and retain readable contrast and text scaling. Accessibility focus must not trigger accidental scrolling or bookmarks. |
| ACC-010 | P1 | Read aloud | Optional on-device text-to-speech with pause/resume, adjustable speech rate and sensible chapter continuation; synchronized highlighting is offered only if reliable, and no network service is required for supported installed voices. |

### 8.6 Acceptance scenarios added by v1.3

1. **Gesture precedence:** Tap plain content to toggle controls, activate an EPUB link, select text and scroll across a chapter boundary; each action behaves independently without a surprise page turn or bookmark.
2. **Bookmark round-trip:** Bookmark offline, repeat the action to remove it, undo, restart, navigate back to the bookmark and verify exact-anchor restoration; test an edited/replaced EPUB with an invalid anchor.
3. **Status transitions:** Start an unread book, reach its end, dismiss completion prompt, manually mark On Hold, reopen and verify manual authority; repeat with automatic start disabled.
4. **Removal safety:** Remove a download, disconnect and reconnect the same account, connect a different account, remove a local import and verify each state-retention choice.
5. **Download failures:** Interrupt network, simulate partial transfer and low storage, then retry; a corrupt file is never available as an offline book.
6. **Sync conflicts:** Simulate two devices moving backward and forward independently; compare exact and approximate candidates, defer resolution, restart and confirm both survive.
7. **Metadata edge cases:** Group multi-author books, filter missing metadata, remove a custom column used by a saved view, and verify no silent expansion or data loss.
8. **Accessible reading:** Test TalkBack reading order, headings, links, TOC, bookmark action, text scaling and focus retention on representative EPUB 2/3 content.

**Deferred scope:** Session history, estimates, duplicate edition linking and read-aloud are P1. They are not prerequisites for the first usable release. Vendor-specific e-ink controls, advanced EPUB and complex query expressions retain their previous priorities.

## 9. Cross-document impacts (not edits)


### ARCHITECTURE.md

- Accommodate gesture precedence, status transition preferences, safe removal/retention semantics, validated downloads, content accessibility and user-driven conflict resolution.

- Support typed, provider-neutral metadata field descriptors and locally evaluated composable sort/group/filter semantics; ensure custom-column capabilities can be discovered without assuming CWNG API support.

- Ensure ReaderEngine contracts and renderer benchmark gates cover RDR-001, RDR-015 through RDR-020, including reverse chapter boundaries, momentum, bounded loading and exact bookmark capture.
- Keep metadata and position synchronization independent, with durable local state and precision-aware merge policies.
- Preserve provider-neutral catalog/download contracts and stable provider-instance book bindings.
- Reflect Foliate-js as the selected primary renderer behind the reader abstraction; retain Reader Lab production validation and formal ADR documentation. Do not expose renderer-specific locators or APIs as product-level guarantees.

### IMPLEMENTATION.md

- Add v1.3 acceptance scenarios for gesture precedence, bookmark toggle, manual status authority, download integrity, account disconnect/reconnect and TalkBack content accessibility.

- Add tests for multi-filter composition, deterministic multi-key ordering, nested groups, offline saved views, large libraries, and missing/renamed/multi-valued custom columns.

- Validate the Foliate-js integration in profile/release mode, including book-wide scrolling, 30-boundary traversal, 100 restoration trials, one-tap offline bookmarking, search, accessibility and offline operation as explicit release gates.
- Add tests for independent sync failure, conflict retention, stable identity and exact/approximate locator semantics.
- Test on Android phone/tablet and available E Ink hardware; record device-specific performance baselines.

**Document ownership:** This file specifies product behavior and acceptance criteria. Implementation details and engineering tasks belong exclusively in ARCHITECTURE.md and IMPLEMENTATION.md, respectively.
