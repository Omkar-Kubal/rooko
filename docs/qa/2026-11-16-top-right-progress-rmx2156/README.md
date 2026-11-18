# Top-right Progress navigation — RMX2156, 2026-11-16

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-038 | Today opens with Progress and Settings at the top right, with no Today tab or bottom bar | `today.png` and `today.xml`; RMX2156 / Android 12 | Passed | Light and AMOLED device appearance not inspected |
| FR-035, FR-038 | The former History view is visibly named Progress | `progress.png` and `progress.xml` | Passed | Existing history data and bridge names remain internal |
| FR-038 | Progress and Settings retain right-aligned controls and a left Back control | `progress.png`, `settings.png`; UI hierarchy | Passed | TalkBack spoken output not inspected |
| FR-038 | Android Back from Settings returns to Today | `back-to-today.xml` after `adb shell input keyevent 4` | Passed | Physical 2× text inspection not performed |

`dart format --output=none --set-exit-if-changed` checked the five changed Dart files with no remaining changes. `flutter test --no-pub test/features/today/today_home_screen_test.dart test/features/history/history_screen_test.dart test/features/onboarding/app_flow_screen_test.dart --reporter compact` passed 54 tests. Targeted `flutter analyze --no-pub` found no issues.

`flutter build apk --debug --no-pub --android-project-arg=kotlin.incremental=false --android-project-arg=ksp.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process` succeeded. `adb -s X4GEAYDMWGAUI7WG install -r -d build/app/outputs/flutter-apk/app-debug.apk` returned `Success`; app data was preserved. APK SHA-256: `2E7B8B0916A12BCB1865727CA35C4C941937417F98CE03AE2A6EF1C21A883038`.

The device was left on Today. No live Instagram Reels or YouTube Shorts counting test was run; the user reserved that test.
