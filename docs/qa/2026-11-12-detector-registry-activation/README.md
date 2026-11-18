# Detector registry activation QA

> Historical predeployment baseline. Live publication, endpoint verification, and the RMX2156 cache acceptance are recorded in the live registry acceptance report at ../2026-11-12-detector-registry-live/README.md.

**Date:** 2026-11-12  
**Scope:** Local publisher/client assurance and RMX2156 debug smoke check. No production registry was hosted or published.

## Acceptance evidence

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
|---|---|---|---|---|
| PR-17 / FR-010 | Read the installed app version locally and resolve only an exact mapping to a bundled, validated detector profile. | `DetectorProfilesTest` verifies that exact versions can share a profile ID through a test-injected bundle, while unknown and disabled versions fail closed; `registry-catalog.json`; RMX2156 package-manager/version UI evidence in [Rook/version QA](../2026-11-12-rook-center-version/README.md). | **Partial.** Exact version display and resolver behavior are covered; catalog rows are source-backed and catalogued-only. | Production profile manifest remains empty. No version can count; no live registry has been published. |
| FR-018 | Validate signature, schema, source URL, expiry, sequence, size, offline cache, and reject unsafe HTTP behavior. | `node --test tool/detector_registry/registry.test.mjs` — **15 passed**. Android `:app:testDebugUnitTest` — **113 passed, 0 failures/errors/skips**. Tests cover supported-profile signing, Android fixture verification, tampering, expiry, rollback, cache retention, fixed GET headers, redirects, oversized bodies, slow headers/bodies, and a later refresh after timeout. | **Local gates pass.** | Real DNS/TLS/CDN response and request metadata were not exercised because the host is not configured. |
| FR-019 | A detector that repeatedly crashes or exceeds its false-positive threshold fails closed, records a coverage gap, and leaves local history readable. | `DetectorRegistryRevocationTest` injects a pending candidate, applies a newer disabled mapping through the service replacement path, and verifies that no count is committed. | **Partial.** Synthetic registry revocation cancels a pending candidate. | Repeated-crash/false-positive threshold behavior, its coverage-gap record, and history readability after detector faults are not demonstrated by this suite; live service update with a production profile is also unavailable. |
| NFR-05 | Keep installed versions, app selection, device ID, and viewing data out of registry requests; disclose host IP/network metadata. | Synthetic HTTPS connection test asserts the fixed registry URL and static headers. PRD/SRS and privacy policy describe host IP/network metadata. | **Request contract covered locally.** | No production access-log/retention configuration exists to inspect. |
| NFR-09 / NFR-10 | Require a pinned HTTPS endpoint and P-256 public key for release artifacts, and match disclosures to actual hosting. | `:app:validateDetectorRegistryReleaseConfig` rejects missing URL/key; same task accepts the throwaway test P-256 key and placeholder HTTPS URL. `:app:assembleRelease` stops at the missing-URL gate. | **Build gate passes its positive and negative checks.** | No production public key or endpoint is configured; release signing and Play/privacy review remain open. |

## Build and device checks

- `node --test tool/detector_registry/registry.test.mjs` — **15/15 passed**.
- `:app:testDebugUnitTest :app:assembleDebug` with `--rerun-tasks`, Android Studio JBR, one Gradle worker, in-process Kotlin, non-incremental Kotlin, and a workspace-local SQLite temp directory — **BUILD SUCCESSFUL**; app test XML totals: **113 tests, 0 failures, 0 errors, 0 skipped** across 22 suites.
- Debug APK: `build/app/outputs/apk/debug/app-debug.apk` (212,890,206 bytes; SHA-256 `03738C96D0104C44C245508361EBB8B01F721550E7357FF165CF3F2FAD336BA1`).
- RMX2156 / Android 12 / API 31 / serial `X4GEAYDMWGAUI7WG`: the rebuilt APK installed with `adb install -r` (“Success”), preserving app data. The first immediate post-install activity task was removed by the OEM before process startup; a subsequent cold launch completed in 6,765 ms with PID `21388` and `MainActivity` resumed. No app crash entry appeared; Accessibility and overlay permissions were not changed. This is an install/launch smoke check only.
- Fresh post-launch evidence: [Today screenshot](rmx2156-final-today.png) and [UI hierarchy](rmx2156-final-ui.xml). Earlier smoke-check details remain in [the RMX2156 run note](../2026-11-12-rmx2156-registry-run/README.md). The launch check did not change permissions or inspect feed behavior.

## Deployment blockers

1. Choose a project-controlled fixed HTTPS host and record primary/backup operators and access-log retention.
2. Name the signing custodian. Generate and hold the P-256 private key outside this workspace; supply only the DER public key for the app build.
3. Complete exact version-history research. The current 17-entry catalog is a partial public-archive snapshot, not every YouTube/Instagram release. Five APKMirror beta/secondary archive labels were excluded because they do not prove installed `versionName`; Instagram `455.0.0.51.72` was excluded from the publishable catalog because the available URL is a mutable current-download page.
4. Validate each proposed detector version on its own corpus and three device families. Until the SRS FR-010–021 thresholds pass, keep `bundled-profiles.json` and production `DetectorProfiles` empty and publish no `supported` mappings.
5. Publish a signed catalog, fetch it back from the chosen host, configure a beta APK, and run the live device/request/privacy acceptance matrix. Replace the debug release-signing configuration before public distribution.

The detailed publication, outage, revocation, expiry, and key-rotation procedure is in the [operations runbook](../../ops/detector-registry-runbook.md).
