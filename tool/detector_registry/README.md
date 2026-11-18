# Detector version registry

The Android app reads each supported target app's installed `versionName` locally, then may fetch one signed registry containing exact package/version records. Requests contain only a static GET for the full file; they do not contain the device ID, selected apps, installed versions, or viewing data. The host can see the request IP address and ordinary network metadata.

`catalogued` means a version has a source record. It does not enable counting. `supported` requires a `profileId` whose signed remote profile passes the strict v2 schema and a passing per-version FR-010–021 detector evidence package. Profiles contain bounded exact Android resource IDs and enum values that select built-in Kotlin strategies. They cannot carry code, text rules, arbitrary selectors, thresholds, or algorithms. `disabled` revokes that exact mapping. Unknown, catalogued, expired, invalid, disabled, unconfigured, and package-mismatched mappings fail closed.

## Current deployment (2026-11-12)

Sequence 1 is live at `https://syncscroll-detector-registry-20261112.soham-badame-7297.chatgpt.site/sync-scroll/v1/registry.json`. It contains 18 catalogued-only versions, expires on 2026-12-12, and has payload SHA-256 `32a7421a56c737e22a2f6c0df9776b026c41cd150d4a5c26e45e8c29fcbb8310`. The configured Android debug build has fetched and cached this sequence on RMX2156. YouTube `21.45.82` and Instagram `455.0.0.51.72` match catalog entries but remain unavailable for counting.

The Android client and publisher now accept schema v2 profiles. Sequence 1 remains a v1 catalog-only payload until a reviewed update is published. Schema v1 remains readable for old cached data and may reference only APK-bundled profiles. The endpoint is a public Codex Sites hostname, not a project-controlled domain. Static access-log behavior is unknown. The signing key is protected outside this workspace using Windows DPAPI `CurrentUser`; it has no verified separate backup or formally assigned custodian. The live 18-entry snapshot is partial; the local reviewed catalog now has 20 catalogued entries. See the [operations runbook](../../docs/ops/detector-registry-runbook.md) and [live acceptance report](../../docs/qa/2026-11-12-detector-registry-live/README.md) before renewing or publishing a new sequence.

## Curated inputs

- `registry-catalog.json` contains source-backed package/version entries and the shared `profiles` array. Update the source ledger in `version-sources.md` with the observation date and evidence before changing it. The profiles array is currently empty because no production profile has passed validation.
- `bundled-profiles.json` is retained only for v1 compatibility tests; new v2 profiles are data in `registry-catalog.json` and do not need to be compiled into the APK.
- `registry.schema.json` documents the signed v1/v2 payload shapes. The publisher also enforces the stricter runtime rules and checks the exact bytes it signs.
- `test-fixtures/` contains a throwaway P-256 public key and signed envelope. The same bytes live under Android test resources; the Node test checks that copies match. They are not production key material.

The initial curated catalog is a partial snapshot of publicly indexed releases, not a complete version history. Public archives can miss staged rollouts, package variants, regions, beta releases, and older releases. A missing version remains unknown and unsupported.

## Version discovery

`discover_versions.mjs` checks the YouTube and Instagram APKPure version indexes and writes `discovery-candidates.json`. It accepts only numeric exact-version URL paths for the configured package, ignores channel/variant suffixes, and lists versions absent from the curated catalog as `review_required`. It does not edit or sign `registry-catalog.json`, fetch APK files, or mark a version supported. Review the package and installed `versionName` evidence, then update `version-sources.md` and the catalog by hand.

Run it locally with:

```powershell
node --test tool/detector_registry/discover_versions.test.mjs
node tool/detector_registry/discover_versions.mjs
```

`.github/workflows/detector-version-discovery.yml` runs this read-only discovery weekly and uploads a 30-day review artifact. The current workspace has no Git metadata or remote, so GitHub has not activated that schedule. The workflow uses no secrets and does not publish registry changes. Discovery is partial archive evidence, not an authoritative inventory of every release.

## Key custody and signing

Before recurring production use, assign a named signing custodian and create a verified encrypted backup in a separate approved location. Keep private key material outside this repository, CI, and the web host. Only the DER SubjectPublicKeyInfo public key may be added to build inputs. The current key is protected with Windows DPAPI for the current user and still needs a separately verified backup. The tool below checks that the private key is ECDSA P-256 and verifies its output before writing.

The custodian runs this command from the repository root, using a secure private-key path outside the workspace:

```powershell
node tool/detector_registry/publish_registry.mjs `
  --catalog tool/detector_registry/registry-catalog.json `
  --private-key C:\RegistryCustody\detector-registry-private.pem `
  --sequence 1 `
  --previous-sequence 0 `
  --output C:\RegistryCustody\registry.json
```

The first publication uses sequence `1` and previous sequence `0`; later publications must use a strictly higher sequence recorded in the runbook. The default validity is 30 days; `--validity-days` can shorten it to 1–30 days. The publisher sets issue and expiry timestamps, validates the generated payload, signs its exact UTF-8 bytes, verifies the envelope against the derived public key, and reports the payload SHA-256. It does not create or print private key material.

Use `node --test tool/detector_registry/registry.test.mjs` before reviewing a catalog or publication. Do not publish a `supported` entry unless the exact package/version has passed the detector gate and references a valid v2 profile. Compatible app versions may reference the same profile ID only when each exact version independently passes the gate. A new app UI behavior that needs a strategy absent from Kotlin still requires an APK update.

## Hosting and builds

Host the envelope as a static file at the recorded HTTPS URL; the current public Site returns `200` directly without redirects or authentication. Recommended path: `/sync-scroll/v1/registry.json`. The client caps the envelope at 512 KiB and the complete request at 15 seconds; slow responses are disconnected. Do not host the private key. Before public distribution, move to an approved project-controlled host, configure the shortest operationally useful access-log retention, and verify the privacy notice against actual host behavior.

For a configured debug build:

```powershell
.\android\gradlew.bat --no-daemon --max-workers=1 `
  '-Pkotlin.compiler.execution.strategy=in-process' `
  '-Pkotlin.incremental=false' `
  -ProokoDetectorRegistryUrl=https://registry.example.org/sync-scroll/v1/registry.json `
  -ProokoDetectorRegistryPublicKey=BASE64_DER_PUBLIC_KEY `
  :app:assembleDebug
```

Default debug builds with empty registry properties make no network request. `assembleRelease`, `bundleRelease`, and release package/sign tasks require a fixed HTTPS URL and a base64 DER EC public key. Public distribution also needs production release signing; the current project release signing setup is still the debug signing config and is not suitable for distribution.

Changing the pinned public key requires an app update. Key rotation is not remote. Keep the registry sequence monotonic across a key rotation. See [`docs/ops/detector-registry-runbook.md`](../../docs/ops/detector-registry-runbook.md) for readiness, renewal, outage, revocation, and rotation procedures.
