# Detector registry operations runbook

## Current readiness

The signed-registry client, v2 publisher, source ledger, and release configuration gate are implemented. A public static endpoint is deployed and pinned in `android/gradle.properties`. Signed sequence **1** is a v1 payload with **18 catalogued-only versions** and is live through **2026-12-12 17:28:53 UTC**. Live HTTP and signature verification passed; a fresh RMX2156 debug install also cached sequence 1. The local reviewed catalog now has **20 catalogued-only versions**. The app correctly keeps its installed YouTube and Instagram versions unavailable because no production detector profile is validated or published. The client reads the current v1 payload and supports v2 remote profiles after a future signed publication.

Version discovery is implemented in `tool/detector_registry/discover_versions.mjs`. The weekly GitHub Actions workflow is defined in `.github/workflows/detector-version-discovery.yml`; it cannot run until this workspace is attached to and pushed to a GitHub repository. Its artifact is review-only and never changes the catalog or signs a registry.

The current origin is a public Codex Sites hostname, not a project-controlled domain. Its request-log fields and retention have not been verified. The private P-256 key is protected with Windows DPAPI for the current user, but there is no separately verified encrypted backup or formally recorded signing custodian. These ownership, retention, and backup controls remain release setup work. Do not add `supported` entries without per-version accuracy evidence.

## Ownership and endpoint record

Current deployment record (open ownership controls are marked as such):

| Field | Required record |
|---|---|
| Registry origin and exact URL | `https://syncscroll-detector-registry-20261112.soham-badame-7297.chatgpt.site/sync-scroll/v1/registry.json` (public Codex Sites hostname; not project-controlled) |
| DNS and host operator | Codex Sites managed hosting; no separate operator or backup operator is recorded |
| Backup host operator | Named backup owner |
| Catalog reviewer | Person who checks package/version provenance and profile status |
| Signing custodian | Not formally assigned; key is protected by Windows DPAPI `CurrentUser` outside the workspace |
| Signing key fingerprint | `a75e5e3a7b968d109a6c5cc8993c09bd535535ce452245e3ccb2dbb075a9bb2e` (SHA-256 of pinned DER public key) |
| Request-log retention | Not verified; available Sites metadata does not expose static-file access-log fields or retention |
| Current sequence and expiry | Sequence `1`; expiry `2026-12-12T17:28:53Z`; payload SHA-256 `32a7421a56c737e22a2f6c0df9776b026c41cd150d4a5c26e45e8c29fcbb8310` |
| Privacy notice review | App notice discloses possible requester IP/network metadata; actual host retention is not verified |

Serve a static response directly with HTTP `200`, `Content-Type: application/json`, no redirect, no authentication, no cookies, and no query string. Confirm TLS, cache invalidation/purge, body-size bounds, and availability monitoring. The client does not upload installed version, selected app IDs, device ID, or viewing data, but the host sees the requester IP and ordinary network metadata. The client rejects redirects, caps the envelope at 512 KiB, and disconnects if the complete request exceeds its 15-second deadline; a still-valid cached registry remains usable after a timeout.

## Key creation and custody

1. The current ECDSA P-256 key was generated on Windows and protected using DPAPI `CurrentUser`; the encrypted blob is outside this workspace. This is not a verified separate backup or a substitute for assigning a custodian.
2. Before relying on the key for ongoing operations, assign a custodian and create/verify an encrypted backup in an approved separate location. Never place the key in this workspace, source control, CI variables, or the static host.
3. Export only the DER SubjectPublicKeyInfo public key as base64 for the Android build property.
4. The public-key fingerprint is recorded above. Record the custodian, backup verification date, and key-rotation contact after they are assigned. Do not record the private-key path or recovery phrase in this repository.
5. A sequence-1 envelope was signed and verified by the publisher with the pinned public key. Repeat the key-read/signing check after a separate backup is established. The shared test fixture is a throwaway key and must never be pinned in a product build.

## Catalog review and publication

