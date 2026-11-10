# Engine comparison

No engine has a weighted score. A weighted score requires every hard acceptance check to be a device pass. None of those device passes exist. Widget tests and source readings are listed separately so they are not mistaken for device passes.

## Hard requirements

| Requirement | epub_rtl | flutter_epub_viewer | foliate-js host | flutter_readium |
| --- | --- | --- | --- | --- |
| AC-001 one scroll crosses chapters | widget_pass on the test binding. Device not tested | wired to epub.js continuous scrolled mode. Not tested | host enables paginator scrolled mode without `no-continuous-scroll`. Not tested | source: scroll is per spine item. Device not tested |
| AC-002 reverse scroll | widget_pass. Device not tested | not tested | not tested | same per-item model. Device not tested |
| AC-003 no blank jump | not tested | not tested | not tested | not tested |
| AC-004 same sentence after restart | block index restored in a widget rebuild. Process death not tested | CFI is stored. Not tested | CFI is stored. Not tested | full Locator JSON is stored. Not tested |
| AC-005 one-tap bookmark | widget_pass on epub_rtl | control is shared, engine not opened | control is shared, engine not opened | control is in the Readium app. Not opened |
| AC-006 bookmark after restart | store unit test reloads the file. Process death not tested | not tested | not tested | not tested |
| AC-007 offline | not tested on a device | not tested | local server is on-device loopback, not tested | not tested |
| AC-008 large EPUB | not tested | not tested | whole-file fetch is a known risk | not tested |
| AC-009 process recreation | not tested | not tested | not tested | not tested |
| AC-010 corpus without critical loss | EPUB-004 hidden text and EPUB-005 table/image widget_pass. Other books not opened | not tested | not tested | not tested |

## Locators

| Engine | Exact identity | Also reported, not an identity |
| --- | --- | --- |
| epub_rtl | spine index + top-level block index | within-block fraction |
| flutter_epub_viewer | `startCfi` when non-empty | `progress`, xpath, per-chapter page numbers |
| foliate-js | CFI from `relocate` | section fraction |
| flutter_readium | href plus CSS selector or quote, when the locator has one; otherwise the whole locator is only approximate | `totalProgression` |

Percentages are never bookmark keys.

## Typography the lab sends

`wired` means the lab sends the field. It does not mean a device showed the change.

| Field | epub_rtl | flutter_epub_viewer | foliate host | flutter_readium |
| --- | --- | --- | --- | --- |
| Font size | wired | wired | wired | wired as a ratio |
| Font family | wired, no font bundled | wired via CSS | wired via CSS | wired |
| Line height | wired | wired via CSS | wired via CSS | wired |
| Paragraph spacing | wired | wired via CSS | wired via CSS | wired |
| Margins | wired as padding | wired via CSS | wired via CSS | wired as a margin ratio |
| Align start / justify | wired | wired | wired | not sent; `textAlign` exists on the plugin and the lab does not set it yet |
| Align center / end | unsupported | wired via CSS | wired via CSS | not sent |
| Light / dark / e-ink colors | wired | wired | wired | wired |
| Reduced motion | no snap animation exists in scroll mode | snap and Android snap animation forced off | `animated` attribute removed | no reduced-motion field was found; not sent |

## Architecture

epub_rtl keeps the book as Flutter slivers and builds chapters as they approach the viewport. That is the shape R-001 asks for, with a small CSS subset and no CFI. The widget tests match that shape. They do not show whether a fling on a 120 Hz panel stays smooth across the 1 px rule, or how EPUB-003 behaves in memory.

flutter_epub_viewer puts epub.js continuous mode in a WebView. That can be one scroll, and epub.js is known to struggle at chapter navigation in scrolled flow. Until a device recording shows three boundaries with no blank frame and no extra gesture, it is only a configuration.

The Foliate host is the closest code to Readest's scrolled paginator, because it is that paginator. Readest the application is AGPL and was not copied. The host still has to be watched on a device. Preloading adjacent sections can still hitch, jump, or blank; the Readest project has a history of those bugs inside this same paginator.

flutter_readium is the strongest native toolkit and the weakest match to a single book-long scroll. Its locator model is the best of the four for annotations, and its scroll model is the wrong one for R-001 unless a device run shows the next spine item arriving inside the same fling. The lab is set up to make that observation. It has not been made.

## Licensing

Mia Legilo is MIT. Linking a library is not the same as copying an application.

| Piece | License evidence used | MIT-app note |
| --- | --- | --- |
| epub_rtl 0.1.0 | MIT, copyright 2026 Abdeldjalil Chougui, in the package | Compatible. Keep the notice |
| flutter_epub_viewer 2.2.1 | `LICENSE` in the package is BSD-3-Clause, copyright 2024 Fayis Muhammed T K. The README text also says MIT. The license file is the one to follow | BSD-3-Clause can be linked from MIT code if the notice and disclaimer ship with the binary. Do not drop the notice |
| flutter_inappwebview 6.2.0-beta.3 | Apache-2.0 | Notice and the Apache text ship with the binary |
| Bundled epub.js | The webpack bundle contains an Apache-2.0 Mozilla notice and an MIT notice. A full bill of materials of that bundle was not extracted | Do not assume the Dart package license covers every file inside `epub.js` |
| foliate-js at `090ccca` | MIT, copyright 2022 John Factotum. `assets/foliate/LICENSE` and `NOTICE` | Compatible. The vendored files stay under MIT |
| vendor/zip.js | Shipped inside foliate-js. Upstream zip.js is BSD-3-Clause | Keep that notice. The minified file's header was not a readable license block, so the upstream license named by the foliate README is the one recorded |
| Readest application | AGPL-3.0 | Not vendored and not a dependency. Do not copy it into Mia Legilo |
| flutter_readium 0.9.1 | BSD-3-Clause, copyright 2026 Royal Danish Library | Compatible to link, with the notice |
| Readium kotlin-toolkit 3.4.0, pulled by the plugin | The plugin's Gradle file depends on `org.readium.kotlin-toolkit` artifacts. Readium's toolkit license is BSD-3-Clause | Same notice obligation. This report did not re-audit every transitive Android artifact |

## Maintenance

Dates below are the ones published on pub.dev or git at the time of this investigation (2026-11-10).

- epub_rtl 0.1.0 was published 2026-09-29. One version. Flutter `>=3.24`, Dart `^3.5`. Young, small API, pure Dart and Flutter.
- flutter_epub_viewer 2.2.1 was published 2026-10-28. Active through 2026. Android, iOS, macOS, web. Depends on a beta of flutter_inappwebview.
- flutter_readium 0.9.1 was published the day of this investigation. The Android plugin file requires compileSdk 37, minSdk 24, Kotlin 2.3.21, and Readium kotlin-toolkit 3.4.0. The Flutter template used here is AGP 9.1.0. The debug APK still linked.
- foliate-js has no stable release in the Readest fork. The commit used is 2026-11-09. The library README says the API can break. Pin the commit, which this lab does.

## If the device runs also fail R-001

Do not lower R-001. The production shape is then a Flutter sliver reader: one scrollable, chapters built near the viewport, a semantic anchor that survives reflow. epub_rtl is already that shape with a narrow CSS subset and no CFI. The remaining work is CFI (or another stable locator), fuller CSS and images, and proof on the target panels. That is a reader engine, not an application shell. It is smaller than adopting Readium and then replacing its navigator, and it avoids the AGPL application.

Adopting the Foliate paginator remains the alternative if the device recordings show it crossing chapters without a hitch. The cost is a WebView, a pinned JavaScript commit, and whole-file loading unless the host grows random-access reads.
