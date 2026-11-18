# Rook to setup transition check

Target: RMX2156, Android 12, device `X4GEAYDMWGAUI7WG`.

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-001 | The revealed Rook greeting and counting explanation remain visible on the Okay page and begin near their previous positions | `flutter test --no-pub test/features/onboarding/app_flow_screen_test.dart` measures both positions across the page boundary | Passed; each starts within 28 dp | Device frame capture unavailable |
| FR-001 | Both text blocks move upward, the ring settles, and the new heading appears letter by letter | Intermediate-frame widget test and `setup-transition-final.png` | Passed in widget test; final layout reviewed on RMX2156 | This ROM has no Android `screenrecord` command for a device video |
| FR-001 | Background pause, reduced motion, Back, draft restore, and Okay navigation | Onboarding widget suite | Passed, 20/20 | TalkBack spoken output not checked in this pass |
| FR-001 | Earlier copy fades to 26% opacity as it moves upward; the new message fades in below | Intermediate-frame widget assertions and `setup-opacity-final.png` | Passed in widget test; settled arrangement inspected on RMX2156 | This ROM has no Android `screenrecord` command for device motion capture |

`dart format --output=none --set-exit-if-changed` found no changes; targeted `flutter analyze --no-pub` found no issues. The debug APK built with Android Studio JBR, workspace-local SQLite temp storage, and non-incremental Kotlin/KSP. It was installed in place with `adb install -r -d`, preserving app data. The RMX2156 UI hierarchy confirms all three text blocks, Ready Rook, and Okay in the final state. No Reels/Shorts counting was tested.

Opacity follow-up: `setup-opacity-final.png` and `setup-opacity-ui.xml` were captured after the new APK install on device `X4GEAYDMWGAUI7WG`. The widget test checks both prior text blocks at full, intermediate, and 26% final opacity, the new heading at zero, intermediate, and full opacity, upward movement, letter reveal, and background pause. The final screenshot shows the prior copy above the new heading. The device animation itself was not recorded.
