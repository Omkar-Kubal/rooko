# Samsung Android 16 counter pilot

## Scope

Quick device validation of the Ready Rook floating counter and the debug-only text-key estimate path using the installed Instagram, YouTube, and Facebook versions. This pilot cannot establish confirmed support; production profiles remain subject to the full SRS accuracy corpus.

## Setup evidence

| Check | Result |
|---|---|
| Device | Samsung Galaxy A07, model SM-A076B, Android 16 / API 36, ADB serial `R9ZL704T1GP` |
| App install | Sync Scroll debug build 27 (`com.appylab.syncscroll`, target SDK 36), installed with `adb install -r`; no prior Sync Scroll installation or app data to clear |
| Follow-up build | On 2026-11-09, debug build 28 was installed in place with `adb install -r`; app data, selections, consent, and permission state were preserved. Package version code: `28`. |
| Instagram | `454.0.0.54.77`; exact debug estimate profile exists |
| YouTube | `21.40.165`; build 27 had no matching debug profile. Build 28 adds this exact version to the debug estimate profile; release builds and unmatched versions remain unsupported. |
| Facebook | `586.0.0.52.53`; no debug estimate profile |
| App selection | Instagram, YouTube, Facebook selected in onboarding at the user's direction |
| Consent / Accessibility | User completed the in-app disclosure and manually enabled the service. Android reports `com.appylab.syncscroll/com.appylab.syncscroll.SelectedAppAccessibilityService`. Today now shows Instagram as `Estimate-only counting`, confirming the separate debug text-key consent is active; YouTube and Facebook remain unsupported. Coverage currently says `Monitoring was interrupted today` following setup, so baseline coverage is partial. |
| Overlay opt-in | User accepted Sync Scroll's separate floating-counter disclosure. The in-app `Show live counter` option is on. Android `appops get` reports `SYSTEM_ALERT_WINDOW: allow`. |
| Service state | `dumpsys accessibility` shows Sync Scroll as an enabled, bound service on API 36. |
| Rook preview | Settings preview displayed the Rook medallion, `0`, `EST.`, and close control over the Sync Scroll Settings screen. Screenshot: [`2026-11-09-android16-counter-preview.png`](2026-11-09-android16-counter-preview.png). No target-app content was in the screenshot. |
| Reels navigation | The two deep links launched Instagram's `MainTabActivity` but did not trigger the overlay. After the user manually opened Reels, Sync Scroll's overlay window appeared. Only activity and overlay-window metadata were inspected. |
| YouTube navigation | Before build 28, the `https://www.youtube.com/shorts` link launched YouTube `InternalMainActivity`; no overlay appeared. After build 28, the user manually opened Shorts and the Sync Scroll overlay window appeared. Only activity/window metadata and aggregate counts were inspected; no feed UI tree or screenshot was captured. |

## Live pilot results

Instagram was on the recognized Reels viewer when Sync Scroll's overlay window appeared. We did not inspect its screen tree or take feed screenshots. The Instagram estimate aggregate was read from the local daily aggregate only; no item text or identity was read from app storage.

| Sequence | Input | Instagram estimate aggregate | Observation |
|---|---:|---:|---|
| Before opening Reels | — | 0 | Today showed Instagram as estimate-only; no confirmed counts. |
| Batch 1 | 5 vertical swipe gestures | 0 → 4 | Four estimate increments observed. Exact distinct-item ground truth was not independently checked. |
| Batch 2 | 5 vertical swipe gestures | 4 → 8 | Four estimate increments observed. The overlay was present after the batch. |
| Return to Instagram | No deliberate swipe; wait 3 seconds | 8 → 9 | One estimate appeared on re-entry. Could be a new eligible entry item or a repeat; item ground truth is unavailable. |
| Stationary hold | 3 seconds, no swipe | 9 → 9 | No repeat increment. |
| Batch 3 | 5 vertical swipe gestures, 1.5-second dwell; aggregate read after each | 9 → 14 | Each gesture was followed by one estimate (`10, 11, 12, 13, 14`); the overlay remained present. |

