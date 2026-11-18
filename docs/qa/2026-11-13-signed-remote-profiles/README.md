# Signed remote detector profiles acceptance

Date: 2026-11-13

## Result

The app and publisher now support signed schema v2 remote profiles. Exact package/version entries can reference shared bounded configuration that selects an existing Kotlin Accessibility detector strategy. The app verifies the profile and the signed per-version validation summary before resolving support. Schema v1 remains readable for cache compatibility and can resolve only an APK-bundled profile.

This is registry delivery infrastructure, not new detector evidence. The checked-in catalog contains 18 catalogued-only releases and an empty profile list. The live endpoint remains sequence 1/schema v1, so YouTube `21.45.82` and Instagram `455.0.0.51.72` remain unavailable for counting.

## Acceptance map

| SRS ID | Acceptance behavior | Evidence | Result | Remaining gap |
|---|---|---|---|---|
| FR-010 | Local exact version maps to a validated profile; compatible versions may share an ID | Kotlin tests resolve two exact versions through one signed profile; v2 parser rejects failed evidence | Pass | No production app/version has a validated profile yet |
| FR-018 | Signed v2 profile fields are bounded, signed, cached/parsed safely, and fail closed; v1 remains accepted | Node 23/23; Android 119/119; shared signed v2 fixture passes in Node and Android; existing v1 envelope fixture still passes | Pass | Live endpoint is still schema v1; v2 publication not performed |
| PR-17 | App version selection does not upload installed version or device data | Existing request transport unchanged; it requests the complete static registry. Registry request boundary reviewed in `DetectorVersionRegistry.kt` | Pass by code review | Request capture was not available without an attached device |
| FR-012–021 | A supported mapping represents measured detector accuracy | Publisher and app enforce signed minimum values: 200 transitions, 100 stationary/non-feed cases, 3 device families, precision ≥98%, recall ≥90%, zero stationary repeats | Gate enforced | No real validation corpus is available for current installed versions |

## Verification

- `node --test tool/detector_registry/registry.test.mjs` — 23 passed, 0 failed.
- Registry catalog and JSON Schema parse with Node — passed.
- Android `:app:testDebugUnitTest --rerun-tasks --no-daemon -Pkotlin.incremental=false` with Android Studio JBR, in-process Kotlin compiler, and `org.sqlite.tmpdir=build/sqlite-tmp` — 119 passed, 0 failures, 0 errors, 0 skipped.
- Android `:app:assembleDebug` with the same Windows cross-drive workaround — succeeded. Artifact: `build/app/outputs/apk/debug/app-debug.apk`.
- RMX2156 / Android 12: `adb install -r build/app/outputs/apk/debug/app-debug.apk` succeeded; package version remains `1.0.0`, its process was running, Accessibility remained enabled, overlay app-op remained `allow`, and the cached registry sequence remained `1`. `logcat -b crash` showed no app crash. The `-r` install preserved app data.
- The phone was locked with Android Accessibility Settings as the foreground activity after installation. I did not unlock it or change permissions, so I could not inspect the app screen, issue feed gestures, refresh the registry interactively, or verify an overlay/count on-device.

The v2 cross-language fixture is test-only. Its `fixture-only` validation report ID and synthetic threshold values are not production evidence. Its throwaway test private key was generated in memory and not saved; only the fixture envelope and public key are present in test resources.

## Data and deployment state

- `tool/detector_registry/registry-catalog.json` now uses catalog schema v2 with 18 source-backed catalog rows and `profiles: []`.
- The publisher emits schema v2 and requires passing validation evidence for each supported version. Evidence numbers remain tied to the signing operator's QA review; a profile ID or signed summary does not create ground truth.
- The Android client accepts v2 and maintains v1 compatibility. The live endpoint still serves the existing v1 sequence 1 payload. No production profile was signed or published.
- Current exact versions remain unsupported until a real profile is validated and published. A compatible profile can be shared by multiple versions only after each exact version independently passes the gate.
- A new target-app behavior requiring an algorithm absent from Kotlin still needs a Sync Scroll APK update; remote data cannot add code or text-reading behavior.

## Next acceptance work

When RMX2156 is unlocked, capture content-free structural signals for its current YouTube and Instagram versions, then collect the complete per-version corpus across three device families. Publish a schema v2 entry only after review of that evidence. Move registry hosting and signing custody to project-controlled operations before public rollout; the current host, access-log retention, and separate key backup remain open in the existing registry runbook.
