# Mia-Legilo design-system audit

## Verdict

The literary visual direction is established, but the artifacts are not yet a consistent, accessible implementation contract. Resolve token authority, essential contrast, interaction semantics and the 48-logical-pixel control contract before translating these screens into Flutter.

This is an audit, not a redesign. No existing designs or requirements were changed.

## Scope and method

- Inventory: **24 design directories: 21 HTML mockups, 21 paired PNGs and 3 theme DESIGN.md files**. Earlier conversational counts of 24/26 screens were incorrect.
- All HTML files were inspected programmatically for token definitions and exact HTML attributes. All three theme definitions were compared with screen configurations. Product requirements were cross-checked against SPEC.md, ARCHITECTURE.md and IMPLEMENTATION.md.
- Browser sample: Chromium at 390 × 844 CSS pixels, serving the local mockups over loopback HTTP. axe-core 4.10.3 checked WCAG 2 A/AA, 2.1 AA and 2.2 AA tags on library home, advanced filters, ivory appearance and dark appearance. Keyboard and computed-style checks supplemented automation.
- Two supplied PNGs were sampled for visual context, not treated as accessibility evidence or proof of current HTML behavior. No exhaustive screenshot comparison was performed.
- Raw sampled axe violations, incomplete checks, measured button rectangles and the complete HTML inventory are in [design-audit-evidence.json](design-audit-evidence.json). Counts below concern artifacts, not production-app defects.
- No Flutter implementation was present in the inspected project. Android TalkBack, WebView integration, E Ink hardware, text scaling, landscape/tablet reflow, offline rendering and a full visual-regression suite remain untested. This is **not a WCAG conformance certification**.

References below are relative to the repository root. `stitch_design/<screen>/code.html:L` identifies a source line; several token configurations are intentionally minified onto one line.

## Priority findings

### 1. High — Undefined tokens cause visible rendering failures

The advanced filter and tactile bottom-sheet showcase use `paper-surface`, `ink-charcoal`, `ink-muted`, `sage-accent`, `ochre-accent` and `border-ink`, but do not define those colors in their Tailwind configurations. These are not Tailwind built-in names.

Evidence:

- `stitch_design/advanced_library_filtering_sheet/code.html:29` applies `bg-paper-surface` to the sheet; lines 35–39 use additional missing ink/accent tokens.
- Its configuration at line 4 instead provides a different Material-style palette. Browser inspection returned `paper-surface: null`, sheet background `rgba(0, 0, 0, 0)` and body background `rgb(249, 249, 250)`.
- `stitch_design/mia_legilo_sketchcn_tactile_bottom_sheets_showcase/code.html` repeats the same missing-token vocabulary. Static inspection confirmed absence from its configuration; this second screen was not browser-tested.

Impact: a screenshot cannot serve as an executable specification when current source silently falls back to transparent backgrounds or inherited text colors.

Recommendation: select an authoritative semantic palette, restore every referenced token, and make undefined custom token references a failing validation check. Do not merely copy enough hex values to make one screen look correct.

### 2. High — Essential text fails contrast in the intended palette

WCAG 1.4.3 requires 4.5:1 for normal text. The 3:1 large-text allowance starts at 18pt (24 CSS px), or 14pt bold (approximately 18.67 CSS px); it does not apply to the small labels here.

| Actual or specified pairing | Ratio, rounded | Evidence |
|---|---:|---|
| Selected “All” chip: `#FAF8F2` on `#83917A` | 3.14:1 | Library home line 36, rendered axe failure at 12px |
| “Read today at 2:15 PM”: `#C87D55` on `#F2EBE0` | 2.72:1 | Library home line 67, rendered axe reports 2.71 with its truncation |
| Sepia muted text: `#7e6c56` on `#f6efdf` | 4.40:1 | Warm library token pairing; calculated, not independently rendered |
| Sepia muted text: `#7c6f5d` on `#f7f1e3` | 4.35:1 | Warm appearance token pairing; calculated, not independently rendered |

The light theme's own component guidance prescribes low-contrast accent text and selected-chip colors (`literary_notebook_tactile/DESIGN.md:209–212`). This needs correction at the design-system level, not just in markup.

The sampled dark appearance screen's axe contrast flag concerns a low-opacity decorative `§1`. Decide whether it is meaningful: give it sufficient contrast if meaningful, or exclude it from accessibility semantics if purely decorative. Do not equate this flag with a failure of the main dark reading text.

