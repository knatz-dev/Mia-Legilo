# Physical Android benchmark procedure

Do not copy emulator numbers into this file's results, and do not treat the debug APK compile as a run. Record a row in `results/measurements.csv` only after the command below printed a number on the device you name.

Use the same eight EPUBs from `assets/test_books` on every engine. Five runs is the minimum for a median. Report median, minimum, maximum, and p95 when you have at least five samples. Keep the raw rows.

## 1. Record the device

```bash
adb devices -l
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.sdk
adb shell wm size
adb shell wm density
adb shell dumpsys display | sed -n '1,40p'
```

Write the model, Android version, resolution, refresh rate, and whether the panel is LCD, OLED, or e-ink into `results/environment.json`. If it is not an e-ink panel, leave F-010 as not tested. Do not infer ghosting.

Also record `flutter --version` and the package versions pinned in the two pubspecs.

## 2. Install

```bash
cd experiments/reader_lab
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk

cd engines/flutter_readium_app
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Release builds are the performance builds. The debug APKs already compiled here are only compile checks.

Turn on airplane mode before F-008. Leave it on for the whole offline run.

## 3. Functional checks

For each engine and for EPUB-007 (short chapters) and EPUB-002 (medium):

| Id | Pass condition | Fail condition |
| --- | --- | --- |
| F-001 | From the last lines of a chapter, one downward fling shows the next chapter's text without another tap or control | The chapter ends and waits for a page turn, button, or chapter swipe |
| F-002 | The same, scrolling upward | Upward scrolling stops at the chapter start |
| F-003 | Slow drag and a fast fling both cross at least three boundaries with no blank frame and no jump back to a chapter top | A blank screen, a snap, or a required extra gesture |
| F-004 | Note a sentence. Leave the reader, kill the process (`adb shell am force-stop <package>`), reopen. The same sentence is visible | Only a percentage is restored, or a different paragraph is visible |
| F-005 | From that sentence, raise font size and line height. The same sentence remains visible | The reader jumps to another chapter or loses the anchor |
| F-006 | One tap on the bookmark icon fills it with no dialog. Force-stop, reopen, open the bookmark, see the same sentence. One tap clears it | A dialog, a lost bookmark, or a different passage |
| F-007 | Open EPUB-003 (120 spine items). Scroll across at least ten boundaries. The process stays up | A crash, or memory that keeps climbing after you return to a chapter and idle |
| F-008 | Airplane mode on. Open, scroll, bookmark, force-stop, restore | Any step needs a network |
| F-009 | Rotate, background the app, and `adb shell am kill <package>` while it is backgrounded. Reopen to the same sentence | The position is lost |
| F-010 | Only on e-ink hardware: monochrome theme, reduced motion, bookmark tap. Record whether the tap repaints the whole panel | Do not mark this from an LCD or an emulator |

Take a screen recording of one forward crossing and one reverse crossing per engine. Store the file path in the report. A still image of the middle of a chapter is not evidence of a boundary crossing.

Package names:

- Reader Lab: `biz.mialegilo.readerlab.reader_lab`
- Readium lab: `biz.mialegilo.readiumlab.readium_lab`

## 4. Performance, only after the functional pass

Skip performance for an engine that fails F-001 or F-002. A fast per-chapter scroller is not a candidate.

Startup, five cold starts, from process start to the first sentence of EPUB-001 being visible:

```bash
adb shell am force-stop <package>
adb shell am start -W -n <package>/<activity>
```

That `am start -W` number is time-to-window, not time-to-first-readable-text. Also time the readable sentence with a screen recording. Write both, and name which is which.

Scrolling, while diagnostics are off:

```bash
adb shell dumpsys gfxinfo <package> reset
# fling for 10 seconds across chapter boundaries
adb shell dumpsys gfxinfo <package>
```

Record total frames, janky frames, and the 95th percentile frame time from that dump. Repeat five times. Name the unit milliseconds.

Memory, total PSS, not the Dart heap:

```bash
adb shell dumpsys meminfo <package>
```

Take it after launch, after opening EPUB-003, after crossing ten chapters, and 30 seconds after leaving the reader. Five runs. If the last sample is higher than the post-open sample on every run and still rising, mark unbounded growth.

CPU during a 10 second fling and during 10 seconds of idle:

```bash
adb shell top -n 5 -d 1 -p $(adb shell pidof <package>)
```

Bookmark write: time from tap to the icon change is the visible latency. It should be one frame if the lab's in-memory update is intact. Separately, time until `bookmarks.json` appears under the app documents directory if you pull the file. Five taps. Do not invent the latency from the code.

## 5. How to score afterwards

A hard requirement counts as pass only when the device procedure passed. Widget tests stay in their own column. An engine that fails F-001 or F-002 gets no weighted score. If every engine fails those two, the ADR stays Deferred and the follow-up is a Flutter sliver reader, not a relaxation of the requirement.
