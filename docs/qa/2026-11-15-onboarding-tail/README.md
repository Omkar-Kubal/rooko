# Onboarding continuation — 2026-11-15

The ten user screenshots were used as visual references for the pages after the existing month-grid and particle-head story. The resulting flow uses Sync Scroll copy, Ready Rook, neutral controls, and Instagram/YouTube only. It does not add reference-app claims about feed blocking, roasting, or background access.

## Reduced setup flow follow-up

The user explicitly kept the “Over the next 10 years” 120-dot story page. `kept-future-final.png` captures it on RMX2156; its route and content remain in the five-page story. The standalone app-selection and floating-counter opt-in pages were removed from the active onboarding route after their screenshots were reviewed. Fresh installs select installed Instagram and YouTube by default, with selection editable in Settings. The access checklist carries the optional floating-counter action and its separate overlay guide. The detailed tracking disclosure and affirmative consent remain.

The privacy page now names the selected feed(s) and no longer says that app selection follows. `privacy-final-reduced.png` captures the updated page. On RMX2156 / Android 12, the privacy page led to the tracking disclosure, the access checklist (`access-checklist-reduced-flow.png`), and the final Instagram/Today handoff (`handoff-reduced-flow.png`). This walkthrough used “Not now” at the disclosure; no Android permission was changed and no live feed was tested. The screen hierarchy confirmed both final actions.

The four targeted onboarding test files passed **54/54** with `flutter test --no-pub` after this reduction. Targeted onboarding analysis was clean, and the debug APK was built and installed in place with app data preserved. Device inspection covered the reduced dark-theme path; light/AMOLED appearance, TalkBack spoken output, and a physical overlay-grant return remain open.

Follow-up: the per-app availability rows and the repeated overlay-access paragraph shown in `access-checklist-reduced-flow.png` were removed from the current access checklist. That image is retained as prior evidence. The new `app_flow_screen_test.dart` asserts their absence (32/32 tests passed); targeted analysis is clean. The newer debug APK built and installed in place on RMX2156 with data preserved (SHA-256 `9553E8A630097A7869A1C3EE22A0F9B0A407EF173A59446BE28AB376507C8726`). Onboarding was already completed on the device, so the revised checklist was not visually recaptured. No Android grant or live feed was tested.

## Acceptance evidence

| SRS ID | Behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-001, FR-002A, FR-002B | Story retains the 120-dot ten-year page, then reaches the dotted shield, privacy, access checklist, and final handoff | `kept-future-final.png`, `privacy-final-reduced.png`, `access-checklist-reduced-flow.png`, `handoff-reduced-flow.png` from RMX2156 / Android 12 | Rendered and navigable | Light and AMOLED device review remain open |
| FR-002B | Shared page fades, staged shield reveal, Back, reduced motion, background pause, and old-draft migration | 54 targeted Flutter tests, including shield motion and app-flow transitions | Passed | Physical-device frame timing was not measured |
| FR-001, FR-002B | Accessibility disclosure and guide precede Settings; guide cancellation does not open Settings | `consent-final.png`, `accessibility-guide-final.png`; targeted widget flow tests | Passed | TalkBack spoken output remains open |
| FR-002B, FR-050 | Floating counter is optional from the access checklist and its overlay guide is separately requested | `access-checklist-reduced-flow.png`; targeted opt-in, denial, and Settings-return tests | Passed in widget tests | Overlay guide was not visually captured in the reduced device flow; Android overlay grant was not changed |
| FR-002B | Final app launch is limited to a selected installed Instagram or YouTube app, with Today fallback | `handoff-reduced-flow.png`; targeted handoff tests | Passed | Live Reels/Shorts counting was not tested at the user's request |

## Commands and build

- `dart format --output=none --set-exit-if-changed` on the four changed onboarding Dart files: 0 changes.
- `flutter analyze lib/features/onboarding`: no issues.
- `flutter test --no-pub test/features/onboarding/app_flow_screen_test.dart test/features/onboarding/onboarding_story_screen_test.dart test/features/onboarding/onboarding_question_screen_test.dart test/features/onboarding/rook_privacy_bridge_screen_test.dart --reporter compact`: 54 passed after the setup-flow reduction.
- `flutter build apk --debug --no-pub --android-project-arg=kotlin.incremental=false --android-project-arg=ksp.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process`: passed. The plain incremental build first hit the known cross-drive Kotlin cache failure.
- `adb install -r -d build/app/outputs/flutter-apk/app-debug.apk`: succeeded on RMX2156 / Android 12 without clearing data. Current APK SHA-256: `621AD6BE462F8F14548688BB1EFEF1CD6666693C8EA050563D5D0ED004A1B69B`.

The selected device setup had Instagram installed and selected, with Accessibility off. No live feed or counter test was performed. The earlier History test failure is outside this onboarding change.