The final Today screen after the initial build 27 Instagram pilot showed `14 estimated`, `No confirmed counts yet`, Instagram `14 est. · Estimate-only counting`, YouTube `Unsupported app version`, and Facebook `Unsupported app version`. Unsupported values were shown as `—`, not as zero activity. Coverage remained partial because setup interrupted monitoring earlier that day. At that point, YouTube `21.40.165` did not match the then-installed debug profiles `21.42.243` or `21.44.534`; Facebook `586.0.0.52.53` had no debug profile. The later build 28 YouTube profile check is recorded below.

The follow-up YouTube attempt left the Instagram total at 14. Today continued to show YouTube as unsupported. This verifies the current version gate only; YouTube Shorts counting was not tested because this installed version has no exact debug profile and the link did not independently confirm the Shorts viewer.

## YouTube `21.40.165` follow-up

### Profile and build verification

- Added YouTube `21.40.165` as an exact-version, debug-only text-key estimate profile, reusing `reel_recycler` and `reel_player_page_container` from the existing YouTube profiles.
- `:app:testDebugUnitTest -Pkotlin.incremental=false` passed. `DebugEventEstimateTest` confirms `21.40.165` is accepted for debug builds, adjacent version `21.40.166` is rejected, and the profile is rejected in release builds.
- `flutter build apk --debug --build-number=28 --no-pub --android-project-arg=kotlin.incremental=false` succeeded. Build 28 installed with `adb install -r`; the user’s app data was preserved.
- After installation, ADB verified YouTube `21.40.165`, API 36, Sync Scroll Accessibility enabled and bound, `debug_text_test_consent=true`, `bubble_enabled=true`, and `SYSTEM_ALERT_WINDOW: allow`.

### Live YouTube observation

- The YouTube estimate aggregate was `0` before the user opened Shorts. The Shorts URL still opened `InternalMainActivity`; after the user manually opened Shorts and replied “Ready,” the Sync Scroll application-overlay window was present.
- The aggregate increased from `0` to `2` during feed entry/settling and before any deliberate swipe in this follow-up batch. The reading came from the local daily aggregate only. The two increments could not be matched to independently verified distinct Shorts.
- A 3-second stationary-hold command was interrupted before it returned a result. A later ADB check found the Samsung disconnected. No controlled YouTube swipe batch completed, so this run does not measure swipe recall, precision, or stationary behavior.
- No feed text, item key, screen tree, or screenshot was collected. The user’s decision on 2026-11-10 is that the current event-driven estimate logic and completed testing are sufficient as the working counter logic for this iteration. This is a product decision; the observed `0 → 2` remains an estimate observation with unknown item ground truth.

This follow-up verifies the exact-version debug gate, APK build/install, and overlay presence on a manually opened Shorts viewer. It does not establish one-item-per-swipe accuracy or confirmed production support. The overlay should continue to display `EST.`; estimate totals do not activate a limit.

This is a small one-device debug estimate pilot, not an accuracy certification. The two earlier batches recorded four increments per five gestures, and the re-entry increment is unresolved; the final batch recorded five increments per five gestures. A gesture input is not independent ground truth that a distinct Reel advanced. The app versions stay unconfirmed/unsupported for production counting, and estimates did not activate a limit.

## Acceptance mapping

| SRS ID | Acceptance behavior | Evidence | Result / gap |
|---|---|---|---|
| FR-010 | Unknown or unmatched app versions remain unsupported | Build 28 profile unit tests accept YouTube `21.40.165` only in debug, reject `21.40.166` and release; Samsung API 36 showed overlay presence after the user opened Shorts | Exact-version debug estimate path verified. No confirmed release profile; Facebook and other unmatched versions remain unsupported. |
| FR-012 | Confirmed counts require 1,000 ms exposure and identity checks | The debug estimator uses 150 ms settling and 500 ms spacing; Instagram and YouTube live aggregates are labeled estimated. YouTube entry produced `0 → 2` before deliberate swipes. | User accepts current estimate logic for this iteration. One-second confirmed exposure, identity accuracy, and YouTube swipe accuracy were not validated. |
| FR-050 | Floating counter requires opt-in and shows the count/quality marker | Separate in-app disclosure accepted; overlay permission allowed; Rook preview screenshot; live overlay window metadata on recognized Instagram Reels and user-opened YouTube Shorts | Permission and overlay presence verified on API 36. Live YouTube appearance/placement, occlusion, and broader device coverage remain unreviewed. |

