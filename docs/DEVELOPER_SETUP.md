# Developer Setup

## Prerequisites

- Flutter 3.50.x (stable) on PATH
- Android SDK (API 34+ installed) at a path without spaces
- JDK 21 (Microsoft/OpenJDK)
- Android licenses accepted

## Environment variables (Windows example)

```powershell
$env:FLUTTER_ROOT = "C:\flutter"
$env:JAVA_HOME = "C:\Program Files\Android\openjdk\jdk-21.0.8"
$env:ANDROID_HOME = "C:\Android\Sdk"
$env:ANDROID_SDK_ROOT = "C:\Android\Sdk"
$env:PATH = "C:\flutter\bin;C:\Android\Sdk\platform-tools;" + $env:PATH
```

## Common commands

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

## Deploy the current iteration to the emulator

```powershell
pwsh -NoProfile -File scripts/deploy-emulator.ps1
# Select a specific running emulator when needed:
pwsh -NoProfile -File scripts/deploy-emulator.ps1 -DeviceId emulator-5556
# Run the script's checks without building or installing:
pwsh -NoProfile -File scripts/deploy-emulator.test.ps1
```

The deployment script uses `FLUTTER_ROOT`, `ANDROID_HOME` and `JAVA_HOME`, falling back to persisted Windows user variables when the current process predates their configuration. It builds from the repository root, prefers `emulator-5554` (otherwise the sole ready emulator), installs a fresh debug APK without clearing app data, and checks that the launched app stays running. It fails on unavailable/ambiguous devices and failed commands. Visually verify startup and the iteration's changed flow afterward; the process check is not a UI test.

For persistent command discovery, set those variables and `ANDROID_SDK_ROOT` in Windows user environment settings and add Flutter's `bin`, the chosen SDK's `platform-tools`, and the JDK's `bin` to the user PATH. Restart the terminal/Pi afterward; `/reload` alone does not refresh inherited Windows environment variables. Use one SDK consistently. The session-only example above also works when exported before starting Pi.

## Notes

- Android SDK must reside in a path without spaces (Flutter/NDK limitation).
- HTTP client selected: `dio` (FND-003 finalized).
- See `TEST_DATA_POLICY.md` for fixture handling.
