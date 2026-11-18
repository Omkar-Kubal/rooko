# Eight-state Rook wiring QA

Date: 2026-11-14

This initial pass wires the approved Rook states to Today, History, and the Android floating counter. Current product authority is [PRD](../../PRD.md) and [SRS](../../SRS.md), especially FR-031, FR-035, FR-050–051, and FR-053–059. Limits and limit-driven interruptions/overrides remain deferred; legacy preference values stay stored but inert.

The final integration and accessibility follow-up is [recorded separately](../2026-11-14-rook-state-wiring-follow-up/README.md). Its fresh Android suite result (127 passed) supersedes the 119-test count below; the original device captures and drag/dismiss check remain evidence for the first pass.

## Behavior delivered

- Today and the floating counter use the same combined selected-app count: Ready 0–49, Strained 50–99, Injured 100–149, Queasy 150–199, Vomiting 200+.
- Today gives Sleeping precedence when consent, monitoring access, or all selected validated profiles are unavailable. A recent validated Android feed-exit signal may select Recovering for up to 600 ms; overlay permission alone does not change Today’s pose.
- History shows Victorious only for the most recent strictly lower, fully verified combined-count day in the visible period. The first verified day is the baseline; incomplete and migrated legacy days remain unknown.
- Every state has transparent SVG art and eye-only Rive animation. Ready through Queasy use the shared `assets/rook/rook.riv`; Vomiting, Recovering, Victorious, and Sleeping use dedicated Rive files. Flutter uses the matching SVG for reduced motion, backgrounding, or Rive failure. The floating counter uses static PNGs for its five count poses.
- The native counter retains its count badge and top-center initial position, switches image only when the band changes, and keeps drag/dismiss and permission/feed-loss hiding behavior.

## Acceptance map

| SRS ID | Acceptance behavior | Evidence | Result | Remaining gap |
| --- | --- | --- | --- | --- |
| FR-031, FR-058 | Combined total selects all five bands; Sleeping/Recovering precedence and validated feed-exit window | `flutter test --no-pub` (71 tests); `test/features/today/rook_state_test.dart`; `test/features/today/today_home_screen_test.dart`; Android `ValidatedFeedExitPolicyTest`; fresh RMX2156 Today screenshot and UI tree | Passed | Live count bands were not exercised because the selected device app versions are unsupported and Accessibility is off. Boundaries are covered by unit tests. |
| FR-050–051, FR-059 | Counter uses five static poses and combined badge, remains movable/dismissible, and hides when required monitoring/overlay/feed conditions fail | `RookCountPoseTest`, `FloatingCounterPolicyTest`; RMX2156 counter preview, drag, and dismiss screenshots | Passed for mapping, preview, drag, and dismiss | A live recognized-feed transition and actual overlay-permission revocation were not run on the phone. Permission/feed gating is covered by native policy tests. |
| FR-035, FR-053, FR-055, FR-059 | Conservative day verification, migration of older records as unknown, strict personal-best ordering, baseline and verified zero-count handling | Android `:app:testDebugUnitTest --rerun-tasks`: 119 passed, 0 failures/errors/skips; includes `DailyVerificationPolicyTest`, `HistoryMigrationTest`, and `HistoryRepositoryTest`; Flutter History tests cover the visible Victorious card and unknown/zero-day behavior | Passed in automated tests | The phone had no verified personal-best record, so Victorious was not shown in the device capture. No fixture data was added to the device. |
| FR-056–057, FR-059 | Eight typed states, matching transparent SVG/Rive assets, eye-only motion, background/reduced-motion fallback | Flutter tests verify every SVG frame paints, every Rive asset is bundled, all reduced-motion frames render, and background uses SVG. Per-state runtime/render evidence: [Strained](../2026-11-14-rook-strained-rive/README.md), [Injured](../2026-11-14-rook-injured-rive/README.md), [Queasy](../2026-11-14-rook-queasy-rive/README.md), [Vomiting](../2026-11-14-rook-vomiting-rive/README.md), [Recovering](../2026-11-14-rook-recovering-rive/README.md), [Victorious](../2026-11-14-rook-victorious-rive/README.md), [Sleeping](../2026-11-14-rook-sleeping-rive/README.md) | Passed for assets and the exercised fallback paths | Rive’s explicit failed-load fallback is implemented but was not fault-injected in this pass. |

## Commands and results

- `flutter test --no-pub` — 71 passed.
- `flutter analyze --no-pub --no-fatal-infos` — exit 0; no errors or warnings. Three informational Rive boolean-input API deprecations remain in `lib/features/today/rook_mascot.dart`.
- `dart format --output=none --set-exit-if-changed lib test` — exit 0; 28 files checked, none changed.
- From `android/`: `.\gradlew.bat :app:testDebugUnitTest --no-daemon --rerun-tasks '-Pkotlin.incremental=false'` — 119 passed, 0 failures/errors/skips.
- `flutter build apk --debug --no-pub --android-project-arg=kotlin.incremental=false` — succeeded in 36.8 seconds. APK: `build/app/outputs/flutter-apk/app-debug.apk`, SHA-256 `32739C03268F5D7C2ABF6B8079D32B9877746835963E1A63B1D88857E4639B83`.

## Device evidence

- Target: Realme RMX2156, Android 12 / API 31, package `com.appylab.syncscroll` 1.0.0 (code 1). The rebuilt APK installed with `adb install -r` and launched without clearing app data.
- Accessibility remained off and overlay permission remained allowed; neither setting was changed. Today showed the Sleeping Rook and an access prompt, confirming unavailable-monitoring precedence while the optional overlay grant alone had no effect on its pose. The UI tree exposes the accessible label `Sleeping Rook`.
- Settings’ counter preview showed transparent Ready art with a `0` badge. A drag moved it over the Settings content; dismissing it within the 10-second preview window closed the overlay and left Settings in place. The first attempted close occurred after that preview timeout and hit the underlying Apps row; the repeat within the active window passed. App selection remained unchanged.
- History showed an existing saved weekly total of 9 and no Victorious card. No count or verification fixture was written to the phone.
- Captures: [Today](today-rmx2156.png), [Today accessibility tree](today-ui-fresh.xml), [History](history-rmx2156.png), [counter preview](counter-preview-rmx2156.png), [counter after drag](counter-drag-rmx2156.png), [counter after dismiss](counter-drag-dismiss-rmx2156.png).

## Limits of this verification

The exact Instagram and YouTube versions on this phone do not have validated production profiles, so a live feed count/state transition could not be exercised without bypassing the fail-closed detector rule. Device testing therefore covers the permission-off Today pose and the manual counter preview; fixed bands, feed-exit logic, and verified-history ordering rely on automated tests and the per-asset Rive evidence above. Cold launch took 8.9 seconds on this device; the existing two-second startup target remains a separate open release gate.
