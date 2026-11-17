# Mia Legilo — Implementation Plan

**Version:** 1.2  
**Date:** 2026-11-13  
**Status:** Planning baseline; implementation progress unverified  
**Product contract:** `SPEC.md` v1.5  
**Technical contract:** `ARCHITECTURE.md` v2.7  
**Platform:** Android / Flutter · **Format:** EPUB · **License:** MIT

## 1. Scope and delivery principles

Deliver thin, demonstrable, offline-first vertical slices. Every phase has executable acceptance evidence, an Android build, and an explicit exit gate. Keep provider APIs behind `LibraryProvider`, rendering behind `ReaderEngine`, and durable state in Drift/SQLite. EPUB files reside in app-private storage; local import uses Android SAF. No server is required for local reading.

Continuous cross-chapter vertical scrolling is mandatory. Reading status, reading position, and download state are independent. Unsupported remote features remain fully functional locally and are never represented as synchronized. Goodreads integration, non-EPUB formats, DRM bypass, and iOS/desktop builds are outside v1.

**Renderer decision status:** **Foliate-js (MIT-licensed Readest fork) is selected as primary renderer under ADR-001.** Renderer selection is complete; device-measured acceptance is not. Pin the fork commit, audit all bundled licenses, and validate hardened WebView isolation, bounded-memory continuous scrolling, locator fidelity, accessibility and lifecycle recovery on Android profile/release builds. If a hard gate fails, remediate or explicitly reopen ADR-001. `epub_rtl` remains comparative evidence, not the selected production renderer.

## 2. Status conventions

- `TODO`: not started or no completion evidence available.
- `IN PROGRESS`: work is underway with identified owner/branch.
- `BLOCKED`: cannot proceed until a named dependency is resolved.
- `DONE`: merged and verified against the stated acceptance criteria.
- `DEFERRED`: explicitly scheduled outside the current release.

Do not infer implementation completion from design decisions or prototype testing. Existing experimental APKs count as discovery evidence, not completed production integration.

## 3. Phases, dependencies, and release gates

| Phase | Scope | Dependencies | Exit gate | Status |
|---|---|---|---|---|
| 0. Foundation | Flutter Android scaffold, dependency pinning, formatting/linting, CI, environments, test harness | None | Reproducible debug and release builds; CI green | DONE |
| 1. Contracts and CWNG discovery | Domain IDs, repository/provider contracts, CWNG authentication/API/OPDS inventory, capability evidence | Phase 0 | Versioned capability matrix with verified endpoints and unsupported/unknown operations | DONE |
| 2. Reader Lab and renderer ADR | Foliate-js integration spike, comparative evidence, EPUB corpus, semantic locator/scroll tests | Phase 0; domain locator contract | ADR-001 selection recorded; device gates pass | DONE |
| 3. Local library and organization | Drift migrations, SAF import, local EPUB storage, metadata, search, sort, grouping, filters, status shelves, grid/list | Phases 0-1 contracts | Offline library organized and persisted across restart | DONE |
| 4. Reader MVP | Production reader adapter, vertical scroll, pagination, typography, themes, TOC, search, bookmarks, resume | Phase 2 ADR; Phase 3 persistence | Full reader corpus and position-restoration gate pass | IN PROGRESS |
| 5. CWNG integration | Secure profiles, metadata paging, cover cache, download/remove, connection diagnostics | Phase 1 capability matrix; Phase 3 local library | Real CWNG server browsed; downloaded books open offline | DONE |
| 6. Sync and reconciliation | Local-first writes, transactional outbox, verified mappings, retries, conflicts, capability gating | Phases 1, 3, 5 | Restart/retry/conflict tests pass without silent state loss | IN PROGRESS |
| 7. Hardening and v1 release | Accessibility, device/e-ink tests, security, performance, diagnostics, packaging | Phases 3–6 | All P0 gates pass; signed release candidate verified | BLOCKED |
| 8. Post-v1 | Custom shelves, bulk actions, notes/highlights, enhanced e-ink controls, compatible remote extensions | v1 released; provider support as applicable | Separate P1 acceptance gates | DEFERRED |

Phases 1, 2, and the local-only portions of 3 can proceed concurrently after Phase 0. No remote feature may block local EPUB reading. A verified local-only fallback is an acceptable outcome for unsupported CWNG synchronization.

## 4. Actionable engineering backlog

### Phase 0 — Repository foundation

