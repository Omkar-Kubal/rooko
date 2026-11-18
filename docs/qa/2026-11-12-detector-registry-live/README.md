# Live detector registry acceptance

**Date:** 2026-11-12  
**Scope:** Public sequence-1 catalog, signature verification, configured Android build, and connected RMX2156 cache/fetch evidence.

## Result

The internet registry integration is live end to end. The app downloads and verifies a signed registry, caches it, and matches local package-manager versions against its exact package/version records. The current public registry has **18 catalogued entries** and **zero supported entries**. RMX2156 YouTube `21.45.82` and Instagram `455.0.0.51.72` are recognized in the catalog but remain unavailable for counting because no production detector profile has passed the accuracy gate.

The current endpoint is a public Codex Sites hostname, not a project-controlled domain. Static access-log contents/retention are not exposed by the available metadata. See the [operations runbook](../../ops/detector-registry-runbook.md) for custody and release controls still open.

## Acceptance map

| SRS ID | Behavior | Evidence | Result | Open gap |
|---|---|---|---|---|
| PR-17 / FR-010 | Read exact installed app versions locally and resolve only exact registry records to an APK-bundled validated profile. | RMX2156 reports YouTube `21.45.82` and Instagram `455.0.0.51.72`; both appear in the verified sequence-1 payload as `catalogued`. The app UI shows the installed version and “Not supported.” `DetectorProfiles` production map and `bundled-profiles.json` are empty. | **Live version matching verified; fail-closed behavior preserved.** | No production profile has passed FR-012–021. A full detector corpus across three device families is still required per version. |
| FR-018 | Fetch and verify a bounded signed registry; cache only valid, current, non-rollback data; send no app/device fields. | Direct request returned HTTP `200`, no redirect, `application/json`, 4,713 bytes. The payload verifies against the app-pinned P-256 key: sequence `1`, 18 entries, expiry `2026-12-12T17:28:53Z`, payload SHA-256 `32a7421a56c737e22a2f6c0df9776b026c41cd150d4a5c26e45e8c29fcbb8310`. All 18 live entries deep-match the local reviewed catalog. RMX2156 app preferences contain highest sequence `1` and the same payload digest. | **Live endpoint, catalog, signature, and device cache verified.** | A device-side request capture and host access-log review were not available. |
| FR-018 | Reject malformed, expired, oversized, tampered, redirected, and rolled-back registry data; retain a valid cache after failed refresh. | `node --test tool/detector_registry/registry.test.mjs`: 16/16 passed. Android `:app:testDebugUnitTest --rerun-tasks`: 154 tests, 0 failures/errors/skips, including parser, refresh, transport, cache, rollback, and revocation suites. | **Local failure-path tests pass.** | Production host redirect/cache-purge and key-rotation drills remain open. |
| FR-019 | Stop a pending count when an updated registry disables its exact detector mapping and retain local data. | `DetectorRegistryRevocationTest` passes within the Android suite. | **Synthetic revocation path passes.** | A live supported profile does not exist, so live candidate revocation was not exercised. |
| NFR-05 | Keep installed versions, app selection, device ID, and usage data out of registry requests; disclose host IP/network metadata. | Client transport fixture asserts the static whole-registry GET. The in-app privacy notice discloses that the host may receive IP/network metadata. | **Request contract and copy verified locally.** | Device network trace and actual static-host log-retention policy remain unverified. |
| NFR-09 / NFR-10 | Pin a fixed HTTPS endpoint/key for release configuration and match privacy disclosures to actual hosting. | `:app:validateDetectorRegistryReleaseConfig` passed with the configured endpoint/key. Debug APK was built and installed; generated `BuildConfig` contains the exact deployed URL and pinned key. | **Build configuration passes.** | Release signing still uses the debug signing configuration; public distribution is not ready. Host log review and Play/privacy review remain open. |

## Build and device evidence

- Node publisher/verifier: `node --test tool/detector_registry/registry.test.mjs` — **16 passed, 0 failed**.
- Android: from `android/`, run `:app:testDebugUnitTest --rerun-tasks :app:assembleDebug :app:validateDetectorRegistryReleaseConfig` with Android Studio JBR, one worker, in-process/non-incremental Kotlin, and `D:\appylab\sync-rot\build\sqlite-temp` for SQLite. Result: **BUILD SUCCESSFUL**; JUnit XML totals **154 tests, 0 failures, 0 errors, 0 skipped**; debug assembly and release registry-input validation passed.
- Flutter: `flutter test --no-pub` — **50 passed**. `flutter analyze --no-pub` — exit 0; five existing Rive `boolean` deprecation info notices, no warnings/errors.
- Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`, 212,890,206 bytes, SHA-256 `56B40A49742999174009CD479EECFF04F34B65D77E126AD884D97EAD2C816817`.
- Device: realme RMX2156, Android 12/API 31, serial `X4GEAYDMWGAUI7WG`, app `1.0.0`. `adb install -r` succeeded with data retained; cold launch resumed `MainActivity` (PID `3671`). Registry cache has sequence `1` and the expected payload digest. No fatal app exception was found in the captured logcat tail. Accessibility and overlay permissions were not changed.
- Public site metadata reports the registry Site active and public. The source host is `syncscroll-detector-registry-20261112.soham-badame-7297.chatgpt.site`.

## Remaining work before release

1. Replace the temporary public Site origin with a project-controlled HTTPS origin, or record an explicit ownership/availability decision.
2. Assign a signing custodian and establish a separately verified encrypted key backup. The current private key is protected using Windows DPAPI for the current user, with no verified separate backup.
3. Verify actual host request-log fields and retention, then align the privacy notice and Play disclosures.
4. Expand the version archive beyond this partial 18-entry snapshot. The public archive sources are incomplete and do not establish every historical or regional version.
5. Validate each proposed detector version against at least 200 transitions and 100 stationary/non-feed cases across three device families, meeting the SRS precision/recall thresholds. Keep all mappings catalogued-only until then.
6. Configure production Android release signing and complete multi-device request, offline, expiration, privacy, and Play-policy checks.

The earlier predeployment local acceptance record is retained in [registry activation QA](../2026-11-12-detector-registry-activation/README.md).
