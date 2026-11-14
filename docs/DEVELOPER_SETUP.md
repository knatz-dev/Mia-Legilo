# Developer Setup

## Prerequisites

- Flutter 3.50.x (stable) on PATH
- Android SDK (API 34+ installed) at a path without spaces
- JDK 21 (Microsoft/OpenJDK)
- Android licenses accepted

## Environment variables (Windows example)

```powershell
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

## Notes

- Android SDK must reside in a path without spaces (Flutter/NDK limitation).
- HTTP client selection (`http` vs `dio`) is provisional pending a spike (FND-003).
- See `TEST_DATA_POLICY.md` for fixture handling.
