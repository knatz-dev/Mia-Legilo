# Mia Legilo — Implementation Plan

**Version:** 1.1  
**Date:** 2026-11-10  
**Status:** Planning baseline; implementation progress unverified  
**Product contract:** `SPEC.md`  
**Technical contract:** `ARCHITECTURE.md`  
**Platform:** Android / Flutter · **Format:** EPUB · **License:** MIT

## 1. Scope and delivery principles

Deliver thin, demonstrable, offline-first vertical slices. Every phase has executable acceptance evidence, an Android build, and an explicit exit gate. Keep provider APIs behind `LibraryProvider`, rendering behind `ReaderEngine`, and durable state in Drift/SQLite. EPUB files reside in app-private storage; local import uses Android SAF. No server is required for local reading.

Continuous cross-chapter vertical scrolling is mandatory. Reading status, reading position, and download state are independent. Unsupported remote features remain fully functional locally and are never represented as synchronized. Goodreads integration, non-EPUB formats, DRM bypass, and iOS/desktop builds are outside v1.

**Renderer decision status:** User testing of Android debug APKs favors **foliate-js**; `epub_rtl` was promising but did not report percentage progress satisfactorily. Prioritize foliate-js as the primary integration candidate. Keep the formal Reader Lab validation and renderer-selection ADR open until documented acceptance results are complete. The source documents currently identify renderer selection as ADR-004; prior conversation references ADR-001. Resolve the identifier discrepancy in the architecture decision index before merging an ADR, without renumbering silently.

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
| 0. Foundation | Flutter Android scaffold, dependency pinning, formatting/linting, CI, environments, test harness | None | Reproducible debug and release builds; CI green | TODO |
| 1. Contracts and CWNG discovery | Domain IDs, repository/provider contracts, CWNG authentication/API/OPDS inventory, capability evidence | Phase 0 | Versioned capability matrix with verified endpoints and unsupported/unknown operations | TODO |
| 2. Reader Lab and renderer ADR | Foliate-js integration spike, comparative evidence, EPUB corpus, semantic locator/scroll tests | Phase 0; domain locator contract | All hard reader gates pass; ADR accepted or remediation documented | TODO |
| 3. Local library and organization | Drift migrations, SAF import, local EPUB storage, metadata, search, sort, grouping, filters, status shelves, grid/list | Phases 0–1 contracts; independent of remote API | Offline library organized and persisted across restart | TODO |
| 4. Reader MVP | Production reader adapter, vertical scroll, pagination, typography, themes, TOC, search, bookmarks, resume | Phase 2 ADR; Phase 3 persistence | Full reader corpus and position-restoration gate pass | BLOCKED |
| 5. CWNG integration | Secure profiles, metadata paging, cover cache, download/remove, connection diagnostics | Phase 1 capability matrix; Phase 3 local library | Real CWNG server browsed; downloaded books open offline | TODO |
| 6. Sync and reconciliation | Local-first writes, transactional outbox, verified mappings, retries, conflicts, capability gating | Phases 1, 3, 5 | Restart/retry/conflict tests pass without silent state loss | BLOCKED |
| 7. Hardening and v1 release | Accessibility, device/e-ink tests, security, performance, diagnostics, packaging | Phases 3–6 | All P0 gates pass; signed release candidate verified | BLOCKED |
| 8. Post-v1 | Custom shelves, bulk actions, notes/highlights, enhanced e-ink controls, compatible remote extensions | v1 released; provider support as applicable | Separate P1 acceptance gates | DEFERRED |

Phases 1, 2, and the local-only portions of 3 can proceed concurrently after Phase 0. No remote feature may block local EPUB reading. A verified local-only fallback is an acceptable outcome for unsupported CWNG synchronization.

## 4. Actionable engineering backlog

### Phase 0 — Repository foundation

- [ ] `FND-001` Create Flutter Android application, environments, version pinning, and documented developer setup.
- [ ] `FND-002` Establish `app/`, `core/`, `domain/`, `features/`, `integrations/`, and `reader_engines/` boundaries consistent with architecture.
- [ ] `FND-003` Configure Riverpod, go_router, Drift, secure storage, and HTTP client through replaceable interfaces; finalize HTTP package by spike.
- [ ] `FND-004` Configure formatting, `flutter analyze`, unit/widget tests, Android build workflow, and dependency/license checks.
- [ ] `FND-005` Add fixture/test-data policy, error reporting with redaction, and deterministic test clocks/network fakes.

### Phase 1 — Domain and CWNG discovery

