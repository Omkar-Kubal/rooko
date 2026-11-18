# Detector Registry Activation Implementation Plan

> **For agentic workers:** Use the existing [registry design](../specs/2026-11-12-online-version-registry-design.md) and complete the checked client implementation in the [earlier plan](2026-11-12-online-version-registry.md). The tasks below activate and operate it. Check off each task only after its evidence is saved.

**Goal:** Make Sync Scroll automatically resolve a locally installed YouTube or Instagram version through a live, signed internet registry, and count only versions with a validated detector profile bundled in the APK.

**Architecture:** Android reads the exact installed `versionName` with `PackageManager`. It downloads one shared signed catalog from a fixed HTTPS URL, then maps an exact package/version entry to a profile ID already in the APK. The registry carries support decisions, never executable detector rules. Unknown and unvalidated versions remain unavailable.

**Tech stack:** Kotlin/Android, static HTTPS hosting, ECDSA P-256 with SHA-256, JSON Schema, dependency-free Node.js publishing tools, Gradle build properties, Flutter status UI.

**Spec:** [Online registry design](../specs/2026-11-12-online-version-registry-design.md); PRD PR-17 and SRS FR-010–019, FR-021, NFR-05, NFR-09, NFR-10.

## Current baseline and scope

- **User-approved requirement:** Internet-hosted catalog of known exact versions, automatic resolution, and a shared detector profile where versions have compatible signals. PRD PR-17 and SRS FR-010/018 already record this.
- **Implemented before activation work:** Signed registry parser/cache/fetch, build URL/key properties, and exact-version lookup. The client has a 512 KiB envelope limit, 10,000-entry limit, no redirects, a 15-second overall request deadline, and at least 15 minutes between fetch attempts.
- **Live activation complete:** Public sequence 1 is deployed at the endpoint in `android/gradle.properties`, signed with the pinned P-256 key, and contains 18 catalogued-only entries. The RMX2156 Android 12/API 31 app fetched and cached it. Direct HTTP returned 200 without redirect; the signed payload was verified against the pinned key. See [live QA](../../qa/2026-11-12-detector-registry-live/README.md).
- **Implemented in activation work:** Node publisher/validator, source ledger, Android parser/refresh fixtures, controlled transport seam, cache/failure tests, release registry-input gate, and operations runbook. Fresh checks: Node 16/16; Android 154/154; Flutter 50/50; debug assembly and release registry-config validation passed.
- **Still missing:** The current public host is not a project-controlled domain; request-log retention is unknown; no formally named signing custodian or verified separate key backup exists; the 18-entry catalog is partial; production detector profiles remain empty. Production APK signing and the broader multi-device privacy/detector matrix remain open.
- **Version source:** Public internet release records populate the catalog. The phone itself supplies its installed `versionName`; a public website cannot know that device fact without the app reporting it. Sync Scroll sends no installed version, selected-app list, device ID, or usage data in a registry request.
- **Coverage limit:** No public source guarantees a complete historical list across staged rollouts and APK variants. Catalog every release that can be tied to a package, exact version, and source URL; leave undiscovered versions unknown. A catalog entry alone never enables counting.
- **Deployment state:** The current public Sites endpoint uses a 30-day validity window; sequence 1 expires 2026-12-12. A project-controlled host, backup/custody record, access-log review, and scheduled renewal owner remain open.
- **Project QA observation:** Prior YouTube debug pilots exposed missing Accessibility labels and inconsistent sponsored-item handling; those observations do not validate a release profile. No reference-app REA observation is used as a Sync Scroll requirement in this plan.

## Global constraints

- All target-app observation remains local, consented, and restricted to selected packages.
- Do not persist feed text, item labels, media, screenshots, or full Accessibility trees.
- Do not promote the separately consented debug text-key path into release support.
- A signed `supported` mapping resolves only if its `profileId` is bundled in that APK and that exact version passes the SRS detector gate.
- A catalogued, disabled, unknown, expired, invalid, or unbundled mapping fails closed. Today and History use the single counter-recorded total only.
- Keep the signing private key outside this workspace, CI, and the web host. The public key and endpoint are build inputs.
- Registry requests fetch the whole catalog with static headers. The privacy notice must describe host IP/network metadata.

