---
name: Obsidian Night
colors:
  surface: '#141311'
  surface-dim: '#141311'
  surface-bright: '#3a3936'
  surface-container-lowest: '#0f0e0b'
  surface-container-low: '#1c1b19'
  surface-container: '#21201c'
  surface-container-high: '#2b2a27'
  surface-container-highest: '#363531'
  on-surface: '#e6e2dd'
  on-surface-variant: '#c4c8be'
  inverse-surface: '#e6e2dd'
  inverse-on-surface: '#32302d'
  outline: '#8e9289'
  outline-variant: '#444841'
  surface-tint: '#b8ccb0'
  primary: '#b8ccb0'
  on-primary: '#243520'
  primary-container: '#83967c'
  on-primary-container: '#1e2e1a'
  inverse-primary: '#51634c'
  secondary: '#ffb5a0'
  on-secondary: '#5b1a07'
  secondary-container: '#7c321d'
  on-secondary-container: '#ffa085'
  tertiary: '#b9ccb1'
  on-tertiary: '#253422'
  tertiary-container: '#84967e'
  on-tertiary-container: '#1e2d1b'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#d4e9cb'
  primary-fixed-dim: '#b8ccb0'
  on-primary-fixed: '#101f0d'
  on-primary-fixed-variant: '#3a4b35'
  secondary-fixed: '#ffdbd1'
  secondary-fixed-dim: '#ffb5a0'
  on-secondary-fixed: '#3b0900'
  on-secondary-fixed-variant: '#79301b'
  tertiary-fixed: '#d5e8cd'
  tertiary-fixed-dim: '#b9ccb1'
  on-tertiary-fixed: '#101f0e'
  on-tertiary-fixed-variant: '#3b4b37'
  background: '#141311'
  on-background: '#e6e2dd'
  surface-variant: '#363531'
typography:
  display-lg:
    fontFamily: Newsreader
    fontSize: 48px
    fontWeight: '400'
    lineHeight: 56px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Newsreader
    fontSize: 36px
    fontWeight: '400'
    lineHeight: 44px
    letterSpacing: -0.01em
  headline-lg:
    fontFamily: Newsreader
    fontSize: 32px
    fontWeight: '400'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Newsreader
    fontSize: 26px
    fontWeight: '400'
    lineHeight: 34px
  headline-md:
    fontFamily: Newsreader
    fontSize: 24px
    fontWeight: '400'
    lineHeight: 32px
  headline-sm:
    fontFamily: Newsreader
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 28px
  body-lg:
    fontFamily: Newsreader
    fontSize: 19px
    fontWeight: '400'
    lineHeight: 30px
    letterSpacing: 0.01em
  body-md:
    fontFamily: Newsreader
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 26px
  body-sm:
    fontFamily: Newsreader
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  label-lg:
    fontFamily: Newsreader
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-md:
    fontFamily: Newsreader
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: 0.03em
  label-sm:
    fontFamily: Newsreader
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-mobile: 1rem
  margin: 3rem
  margin-mobile: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style
This design system crafts an intimate, late-night reading sanctum. Rooted in literary reverence and tactile craftsmanship, it translates the quiet contemplation of a private library at midnight into an atmospheric digital surface. The tone is deeply human, restorative, scholarly, and hushed.

Drawing from a tactile, literary-minimalist design style, the interface replaces harsh digital neon and stark contrasts with rich, organic charcoal substrates, fibrous border nuances, and hand-drawn qualities. It evokes the sensory calm of aged parchment preserved under soft lamplight, offering a soothing, fatigue-free environment for immersive long-form reading, note-taking, and intellectual curation.

## Colors
The palette evokes an ink-washed nocturnal study. Surfaces rely on layered charcoal and graphite tones rather than absolute black, maintaining a warm, paper-adjacent depth.

- **Background & Canvas**: Primary base sits at `#191816` (void charcoal), lifting into `#201f1c` for container surfaces and `#262421` for elevated modules and floating trays.
- **Typography & Ink**: Primary copy renders in soft ivory `#e8e4dc`, ensuring high legibility without retinal strain. Secondary narrative, metadata, and captions drop into weathered bone `#cfcabf` and muted umber `#9c9689`.
- **Primary Accent (Sage)**: `#7e9177` provides grounded, herbal emphasis for interactive states, progress rings, and subtle highlights. Its lighter step, `#98aa91`, serves active states and focus rings.
- **Secondary Accent (Terracotta)**: `#b86047` serves as an analog bookmark, dog-ear indicator, marginalia alert, and primary call-to-action anchor.
- **Delicate Outlines & Inks**: Structural outlines rely on `#403d38` and `#524e47`, simulating faint graphite rules and hand-drawn ink margins.

## Typography
Typographic hierarchy is built exclusively around **Newsreader**, honoring classic editorial book design. It utilizes optical sizing cues, generous line heights, and open proportions to mimic physical letterpress typesetting on heavy paper.

