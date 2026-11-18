# Counter preview with generated scenes — RMX2156 — 2026-11-14

## Device review

- Device: RMX2156 (`X4GEAYDMWGAUI7WG`), Android 12 / API 31.
- Built the debug APK using Android Studio JBR and a workspace-local SQLite temp directory. Kotlin/KSP incremental processing was disabled because the regular incremental cache cannot reconcile plugin sources on `C:` with this project on `D:`.
- Installed with `adb install -r build/app/outputs/flutter-apk/app-debug.apk` (`Success`) and relaunched `com.appylab.syncscroll/.MainActivity`. Existing app data was preserved.
- Visual review confirms the Sync Scroll mark and wordmark at the upper left, the phone centered in the content area, a generated photographic scene behind the count/Rook overlay, and no visible back chevron. The example count was 211.
- Follow-up sizing review: increased the phone from 330 dp to 390 dp maximum height (about 18%). The screen now sizes its content to the available viewport, keeping the heading, frame, Pause preview control, preview-only note, and Continue button visible together without scrolling. The final screenshot and accessibility hierarchy show those elements in view.
- Header follow-up: increased the top-left Rook mark from 28 dp to 32 dp and removed the numbered progress labels from every onboarding page. The preview and next Supported Apps intro were opened on device; their UI hierarchy contains no “Welcome · 1 of 4” or “Apps · 2 of 4” label. Existing back navigation remains available on pages that had it. The device was returned to the counter preview.
- No Instagram or YouTube feed was opened, no permissions were changed, and no automated tests were run.

## Checks

- `dart format lib/features/onboarding/onboarding_screens.dart lib/features/onboarding/app_flow_screen.dart` — completed.
- `flutter build apk --debug --no-pub --android-project-arg=kotlin.incremental=false --android-project-arg=ksp.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process` — succeeded.
- `flutter analyze --no-pub` — reported three informational deprecations in `lib/features/today/rook_mascot.dart` for the Rive boolean state-machine API and exited 1. The preview's deprecated opacity call was updated; no analyzer issue remains in the changed onboarding screen.

## Screenshot

Original layout before the frame-size update:

![Counter preview with generated scene on RMX2156](counter-preview.png)

Updated larger frame:

![Larger counter preview on RMX2156](counter-preview-larger.png)

Latest logo size and progress-label update:

![Counter preview without onboarding progress label](counter-preview-final.png)

![Supported Apps intro without onboarding progress label](supported-apps-intro-no-progress.png)
