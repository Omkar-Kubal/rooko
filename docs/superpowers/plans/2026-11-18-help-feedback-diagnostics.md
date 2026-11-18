# Help & Feedback implementation plan

**Design:** [`../specs/2026-11-18-help-feedback-diagnostics-design.md`](../specs/2026-11-18-help-feedback-diagnostics-design.md)

## Task 1 — Extend the Android support bridge

- In `lib/core/platform/tracking_platform.dart`, add optional `androidVersion`
  and `androidApiLevel` fields to `TrackingSnapshot`, parsed from nullable map
  values.
- Add `SupportEmailKind { featureRequest, support }` and methods
  `Future<bool> openSupportEmail(SupportEmailKind kind)` and
  `Future<bool> openSupportedAppSettings(String appId)` to `TrackingPlatform`.
- Implement those methods in `MethodChannelTrackingPlatform` with a
  `supportEmailKind` or `appId` argument. Do not accept arbitrary email address
  or package strings from Flutter.
- In `MainActivity.kt`, include `Build.VERSION.RELEASE` and
  `Build.VERSION.SDK_INT` in the tracking snapshot. Allow only the two
  supported app IDs for `ACTION_APPLICATION_DETAILS_SETTINGS`. Map the two
  support-email enum values to the fixed Proton Mail recipient and fixed
  subjects, using `ACTION_SENDTO` with a `mailto:` URI; return `false` if no
  handler opens.
- Add no external dependency. Update existing fake `TrackingPlatform`
  implementations only so analyzer can resolve the expanded interface.

## Task 2 — Add release notes and Help & Feedback entry points

- Add local Sync Scroll release-note data for the current version under
  `lib/features/settings/` without inventing past release history.
- Add reusable Support sheet presenters in
  `lib/features/settings/help_feedback_sheets.dart`.
- Add **What's New** and active **Help & Feedback** rows to the Settings Support
  group. What's New shows the bundled current-version notes. Help & Feedback
  presents Troubleshoot counting, Feature Requests, and Support Email.
- Route email rows through `TrackingPlatform.openSupportEmail`; show an inline
  error/snackbar when Android has no email handler. Route troubleshooting to
  `HelpDiagnosticsScreen` while keeping Back behavior intuitive.

## Task 3 — Build the local troubleshooting screen

- Add `lib/features/settings/help_diagnostics_screen.dart` with typed
  user-facing status strings derived from `TrackingSnapshot`.
- Refresh the selected-app status on entry and every app resume. Render load
  failure with a retry action and do not treat missing snapshot fields as
  granted access.
- Show consent, Accessibility grant/operation, selected app install/version and
  counting-path availability, and the optional counter toggle/overlay grant as
  independent sections. Do not infer a current feed from last-count time.
- Provide consent-aware Accessibility recovery, overlay settings recovery only
  when overlay is opted in, installed app-info actions, and a route back to app
  selection. Re-query actual status after Android settings returns.
- Keep visuals monochrome, accessible, scrollable at large text, and consistent
  with existing `AppTypography`, `AppColors`, `AppSpacing`, `AppRadii`, and
  `AppIcons`.

## Task 4 — Add the reviewed diagnostic summary

- Build the report from an explicit allowlist: app version, Android release/API,
  consent, Accessibility grant/operation, selected supported-app names and
  installed version, coarse availability, and counter/overlay state.
- Show the exact report and its exclusions in a confirmation dialog before
  writing it to the clipboard. Do not include counts, observed time, timestamps,
  device IDs/model, feed content, screenshots, Accessibility trees, or item
  identifiers. Do not add sharing or network upload in this pass.
- Surface a brief confirmation after copying.

## Task 5 — Update the product contract and verify

- Change PRD UX-11 from planned to implemented behavior and add an SRS Support
  requirement covering status, recovery, mail composer, local release notes,
  and report exclusions.
- Update `context.md` and `progress.md` with the accepted behavior and exact
  formatter/analyzer/build evidence.
- Run `dart format` on changed Dart files, `flutter analyze --no-pub`, and
  `flutter build apk --debug` with Android Studio JBR and the workspace SQLite
  temporary directory. Do not run automated tests or open Reels/Shorts feeds.
