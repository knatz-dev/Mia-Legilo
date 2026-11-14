# Reader Lab Report (Phase 2)

**Date:** 2026-11-14
**Renderer:** Foliate-js (commit 22a49acaa120877ede21f713679ab8ba4d1ef663)
**Status:** Pending device measurements

## Device matrix
| Device | Model | OS | Refresh rate | Notes |
|---|---|---|---|---|
| Phone | TBD | TBD | TBD | |
| Tablet | TBD | TBD | TBD | |
| E-ink | TBD | TBD | TBD | optional |

## EPUB corpus
- 30 Project Gutenberg fixtures (see test/fixtures/epub/MANIFEST.md).
- Additional RTL/broken/malformed to be added.

## Measurements
| Metric | Target | p50 | p95 | Result |
|---|---|---|---|---|
| Cold load (typical EPUB) | <=2s reopen | - | - | pending |
| Reopen cached | <=2s | - | - | pending |
| Frame pacing (scroll) | >=95% frames | - | - | pending |
| Memory growth (30 transitions) | no unbounded growth | - | - | pending |

## Cross-chapter scroll
- Transitions both directions: 0/30 completed (pending).
- Discontinuities observed: TBD.

## Semantic restoration
- Trials: 0/100 (pending).
- Exact: TBD, Approximate: TBD, Failed: TBD.

## Accessibility
- TalkBack traversal: pending.
- 48dp touch targets: implemented in ReaderPage.
- Reduced motion: pending.

## Security
- Hostile EPUB tests: pending.
- Bridge attack cases: pending.

## Device run (2026-11-14)
- Profile build: `build/app/outputs/flutter-apk/app-profile.apk` (70.2MB) — built and launched on emulator (sdk gphone64 x86_64, API 35).
- App launched without crash; WebView (Foliate-js) initialized.
- Manual scroll/restoration/accessibility measurements: pending (requires physical device interaction).

## Conclusion
G2 gate pending device evidence.
