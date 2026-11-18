# Eight-state Rook wiring follow-up

Date: 2026-11-14

This closes the integration and accessibility follow-up to the [initial Rook wiring QA](../2026-11-14-rook-state-wiring/README.md). Product behavior remains governed by the [PRD](../../PRD.md) and [SRS](../../SRS.md), including FR-031, FR-035, FR-050–051, and FR-053–059. Daily limits, limit interruptions, and overrides remain deferred; stored legacy limit values remain inert.

## Follow-up changes

- Sync Scroll Activity resume consumes an already-recognized feed ID and reports an exit through the existing consent, selected-app, validated-profile, and service-operational checks. The Accessibility service still ignores its own overlay-generated events.
- A selected-profile availability gap or changed selected-app/profile fingerprint now invalidates the current History verification day immediately. Registry changes compare the selected profile set before and after an update; invalidation is deduplicated by local date.
- At local midnight, refresh the counter's new-day pose/count only when it is already visible and retained feed IDs resolve to currently selected, validated installed profiles. Stale IDs are dropped, so a hidden counter cannot be restored from cached recognition.
- The floating counter’s accessible “Hide floating counter” control now has a 48 dp touch target. A Robolectric test inspects the real overlay view and its click/focus semantics.

## Acceptance evidence

| SRS IDs | Verified behavior | Evidence | Remaining gap |
| --- | --- | --- | --- |
| FR-031, FR-058 | Host resume reports a recognized exit once; count-state logic, unavailable-monitoring precedence, and rollover remain covered by native and Flutter tests | `HostActivityResumePolicyTest`, `ValidatedFeedExitPolicyTest`, Flutter Rook state tests; latest Today capture and accessibility tree | No live feed transition on this device: Accessibility is off and selected app versions lack validated profiles. |
| FR-050–051, FR-059 | Counter rollover refresh, no resurrection after hidden/root-loss/profile revocation, static Ready preview, shared 0 badge, and accessible dismiss target | `FloatingCounterDayRolloverTest`, `FloatingCounterMidnightEligibilityTest`, `FloatingCounterPolicyTest`, `FloatingCounterOverlayAccessibilityTest`; [updated Settings counter preview](counter-midnight-fix.png) | Live count-band changes, overlay permission revocation, and recognized-feed loss were not exercised on device. Earlier drag/dismiss captures remain in the initial QA record. |
| FR-035, FR-053, FR-055, FR-059 | A profile-loss gap stays unverified after profiles return; changed fingerprints invalidate the candidate; Room migration and personal-best ordering remain covered | `DayVerificationInvalidationPolicyTest`, `HistoryRepositoryTest`, `HistoryMigrationTest`, `DailyVerificationPolicyTest`; 130-test Android run | No verified personal-best fixture existed on device, so Victorious was not displayed there. No test data was written to the device. |
| FR-056–057 | Today renders Sleeping with matching artwork and the “Sleeping Rook” accessible label; History and the counter preview render on-device; reduced motion, app background, and SVG fallback remain covered by Flutter tests | [Updated Today](today-midnight-fix.png), [Today UI tree](today-midnight-fix-ui.xml), [updated History](history-midnight-fix.png), [Settings with the counter preview](counter-midnight-fix.png), `flutter test --no-pub` | Rive load failure was not fault-injected; live band and animated-state review is limited by unsupported installed app versions. |

## Verification run

- Focused Android rollover/eligibility tests — `FloatingCounterDayRolloverTest` and `FloatingCounterMidnightEligibilityTest` passed after the new hidden-root and revoked-profile assertions initially failed against the stale-refresh behavior.
- `flutter test --no-pub` — 71 passed.
- `flutter analyze --no-pub --no-fatal-infos` — exit 0; no warnings or errors. Three informational Rive boolean-input deprecations remain in `lib/features/today/rook_mascot.dart`.
- `dart format --output=none --set-exit-if-changed lib test` — exit 0; 28 files checked, none changed.
- From `android/`, `:app:testDebugUnitTest --no-daemon --max-workers=1 '-Pkotlin.incremental=false' '-Pkotlin.compiler.execution.strategy=in-process'` — **130 tests, 0 failures, 0 errors, 0 skipped** across 30 app suites.
- Focused TDD evidence for the 48 dp dismiss-target fix: the test failed on the original layout with `expected:<48> but was:<32>`, then passed after widening the real view to 48 dp; the full Android suite passed after the change.
- `flutter build apk --debug --no-pub --android-project-arg=kotlin.incremental=false` — succeeded; `adb install -r` succeeded without clearing application data. Updated APK SHA-256: `8437BEF8630FAEC692A0AF88C5B58B40563AAAD38D58E34D24FCC093D93B661D`.

## Device evidence and limits

- Target: Realme RMX2156, Android 12 / API 31, package `com.appylab.syncscroll`. Accessibility access remained off and overlay access remained allowed; app selection and stored data were preserved.
- After installing the updated APK, Today showed Sleeping and the access prompt; its UI tree exposes `Sleeping Rook`. History rendered the existing week record, and the Settings preview showed transparent Ready artwork with the shared `0` badge over the monochrome surface. The overlay window is not included in the OS UI hierarchy dump; the real-view native test verifies its accessible dismiss target is 48 dp. The latest crash-buffer scan had no app fatal-exception or signal entries.
- Latest saved captures: [Today](today-midnight-fix.png), [Today UI tree](today-midnight-fix-ui.xml), [History](history-midnight-fix.png), [Settings with counter preview](counter-midnight-fix.png), and [Settings UI tree](settings-midnight-fix-ui.xml). No synthetic counts or verification records were added. Accessibility remained off, overlay access remained on, two app selections and all saved data were preserved, and the device was returned to Today.
- Live feed-exit, midnight, and permission-loss transitions could not be exercised on-device because Accessibility is off and installed Instagram/YouTube versions lack validated profiles. An on-device Victorious record also remains unavailable. Automated policy and repository tests cover deterministic rules. Rive load failure was not fault-injected. The existing cold-start measurement remains 8.9 seconds against the separate two-second target.
