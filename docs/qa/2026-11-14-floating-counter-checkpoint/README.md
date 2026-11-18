# Floating counter disappearance during long Reels session

Date: 2026-11-14. User observation: Reels and Shorts counts matched their scrolling in the former experimental build. During a Reels session, the entire live floating counter disappeared near count 53. Today and the counter preview showed the updated count; the Floating counter Settings switch remained on. The agent did not open either feed.

## Investigation

`SelectedAppAccessibilityService` runs a History verification checkpoint every five minutes and also called `refreshFloatingCounterForLocalDay()` on each checkpoint. Before this fix, the refresh method rescanned the active Accessibility root on **same-day** checkpoints when the overlay was visible. If the root was briefly unavailable during a swipe, it immediately hid the overlay, although neither consent nor the overlay setting changed. `FloatingCounterDayRollover` already knew whether the local date had changed, but the service did not check that before rescanning. This is a deterministic premature-hide path consistent with the report; the precise trigger on the user's device was not captured.

The service now skips local-day overlay refresh when the date has not changed. At midnight it still rechecks the current feed and eligibility for an already-visible counter. Foreign-window and permission-loss hide paths are unchanged.

| SRS ID | Acceptance behavior | Evidence | Result | Remaining evidence |
| --- | --- | --- | --- | --- |
| FR-050 | Count pose and badge remain visible across an ordinary checkpoint | Robolectric test with visible count 53 and temporarily missing root | Test failed before the fix at the visibility assertion and passed after it | User live test |
| FR-051 | Midnight can refresh visible overlay; hidden overlay stays hidden | Existing midnight eligibility tests | Passed after fix | User midnight/device test |

## Verification

- The new Robolectric test failed before the fix at `same-day checkpoint must not hide a visible counter`; after the fix, the targeted `FloatingCounterMidnightEligibilityTest` class passed.
- `:app:testDebugUnitTest :app:assembleDebug :app:assembleRelease --no-daemon --max-workers=1 -Pkotlin.incremental=false -Pksp.incremental=false -Dkotlin.compiler.execution.strategy=in-process`: build succeeded. Android XML reports 135 tests, 0 failures, 0 errors, 0 skipped.
- `flutter test`: 79 passed. No Dart UI code changed in this patch.
- `adb install -r build/app/outputs/apk/debug/app-debug.apk`: `Success` on the connected RMX2156, preserving app data. No Reels or Shorts feed was opened by the agent.
- Debug APK: `build/app/outputs/apk/debug/app-debug.apk`, SHA-256 `9CA55673B558FF49B1D806A09EA815A35184C6216FF2A11F52CADA458115FF09`.
- Release APK: `build/app/outputs/apk/release/app-release.apk`, SHA-256 `5D578FD7C88925D61F0D83F046E4F1704D2B9721605D4F4BE99CE127082DE56E`.

The user will check live overlay persistence during a long Reels session. This regression proves the identified same-day checkpoint hide path is removed; it does not prove that this was the exact event behind the earlier device observation or rule out other hide paths.