## Review focus

| Condition | Expected behavior and owning task |
| --- | --- |
| A newly published version appears before QA finishes | It can be `catalogued`; it cannot count (Tasks 2, 4). |
| Same profile ID is assigned to a second app version | That version has independent compatibility and accuracy evidence (Task 4). |
| Host returns a redirect, corrupt signature, oversized body, or older sequence | Existing valid cache survives; otherwise support is unavailable (Tasks 3, 6). |
| Supported version is remotely disabled while the service is active | A newer signed registry cancels current candidates and stops future counts (Tasks 6, 7). |
| Device remains offline after an emergency disable | It may use an unexpired cached registry until expiry; the runbook states this window (Tasks 1, 8). |

---

### Task 1: Choose the host and signing ownership

**Status:** Partially complete. A public Codex Sites endpoint, pinned P-256 key, DPAPI-protected Windows key, and sequence-1 publication are active. The host is not project-controlled; the custodian/backup and request-log retention are unverified.

**Files:** Update `tool/detector_registry/README.md`; create `docs/ops/detector-registry-runbook.md`.

- [x] Deploy a static HTTPS endpoint and pin it in Android build configuration. The public Sites endpoint returned HTTP 200, no redirect, `application/json`, and a 4,713-byte body; it is not project-controlled.
- [x] Generate a P-256 key, protect it outside the workspace using Windows DPAPI `CurrentUser`, and pin its DER public key. The public key fingerprint and sequence are recorded in the runbook.
- [x] Set sequence 1 to 30-day validity and verify its signature and expiry.
- [ ] Move to a project-controlled origin or record an explicit owner/availability decision; assign a custodian and separate encrypted backup; verify request-log retention; name reviewer/host owner; set renewal reminders.

**Exit evidence:** Host/owner record, public-key fingerprint, retention configuration, and `curl -i` response saved in the runbook. The private key and its backup path are not recorded in the repository.

### Task 2: Build a provenance-backed version catalog

**Status:** Partial source catalog complete (20 exact package/version entries: 10 YouTube and 10 Instagram). A review-only APKPure discovery script and weekly GitHub Actions workflow are now defined; the schedule is inactive until the workspace is attached to a GitHub repository. Two newly discovered YouTube detail pages were verified for exact canonical URL and `softwareVersion`, then added as catalogued-only. Public release archives are incomplete; channel labels without installed `versionName` evidence and mutable current-download routes are excluded.

**Files:** Create `tool/detector_registry/registry-catalog.json`, `tool/detector_registry/version-sources.md`, and `tool/detector_registry/bundled-profiles.json`; update `tool/detector_registry/README.md`.

- [x] For YouTube and Instagram, collect current release/version evidence from their official Google Play listings where an exact version is visible. Cross-check historical package/version records against public release archives such as APKMirror; keep a version-specific HTTPS `sourceUrl` for every published entry. Record the observation date and any conflicting source in `version-sources.md`.
- [x] Add only verified package/version strings to the payload. Start every discovered release as `catalogued` with no `profileId`. Do not infer compatibility from adjacent version numbers, shared major versions, release notes, or a download site's claim.
- [x] Compare the catalog with exact versions observed on QA devices, including RMX2156's YouTube `21.45.82` and Instagram `455.0.0.51.72`. Add an entry only if its source can be independently checked; leave the rest unknown.
- [ ] Recheck sources weekly and after a target app update. A source change proposes a catalog change; it does not automatically publish a `supported` mapping.

**Exit evidence:** Source ledger and a catalog in which every entry has a public HTTPS provenance URL. The initial catalog may have zero entries if no exact-version source is verified.

### Task 3: Add publication and client assurance gates

**Status:** Local publisher and Android assurance gates are implemented and pass. Live-host behavior and RMX2156 cache acceptance are also verified in the [live QA report](../../qa/2026-11-12-detector-registry-live/README.md). Host log policy and device request capture remain open.

**Files:** Create/update `tool/detector_registry/registry.mjs`, `publish_registry.mjs`, and their tests; update `registry.schema.json` and `DetectorVersionRegistry.kt` only where a test exposes a gap. Add Android parser and refresh tests.

