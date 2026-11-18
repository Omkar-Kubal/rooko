# Today Rook centering and installed app versions

Date: 2026-11-12

## Acceptance evidence

| SRS ID | Acceptance behavior | Evidence | Result |
|---|---|---|---|
| FR-031 | Today keeps its single count and app split while omitting access/detection timestamps and status explanations. | `flutter test test/features/today/today_home_screen_test.dart`; RMX2156 screenshot and UI tree. | Passed. The access banner remains the approved recovery entry. |
| FR-010 | Installed app version and detector-profile availability are distinct facts. | `MainActivity.installedVersion()` uses Android `PackageManager`; RMX2156 app picker screenshot and `dumpsys package`. | Versions read automatically. Both installed versions currently have no production detector profile, so both show “Not supported.” |
| NFR-06 | Ready Rook remains centered and the screen uses accessible semantic labels. | RMX2156 UI tree bounds `[290,858][790,1328]` on a 1080×2181 display. Center: `(540,1093)`, or 50.1% of display height. The widget test checks viewport center. | Passed. |

## Device results

- Target: RMX2156, Android 12 / API 31.
- Installed package: `com.appylab.syncscroll`, debug version `1.0.0`, version code 1. The prior installed code 35 required `adb install -r -d`; the package data was retained and the Room database files remained present. Accessibility/overlay settings were not changed.
- Installed YouTube version: `21.45.82`.
- Installed Instagram version: `455.0.0.51.72`.
- Both app rows display the exact installed version followed by “Not supported.” Production `DetectorProfiles` is empty because no current app/version has passed the independent item-identity evidence gate.

## Verification

- `flutter test --reporter expanded` — 50 passed.
- `flutter analyze` — no errors; five existing Rive deprecation infos.
- Android `:app:testDebugUnitTest` — task succeeded as `UP-TO-DATE` in the latest run; no test cases were re-executed in that run.
- Debug APK assemble — succeeded with Android Studio JBR, Kotlin incremental compilation disabled for this C:/D: Windows setup, and `org.sqlite.tmpdir` pointed at `build/sqlite-temp`.
- The stock `flutter build apk --debug --no-pub` wrapper still fails locally: Kotlin incremental caches cannot relativize SDK/Pub sources on C: against this workspace on D:, and Room KSP rejects `C:\Windows\Temp` as a temp directory. The direct Gradle assemble succeeded with the local overrides; these settings were not added to project configuration.

The successful direct assemble used:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:JAVA_TOOL_OPTIONS = '-Dorg.sqlite.tmpdir=D:\appylab\sync-rot\build\sqlite-temp'
.\gradlew.bat --no-daemon --max-workers=1 `
  '-Pkotlin.compiler.execution.strategy=in-process' `
  '-Pkotlin.incremental=false' :app:assembleDebug --console=plain
```

The Android unit-test task was invoked with the same Gradle flags and `:app:testDebugUnitTest`.

## Screenshots

### Today

![Today on RMX2156](rmx2156-today.png)

### Settings

![Settings on RMX2156](rmx2156-settings.png)

### App version picker

![Installed app versions on RMX2156](rmx2156-app-picker.png)
