# Top navigation review — RMX2156, 2026-11-16

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-038 | Today defaults with only History and Settings at top left, no bottom bar | `today.png`; RMX2156 / Android 12 UI hierarchy | Passed after dismissing the full access message | Light and AMOLED device appearance not inspected |
| FR-038 | History and Settings retain top controls and a Back button | `history.png`, `settings.png`; UI hierarchy | Passed | TalkBack spoken output not inspected |
| FR-038 | Android Back returns Settings to Today | `adb shell input keyevent 4`; Today UI hierarchy after return | Passed | No live feed counting test |
| FR-038, FR-004 | Permission wall hides navigation until dismissed; narrow large-text layout remains usable | Today/app-flow widget tests | Passed | Physical 2× text inspection not performed |

`dart format` found no further changes after formatting. `flutter analyze --no-pub lib/features/today/today_home_screen.dart test/features/today/today_home_screen_test.dart test/features/onboarding/app_flow_screen_test.dart` found no issues. `flutter test --no-pub test/features/today/today_home_screen_test.dart test/features/onboarding/app_flow_screen_test.dart --reporter compact` passed 46 tests. The debug APK built with non-incremental Kotlin/KSP arguments and `adb -s X4GEAYDMWGAUI7WG install -r -d build/app/outputs/flutter-apk/app-debug.apk` returned `Success`. APK SHA-256: `6AAB23B3F701D9FBAA28985110862229E3CC6DF6C15029E782EE7AA305E6C60E`.

The full Today access message was dismissed to expose the top navigation, leaving its compact access banner. Android permissions were not changed. The user-reserved Reels/Shorts counting test was not run. Historical QA screenshots showing the old bottom bar remain as evidence of earlier builds.