- [x] Add a publisher validation command that rejects schema/allowlist violations, duplicate package/version entries, non-HTTPS sources, unsupported `profileId` values, an expiry before issue time, payloads over the Android 512 KiB envelope limit, and sequences that do not advance beyond the last published value. It must inspect the actual payload bytes that will be signed.
- [x] Add fixed-key/fixed-clock Android fixtures for valid signature, tampering, expiry, future issue time, duplicate entries, invalid source/package, unknown profile ID, rollback, and a changed payload reusing a sequence. Preserve a still-valid old cache after a bad refresh.
- [x] Exercise HTTPS refresh through a controlled transport seam: fixed whole-catalog request, no app/device/version fields, bounded body/timeouts, no redirect, offline cache, expired cache, and concurrent refresh callbacks. Add or refactor production code only when a fixture demonstrates a failure.
- [x] Verify that the publisher's signed envelope is accepted by the Android parser and that a changed payload with the same sequence is rejected.

**Exit evidence:** Focused Node.js and Android test results, plus a signed fixture that round-trips through the Android verifier. No live private key enters tests.

### Task 4: Validate and bundle production profiles

**Status:** Blocked on per-version corpus results across three device families. The production profile list remains empty and all registry rows are catalogued-only.

**Files:** Modify `android/app/src/main/kotlin/com/appylab/syncscroll/DetectorProfiles.kt` and detector code only as evidence requires; add detector fixtures/tests and an app/version matrix under `docs/qa/`.

- [ ] Choose the exact currently available YouTube and Instagram versions for a beta cohort. For each, record the feed marker, transition signal, item identity signal, device/API range, profile ID, and fixture revision. Do not assume one profile works across all versions.
- [ ] Prove feed-only processing, first-item behavior, at least 1,000 ms visibility, stable identity or two independent structural signals, no stationary repeats, five-minute revisit handling, cross-date attribution, service restart, permission loss, and sponsored/non-feed cases. Prior YouTube debug pilots show missing accessible labels and sponsored-item errors, so they cannot serve as release validation.
- [ ] Build a labeled corpus for **each version proposed as supported**: at least 200 item transitions and 100 stationary/non-feed cases across at least three device families and the supported OS range. Require precision at least 98%, recall at least 90%, and zero stationary repeats, as SRS FR-010–021 specifies.
- [ ] Bundle only passing profile rules in `DetectorProfiles.kt` under stable profile IDs. If two versions share an ID, save independent results and a signal-equivalence review for both. If no version passes, leave the production map empty and publish only `catalogued` entries.

**Exit evidence:** Version-by-version matrix, labeled corpus, privacy review of observed fields, detector test results, and a release artifact scan showing the debug text-key path is disabled.

The catalog-only publication in Task 5 can run after Task 3 while this detector work continues. It proves the host and client path without enabling a version.

### Task 5: Publish the first signed catalog and configure a beta APK

**Status:** Complete for a catalog-only debug/beta deployment. Sequence 1 is signed, published, directly fetched and verified, pinned in the configured debug APK, and cached on RMX2156. No detector is enabled because the production profile list is empty.

**Files:** Update `registry-catalog.json`, `version-sources.md`, and the runbook; add the release configuration gate in `android/app/build.gradle.kts`.

- [x] Publish sequence 1 with the 18 exact sourced catalog entries; all remain catalogued-only.
- [x] Sign and verify the exact payload. The public envelope verifies against the pinned key; digest, expiry, and fingerprint are in the runbook.
- [x] Fetch the public response; verify HTTP status, content type, no redirect, size, payload digest, and signature.
- [x] Build and install the configured debug APK on RMX2156. Release signing remains a separate public-distribution requirement.
- [x] Require release artifact tasks to fail if either endpoint or P-256 key input is missing. The missing-input negative check and throwaway-key positive check were exercised during initial implementation; current `:app:validateDetectorRegistryReleaseConfig` passes with the configured live URL and pinned P-256 key.

