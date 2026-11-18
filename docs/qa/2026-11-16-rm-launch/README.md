# RMX2156 app launch — 2026-11-16

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-001 | The installed app opens the counter-preview onboarding screen | RMX2156 / Android 12; `adb shell am start -n com.appylab.syncscroll/.MainActivity`; resumed-activity and UI-hierarchy checks; `launch.png` | Passed | Onboarding interactions and live feed counting were not exercised |

`flutter build apk --debug --no-pub --android-project-arg=kotlin.incremental=false --android-project-arg=ksp.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process` passed. `adb -s X4GEAYDMWGAUI7WG install -r -d build/app/outputs/flutter-apk/app-debug.apk` returned `Success`, preserving app data. Installed version: `1.0.0`. APK SHA-256: `9553E8A630097A7869A1C3EE22A0F9B0A407EF173A59446BE28AB376507C8726`.