- [ ] `INT-001` Define `BookId`, `ProviderInstanceId`, remote identity `(providerInstanceId, remoteBookId)`, status, locator, shelf, download, and annotation contracts.
- [ ] `INT-002` Define capability states `unknown`, `unsupported`, `readOnly`, `writeOnly`, `readWrite` independently for books, downloads, progress, status, shelves, bookmarks, and annotations.
- [ ] `INT-003` Inventory actual CWNG version, authentication, OPDS, pagination, metadata, download, and write endpoints; retain sanitized request/response fixtures.
- [ ] `INT-004` Test authentication lifecycle, invalid credentials, TLS failures, expiration, and reconnect behavior.
- [ ] `INT-005` Verify status mappings, position semantics, shelf/annotation support, remote revisions/ETags, and idempotency guarantees. Mark unverified behavior `unknown`.
- [ ] `INT-006` Publish provider capability matrix and contract tests against fixtures and a pinned real CWNG deployment.

### Phase 2 — Reader Lab

- [ ] `LAB-001` Assemble at least 30 legally usable EPUB 2/3 fixtures covering large/small books, spine boundaries, images, CSS extremes, Unicode, RTL, footnotes, broken content, and malformed archives.
- [ ] `LAB-002` Wrap foliate-js behind `ReaderEngine`; prototype WebView lifecycle, bridge messages, navigation, scroll events, progress and errors.
- [ ] `LAB-003` Demonstrate uninterrupted vertical scrolling through spine boundaries, with no forced page gestures or unexpected resets.
- [ ] `LAB-004` Verify semantic position capture and restoration after restart, orientation change, font/theme changes, and mode switch; document CFI/anchor limitations.
- [ ] `LAB-005` Verify optional horizontal pagination, TOC, in-book search, internal links, bookmarks, and accessibility limitations.
- [ ] `LAB-006` Measure load/reopen latency, frame pacing, memory across 30 chapter transitions, battery/e-ink behavior, and WebView crash recovery on named Android devices.
- [ ] `LAB-007` Document `epub_rtl` comparison and its missing/unsatisfactory percentage reporting, distinguishing display percentage from authoritative semantic location.
- [ ] `LAB-008` Record benchmark, risks, mitigations, selected engine/version, and accepted ADR. If a hard gate fails, remediate or reopen selection.

### Phase 3 — Offline library and advanced organization

- [ ] `LIB-001` Implement versioned Drift schema and migration tests for books, authors, series, provider links, reading states, downloads, shelves, annotations, outbox, conflicts, and settings.
- [ ] `LIB-002` Implement SAF import, EPUB validation, safe archive handling, metadata extraction, app-private storage, and duplicate identity policy.
- [ ] `LIB-003` Implement reactive cover grid and detailed list, persisted view selection, empty/loading/error states, and adaptive layouts.
- [ ] `LIB-004` Implement title/author/series search, stable sorting (title, author, added, last read), deterministic tie breakers, and series numeric index ordering.
- [ ] `LIB-005` Implement **first-class grouping and filtering**: author, series, reading status/shelf, source and local availability where metadata supports them. Combine search, sorting, grouping, and multiple filters consistently; preserve user selections.
- [ ] `LIB-006` Implement status model `Unread`, `Want to Read`, `Reading`, `Completed`, `On Hold`, `Abandoned` and corresponding status shelves; keep download state independent.
- [ ] `LIB-007` Implement book details with available metadata, source, series navigation, download availability, and clear local/remote state labels.
- [ ] `LIB-008` Implement offline reopen, missing-file recovery, cover caching, local state persistence, and deletion confirmation.
- [ ] `LIB-009` Test large-library query performance, combinations of filters/grouping/sort, null metadata, duplicate titles, and state persistence after restart.

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

**G2 — Reader selection:** Foliate-js (or documented alternative) passes continuous cross-chapter vertical scroll, locator restoration, navigation, and performance gates; accepted renderer ADR.

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
| Architecture ADR numbering conflict | Reconcile ADR-001 vs ADR-004 reference before decision record merge |

## 10. Engineering progress ledger

**Last reviewed:** 2026-11-10  
**Production implementation completion:** Not verified.  
**Discovery evidence:** Android debug APK comparison favored foliate-js; `epub_rtl` had deficient percentage reporting.  
**Current critical path:** Foundation → Reader Lab / renderer ADR → production reader → local/connected acceptance → release hardening.  
**Parallel path:** CWNG discovery → provider adapter → capability-gated synchronization.

Record future updates as: `date | task ID | status | PR/commit | evidence | blocker/next action`. Do not mark tasks done without test or merged-build evidence.

## 11. Cross-document change requests (do not edit here)

**`ARCHITECTURE.md`:** Record foliate-js as preferred candidate or selected renderer only after formal ADR acceptance; clarify WebView bridge and asset isolation; reconcile renderer ADR numbering (`ADR-001` versus `ADR-004`); ensure library grouping/filtering query strategy and persistence are covered.

**`SPEC.md`:** Verify that grouping, multi-filter combinations, persisted organization preferences, and stable sort behavior have explicit requirement IDs and acceptance tests. If newer approved requirements already cover them, use those IDs instead of adding duplicates. Preserve the distinction between approximate percentage and semantic locator, and between local-only and remotely synchronized state.

These are impact notices only. `SPEC.md` and `ARCHITECTURE.md` remain separate authoritative documents.
