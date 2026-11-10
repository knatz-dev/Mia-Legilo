# ADR-001: EPUB rendering engine

## Status

Deferred.

No engine is Accepted. Device runs for continuous scrolling, position restoration, bookmarks, memory, and lifecycle do not exist yet. Widget tests and source readings are not enough to accept an engine.

## Context

Mia Legilo needs one EPUB surface that feels like a single vertical document, restores the same sentence, and bookmarks that sentence in one tap. The reader is offline-first and will run on Android tablets and, later, Android e-ink devices. This ADR covers only the rendering engine. It does not choose the library UI, accounts, or Calibre-Web sync.

The comparison app is `experiments/reader_lab`. It is not production code and must not be merged into the app's product graph as a dependency.

## Mandatory requirements

R-001 and R-002 from the engineering task are the gates. A reader that scrolls inside a chapter and then asks for another gesture fails, even if the in-chapter scroll is smooth. A percentage is not an exact location. One tap must bookmark the current semantic anchor, offline, without a dialog. E-ink ghosting is out of scope until an e-ink device is in the results.

## Candidates evaluated

- epub_rtl 0.1.0, MIT, pure Flutter.
- flutter_epub_viewer 2.2.1, BSD-3-Clause in its license file, epub.js in a WebView, configured for continuous scrolled mode.
- foliate-js from the Readest fork at `090ccca` (2026-11-09), MIT, original WebView host. The Readest application was not copied.
- flutter_readium 0.9.1, BSD-3-Clause, isolated app, `EPUBPreferences.scroll: true`.

## Benchmark environment

Flutter 3.47.9, Dart 3.13.7, Android debug APKs compiled and not installed. No device, no emulator. Details are in `experiments/reader_lab/results/environment.json`.

## Functional results

epub_rtl, on the Flutter test binding only: one scroll view contains later and earlier chapters; `display: none` is honored; a table cell and an image from the mixed fixture render; the same block remains after a font and line-height change; one tap bookmarks that anchor and a second tap removes it.

flutter_epub_viewer and the Foliate host are configured for the continuous-scroll mode of their engines. They were not opened.

flutter_readium's 0.9.1 sources describe scroll as per-resource. The lab turns that mode on so a device can confirm it. It is not a pass, and it is not yet a measured device failure.

Full table: `experiments/reader_lab/results/benchmark-report.md`.

## Performance results

None. CSV rows are corpus sizes and debug APK file sizes. They are labeled as such.

## Licensing assessment

MIT code can link to MIT, BSD-3-Clause, and Apache-2.0 libraries if the notices ship with Mia Legilo. epub_rtl and foliate-js are MIT. flutter_epub_viewer and flutter_readium are BSD-3-Clause. flutter_inappwebview is Apache-2.0. The epub.js bundle contains further notices that were not fully inventoried. The Readest application is AGPL and is not a candidate for copying, regardless of foliate-js being MIT.

## Decision

No engine is selected.

The working hypothesis, which this ADR does not accept, is:

1. Do not make flutter_readium the primary reader. Its locator model is worth keeping in mind for annotations. Its navigator, as documented in 0.9.1, does not implement book-wide vertical scrolling.
2. On a device, record epub_rtl and the Foliate host first, on the same EPUBs, with the procedure in `experiments/reader_lab/scripts/device_benchmark.md`. flutter_epub_viewer is the third recording, because it is another WebView on epub.js and the package already warns about scrolled navigation.
3. Accept an engine only when F-001, F-002, F-004, and F-006 pass on the target Android hardware, and EPUB-003 does not crash or grow without bound.
4. If those recordings fail, build the production reader as a Flutter sliver list in the shape epub_rtl already has, and add a real CFI plus the CSS and media the benchmark shows it lacks. Do not relax R-001 to fit Readium or a per-chapter WebView.

## Rationale

The requirement is a property of the scroll model. epub_rtl's scroll model matches it, and the widget tests agree, with the limits above. The Foliate paginator is the implementation Readest uses to chase the same property, and it is unproven in this host. Readium is a different scroll model. Popularity and toolkit completeness do not repair a per-chapter scroll.

## Consequences

Production integration waits. The lab stays under `experiments/`. Notices for BSD and Apache dependencies are required before any of those libraries ship in Mia Legilo. Foliate stays pinned to a commit if it is the one that eventually passes.

## Known limitations

Widget tests do not show fling momentum, blank frames, WebView memory, process death, rotation, or e-ink refresh. The 1 px rule in epub_rtl may still hitch on a device. Foliate loads the entire EPUB into the WebView. Readium's font-size and margin values in the lab are scaled by constants that have not been checked against the native renderer.

## Follow-up work

1. Run `scripts/device_benchmark.md` on at least one LCD or OLED Android device. Record five runs where the procedure asks for five.
2. If an e-ink Android device is available, run F-010 there and only there.
3. If epub_rtl passes the device gates, design the production port: a `ReaderController` that owns open, the current `ReadingLocation`, bookmark toggle, and dispose; the widget stays a sliver view; CFI is added or the block anchor is documented as the supported locator; files are opened from disk, not from a full-memory copy; Android `onTrimMemory` and process death go through the same position file the lab uses.
4. If only Foliate passes, the production host is a single WebView with the pinned MIT commit, a loopback or asset server that can read zip entries without holding the whole book if measurements show that matters, and the CFI already emitted by `relocate`.
5. Update this ADR to Accepted only after those measurements are in `results/measurements.csv` and the functional table has device passes for every hard requirement. Until then it stays Deferred.