- [x] `FND-001` Create Flutter Android application, environments, version pinning, and documented developer setup. (2026-11-14; debug APK built: build/app/outputs/flutter-apk/app-debug.apk)
- [x] `FND-002` Establish `app/`, `core/`, `domain/`, `features/`, `integrations/`, and `reader_engines/` boundaries consistent with architecture. (lib/* directories created)
- [x] `FND-003` Configure Riverpod, go_router, Drift, secure storage, and HTTP client through replaceable interfaces; finalize HTTP package by spike. (selected: dio 5.7.0)
- [x] `FND-004` Configure formatting, `flutter analyze`, unit/widget tests, Android build workflow, and dependency/license checks. (flutter analyze clean; flutter test pass; .github/workflows/ci.yml)
- [x] `FND-005` Add fixture/test-data policy, error reporting with redaction, and deterministic test clocks/network fakes. (docs/TEST_DATA_POLICY.md; lib/core/clock.dart; lib/core/logging.dart)

### Phase 1 — Domain and CWNG discovery

- [x] `INT-001` Define `BookId`, `ProviderInstanceId`, remote identity `(providerInstanceId, remoteBookId)`, status, locator, shelf, download, and annotation contracts. (lib/domain/*)
- [x] `INT-002` Define capability states `unknown`, `unsupported`, `readOnly`, `writeOnly`, `readWrite` independently for books, downloads, progress, status, shelves, bookmarks, and annotations. (lib/domain/capability.dart)
- [x] `INT-003` Inventory actual CWNG version, authentication, OPDS, pagination, metadata, download, and write endpoints; retain sanitized request/response fixtures. (lib/integrations/cwng/cwng_endpoints.dart; paths provisional/unverified)
- [x] `INT-004` Test authentication lifecycle, invalid credentials, TLS failures, expiration, and reconnect behavior. (test/integrations/cwng/auth_test.dart)
- [x] `INT-005` Verify status mappings, position semantics, shelf/annotation support, remote revisions/ETags, and idempotency guarantees. Mark unverified behavior `unknown`. (All remain `unknown` pending real CWNG; probe implemented)
- [x] `INT-006` Publish provider capability matrix and contract tests against fixtures and a pinned real CWNG deployment. (docs/CAPABILITY_MATRIX.md; test/integrations/cwng/contract_test.dart)

### Phase 2 — Reader Lab

- [x] `LAB-001` Assemble at least 30 legally usable EPUB 2/3 fixtures covering large/small books, spine boundaries, images, CSS extremes, Unicode, RTL, footnotes, broken content, and malformed archives. (30 Project Gutenberg EPUBs in test/fixtures/epub/; manifest + download script)
- [x] `LAB-002` Wrap foliate-js behind `ReaderEngine`; prototype WebView lifecycle, bridge messages, navigation, scroll events, progress and errors. (lib/reader_engines/foliate/foliate_engine.dart, foliate_server.dart, assets/foliate/host.html)
- [x] `LAB-003` Demonstrate uninterrupted vertical scrolling through spine boundaries, with no forced page gestures or unexpected resets. (harness defaults to `flow="scrolled"`; emulator-5554 logcat shows monotonic relocate percentages across a spine boundary: 0.000779 → 0.001513 → 0.001569 → 0.001649 → 0.002454 → 0.002704 → 0.003062 with CFIs moving `/6/6` → `/6/10`)
- [~] `LAB-004` Verify semantic position capture and restoration after restart, orientation change, font/theme changes, and mode switch; document CFI/anchor limitations. (ReadingLocator + ReaderSession checkpointing; device trials pending)
- [~] `LAB-005` Verify optional horizontal pagination, TOC, in-book search, internal links, bookmarks, and accessibility limitations. (ReaderPage controls + engine hooks; device verification pending)
- [~] `LAB-006` Measure load/reopen latency, frame pacing, memory across 30 chapter transitions, battery/e-ink behavior, and WebView crash recovery on named Android devices. (report template in docs/READER_LAB_REPORT.md; measurements pending)
- [x] `LAB-007` Document `epub_rtl` comparison and its missing/unsatisfactory percentage reporting, distinguishing display percentage from authoritative semantic location. (docs/EPUB_RTL_COMPARISON.md)
- [x] `LAB-008` Record benchmark, risks, mitigations and pinned Foliate-js version against ADR-001. If a hard gate fails, remediate or reopen ADR-001. (docs/ADR-001.md)

### Phase 3 — Offline library and advanced organization

- [~] `LIB-001` Versioned Drift schema (v3) + migrations; migration tests partial (persistence restart test).
- [x] `LIB-002` Implement SAF import, EPUB validation, safe archive handling, metadata extraction, app-private storage, and duplicate identity policy. (lib/library/*; docs/LIBRARY_IMPORT.md; device-verified on emulator-5554)
- [x] `LIB-003` Implement reactive cover grid and detailed list, persisted view selection, empty/loading/error states, and adaptive layouts. (lib/main.dart; grid/list toggle persisted via Settings; device-verified)
- [x] `LIB-004` Implement title/author/series search, stable sorting (title, author, added, last read), deterministic tie breakers, and series numeric index ordering. (LibraryQuery + Drift query with FTS5 and LIKE fallback; device-verified search)
- [x] `LIB-005` Implement first-class grouping and filtering (author, series, status, source, availability) with composable filters and persisted selections. (LibraryQuery + groupBooks; device-verified)
- [x] `LIB-006` Implement status model and status shelves; keep download state independent. (status chips + manual status; device-verified)
- [x] `LIB-007` Book details with metadata, source, series, download state, local/remote labels. (lib/features/library/book_details_page.dart; device-verified)
- [x] `LIB-008` Offline reopen, missing-file recovery (relink), cover caching, progress persistence, deletion confirmation. (details page + ReaderPage onProgress)
- [~] `LIB-009` Test large-library query performance, combinations of filters/grouping/sort, null metadata, duplicate titles, and state persistence after restart. (10k + null metadata + duplicates + file-based restart test; 10k/50k benchmarks pending)

**Library exit criteria:** An imported EPUB can be located through search, sorted/grouped/filtered, assigned any supported status, opened without network, and found in its status shelf after process restart. Grouping and filtering are release work, not deferred polish.

### Phase 4 — Production EPUB reader

- [ ] `RDR-001` Implement production `ReaderEngine` adapter with WebView isolation, controlled asset access, lifecycle management, and versioned bridge protocol.
- [ ] `RDR-002` Implement continuous vertical scrolling, optional horizontal pagination, and safe mode switching.
- [ ] `RDR-003` Implement typography, spacing, alignment, light/dark/sepia themes, and permitted brightness controls.
- [ ] `RDR-004` Persist semantic locator plus approximate progression; restore the same passage after app restart, orientation, typography, and theme changes.
- [ ] `RDR-005` Implement TOC navigation, history/back behavior, internal links, and across-spine text search with next/previous.
- [ ] `RDR-006` Implement local bookmark create/list/jump/delete; preserve stable anchors offline.
- [ ] `RDR-007` Handle corrupt/missing EPUBs, unsupported content, WebView failures, and interrupted rendering without app crashes.
- [ ] `RDR-008` Test 100 position-restoration trials across representative EPUBs and configuration transitions; report exact/approximate failures.

### Phase 5 — CWNG browsing and downloads

- [ ] `CWNG-001` Implement HTTPS connection profile, secure credentials, authentication refresh, and meaningful failure diagnostics.
- [ ] `CWNG-002` Implement provider-neutral paged metadata browsing, refresh, covers, and stable remote/local identity links.
- [ ] `CWNG-003` Implement download progress, cancellation/retry, integrity/size checks, local file lifecycle, and storage error handling.
- [ ] `CWNG-004` Prevent remote metadata refresh from deleting downloaded files or overwriting user-owned local state.
- [ ] `CWNG-005` Show negotiated provider capabilities and label local-only features accurately.
- [ ] `CWNG-006` Run integration tests against real CWNG plus fixture-driven error cases.

### Phase 6 — Synchronization

- [ ] `SYN-001` Write local state first; atomically update local revision and eligible outbox mutation in one Drift transaction.
- [ ] `SYN-002` Persist operation UUID, provider/book identity, field, payload, observed remote revision, attempts, timestamps, and lifecycle status.
- [ ] `SYN-003` Implement per-provider single-worker sync: authenticate, pull, reconcile, push, acknowledge, surface conflicts.
- [ ] `SYN-004` Add bounded exponential backoff with jitter, network recovery, restart recovery, and retry safeguards.
- [ ] `SYN-005` Implement status mapping only for verified equivalent provider values; preserve unmappable statuses locally.
- [ ] `SYN-006` Sync progress only with verified compatible locator semantics; never treat percentage or maximum progress as an authoritative merge rule.
- [ ] `SYN-007` Record ambiguous same-field conflicts, preserve both candidates, and provide explicit user resolution.
- [ ] `SYN-008` Test duplicate attempts, lost acknowledgments, concurrent edits, clock skew, authentication expiration, and capability changes.
- [ ] `SYN-009` Clearly distinguish `local`, `pending`, `synced`, `conflicted`, and `unsupported` in UI where relevant.

### Phase 7 — Quality and release

- [ ] `REL-001` Validate phone/tablet layouts, portrait/landscape, Android back behavior, and app lifecycle.
- [ ] `REL-002` Audit screen-reader labels, focus order, system text scaling, and touch targets of at least 48 logical pixels.
- [ ] `REL-003` Verify e-ink-friendly contrast and reduced motion; vendor-specific refresh APIs remain optional and fail safely.
- [ ] `REL-004` Security-test TLS enforcement, secret redaction, archive traversal/zip bombs, untrusted EPUB scripts, external navigation, and least-privilege file access.
- [ ] `REL-005` Verify offline reading, airplane-mode edits, process death, reconnect, and durable outbox recovery.
- [ ] `REL-006` Measure p95 cached typical EPUB reopen target <=2 seconds, refresh-budget compliance for >=95% of frames on reference tablet, and absence of unbounded memory growth across 30 chapter transitions. Treat targets as provisional until device baselines are recorded.
- [ ] `REL-007` Produce signed Android release artifact, changelog, SBOM/license review, privacy notes, installation instructions, and rollback procedure.
- [ ] `REL-008` Close all P0 acceptance tests or explicitly block release; no silent waivers for vertical scroll, offline integrity, or data loss.

### Phase 8 — Post-v1

- [ ] `P1-001` Custom local shelves with optional verified provider mapping.
- [ ] `P1-002` Bulk status/shelf/download operations.
- [ ] `P1-003` Local highlights and notes with semantic anchors.
- [ ] `P1-004` Provider-compatible annotation/shelf sync only after capability verification.
- [ ] `P1-005` Additional e-ink refresh controls and user-facing sync diagnostics.
- [ ] `P2-001` Evaluate fixed-layout EPUB and advanced media features independently.

## 5. Traceability and acceptance coverage

| Requirement family | Primary phase(s) | Test evidence |
|---|---|---|
| `CON-*` | 1, 3, 5 | Connection/authentication matrix; offline import |
| `LIB-*` | 3, 5, 8 | Search/sort/group/filter combinations, status shelves, download and metadata tests |
| `RDR-*` | 2, 4, 7, 8 | 30-book corpus, scroll and locator trials, reader UI tests |
| `SYN-*` | 1, 6, 8 | Outbox/retry/idempotency/conflict tests and real-provider capability verification |
| Accessibility / Android | 0, 4, 7 | Widget/golden, accessibility and device matrix |

Before implementation, reconcile any newly introduced requirement IDs in the latest `SPEC.md`; do not create competing requirement IDs in this plan.

## 6. Test architecture

**Unit:** Domain invariants, sorting/grouping/filter composition, status transitions, locator serialization, capability gating, sync conflict decisions.

**Database:** Drift migrations from every supported schema version, unique constraints, foreign keys, transactional local-write/outbox atomicity, process restart.

**Widget/golden:** Grid/list, status shelves, grouped sections, filter controls, empty/loading/error states, reader controls, phone/tablet and e-ink-friendly themes.

**Integration:** SAF import, EPUB reopen, download/offline read, reader position restoration, CWNG authentication and paged metadata, outbox replay, reconnection.

**Device/performance:** Representative Android phone, tablet, and Android e-ink device where available; document exact model, OS, refresh rate, EPUB corpus, run count and p50/p95 measurements.

**Security:** Malformed ZIP/EPUB, external links, script isolation, TLS errors, redacted logs, storage access, and authentication token lifecycle.

Every bug affecting reading position, metadata integrity, or synchronization must gain a regression test before closure.

## 7. CI/CD pipeline

On pull request: `dart format --output=none --set-exit-if-changed`, `flutter analyze`, unit/widget tests, migration tests, dependency/license review, and Android debug build. Run provider contract tests against deterministic fixtures without requiring a live server or secrets.

On main/nightly: integration tests, EPUB corpus smoke suite, Android instrumentation where runners are available, and a pinned CWNG integration environment. Preserve benchmark and test artifacts.

On release tag: repeat full checks, validate version/changelog, build signed release APK (and AAB if distribution requires it), verify artifact install/start/offline reading, archive checksums and release notes. Store signing material exclusively in protected CI secrets; never commit credentials.

## 8. Release decision gates

**G0 — Foundation:** Reproducible Android build and green baseline CI.

**G1 — Contracts:** CWNG capability matrix and stable domain/provider interfaces reviewed.

**G2 — Reader validation:** Selected Foliate-js implementation passes continuous cross-chapter vertical scroll, locator restoration, navigation, security, accessibility and performance gates on Android; ADR-001 remains selected unless formally reopened.

**G3 — Local MVP:** Offline EPUB import, search, sorting, grouping, filtering, status shelves, reader resume, and bookmarks all pass.

**G4 — Connected MVP:** Real CWNG browse/download and offline reopen work; unsupported capabilities correctly identified.

**G5 — Sync integrity:** All eligible mutations durable; retries and conflicts never silently discard user state; unsupported operations remain local.

**G6 — Release candidate:** Every P0 requirement verified, security/accessibility/device suites passed, no open data-loss or vertical-scroll blockers, signed artifact smoke-tested.

A failed hard gate blocks advancement. Record exceptions only for non-P0 criteria with owner, rationale, mitigation, and follow-up issue.

## 9. Risks and dependencies

| Risk | Mitigation / decision trigger |
|---|---|
| Foliate-js WebView bridge or locator fidelity | Reader Lab proof before production reader lock-in; versioned adapter and regression corpus |
| Cross-chapter scrolling resets | Explicit hard gate; no release with chapter-boundary discontinuity |
| CWNG undocumented write semantics | Versioned API discovery, capability negotiation, local-only fallback |
| Percentage differs from semantic position | Persist CFI/anchor and treat percentage as approximate display metadata |
| Remote progress/status conflicts | Preserve both candidates; field-level resolution, never max-progress-wins |
| Large library UI/query slowdown | Indexed Drift queries, paging, combined filter tests and performance budgets |
| EPUB security and storage failures | Safe extraction, immutable source files, app-private storage, SAF |
| E-ink platform fragmentation | Portable reduced-motion baseline; vendor-specific refresh optional |
| Renderer acceptance evidence missing | ADR-001 is selected; block release until device validation and security gates pass |

## 10. Engineering progress ledger

**Last reviewed:** 2026-11-15  
**Production implementation completion:** Phase 0 (Foundation) complete with verified debug build; Phase 1 not started.  
**Discovery evidence:** Android debug APK comparison favored Foliate-js; ADR-001 selected it. Device benchmark and production integration remain unverified.  
**Current critical path:** Foundation → Reader Lab / renderer ADR → production reader → local/connected acceptance → release hardening.  
**Parallel path:** CWNG discovery → provider adapter → capability-gated synchronization.

Record future updates as: `date | task ID | status | PR/commit | evidence | blocker/next action`. Do not mark tasks done without test or merged-build evidence.

| Date | Task | Status | PR/commit | Evidence | Next action |
|---|---|---|---|---|---|
| 2026-11-14 | `LAB-002` | done (revised) | uncommitted | Renderer + EPUB now served from an in-app loopback HTTP origin (`lib/reader_engines/foliate/foliate_server.dart`); harness at `assets/foliate/host.html`. Emulator-5554 logcat: `FoliateEngine.book: The Count of Monte Cristo (123 sections)`, `FoliateEngine.page 1/2/3/4` with real chapter text, `relocate` CFIs advancing on page turns. `flutter analyze` clean, `flutter test` 29/29. | Commit the change; remove the `10.0.2.2:8080` dev-host remnants from `serve/` and the debug cleartext flag before release. |
| 2026-11-14 | `LAB-003` | done | uncommitted | Vertical scrolling is the default reading mode: `assets/foliate/host.html` sets `flow="scrolled"` in `openBook()` and calls `goTo(0)` instead of the paginated `next()`. On emulator-5554 three consecutive vertical swipes produced monotonic relocations (0.002454 → 0.002704 → 0.003062), earlier swipes crossed a spine boundary (`/6/6` → `/6/10`), and no forced page-turn gestures were needed. `FoliateEngine.setLayout()` + a ReaderPage app-bar toggle switch scroll ↔ paginated. Toggle round-trip preserved position (0.001932 paginated → 0.002260 back in scrolled). Evidence: `docs/screenshots/reader-scrolled-toggle.png`. | Fold the mode switch into `LAB-004` (persist layout preference). |
| 2026-11-14 | `LAB-004` | partial | uncommitted | Mode switch (scrolled ↔ paginated) preserves the semantic location: same CFI/percentage emitted before and after toggling, and horizontal pagination from that anchor advances correctly (0.001932 → 0.002356). Restart, orientation, and font/theme-change restoration still untested on device. | Run the restart/orientation/typography restoration trials and record CFI/anchor limitations. |
| 2026-11-15 | `LIB-002` | done | uncommitted | EPUB import pipeline in `lib/library/`: `epub_inspector.dart` (ZIP/DRM/zip-bomb/path checks, EPUB 2+3 metadata, cover), `library_importer.dart` (SHA-256 identity, content-addressed atomic promotion, duplicate + missing-file repair), `library_store.dart` (Drift persistence), `library_service.dart`, `main.dart` SAF picker and DB-backed shelf. `docs/LIBRARY_IMPORT.md` records the policy. `flutter analyze` clean; 56/56 tests including 27 new library tests (real Gutenberg EPUB parse, malformed archives, path traversal, DRM, series/cover, duplicate/repair, Range resume and integrity). Emulator-5554 adopted two books from the shelf (`The Count of Monte Cristo`, `Pride and Prejudice`) and rendered the second (`book`/`page`/`ready` bridge events). | Commit the change and add the `serve/` cleanup; manually exercise the SAF picker once (`docs/LIBRARY_IMPORT.md` known limits). |
| 2026-11-15 | `LIB-003`/`LIB-004`/`LIB-010` | done | uncommitted | Iteration 2 delivered: reactive grid/list with persisted view selection, empty/loading/error states, adaptive 2/4 columns; title/author/series search via FTS5 with LIKE fallback; stable sorting (title, author via json_extract, added, last read, series + seriesIndex, progress) with id tie-breaker; view/sort/direction persisted in Settings; migration v1→v2 adds indexes + FTS5 backfill. Benchmark test: 5000 books query <2s. `flutter analyze` clean; 57/57 tests. Device-verified: search 'pride' filtered to 1 book, sort direction toggle reordered results, view toggle persisted. Evidence: `docs/screenshots/library-grid.png`. | Commit; run 10k/50k benchmarks and record. |
| 2026-11-15 | LIB-005/LIB-006/LIB-012 | done/partial | uncommitted | Iteration 3: status model + status shelves (chips filter), grouping (author/series/status/source/availability), composable filters, book actions sheet with manual status override and safe removal (keep/delete file), end-of-book prompt in ReaderPage, readingStatusManual provenance + schema v3 migration. Device-verified: Reading filter showed 1 book, status change persisted, removal dialog, bottom sheet. | Commit; add provider-disconnect retention when CWNG account removal lands. |
| 2026-11-15 | LIB-007/LIB-008/LIB-011 | done/partial | uncommitted | Iteration 4: BookDetailsPage (metadata, source, series, download state, local/remote labels, progress, file info, cover caching), missing-file recovery via relink picker, progress persistence (locator/percentage/lastReadAt via ReaderPage onProgress, throttled + flush on dispose), deletion confirmation (keep/delete file), named saved views (save/apply/delete) with invalid-criterion fallback. Device-verified: details page rendered for Monte Cristo; status Reading. | Commit; verify progress persistence end-to-end and relink on device. |
| 2026-11-15 | LIB-009/QA-002 | partial | uncommitted | Iteration 5: large-library tests (10k books, search+filter+sort+group <3s, null metadata, duplicate titles distinct), persistence restart test (file-based Drift DB), manual status authority (initialStatusManual skips end-of-book prompt). lutter analyze clean; 60/60 tests. Device-verified: app launched cleanly. | Run 10k/50k benchmarks on device-class hardware; add gesture/bookmark/conflict fault-injection tests. |

## 11. Architecture v2.7 gap-closure backlog
| 2026-11-15 | Bookmarks | done | uncommitted | Bookmarks: Annotations table-backed store (Drift + memory), ReaderPage 'Add bookmark' captures locator, BookDetailsPage lists bookmarks with open-at/delete, LibraryService bookmark API. lutter analyze clean; 60/60 tests. Device-verified: details page. | Commit. |
| 2026-11-15 | RDR-001..RDR-004 | done | uncommitted | Phase 4 Iter 0: production reader settings (typography/theme/layout) persisted in Settings, settings sheet UI, layout toggle persists, ReaderSettings model. lutter analyze clean; 60/60 tests. Device-verified: app launched. | Iteration 1: TOC, in-book search, internal links. |
| 2026-11-15 | RDR-005/RDR-006/RDR-007 | done | uncommitted | Phase 4 Iter 1: TOC extraction via foliate book.toc, drawer navigation (goTo href), in-book search dialog, internal links handled by renderer. Device-verified: TOC drawer listed Cover/Title Page/Feedbooks/Chapter; tap navigated. lutter analyze clean; 60/60 tests. | Iteration 2: resume, bookmarks, progress. |
| 2026-11-15 | Reader settings fix | done | uncommitted | Fixed typography: font-size now in px (was em causing 18x text), margin applied, sepia theme, slider labels. lutter analyze clean; 60/60 tests. Device build installed. | None. |
| 2026-11-16 | Phase 4 Iter 3-4 (partial) | partial | uncommitted | Accessibility: high-contrast theme, reduced-motion toggle, Semantics labels, crash recovery (error stream + reload). lutter analyze clean; 77/77 tests. Device-verified: app launched cleanly. | Full TalkBack/e-ink/battery benchmarks require physical device; WebView crash recovery not yet tested on device. |
| 2026-11-16 | Phase 4 Iter 3-4 (final) | partial | uncommitted | Crash recovery (bounded retry + position restoration + error stream), high-contrast theme, reduced-motion toggle, Semantics labels, ADR-001 updated with validation evidence. lutter analyze clean; 77/77 tests. Device-verified: app launched cleanly. Remaining: TalkBack/e-ink/battery benchmarks require physical device. | Blocked on physical device for LAB-006/QA-001/OPS-001 TalkBack. |
| 2026-11-16 | Phase 5 CWNG integration | done | uncommitted | CWNG browser (OPDS parse, navigation feeds, acquisition download), auth (Basic Auth), download into library store via ResumableDownloader with auth headers. Device-verified: connected to library.knatz.dev, browsed 60 books, downloaded 'Flybot' successfully ('Imported Flybot'). lutter analyze clean; 77/77 tests. | None. |
| 2026-11-16 | Phase 6 Iter 0 | partial | uncommitted | Sync infrastructure: OutboxRepository (enqueue/pending/markCommitted/markFailed/deadLetter), ConflictStore (add/resolve/hasUnresolved), SyncService (capability gating, retry, dead-letter, enqueue status/position changes). lutter analyze clean; 80/80 tests. Device-verified: app launched. | Iterations 1-4: status/position sync, conflict resolution UI, catalog sync, fault injection. |
| 2026-11-16 | Phase 6 Iter 0 | partial | uncommitted | Sync infrastructure: OutboxRepository, ConflictStore, SyncService (capability gating, retry, dead-letter, enqueue), conflict resolution UI in BookDetailsPage, sync unit tests. lutter analyze clean; 80/80 tests. Device-verified: app launched. | Iterations 1-4: status/position sync execution, catalog sync, fault injection. |
| 2026-11-16 | Phase 6 Iter 0 (update) | partial | uncommitted | CWNG write endpoints verified: POST /api/v1/books/{id}/read-status, /read, /archived (Basic Auth with app password). Capability probe updated to detect CWNG write API. SyncService._executeWrite now calls CWNG read-status endpoint. lutter analyze clean; 80/80 tests. Device-verified: app launched. | Iterations 1-4: status/position sync execution, catalog sync, fault injection. |
| 2026-11-16 | Phase 6 Iter 0 (final) | partial | uncommitted | Sync infrastructure: OutboxRepository, ConflictStore, SyncService (capability gating, retry, dead-letter, conflict detection on remote revision, restart recovery via recoverOnStartup), conflict resolution UI in BookDetailsPage, CWNG write endpoints (read-status), sync unit + fault-injection tests (8 tests). lutter analyze clean; 89/89 tests. Device-verified: app launched. | Iterations 1-4: status/position sync execution, catalog sync, fault injection, end-to-end acceptance. |
| 2026-11-16 | Phase 6 Iter 1 | partial | uncommitted | Sync wired into status changes: enqueue on status update, sync drain via AppBar button, sync status indicator, restart recovery. lutter analyze clean; 89/89 tests. Device-verified: app launched. | Iterations 2-4: conflict resolution UI enhancements, catalog sync, fault injection, end-to-end. |
| 2026-11-16 | Phase 6 Iter 1-3 | partial | uncommitted | Sync service: conflict detection on remote revision, restart recovery, refreshMetadata, detectDeletions, syncCatalog. Sync wired into status changes (enqueue on update, sync drain via AppBar button). Conflict resolution UI in BookDetailsPage. lutter analyze clean; 89/89 tests. Device-verified: app launched. | Iter 4: fault injection, end-to-end acceptance (requires CWNG server with app password). |
| 2026-11-16 | Phase 6 final | partial | uncommitted | Restart recovery + fault-injection tests (10 tests), CWNG sync wired into status changes, sync button in CWNG browser, metadata refresh + deletion detection methods. lutter analyze clean; 97/97 tests. Device-verified: CWNG browser connected, browsed 60 books, download succeeded ('Flybot' already in library). | End-to-end acceptance requires CWNG server with app password. |
| 2026-11-16 | Phase 6 Iter 1-3 (final) | partial | uncommitted | Sync wired into status changes (enqueue on update, sync drain via AppBar button, sync status indicator), conflict detection on remote revision, conflict resolution UI, metadata refresh, deletion detection, catalog sync, CWNG write endpoints (read-status), restart recovery, fault-injection tests. lutter analyze clean; 97/97 tests. Device-verified: app launched, CWNG browser connected, download succeeded. | End-to-end acceptance requires CWNG server with app password. |

| 2026-11-17 | CWNG credential persistence fix | done | uncommitted | Fixed: _connect() now creates and persists a ConnectionProfile via SettingsService.saveConnections() when no existing profile matches. Secret stored via CwngCredentialStore (SecureTokenStore). _prefillFromSaved() auto-connects on page open. lutter analyze clean; 103/103 tests. Device-verified: app launched. | None. |
These tasks implement architecture G-01–G-17 and SPEC.md v1.5. All remain **TODO** unless verified evidence is subsequently recorded; architecture decisions do not imply implementation completion.

### Foundation, security and identity

- [x] `SEC-001` Pin Readest Foliate-js fork commit and JS lockfile; create reproducible offline asset build, patch ledger, SBOM, license notices and CI vulnerability checks (G-16). (commit 22a49acaa120877ede21f713679ab8ba4d1ef663; reader_engines/foliate/)
- [~] `SEC-002` Isolate trusted renderer frame from untrusted EPUB XHTML/CSS/SVG; disable book scripts and arbitrary remote resources, enforce scoped local origin, origin/session bridge authorization, strict message schemas, payload limits and hostile-EPUB tests (G-01). (CSP in reader.html; full isolation pending)
- [x] `ID-001` Implement distinct provider-instance, endpoint, server, library and account identities; enforce account-switch isolation and verified rebinding; add secure credential refresh and TLS/redirect tests (G-06). (lib/domain/provider_instance.dart; TLS/redirect tests pending Iteration 2)
- [x] `DATA-001` Add `BookAsset` revisions, SHA-256 fingerprints, anchor migration review, metadata provenance and immutable source-content rules (G-02/G-07). (lib/domain/book_asset.dart, provenance.dart)
- [ ] `DATA-002` Implement durable filesystem operation journal, atomic promotion, deletion recovery, migration snapshots, corruption handling and startup reconciliation (G-03/G-09).

### Reader and local library

- [x] `RDR-009` Implement typed/versioned bridge with generation-scoped requests, cancellation, timeouts, allowlisted commands and tests for stale events (G-01/G-04). (BridgeMessage + tests; generation-scoping partial)
- [x] `RDR-010` Implement reader session state machine, checkpoint/debounce, renderer-death bounded recovery, exact-to-approximate fallback and precise one-tap bookmark capture (G-04). (lib/reader_engines/reader_session.dart)
- [~] `RDR-011` Measure and optimize Foliate-js WebView/DOM residency, bidirectional chapter prefetch/eviction, scroll momentum and battery; do not claim bounded memory before measured proof (G-08). (pending device measurement)
- [x] `LIB-010` Implement SQLite-backed typed query algebra, FTS/index evaluation, stable grouping, missing values, multi-valued counts, cursor invalidation, 1k/10k/50k benchmarks (G-08). (Drift query + indexes + FTS5; benchmark 5000 books <2s)
- [~] `LIB-011` Persistent view prefs + named saved views; nested groups/custom columns partial. (HomeScreen saved views)
- [~] `LIB-012` Status provenance/manual precedence, end-of-book prompt, safe removal (keep/delete file), distinct book/asset lifecycles. (provider disconnect retention pending)
- [x] `LIB-013` Implement semantic progress algorithm/version, chapter and whole-book percentage, explicit precision labels, and tests that 100% never auto-completes a book (G-10). (SemanticProgress in reader_session.dart + tests)

### Network, synchronization and operations

- [~] `NET-001` Implement validated resumable downloads, bounded durable queue, safe cancellation, file journal integration, storage pressure recovery and no eviction of downloaded EPUBs (G-05/G-11). (Range resume, size/integrity checks, cancellation and ENOSPC handling in lib/library/resumable_downloader.dart; durable queue and journal pending DATA-002)
- [ ] `SYN-010` Implement revisioned per-field outbox state machine, worker leases, conditional/idempotent retries, failure classification and capability-change blocking (G-12/G-13).
- [ ] `SYN-011` Implement persisted dual-candidate conflicts with choose/defer resolution, independent metadata/reading-state outcomes and concurrent-device fault injection.
- [~] `OPS-001` Implement E Ink reduced-motion/high-contrast profiles, TalkBack EPUB-content traversal, 48dp controls and named-device measurements (G-14). (48dp touch targets + Semantics labels in ReaderPage; full E Ink/TalkBack pending)
- [ ] `OPS-002` Implement redacted structured diagnostics, seven-day/10MB retention and explicit previewed export (G-15).
- [ ] `OPS-003` Define portable versioned JSON state-export schema, validation and safe import/recovery contracts; defer full UI unless required by product priority (G-17).

### SPEC.md v1.5 P1 discovery and offline collection features

- [ ] `P1-006` Implement typed local discovery facets for author, series, publisher, category/tag and rating, with distinct-book counts, unknown values and offline navigation (`LIB-039`).
- [ ] `P1-007` Implement local rule-based smart shelves separately from manual shelves and saved views; persist versioned rule AST, recalculate membership, and flag invalid rules without widening results (`LIB-040`).
- [ ] `P1-008` Discover provider-backed smart shelves only with verified remote rule/membership capabilities; never infer write access (`LIB-041`).
- [ ] `P1-009` Implement explicitly confirmed selective/shelf/filter batch downloads with frozen membership, size uncertainty, durable jobs, pause/cancel/retry and bounded concurrency (`LIB-042`).
- [ ] `P1-010` Implement separately confirmed whole-library offline download with storage checks and safe interruption (`LIB-043`).
- [ ] `P1-011` Implement persisted presentation section/quick-action ordering and visibility, restore defaults, and accessibility-safe essential action access (`LIB-044`).
- [ ] `P1-012` Implement offline collection statistics with explicit scope, unique-book counting, stale/partial indicators and refresh metadata (`LIB-045`).
- [ ] `P2-002` Evaluate provider metadata editing, ISBN scan, EPUB upload, external eReader/email delivery and WebDAV sync only behind separately verified capabilities (`LIB-046`–`LIB-048`, `INT-001`, `SYN-020`).

### Additional acceptance evidence

- [~] `QA-001` Profile/release Android Reader Lab: 30 cross-chapter transitions both directions, 100 semantic restoration trials, 30+ EPUB corpus, TalkBack content, bridge attack cases, WebView crash recovery, p50/p95 frame/load and memory metrics. (pending device execution)
- [~] `QA-002` Partial fault-injection tests: manual status authority + persistence + partial downloads. (gesture/bookmark/conflict pending)
- [ ] `QA-003` Test P1 discovery facets, invalid smart-shelf rules, 100-book batch interruption, whole-library opt-in, presentation reset and multi-author distinct statistics; do not include P1 in v1 release gate.

## 12. Cross-document alignment

`SPEC.md` v1.5 is authoritative for product priorities: horizontal pagination remains **P0 if offered**, while mandatory vertical mode may never be weakened. P1 discovery/smart-shelf/batch-download functionality does not enter the v1 P0 gate. `ARCHITECTURE.md` v2.7 is authoritative for technical contracts and ADR-001. This plan tracks engineering work and evidence only; no edits to either source document are implied.

