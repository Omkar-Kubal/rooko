# Online Detector Version Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve a device's locally detected app version to an internet-maintained, signed catalog entry and a validated detector profile already bundled in Sync Scroll.

**Architecture:** Android fetches one complete HTTPS envelope and verifies its ECDSA/SHA-256 signature before parsing or caching it. The registry maps exact package/version pairs to shared profile IDs; detector rules remain local, and each event still checks the exact locally installed version.

**Tech Stack:** Kotlin, Android `HttpsURLConnection`, Android `SharedPreferences`, platform ECDSA, Gradle build properties, JSON Schema, and dependency-free Node.js crypto for local validation/signing.

**Spec:** [2026-11-12 online detector version registry](../specs/2026-11-12-online-version-registry-design.md)

## Global Constraints

- Unknown, catalogued-only, invalid, disabled, expired, and unbundled profile mappings fail closed.
- Registry requests contain no device identifier, selected app, installed version, or usage data.
- Remote payloads contain data only and cannot add code, selectors, or detector rules.
- Profile IDs may be shared only across versions independently validated against FR-010–021.
- Current production detector profiles are empty; this work does not claim YouTube or Instagram support.
- Never commit the signing private key. A host URL and pinned public key must be configured before the client fetches online.

## Review Focus

- Invalid signature, schema, expiry, or sequence rollback: parser rejects the payload and keeps a still-valid prior cache.
- Expired cache while offline: no profile resolves.
- Catalogued version or unknown profile ID: no detector gets enabled.
- Registry update while a dwell candidate exists: discard the candidate before swapping profiles.
- No configured endpoint/key: perform no request and keep installed versions unsupported.

---

### Task 1: Product contract and design

**Files:** `docs/PRD.md`, `docs/SRS.md`, `context.md`, `progress.md`, `docs/superpowers/specs/2026-11-12-online-version-registry-design.md`

- [x] Define online catalog, local installed-version read, shared profile IDs, fail-closed states, privacy boundary, and hosting open input.

### Task 2: Signed registry client and build setup

**Files:**
- Create: `android/app/src/main/kotlin/com/appylab/syncscroll/DetectorVersionRegistry.kt`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interface:** `DetectorVersionRegistry.readVerified(): VerifiedDetectorRegistry?`; `DetectorVersionRegistry.refreshAsync((VerifiedDetectorRegistry?) -> Unit)`; `VerifiedDetectorRegistry.entryFor(packageName, versionName)`.

- [x] Implement bounded envelope/payload parsing and SHA-256 ECDSA verification against the build-pinned key.
- [x] Validate schema/version syntax/package allowlist, expiry, and duplicate exact versions; reject unknown payload keys.
- [x] Fetch a full HTTPS registry with no redirects, fixed request headers, bounded timeouts/body size, and no device fields.
- [x] Cache the signed envelope and highest accepted sequence; preserve prior cache on fetch/verification failure and reject rollback or same-sequence payload changes.
- [x] Add URL/key Gradle properties and INTERNET permission. Empty properties disable network fetch.

### Task 3: Shared profile resolution

**Files:**
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/DetectorProfiles.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/ReelDetector.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/MainActivity.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/SelectedAppAccessibilityService.kt`

**Interface:** `DetectorProfiles.forVersion(packageName, versionName, registry)` returns a version-bound copy of the bundled profile identified by the signed exact-version entry, or null.

- [x] Make profile rules version-independent and select them by `profileId`; bind the exact device version only after lookup.
- [x] Share the same verified registry source between onboarding/settings support status and Accessibility event handling.
- [x] On verified registry replacement, cancel active production candidates and rebuild the detector; retain debug-only behavior as-is.
- [x] Keep current production versions unsupported because the bundled profile map remains empty.

### Task 4: Registry publication and compile evidence

**Files:**
- Create: `tool/detector_registry/registry.schema.json`
- Create: `tool/detector_registry/registry.mjs`, `registry.test.mjs`, and `publish_registry.mjs`
- Create: `tool/detector_registry/README.md`
- Update: `docs/superpowers/plans/2026-11-12-online-version-registry.md`, `progress.md`

- [x] Document internet catalog provenance (`sourceUrl`), signing, hosting, and build-property setup.
- [x] Add a dependency-free Node validator/signer that validates the exact payload bytes, enforces the Android envelope limit, and keeps private key material external to the workspace. The earlier Python/OpenSSL helper was removed because it did not enforce the client contract.
- [x] Compile Android Kotlin with the cross-drive workaround and record the final result.
- [ ] Configure a live URL/key and publish a release catalog. This step depends on the missing host and signing key.