**Exit evidence:** Public signed response, reproducible build inputs excluding the private key, and an APK inspection confirming the fixed endpoint and pinned public key. A catalog-only publication is a valid first stage; it enables no counting.

### Task 6: Verify live resolution and failure paths on devices

**Status:** Partial. Live signed fetch/cache acceptance is verified on RMX2156/API 31. Counting, per-version accuracy, multiple device families, host logs, offline expiry, and a real request capture remain open.

**Files:** Add an acceptance ledger under `docs/qa/`; update `progress.md` with evidence links.

- [x] On RMX2156/API 31, install the configured debug APK without clearing local data. Verify installed versions, signed sequence 1 in app cache, and unsupported status for the two catalogued-only versions.
- [ ] Repeat registry acceptance on two additional device families. Verify the service profile only after a version has passed Task 4.
- [ ] With explicit Accessibility consent, verify counting only on a Task 4 passing app/version. Check feed entry, distinct advances, stationary holds, revisit, Home/comments/long video, app update to unknown version, and service restart. Compare event totals with the labeled corpus and confirm Today, History, and limits agree.
- [ ] Test grant, decline, revoke, offline with unexpired cache, offline after expiry, bad signature, rollback, disabled mapping, and a live registry replacement while a candidate is pending. Verify that invalid data preserves a still-valid cache and otherwise stops counting without losing history.
- [ ] Capture the registry request shape using a controlled test endpoint or network trace: one shared GET, no installed version, package list, device ID, or usage fields. Verify server logs and privacy copy against the actual deployment.

**Exit evidence:** SRS acceptance table with exact app versions, Android APIs, device families, requests, counts, failures, and screenshots. A successful install/launch alone does not satisfy this task.

### Task 7: Roll out and maintain the registry

**Status:** Runbook covers operation. No renewal automation/owner, backup restore, production host log review, or key rotation drill has been completed.

**Files:** Complete `docs/ops/detector-registry-runbook.md`; update PRD/SRS only if an approved requirement changes; keep `context.md` and `progress.md` current.

- [x] Roll out the first catalog-only registry and verify installed-version status; no counts are enabled. Any future YouTube/Instagram support requires a Task 4 passing version and profile.
- [ ] For a newly found release, add a sourced `catalogued` entry and run compatibility/accuracy validation before changing it to `supported`. Unknown and untested versions remain unavailable, even when an older version uses the same profile ID.
- [ ] To stop a failing version, publish a higher-sequence signed `disabled` entry and purge the host cache. Online clients can receive it at their next refresh; offline clients may retain an unexpired prior registry until its 30-day expiry. If that delay is unacceptable for a discovered fault, use an app update or an approved shorter expiry policy.
- [ ] Renew and sign the registry at least weekly, alert before expiry, keep a sequence/evidence ledger, and monitor the public file. Rotate the signing key only with an app update that pins the new public key; never reset the sequence. Recheck Google Play Accessibility declaration, privacy notice, and data-safety answers for the exact release build.

**Exit evidence:** Runbook with publication, revocation, outage, expiry, key-loss, and key-rotation drills; one recorded production-like release cycle and one disablement drill.

## Acceptance map

| Requirement | Evidence needed to close it |
| --- | --- |
| PR-17 / FR-010 | Exact locally installed version resolves through live signed entry to a bundled, independently validated shared profile; unknown version fails closed. |
| FR-011–017, FR-019, FR-021 | Per-version detector corpus and device matrix; no non-feed or stationary inflation; fault and revocation paths. |
| FR-018 | Public HTTPS response, signature/schema/provenance/sequence/expiry fixtures, offline-cache tests, no-upload request trace, disabled-entry drill. |
| NFR-05 / NFR-09 / NFR-10 | Release artifact and manifest scan, no debug detector path, TLS and key review, privacy/Play disclosure matched to real host logs. |

## Open controls before release

The current RMX2156 evidence proves that the configured app fetches and caches the live registry, but not detector accuracy. Remaining release work is recorded in the [live acceptance report](../../qa/2026-11-12-detector-registry-live/README.md) and [operations runbook](../../ops/detector-registry-runbook.md). Missing release controls are not grounds to enable an unvalidated profile.
