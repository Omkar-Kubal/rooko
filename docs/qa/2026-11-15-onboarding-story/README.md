# Post-question onboarding story — 2026-11-15

The root `onboarding.mp4` is the user-supplied reference. Its visible sequence ends on the ten-year dot grid. The user explicitly selected its statements. Sync Scroll uses its existing monochrome palette and approved Ready Rook art.

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-002A | Projection follows question 8 | `OnboardingProjection` test: 400 → 2,800 / 12,000 / 146,000; 35-second scenario → 2 and 20 months | Passed | Scenario is illustrative, not measured viewing |
| FR-002A | Five pages and recall branch lead toward app selection | `app_flow_screen_test.dart` and `onboarding_story_screen_test.dart`; 42 targeted onboarding tests total; RMX2156 / Android 12 walkthrough from question 8 through the ten-year grid | Passed | Final Continue into app selection covered by widget test, not the device walkthrough |
| FR-002A | Motion, Back, reduced motion, background pause | Focused widget tests and restored-draft test; device Back from ten-year grid to impact page | Passed | Physical motion recording pending; this ROM has no `screenrecord` |
| FR-002A | Layout at phone size and 200% text | Flutter-rendered 410×904 frames and 360×640 / 200% widget test; RMX2156 screenshots | Passed | TalkBack spoken output pending |

`projection.png`, `recall.png`, `memory.png`, `impact.png`, and `future.png` are settled Flutter-rendered previews at 410×904 with Google Sans loaded. `device-projection.png`, `device-recall.png`, `device-memory.png`, `device-impact-mid.png`, `device-impact-final-fixed.png`, and `device-future.png` are RMX2156 / Android 12 captures. The earlier `device-impact-final.png` shows the interest line before its width correction and is superseded by `device-impact-final-fixed.png`.

Final checks: `dart format --output=none --set-exit-if-changed` changed no files; targeted `flutter analyze --no-pub` found no issues; the three targeted onboarding test files passed 42 tests. `flutter build apk --debug --no-pub --android-project-arg=kotlin.incremental=false --android-project-arg=ksp.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process` succeeded with Android Studio JBR and workspace-local temp paths. `adb -s X4GEAYDMWGAUI7WG install -r -d build/app/outputs/flutter-apk/app-debug.apk` returned `Success`, preserving app data. The device walkthrough chose 400 for question 8, selected “I don't remember any,” reached the impact and ten-year pages, and returned with system Back to recheck the final impact layout. No Reels/Shorts counting was tested.

The later particle-motion refinement and physical-device recordings are in [`../2026-11-15-onboarding-particle-motion/README.md`](../2026-11-15-onboarding-particle-motion/README.md); they supersede the motion gap in this earlier record.