1. Review the weekly `detector-version-candidates` Actions artifact after the workflow is activated. For local discovery, run `node tool/detector_registry/discover_versions.mjs`. The report is candidate-only: verify the exact package and `versionName`, add its exact release page and observation date to `tool/detector_registry/version-sources.md`, then update `registry-catalog.json`. The current catalog has 20 entries (10 YouTube, 10 Instagram) and is a partial archive snapshot; the live sequence 1 still contains the earlier 18 entries.
2. Start new versions as `catalogued` without `profileId`. The archive snapshot is incomplete; do not claim that it includes every release.
3. A v2 profile must use `strategyId: accessibility_structure_v1`, exact resource IDs in the mapped app package, 1–8 unique feed and transition IDs, and an existing identity strategy. Never add code, text fields, regular expressions, arbitrary selectors, or detection thresholds.
4. For a proposed `supported` row, review the exact-version QA matrix, source evidence, and remote profile definition for the FR-010–021 gate. One passing version does not validate adjacent versions, even when they share a profile ID.
5. Review sequence, current accepted sequence, and key before running the Node publisher. Publish at least weekly and use the default 30-day expiry; shorten the period only when the outage/revocation tradeoff has been reviewed. Run the publisher from the repository root, using the private-key path held by the custodian:

   ```powershell
   node tool/detector_registry/publish_registry.mjs `
     --catalog tool/detector_registry/registry-catalog.json `
     --private-key C:\RegistryCustody\detector-registry-private.pem `
     --sequence <next-sequence> `
     --previous-sequence <current-sequence> `
     --output C:\RegistryCustody\registry.json
   ```

6. Save the publisher output and review it independently: schema version, sequence, entry/profile counts, expiry, payload digest, catalog diff, and every `supported` mapping. Keep the private key out of the evidence package.
7. Upload the signed envelope to the fixed path. Fetch it from the public URL and compare bytes/digest with the reviewed artifact. Confirm `200`, no redirect, correct content type, and body below 512 KiB.
8. Record publication time, schema version, sequence, expiry, digest, reviewer, signer, host URL, and profile IDs in the release evidence. Never reset or reuse a sequence.

## App build and acceptance

The configured debug build uses the endpoint and pinned public key recorded above. The release build gate validates those values. Public distribution also requires a production Android signing configuration; the workspace currently uses debug signing for release builds and is not distribution-ready.

Before a release artifact is built, pass:

- `rookoDetectorRegistryUrl`: fixed HTTPS URL, without credentials, query, or fragment (configured for the current debug build).
- `rookoDetectorRegistryPublicKey`: base64 DER P-256 public key matching the signer (configured; fingerprint recorded above).
- A production Android signing configuration.

The checked-in catalog currently publishes no remote profile definitions. Do not create a profile just to make an installed version appear supported. Collect exact-version evidence across three device families first; if the feed signals do not support one of the built-in strategies, implement and review a new local strategy in an APK release.

The release build gate rejects a missing/invalid registry URL or public key. Debug builds with blank registry configuration remain offline. On RMX2156/API 31, the configured debug app cached signed sequence 1 and its locally installed versions (`21.45.82` YouTube and `455.0.0.51.72` Instagram) match catalogued entries. This proves live registry fetch/cache acceptance on one device, not detector support or the three-family accuracy gate. Add two more device families, a request capture, and Progress/count invariance checks before closing the broader matrix.

## Renewal, outage, and revocation

- Review sources weekly and after target-app releases. Alert seven days before expiry. Sequence 1 expires on 2026-12-12; no renewal automation or named maintenance owner is recorded. Renew before expiry so offline devices do not lose the registry unexpectedly.
- On a detected bad version, publish a higher-sequence `disabled` record and purge the host cache. Online clients see it at their next allowed refresh. Offline clients may keep a still-valid cached registry until expiry (up to 30 days by default).
- For an invalid response, redirect, oversized body, signature error, or rollback, clients keep a still-valid cache. If the cache is expired or absent, detector resolution fails closed and saved Progress records remain available.
- Monitor the public endpoint and expiry date without collecting device IDs, app versions, selected apps, or usage data in host logs. The current host's static-file log behavior is not exposed in the available project metadata and must be reviewed before public distribution.

## Key rotation

The public key is pinned in the APK, so rotation requires an app update. Prepare and validate the new public key in a new app release before signing production data with it. Continue the registry sequence from the last publication. Do not use remote key delegation and do not lose the old key until the app-update adoption and rollback period are understood. Re-run signature, cache, and offline tests with the new app pin.

## Drills still required

- Host redirect, invalid TLS, `404`, stale CDN response, and cache purge.
- Valid envelope round-trip, bad signature, expired/future time, duplicate version, unknown profile ID, rollback, and changed payload reusing a sequence.
- Offline with valid cache and after expiry; version update to unknown; disablement while a detector candidate is pending.
- Signing-key backup restore, loss response, and app-pinned key rotation.
- Device request inspection and Play/privacy copy review against the deployed host's actual logs.
