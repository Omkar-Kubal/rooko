# Onboarding, Counting, and Today Integration Plan

> **For agentic workers:** execute inline with `superpowers:executing-plans`.

**Goal:** Connect onboarding choices, Android access, and selected-app reel-counting signals to Today, leaving History and Settings unchanged.

**Architecture:** Flutter owns setup and presentation. Kotlin owns the package/version-gated Accessibility service, candidate/dwell/dedupe logic, local per-day app counts, service state, and a typed bridge. Today refreshes native state when the app resumes.

**Tech Stack:** Flutter/Dart, SharedPreferences, Kotlin AccessibilityService, Android local persistence, Android 12/API 31 RMX2156.

**Spec:** `docs/superpowers/specs/2026-11-06-onboarding-today-integration.md`; PRD UX-01–UX-05; SRS FR-001–005, FR-010–017, FR-030–031, FR-040–041, bridge §5.2.

## Global constraints

- Preserve onboarding layout and leave History and Settings screen content unchanged.
- Require affirmative in-app consent before opening Accessibility Settings; query actual service state on return.
- Observe selected supported packages only. Do not read/log/persist feed text or media.
- Key profiles to exact installed app versions; unknown versions fail closed.
- Apply the SRS 750 ms dwell and five-minute duplicate window; no unsupported count may drive a hard limit.
- Report the remaining PRD multi-device accuracy gate; one RM cannot satisfy it.

## Review focus

- Consent is not acknowledged: Settings must not open.
- User declines, returns without grant, or revokes later: Today remains usable and tracking reports off.
- Package is not installed, not selected, or version is unknown: no event is observed/countable.
- Repeated UI events on a stationary item do not increase the total.
- App process restarts or local date changes: the displayed per-app/day total remains scoped to the local date and duplicate handling fails closed.

## File map

- `lib/core/platform/tracking_platform.dart`: typed Dart façade for permission, app support, and Today snapshot methods.
- `lib/features/onboarding/app_flow_screen.dart`: consent-gated settings launch, return verification, and persisted onboarding handoff.
- `lib/features/onboarding/onboarding_screens.dart`: accurately render current access/support result in the existing UX-03/UX-04 layout.
- `lib/features/today/today_home_screen.dart`: show native counts and access/coverage state; do not change History/Settings content.
- `android/app/src/main/kotlin/com/appylab/syncscroll/SelectedAppAccessibilityService.kt`: selected package filtering and structural event normalization.
- `android/app/src/main/kotlin/com/appylab/syncscroll/ReelDetector.kt`: pure profile, transition, dwell, and dedupe rules.
- `android/app/src/main/kotlin/com/appylab/syncscroll/LocalCountStore.kt`: local daily per-app aggregate and duplicate-key persistence.
- `android/app/src/main/kotlin/com/appylab/syncscroll/MainActivity.kt`: versioned MethodChannel mapping and actual enabled-service query.
- `android/app/src/main/AndroidManifest.xml` and `android/app/src/main/res/xml/scroll_accessibility_service.xml`: service declaration and package scope.
- `android/app/src/test/kotlin/com/appylab/syncscroll/ReelDetectorTest.kt`: native counting rules.
- `test/features/onboarding/app_flow_screen_test.dart` and `test/features/today/today_home_screen_test.dart`: consent, persistence, status, and Today integration.

## Implementation status (2026-11-06)

### Detector rules — complete

- [x] Added exact package/version matching, selected-package gating, recognized-feed gating, 750 ms dwell, stationary-item handling, and five-minute duplicate rejection in `ReelDetector.kt`.
- [x] Added and ran native unit tests for the detector; all cases passed.
- [x] Instagram 454.0.0.54.77 has an estimate-only structural clips-pager profile. YouTube 21.43.523 has no usable Shorts transition profile and remains unsupported.

### Native service and local counts — complete

- [x] Registered the consent-gated AccessibilityService with Android's explicit service permission, selected-package allowlist, no gesture capability, and no `isAccessibilityTool` claim.
- [x] Added exact app/version checks; unsupported versions fail closed. The service reads structural view IDs and page indices only for selected packages and does not access node text or media.
- [x] Persisted local daily per-app aggregates and salted temporary duplicate hashes; native tests cover aggregation and duplicate expiry.
- [x] Added the versioned MethodChannel for selected IDs, consent, actual service state, app versions/support, Android Settings launch, and Today snapshots.

### Flutter flow and Today — complete

- [x] Onboarding persists selections and the optional cap, requires affirmative acknowledgement before opening Android Settings, and queries actual service state on return.
- [x] Today reads native daily counts and displays access, per-app support/confidence, last access check, and saved limit state.
- [x] Estimates are clearly labeled and cannot activate limits. History and Settings app screens were not changed.
- [x] `flutter test` — 18 passed; `flutter analyze` — no issues.

### RM device verification — complete for this device pass

- [x] Android unit tests passed with `:app:testDebugUnitTest --rerun-tasks`; `flutter build apk --debug` succeeded and installed on RMX2156 without clearing app data.
- [x] Device: Android 12/API 31; Instagram 454.0.0.54.77; YouTube 21.43.523. Two deliberate Instagram Reels swipes added two estimates; waiting on a stationary Reel did not increment. YouTube Shorts exposed no usable item-transition signal and remains unsupported.
- [x] After the authorized test, Sync Scroll was turned off in Android Settings. Today refreshed to “Tracking is off,” “Access off,” two estimated Instagram items, and unsupported YouTube status. The reference app's previously enabled BrainPal Accessibility service was restored; Sync Scroll remains off.

## Acceptance checks

- [x] Onboarding selections and optional limit preferences are connected to Today; the RM screen showed two selected apps. No limit was configured in that live session.
- [x] Android Settings launch is gated by acknowledgement; actual access is queried from Android rather than inferred from intent return.
- [x] Detector unit coverage verifies package/version, selection, feed, dwell, stationary-item, and duplicate gates.
- [x] Unsupported app/version and access-off states are displayed without fabricating counts.
- [x] Today refreshes after returning from a selected app and remains usable after access is revoked.
- [x] History and Settings app screens are unchanged.
- [x] Device results are labeled estimated/unverified and do not imply that the PRD accuracy gate passed.

## Open validation gates

- The RM test is a smoke test only. The PRD gate still requires at least 200 labeled item transitions and 100 stationary/non-feed cases per launch-supported app across three device families, precision ≥98%, recall ≥90%, and zero stationary repeats. Instagram remains estimated and YouTube 21.43.523 unsupported.
- Revocation state was checked on return to Today, but the FR-006 five-second recovery threshold was not timed as a dedicated benchmark.
- Recheck current Google Play disclosure and Accessibility declaration requirements before release; the Play Console declaration/review is not complete.
