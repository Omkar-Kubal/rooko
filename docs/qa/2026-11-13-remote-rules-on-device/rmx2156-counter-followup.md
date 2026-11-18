# RMX2156 counter follow-up

Date: 2026-11-13  
Device: RMX2156, Android 12 / API 31  
Installed targets: YouTube 21.45.82; Instagram 455.0.0.51.72

## Current setup

- The user accepted Sync Scroll's tracking disclosure, enabled its Accessibility service, enabled the floating counter and Android overlay access, selected YouTube and Instagram, and opted into the separate debug text-key path.
- Accessibility was enabled in Android Settings. `SYSTEM_ALERT_WINDOW` reported `allow`. The crash buffer was empty.
- The live signed registry remains sequence 1 with 18 catalog entries and zero production detector profiles. Both exact app versions remain unavailable for production counting.
- This run used the debug build and its separately consented, process-local text-key path. No feed screenshot was captured and I did not inspect feed labels.

## Device observations

The 15:07 Today screenshot showed total 6: YouTube 2 and Instagram 4. The Instagram check earlier in this device run added two events after one deliberate Reel advance; returning to Reels without another deliberate advance was followed by two more. This is a duplicate-signal warning.

For YouTube, I reopened the app, tapped the Shorts bottom-navigation position, issued one upward gesture, waited, then returned to Sync Scroll. Today showed total 9: YouTube 5 and Instagram 4. The total remained 9 after a three-second hold on Today. This run did not inspect or capture feed content, so it cannot isolate whether the three YouTube increments came from feed entry, the gesture, or repeated debug signals.

The event totals are inconclusive for one-item counting. The single YouTube gesture correlated with three new events, and the Instagram re-entry was followed by two additional events. The 3-second hold was on Today, so it does not test stationary playback inside either feed.

## Acceptance evidence

| SRS ID | Acceptance behavior | Evidence | Result | Remaining work |
|---|---|---|---|---|
| FR-010 | Resolve exact installed versions only to validated profiles | RMX2156 reports YouTube 21.45.82 and Instagram 455.0.0.51.72; registry has no production profiles | Fail-closed behavior observed | Each exact version needs the full accuracy corpus before support is enabled |
| FR-011 | Process events only while the selected app and short-form feed are foreground | YouTube was foreground for the Shorts navigation and gesture; feed content was not inspected | Inconclusive | Verify recognized-feed gating with privacy-safe instrumentation and labeled test cases |
| FR-012 | Record a visible item only after dwell and identity checks | One YouTube gesture correlated with three new events; Instagram re-entry correlated with two | Not met by this run | Investigate duplicate signals and validate item identity and dwell behavior |
| FR-014 | Repeated signals or time on the same item do not add events | Counts did not change during a 3-second hold on Today; no stationary-feed hold was run | Open | Test stationary feed playback and repeated event callbacks |
| FR-017 | Today uses one shared total across selected apps | Today showed 9 total = YouTube 5 + Instagram 4 | Pass for displayed aggregation | Keep this tied to the same persisted Room totals across History, limits, and the overlay |
| FR-018 | Fetch and validate the signed registry | The earlier runtime check verified the live signed sequence 1 cache; see the parent report | Pass for fetch, signature, and cache | Live payload has no profiles and hosting/key operations remain open |

## Today access-wall correction

Today previously treated a same-day coverage-gap record as missing current access and displayed an access wall after permission had been restored. The UI now bases that wall on current consent/service state while keeping coverage metadata internal. The RMX2156 Today screen after the fix has no access banner, and regression tests cover a recovered service with a past gap.

## Verification

- Flutter widget suite: 52 passed.
- `flutter analyze --no-pub`: exit 0, with five existing Rive deprecation notices.
- Android debug APK assembly and in-place installation on RMX2156 succeeded; app data was preserved.
- Device crash buffer: empty.
- Accessibility service: enabled. Overlay AppOp: `allow`.

## Screenshots

The following captures show Sync Scroll only; no feed screenshot was taken.

![Today before access-wall correction, total 6](rmx2156-today-after-feed-tests.png)

![Today after the correction and YouTube debug run, total 9](rmx2156-today-after-youtube-short-test.png)

![Settings after permissions and debug test setup](rmx2156-settings-after-setup.png)

![Earlier floating-counter preview from before the access-state correction](rmx2156-overlay-preview.png)

## Release status

Neither app version is enabled for production counting. The debug observations do not meet SRS FR-010–FR-015. The release gate still requires, per exact app version, at least 200 transitions and 100 stationary/non-feed cases across three device families, with precision at least 98%, recall at least 90%, and zero stationary repeats. The current RMX2156 run is one device and does not meet that evidence threshold.