Recommendation: distinguish decorative accent, accent-text and on-accent tokens. Candidate light-theme text colors `#a8563e` and `#5D6B55` give approximately 4.86:1 and 5.34:1 on `#FAF8F2`; validate them on every intended surface before adoption. Check composited opacity, focus, selected and disabled states separately. Do not reduce opacity on essential metadata without checking the final foreground/background combination.

### 3. High — Control sizes violate the project's own 48-pixel requirement

The product contract is stronger than the generic web AA minimum: SPEC.md:148 (ACC-001), ARCHITECTURE.md:252 and IMPLEMENTATION.md:123 require at least 48 logical pixels. The light design guide explicitly permits a smaller visual shape only with expanded hit areas (`literary_notebook_tactile/DESIGN.md:184`).

Rendered examples at the sampled viewport:

- Library chips are 36px high; grid/list buttons are 32 × 32px.
- Reader appearance close button is 40 × 40px; typeface buttons are 40px high and line-spacing buttons are 44px high.
- The library search trailing button shrinks to approximately 36.9px wide despite its `w-12` class.
- Advanced-filter backspace is 16 × 24px. axe also reports insufficient spacing, so this specific target fails WCAG 2.2 AA 2.5.8, not just the project's 48px contract.

Source anchors: library home lines 36–52 and 113–126; appearance lines 48–51 and 130 onward; advanced filters input/clear area at line 204 onward.

Recommendation: define minimum interactive bounds separately from icon/visual size; prevent flex shrinking of icon buttons and test hit regions, not just class names. Port the contract to Flutter logical pixels. A control smaller than 44px is not automatically a WCAG 2.1 AA failure: 44px is the enhanced target-size criterion; WCAG 2.2 AA generally uses 24px with exceptions. Report the actual standard and product requirement separately.

### 4. High — Missing image alternatives and zoom restrictions

Exact HTML parsing found **35 images across seven mockups, all without an `alt` attribute**. They use `data-alt`, which is not a text alternative. Browser axe confirmed all seven library-home images as failures; see library home line 74 and lines 137 onward.

**18 of 21 mockups** include `user-scalable=no` or `maximum-scale=1.0`; axe flagged the viewport restriction in all four sampled screens. For example, library home line 3. Browser handling varies; the markup restriction is confirmed, not a claim that every browser will honor it.

Recommendation: use concise meaningful cover alternatives where needed, or empty `alt` when the cover duplicates an already-labeled book link. Do not copy long image-generation prompts into spoken labels. Remove viewport zoom restrictions and specify Android system text-scaling behavior independently. Ensure Flutter book cards expose coherent semantics rather than duplicate announcements.

### 5. High — Focus and selection semantics are not consistently represented

Confirmed keyboard defect: Tab on advanced filters focuses `#clear-all-btn`, but computed outline is transparent and box shadow is `none`. The control uses `focus:outline-none` at line 50 with no replacement indicator. Other outline removals occur at lines 204, 362 and 367 and require the same review.

Appearance theme, font and line-spacing choices are ordinary buttons without selected-state semantics (`aria-pressed`, radio role or `aria-checked`). The browser accessibility snapshot exposes all three theme-card names with “check”, including unselected choices, because visually hidden check glyphs are not semantically hidden. Source: `reader_appearance_sketchcn_bottom_sheet/code.html:129–151,336–387`.

The bookmark toggle uses `data-active` rather than an exposed pressed state, while its toast is updated through `innerHTML` (`immersive_reader_controls_active/code.html:14–33,86,101`). Its announcement and undo behavior need explicit design coverage under RDR-022.

Recommendation: specify visible focus tokens, semantic selection states and meaningful action names. Use native buttons/radios or equivalent Flutter semantics. Hide decorative Material Symbol ligatures from assistive technology; provide status announcements for consequential changes. Keep controls reachable without precision gestures.

Correction to preliminary analysis: absence of custom `focus:` classes does not prove missing focus; native browser indicators can remain. Earlier regex counts are not used as a conformance finding.

### 6. High — Sheet behavior is a demo, not an accessible modal contract

The ivory appearance sheet has no dialog role; its Close action translates the sheet offscreen and restores it after 800ms. Clicking Close and pressing Escape left it visible again with focus still on Close. The source explicitly implements this demo behavior at `reader_appearance_sketchcn_bottom_sheet/code.html:390–401`.

The group-books mockup does declare a dialog, so the problem is inconsistency, not a universal absence of dialog markup.

