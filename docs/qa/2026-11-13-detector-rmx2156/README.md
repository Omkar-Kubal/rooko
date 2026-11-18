# Detector registry and RMX2156 follow-up

Date: 2026-11-13  
Device: RMX2156 / Android 12 / API 31  
Installed target apps: YouTube `21.45.82`; Instagram `455.0.0.51.72`

## Outcome

The signed online version registry is reachable and its sequence-1 payload matches the cached digest on the RMX2156. It lists both installed versions as `catalogued`, with no profile IDs. The APK still has an empty production profile map, so neither app is enabled for counting. This is intentional: a registry entry identifies a version but does not provide detector logic or prove item identity/accuracy.

The current Sync Scroll debug APK installed and launched successfully on the RMX2156. The Accessibility service remained off (`settings get secure enabled_accessibility_services` returned `null`), so the current-version structural feasibility run could not start. No feed text, screenshots, or media were collected, and no permission setting was changed.

## Acceptance evidence

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-018 | Fetch a bounded, signed registry; verify it before caching; avoid sending installed app/version data. | Direct HTTPS request: HTTP 200, no redirect; P-256 signature verified using DER ECDSA format; payload sequence 1. Live payload SHA-256 equals the RMX2156 cached digest `32a7421a56c737e22a2f6c0df9776b026c41cd150d4a5c26e45e8c29fcbb8310`. | Passed for live host and device cache. | Request capture and host access-log review remain unavailable. |
| FR-010 | Match the locally installed exact app version to registry availability and a bundled detector profile. | RMX2156 package inventory and cached signed registry entries for YouTube `21.45.82` and Instagram `455.0.0.51.72`; both are `catalogued` with no profile ID. `DetectorProfiles` production map remains empty. | Exact versions are identified; both correctly fail closed for counting. | Neither exact version has a validated detector profile. |
| FR-021 | Enable app/version counting only after the accuracy gate. | `:app:testDebugUnitTest --rerun-tasks` passes 113 tests; current-version live feed corpus was not run. | No profile enabled. | Each exact version still needs at least 200 labeled transitions and 100 stationary/non-feed cases across three device families, with precision ≥98%, recall ≥90%, and zero stationary repeats. |
| Android permission flow | Require user-controlled Accessibility setup and verify its real state. | RMX2156 Android secure setting returned `null` before and after install/launch. | No permission was changed; app remained usable and launched. | Device owner must enable Sync Scroll Accessibility before a structural feasibility pass. |

## Verification

- Android unit suite: `:app:testDebugUnitTest --rerun-tasks --no-daemon -Pkotlin.incremental=false` — 113 tests, 0 failures, 0 errors, 0 skipped. Room's verifier requires `org.sqlite.tmpdir` to point to a writable workspace directory in this environment.
- Flutter: `flutter test --no-pub` — 50 passed.
- Flutter analyzer: `flutter analyze --no-pub` — exit 0, no errors; five existing Rive deprecation info notices.
- Debug APK: `:app:assembleDebug` — succeeded with Android Studio JBR, `kotlin.compiler.execution.strategy=in-process`, `kotlin.incremental=false`, and the workspace SQLite temp directory.
- RMX2156: `adb install -r -d build/app/outputs/apk/debug/app-debug.apk` — success; `am start -W -n com.appylab.syncscroll/.MainActivity` — `Status: ok`, cold launch 7.17 s; app process remained alive and MainActivity resumed.
- Device permission state was not altered. A fresh detector count test was not possible while Accessibility was off and no profile was enabled.

## Next gate

The device owner must enable Sync Scroll through Android Settings, then a privacy-safe structural-only feasibility run can check whether these exact versions expose usable feed markers and transition signals. That single-device pass can only decide whether further study is worthwhile; it cannot satisfy the three-device accuracy gate. Do not publish a profile or count these versions until the exact-version gate passes.

## Symptom triage (later on 2026-11-13)

The RMX2156 was checked again after the user reported that the floating counter was absent and the count was not increasing.

- Accessibility is now enabled and `dumpsys accessibility` lists Sync Scroll as a bound service. Android overlay app-op is allowed.
- Local settings contain affirmative tracking consent, YouTube and Instagram selection, and `bubble_enabled=true`; debug text-key consent is false.
- Sync Scroll `MainActivity` is currently resumed. Its `onResume()` hides the floating overlay while Sync Scroll is in the foreground.
- In either target app, `SelectedAppAccessibilityService` returns early and hides the overlay when `DetectorProfiles.forVersion(...)` returns null. That is the current result for both installed versions, so the detector cannot write new counts. Neither version has a debug text-key profile either.
- A ten-minute, 128 KB capped structural-only probe marker was created. The separately consented identity-relation marker is absent, so no node IDs or text are collected. Android Accessibility settings were opened so the device owner can reconnect the service after the marker is set; no permission was changed by ADB. No probe rows have been collected yet.

The exact user-visible symptoms are therefore explained by current state and support gating: the app is foreground (overlay hidden by design), and the selected target versions have no counting profile. To gather current-version feasibility evidence, the device owner must toggle only Sync Scroll's Accessibility service off and back on in Android Settings, then manually open Instagram Reels or YouTube Shorts and perform a brief hold/swipe/hold sequence while the marker is active. The probe output contains only allowlisted resource IDs, event metadata, and bounded structural features; it does not capture feed text, images, audio, video, or screenshots.
