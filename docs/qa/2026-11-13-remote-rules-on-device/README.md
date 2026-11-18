# Signed remote rules runtime check

Date: 2026-11-13

> **Device follow-up:** the user later accepted the disclosure and enabled Accessibility, overlay access, and the separate debug text-key path. Current RMX2156 counter observations and the Today access-wall correction are recorded in [rmx2156-counter-followup.md](rmx2156-counter-followup.md). The initial device state below describes the earlier registry check before that setup.

## Result

The signed remote profile client and publisher are implemented and pass their current automated suites. The RMX2156 app automatically reads the installed YouTube and Instagram versions and compares them with the internet-hosted registry. The device received the registry cache, but the deployed registry has no detector profiles, so both versions correctly remain unavailable for counting.

The registry request downloads one complete signed file; the app does not send installed app versions or device identifiers. The package manager version lookup is local so the app can compare its result against the downloaded registry.

## Acceptance map

| SRS ID | Acceptance behavior | Evidence | Result | Remaining gap |
|---|---|---|---|---|
| FR-010 | Match each installed app version to its exact registry entry and resolve only a validated profile | RMX2156 app picker shows YouTube `21.45.82` and Instagram `455.0.0.51.72`; the signed registry lists both as `catalogued`, with no profile ID | Fail-closed behavior passes | No production profile has passed the per-version accuracy gate |
| FR-018 | Fetch, verify, cache, and resolve signed registry data; accept v1 compatibility and v2 remote profiles | Live endpoint returned HTTP 200 with no redirect and `application/json`; Node signature verification returned schema v1, sequence 1, 18 entries, 0 profiles, digest `32a7421a56c737e22a2f6c0df9776b026c41cd150d4a5c26e45e8c29fcbb8310`; device cache reports the same digest and sequence. Signed v2 fixture is shared by Node and Android tests | Pass for transport, signature, cache, and v2 test path | Live deployment has not moved to v2 and contains no profiles |
| PR-17 | Keep installed-version and device values out of registry requests | Static whole-file HTTPS GET reviewed in `HttpsDetectorRegistryTransport`; request is independent of installed apps and contains no app/device/version fields | Pass by code review | No packet capture was taken in this run |

## Verification

- `node --test tool/detector_registry/registry.test.mjs` — 23 passed, 0 failed.
- Android `:app:testDebugUnitTest --rerun-tasks --no-daemon -Pkotlin.incremental=false -Pkotlin.compiler.execution.strategy=in-process` — 119 passed, 0 failures (Gradle XML reports).
- `flutter test --no-pub` — 50 passed.
- `flutter analyze --no-pub` — exit 0; five pre-existing Rive deprecation info notices.
- Android `:app:assembleDebug :app:validateDetectorRegistryReleaseConfig` — succeeded.
- RMX2156 / Android 12 / API 31: `adb install -r` succeeded; MainActivity opened and the app picker displayed the exact installed versions and their current profile availability. App data was preserved.
- Fresh Android rerun: `:app:testDebugUnitTest --rerun-tasks` — 119 passed, 0 failures (Gradle XML reports); the debug APK remained running as MainActivity with no crash-buffer entries.

## Device and deployment limits

At the start of the check, the device had no saved app selection or tracking consent. I selected YouTube and Instagram in onboarding; the choices persisted. Android reported Accessibility disabled and `SYSTEM_ALERT_WINDOW` as `ignore`. The app reached the in-app consent screen with its checkbox unchecked; Continue was disabled and Not now was available. I did not accept consent or change Android settings. The debug APK was reinstalled with `adb install -r`, relaunched as MainActivity, and produced no crash-buffer entries. No feed events or counts were exercised. This does not establish current-version detector accuracy or live counter behavior.

The public endpoint is still a non-project-controlled Codex Sites origin. Its sequence 1 payload is schema v1, contains 18 catalogued-only versions, and has no detector profiles. The source catalog is a partial snapshot and has no automated upstream refresh. Signing custody, a separate verified key backup, host-log retention, and a named catalog/profile maintainer remain open. No version may be marked supported until its own evidence meets FR-010–021.

## Screenshot

![RMX2156 app picker showing automatically read installed versions and current availability](rmx2156-registry-app-picker.png)

![RMX2156 onboarding consent screen with consent unchecked](rmx2156-permission-consent.png)