Recommendation: document modal versus nonmodal presentation, initial focus, dismissal, focus return and background interaction. For modal sheets, implement focus containment without trapping users permanently. Map dismissal to Android Back as well as visible controls. The sorting mock's drag handles also need a non-drag reorder alternative before implementation; its reset/apply functions currently only animate (`sort_books_multi_level_sorting_sheet/code.html:111,151,244–272`).

### 7. Medium — Theme specifications disagree internally and across screens

Intentional light/dark/sepia differences are legitimate. The problem is that there is no declared authority for differences *within* a theme or between structured tokens and prose.

Examples:

- Warm DESIGN.md frontmatter declares surface/background `#fff8ef` (lines 4 and 48), while prose uses canvas `#f4ecd8` (line 159). Warm library uses paper `#f6efdf`; warm appearance uses paper `#f7f1e3` and background `#f5edd6`.
- Obsidian frontmatter declares background `#141311`; prose prescribes `#191816` (`obsidian_night/DESIGN.md:146`). The reader screen separately uses `#181715`.
- Light DESIGN.md sets `rounded.full` to `9999px`, `lg` to `0.5rem`, `xl` to `0.75rem` (lines 127–133). Sixteen screen configurations instead override `full` to `0.75rem`, `lg` to `0.25rem`, `xl` to `0.5rem`.
- Light guidance rejects frosted blur (`literary_notebook_tactile/DESIGN.md:188`), but library home line 9 uses `backdrop-blur-xl` and a translucent fixed header.

Recommendation: designate primitive, semantic and component-token layers; document allowed theme overrides and rendering surfaces. Introduce separate circle/pill/card/sheet radii rather than overloading `full`. Consolidate elevation and border tokens, including the intentional organic corner variants. Treat missing per-screen custom values as defaults, not automatically as defects.

### 8. Medium — Typography and preview behavior lack a stable contract

Light guidance intentionally pairs Newsreader with Plus Jakarta Sans; warm and dark prose prescribe all-Newsreader typography. That choice may be valid, but needs explicit separation of app chrome typography from user-controlled EPUB typography. The advanced filter and tactile sheet configs introduce Inter, and dark appearance mixes Newsreader with Plus Jakarta Sans for smaller labels.

More concretely, the ivory appearance demo labels a size as “18pt” while setting 18 CSS px (`reader_appearance_sketchcn_bottom_sheet/code.html:300–306`). Clicking Literata, then using Tab/Enter to select Spectral, updated the stats to “Spectral • 18pt” while computed font remained Newsreader. Its font handler changes only the label/state variable; `updateSpecimen` never applies the selected font family.

The same sheet says “Auto-saved” at line 44 but offers “Apply to The Dispossessed” at line 281. Specify whether adjustments are immediate, preview-only, per-book or global, and what Reset and dismissal persist.

Recommendation: name units explicitly, define font fallback and offline assets, separate reader preferences from UI tokens, and ensure preview, persisted value and actual renderer agree. Preserve the semantic reading locator across changes as required by SPEC.md RDR-004 and IMPLEMENTATION.md:93. Arbitrary `text-[...]` classes include icon sizes and are not all off-scale text defects.

### 9. Medium — Motion/E Ink and cross-runtime theme mapping need design coverage

No HTML mockup contains a `prefers-reduced-motion` or Tailwind motion-reduction branch. Several sheet and button demos animate transforms; appearance dismissal is one verified example. This absence alone is not a universal WCAG AA failure, but the product explicitly requires an E Ink-friendly baseline and avoidable motion (SPEC.md:153; ARCHITECTURE.md:250).

Flutter chrome and the Foliate-js WebView need a common semantic appearance contract, not direct reuse of Tailwind markup. Define which colors, typography, contrast preference and motion settings cross the Dart–JavaScript boundary, how they override book styles safely, and how offline assets are loaded.

Recommendation: produce a theme matrix covering chrome, reader and overlays; define an E Ink presentation profile; generate Dart theme extensions and reader CSS variables from a shared token source if feasible. Use Flutter widget/golden/semantics tests plus WebView tests. A React component library or Storybook is not inherently required for this project.

### 10. High before implementation — State coverage is behind product requirements

The library's “Calibre Synced” badge is a single undifferentiated success label (`mia_legilo_library_home/code.html:19`). SPEC.md:179 and SYN-019 at line 266 require independent metadata and reading-position sync outcomes. The current visual does not specify how metadata-success/position-failure, pending local writes or unsupported provider capabilities are distinguished.

Create a state matrix rather than assuming a happy-path screen covers the product contract:

