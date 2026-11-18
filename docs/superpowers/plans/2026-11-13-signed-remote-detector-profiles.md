# Signed Remote Detector Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Sync Scroll resolve validated app versions to signed, bounded detector profile data without a Sync Scroll APK update.

**Architecture:** The registry keeps exact package/version entries and adds a v2 profile table keyed by stable profile IDs. Profiles contain exact app-scoped Android resource IDs and enum values for the detector strategies already implemented in Kotlin. The APK continues to own all algorithms, timing, privacy handling, and event persistence; v1 registry caches remain readable.

**Tech Stack:** Kotlin, Android/JSON, Node.js built-in crypto, JSON Schema, Gradle, JUnit/Robolectric.

**Spec:** [signed remote detector profiles](../specs/2026-11-12-online-version-registry-design.md)

## Global Constraints

- A remote profile is declarative data only; it cannot add executable logic, feed text rules, arbitrary selectors, thresholds, or new detector strategies.
- Exact versions remain unavailable until each mapping passes the FR-010–021 accuracy gate.
- Profile IDs may be shared only when every mapped version independently passes the gate.
- Requests contain no installed app versions, device identifiers, selected apps, or usage data.
- Keep current YouTube and Instagram mappings unsupported; the production profile list remains empty without evidence.
- Read and preserve valid schema v1 cached envelopes; publish new payloads as schema v2.

## Review Focus

- Malformed or cross-package Android resource IDs, unknown strategy values, unknown keys, and oversized lists are rejected.
- Supported entries that reference absent or package-mismatched profile IDs fail closed.
- Catalogued and disabled versions cannot resolve to a detector even when profile definitions exist.
- A v1 supported mapping still resolves only when its profile is bundled in the APK.
- A profile replacement invalidates active candidates through the existing detector-registry refresh path.

---

### Task 1: Publisher and profile schema

**Files:**
- Modify: `tool/detector_registry/registry.mjs`
- Modify: `tool/detector_registry/registry.schema.json`
- Modify: `tool/detector_registry/registry.test.mjs`
- Modify: `tool/detector_registry/publish_registry.mjs`
- Modify: `tool/detector_registry/registry-catalog.json`

**Interfaces:**
- New v2 profile fields: `profileId`, `packageName`, `strategyId`, `feedMarkerViewIds`, `transitionViewIds`, `identityStrategy`, optional `identityNodeViewId`.
- `strategyId` is exactly `accessibility_structure_v1`.
- `identityStrategy` is one of `stable_opaque_accessibility_token`, `structural_node_pair`, or `bounded_transition_fingerprint`.
- Each ID is an exact `<packageName>:id/<resource_name>` string; marker lists contain 1–8 unique IDs.
- Each supported version carries signed evidence: ≥200 transitions, ≥100 stationary/non-feed cases, ≥3 device families, ≥98% precision, ≥90% recall, and zero stationary repeats.

- [x] **Step 1: Write failing Node tests** for a valid shared profile, publisher output, unknown profile references, cross-package IDs, unsafe fields/strategies, malformed resource IDs, duplicate IDs, and over-limit arrays.
- [x] **Step 2: Run** `node --test tool/detector_registry/registry.test.mjs`; new cases failed against the v1-only validator.
- [x] **Step 3: Implement v2 catalog/payload validation and publishing**, preserving v1 validation for existing Android cache fixtures.
- [x] **Step 4: Re-run** the Node suite; all registry tests pass and a v2 publisher artifact verifies with its public key.

### Task 2: Android verification and resolution

**Files:**
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/DetectorVersionRegistry.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/DetectorProfiles.kt`
- Modify: `android/app/src/test/kotlin/com/appylab/syncscroll/DetectorVersionRegistryTest.kt`
- Modify: `android/app/src/test/kotlin/com/appylab/syncscroll/DetectorProfilesTest.kt`

**Interfaces:**
- `VerifiedDetectorRegistry.profileFor(profileId: String, packageName: String): DetectorRegistryProfile?`
- `DetectorProfiles.forVersion(packageName, versionName, registry, bundledProfiles)` returns a version-bound `AppDetectorProfile` only after exact entry and profile package checks.
- Remote definitions produce only existing `ItemIdentityStrategy` values and built-in Accessibility structure logic.

- [x] **Step 1: Write failing Android tests** for signed v2 profile parsing/resolution, multiple exact versions sharing a profile, wrong package/profile references, unknown strategies/IDs/fields, and v1 compatibility.
- [x] **Step 2: Run** ` .\gradlew.bat :app:testDebugUnitTest`; the focused resolution test failed when remote lookup was disabled, then passed with the implementation.
- [x] **Step 3: Implement bounded v2 parsing and `DetectorRegistryProfile` resolution**; preserve signature, expiry, rollback, cache, and v1 behavior.
- [x] **Step 4: Re-run** ` .\gradlew.bat :app:testDebugUnitTest`; all Android unit tests pass.

### Task 3: Registry operations and acceptance evidence

**Files:**
- Modify: `tool/detector_registry/README.md`
- Modify: `docs/ops/detector-registry-runbook.md`
- Modify: `docs/superpowers/specs/2026-11-12-online-version-registry-design.md`
- Modify: `docs/superpowers/plans/2026-11-13-signed-remote-detector-profiles.md`
- Modify: `context.md`, `progress.md`
- Create: `docs/qa/2026-11-13-signed-remote-profiles/README.md`

- [x] Document the exact profile fields, publisher procedure, evidence gate, privacy boundary, legacy v1 handling, and how to revoke a profile.
- [x] Run Node registry tests, Android unit tests, Android debug APK assembly, and connected-device install/launch checks. RMX2156 was locked on Accessibility Settings, so visual/feed testing remains open.
- [x] Record actual profile-resolution results and device availability; do not describe a successful build or registry fetch as detector validation.
- [x] Keep RMX2156 YouTube `21.45.82` and Instagram `455.0.0.51.72` unsupported unless their exact-version corpus passes on three device families.
