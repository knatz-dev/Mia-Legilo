# Readium lab

Isolated host for flutter_readium 0.9.1. It shares `benchmark_core` and a copy of the generated corpus with the main Reader Lab.

The screen calls `setEPUBPreferences(EPUBPreferences(scroll: true, ...))` before `ReadiumReaderWidget`. `disablePageTurnsWhileScrolling` stays false so a device tester can see whether leaving a chapter needs a separate forward gesture.

Readium's own presentation comment says a scrolled spine item is its own scrollable document. That is why this app is not treated as a continuous-scroll pass. Confirm or refute that on hardware with `scripts/device_benchmark.md`. A debug APK compiled in this workspace. It was not installed.
