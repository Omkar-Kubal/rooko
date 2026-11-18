# Rook onboarding fade handoffs

Target: RMX2156 / Android 12, device `X4GEAYDMWGAUI7WG`.

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-001 | Tap to continue fades out, then Hi, Rook fades in with a short gap | `flutter test --no-pub test/features/onboarding/app_flow_screen_test.dart` checks start, gap, intermediate, and settled opacity | Passed | This ROM has no Android `screenrecord` command; device motion frames were not captured |
| FR-001 | Hi, Rook fades out before opening setup; Okay fades in after a short delay | Widget test checks callback timing and both action opacities | Passed | Device motion frames were not captured |
| FR-001 | Background pauses the outgoing handoff; reduced motion skips delays | Lifecycle widget test and reduced-motion onboarding flow | Passed | TalkBack spoken output was not checked |
| FR-001 | Tap → Hi, Rook → Okay routes remain usable on Android | `tap-to-continue-ui.xml`, `after-tap-ui.xml`, `after-hi-ui.xml`, and `okay-settled.png` | All three settled states and forward navigation checked on RMX2156 | No live feed counting was tested |

Formatting found no changes, targeted Flutter analysis found no issues, and all 23 onboarding tests passed. The debug APK built with Android Studio JBR, workspace-local SQLite temp storage, and non-incremental Kotlin/KSP. `adb install -r -d` installed it over the existing app without clearing data.