- **Headlines & Chapter Titles**: Set with deliberate letter spacing and soft weights (400–500), avoiding aggressive bolding. Let italicized variants carry expressive emphasis.
- **Long-form Body**: Tuned to `19px` with a `30px` line-height on desktop (`body-lg`) to facilitate relaxed, unbroken eye movement across generous measure columns (optimal 60–75 characters per line).
- **Marginalia & Labels**: Small caps and subtle tracking (`0.03em` to `0.05em`) are applied to navigational tags, timestamps, and page numbers, evoking classic footnote pagination.

## Layout & Spacing
The layout philosophy mirrors book design: wide, restful outer gutters, asymmetric marginalia spaces, and a fluid, single-to-two-column reading spine.

- **Grid & Columns**: A 12-column fluid grid accommodates desktop layouts, anchoring central reading columns to 8 columns with 4 columns reserved for marginal notes, glossaries, or table of contents.
- **Adaptive Breakpoints**:
  - **Desktop (1024px+)**: `margin` at `3rem`, accommodating side-by-side annotations and reading panels.
  - **Tablet (768px - 1023px)**: `margin` reduces to `2rem`; marginal notes collapse into bottom sheets or slide-over ink flyouts.
  - **Mobile (< 768px)**: Fluid single-column spine; `margin-mobile` is `1.25rem`, maintaining comfortable thumb clearance and preserving text proportion.
- **Rhythm**: Element pacing leverages intentional vertical breathing room (`space-xl` between thematic breaks) punctuated by faint rule dividers rather than hard container edges.

## Elevation & Depth
Depth eschews sterile drop shadows and glassy synthetic blurs. Visual layering is constructed purely through **tonal paper stepping** and **delicate hand-drawn ink boundaries**.

- **Tonal Tiering**: Base canvases sit at `#191816`. Reading surfaces and card containers step forward to `#201f1c`. Popovers, floating palettes, and dropdowns settle at `#262421`.
- **Tactile Outlines**: Containers and dividers utilize subtle 1px border lines in `#403d38` and `#524e47`. Where possible, borders simulate an imperfect, organic hand-drawn stroke with micro-variations or dashed ink-dash styling (`border-style: solid` with soft antialiasing).
- **Ambient Shadow Tone**: When floating overlays require separation, use soft, wide-spread, low-opacity ambient shadows tinted in warm soot: `0 8px 24px rgba(10, 9, 8, 0.55)`, keeping edges diffused and natural rather than sharp or clinical.

## Shapes
The shape language reflects hand-trimmed book pages, library cards, and archival stationery.

- **Corner Radii**: A gentle, conservative roundness (`roundedness: 1`) governs the system. Small components like tags, chips, and fields use `0.25rem` (4px). Larger cards, reading slates, and modal containers use `0.5rem` (8px).
- **Physical Motifs**: Terracotta ribbons, bookmarker nibs, and chapter banners embrace notched or subtly clipped geometry to reinforce the tactile, stationery-inspired aesthetic.

## Components

### Buttons
- **Primary (Terracotta Seal)**: Filled with `#b86047`, text in `#191816` or dark soot `#201f1c`, rounded to `0.25rem`. States: hover shifts to `#c66f56`; active presses downward with a micro inset feel.
- **Secondary (Ink Border)**: Background `#201f1c`, bordered with 1px `#524e47`, text in `#e8e4dc`. Hover elevates background to `#262421` with border shifting to sage `#7e9177`.
- **Tertiary / Ghost**: Borderless, italicized Newsreader label in `#98aa91`, showing an organic underline on hover.

### Input Fields & Search
- Grounded in `#191816` with a delicate 1px `#403d38` perimeter. Placeholder text sits in `#9c9689`.
- On focus: outline illuminates gently in muted sage `#7e9177` without harsh glow halos, accompanied by an ivory text cursor.

### Bookmarks & Annotations
- Dedicated bookmark ribbons drop vertically from container headers using `#b86047` with a downward arrow notch.
- Margin notes and highlight badges use muted sage `#7e9177` at 15% opacity for backgrounds, bordered by a delicate dashed `#524e47` contour.

### Cards & Reading Panes
- Rendered on `#201f1c` surfaces wrapped in 1px `#403d38`.
- Padding remains generous (`space-lg`), separating chapter excerpts from metadata footnotes. Section breaks inside cards are indicated by centered asterisk dividers (`* * *`) or thin horizontal ink rules.

### Chips & Filters
- Compact pill or softened rectangular capsules with 1px borders in `#403d38`, filled with `#262421`.
- Selected state turns the border to sage `#7e9177`, with text illuminated in `#e8e4dc`.

### Checkboxes & Radio Controls
- Tactile squares (checkboxes) and circles (radios) drawn with a 1px ink border in `#524e47`.
- Checked state fills with sage `#7e9177`, displaying a soft off-white `#191816` checkmark or interior dot reminiscent of an ink stamp.