- Metadata and position: independent last-success, pending, offline/auth-expired, failure and conflict states; preserve readable cached content.
- Library: empty library, no matches, missing metadata/cover and unavailable offline catalog (LIB-032).
- Downloads: queued, downloading, interrupted, corrupt, storage-full and retry; never imply Available before validation (LIB-037/038).
- Reader/bookmarks: unresolved or approximate anchors, removal undo, font-loading failure, persistent accessible control entry and nonintrusive status (RDR-022/023/025, ACC-005/008/009).
- Provider capability-dependent actions: explicitly local-only, read-only or unavailable rather than presenting every action as remotely supported.

The control showcase already includes useful “Unpacking OPF,” “Server Offline,” “Indexing,” “Read Only” and “Unavailable” specimens (`interactive_controls_button_showcase/code.html:475,484,521,530,576`). Preserve these; the gap is their mapping into actionable screen-level recovery flows, not a total absence of non-happy-path styling. Import recovery should explain Android document access and cancellation/access loss without adding broad-storage-permission onboarding (ACC-004).

The shelves footer also says “All shelves synced locally with OPDS Calibre” (`mia_legilo_reading_shelves/code.html:310`). Clarify local persistence versus supported remote shelf synchronization rather than making a blanket claim.

These are design coverage gaps, not claims that a nonexistent production app loses data. IMPLEMENTATION.md already requires these areas to be tested, including empty/loading/error widget states at line 158. Connect those obligations to named component variants and acceptance evidence.

### 11. Medium — Audio controls imply unapproved integration scope

Book details expose a seemingly available “Whispersync” button (`mia_legilo_book_details_obsidian_dark/code.html:220–223`); advanced filters offer “Has Synchronized Audio Narration” with “M4B / WhisperSync manifest” (`advanced_library_filtering_sheet/code.html:179–189`). SPEC.md:18 fixes the initial format to EPUB, while ACC-010 at line 274 describes optional P1 on-device TTS, not this integration.

Recommendation: remove these controls from the release reference or explicitly mark them exploratory/out of scope. Any future audio/provider integration needs an approved capability contract before the UI suggests it is available.

## What already works as a foundation

- Strong recurring literary motifs: warm paper, serif reading text, book-spine treatments, ribbon bookmarks and tactile controls.
- Light/dark/sepia direction and reusable component families are already represented: book cards, chips, navigation, sheets, selectors and reader controls.
- Semantic on-surface/surface token calculations show strong baseline reading-text contrast; accent and metadata uses are the larger contrast risk.
- Some icon controls already have meaningful accessible labels; appearance size controls provide native increment/decrement buttons. Do not describe its decorative slider as the only input route.
- Product docs already require 48px targets, TalkBack, offline behavior, semantic position preservation, E Ink checks and widget/golden testing. The needed work is to make the design artifacts satisfy and demonstrate those contracts.

## Recommended implementation order and acceptance checks

1. **Establish authority:** choose canonical theme tokens and document deviations. Add a token reference validator; resolve all missing custom references. Generate or import shared values instead of copying per screen.
2. **Fix essential accessibility:** contrast-tested text pairs, 48px hit bounds, image semantics, meaningful selected states, visible focus and scalable layouts. Re-run the same browser samples and keep incomplete/manual checks visible.
3. **Specify component behavior:** modal sheets, selection groups, bookmark feedback/undo, sorting reorder alternatives and appearance preview/persistence. Document default, focus, pressed, selected, disabled, loading and error states where applicable.
4. **Complete state coverage:** map each sync/download/empty/error variant to existing requirement IDs without creating competing IDs.
5. **Validate the real platform:** test Flutter and WebView together on phone/tablet, portrait/landscape, system text scaling, keyboard and TalkBack, offline and E Ink profiles. Include semantic-locator restoration after appearance changes. Add golden baselines and review ownership for token changes.

Do not approve production accessibility from these mockups or from an axe pass alone. Keep the exported HTML as reference material until visual, behavioral and semantic contracts are reconciled.

## Automated sample summary

| Screen | axe rule groups with violations | Node counts by rule |
|---|---|---|
| Library home | contrast, title, image alt, viewport | 6 / 1 / 7 / 1 |
| Advanced filters | contrast, title, viewport, target size | 2 / 1 / 1 / 1 |
| Ivory appearance | contrast, title, viewport | 6 / 1 / 1 |
| Dark appearance | contrast, title, viewport | 1 / 1 / 1 |

The missing titles are defects in the standalone HTML reference pages, not automatically Flutter defects. Decorative-content review and axe incomplete checks still require human judgment. Raw evidence contains the failing selectors and exact axe messages; no global pass percentage is claimed.
