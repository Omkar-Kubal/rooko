# Exposure Counter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce accurate, app/version-scoped one-second short-form exposure counts for the five apps shown in onboarding, including the first eligible item on feed entry, while keeping unvalidated profiles estimated or unsupported.

**Architecture:** Kotlin remains responsible for Accessibility observations, candidate state, per-app detector profiles, deduplication, and atomic local count writes. Flutter continues to consume typed daily snapshots and update Today on resume. A floating counter is a post-validation optional M2 follow-up with separate overlay permission; it is not a prerequisite for detector accuracy.

**Tech Stack:** Kotlin `AccessibilityService`, Android/JVM unit tests, SharedPreferences-backed local aggregate store, Flutter/Dart typed MethodChannel snapshot, RM and additional Android devices.

**Spec:** `docs/superpowers/specs/2026-11-07-exposure-counter-design.md`

## Global Constraints

- Android minimum SDK remains 29; only selected supported packages and validated app versions may be observed.
- A count represents an eligible item exposure after 1,000 ms of recognized visibility; it does not claim watched attention or completion.
- Never persist feed text, messages, images, audio, video, screenshots, OCR, or raw accessible item tokens.
- Persist only app-scoped salted identity hashes for the five-minute duplicate window; rotate the identity salt and clear expired hashes.
- Keep confirmed, estimated, and unsupported/coverage-gap states separate; only confirmed events can cross a saved limit.
- Unknown versions fail closed. Do not infer support for a whole app family or future release from one version.
- Accessibility use remains gated by the existing disclosure, affirmative consent, and user-controlled Android permission.
- Keep TikTok Lite out of onboarding; track its separate PRD/SRS v2.0 scope decision.

## Review Focus

- Feed entry with a first item but no swipe: seed a candidate and count once only after a full eligible second.
- Pager index reused for different items: index alone must never deduplicate as stable content identity.
- Stationary item or repeated content-change events: one event maximum for the same exposure.
- Fast swipe, comments, search, long video, app background, and page exit: do not create false feed counts.
- Permission revocation, service interruption, unsupported versions, and OEM service death: cancel pending candidates and expose coverage loss.

---

### Task 1: Lock the count contract and evidence matrix

**Files:**
- Modify: `docs/PRD.md` detector and M0/M2 sections
- Modify: `docs/SRS.md` FR-010–021, especially FR-012/013/017 and the accuracy gate
- Create: `docs/qa/detector-validation-matrix.md`
- Modify: `context.md`, `progress.md`

**Interfaces:**
- Consumes: approved design in `docs/superpowers/specs/2026-11-07-exposure-counter-design.md`
- Produces: one versioned matrix row per tested app/version, including device/API, feed signature, item-identity method, cases run, precision, recall, confidence, and uncovered cases.

- [x] Update PRD and SRS together: replace transition-only 750 ms wording with a 1,000 ms visible-item exposure target, allow a recognized feed-entry candidate for the first item, and retain the M0 accuracy gate as the release condition.
- [x] Record the five onboarding app IDs/packages and a separate TikTok Lite row marked “v2 scope decision; not in onboarding.” Do not mark an untested app/version as supported.
- [x] Define matrix columns for app ID, package, version, Android API/device family, feed marker, transition signal, item identity method, expected cases, TP/FP/FN, confidence, and status.
- [x] Check PRD/SRS/context cross-references for consistent wording; no detector code changes in this task.

### Task 2: Specify profile identity evidence

**Files:**
- Create: `android/app/src/test/resources/detector_profiles/README.md`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/DetectorProfiles.kt`
- Modify: `android/app/src/test/kotlin/com/appylab/syncscroll/DetectorProfilesTest.kt`

**Interfaces:**
- Consumes: matrix entries collected in Task 1 and app-version observations from supervised device sessions.
- Produces: exact-version `AppDetectorProfile` entries with feed signature, transition source, identity strategy, fixture revision, and explicit confidence.

- [x] Keep each profile exact-version until multiple tested versions establish an unchanged signature range.
- [x] Add a profile only when the evidence matrix has real feed-entry, item-change, non-feed, and item-identity observations for that version. No profile was enabled because the required identity evidence was absent.
- [x] Add profile tests for recognized feed, non-feed rejection, exact supported version, unknown version fail-closed behavior, and item-identity strategy availability.
- [x] Use synthetic structural fixtures; do not store accessible text, media, or captured screens.

### Task 3: Replace index identity and implement one-second candidates

**Files:**
- Create: `android/app/src/main/kotlin/com/appylab/syncscroll/ItemIdentityHasher.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/ReelDetector.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/SelectedAppAccessibilityService.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/LocalCountStore.kt`
- Modify: `android/app/src/test/kotlin/com/appylab/syncscroll/ReelDetectorTest.kt`
- Modify: `android/app/src/test/kotlin/com/appylab/syncscroll/LocalCountStoreTest.kt`
- Create: `android/app/src/test/kotlin/com/appylab/syncscroll/ItemIdentityHasherTest.kt`

**Interfaces:**
- Consumes: versioned `AppDetectorProfile` identity strategy from Task 2.
- Produces: per-app candidate lifecycle that starts on recognized feed entry or distinct item transition, revalidates the same item at 1,000 ms, and emits at most one count per eligible exposure.
- Identity hashing interface: `AppScopedIdentityHasher.hash(appId: String, profileKey: String, opaqueToken: String, elapsedRealtimeMillis: Long): String`; the salt store rotates after 24 hours of monotonic elapsed time and immediately after an elapsed-clock reset.

- [x] Add failing unit tests for initial-item candidate seeding, 999 ms rejection, 1,000 ms confirmation, same-item stationary events, fast swipe rejection, distinct identities sharing an index, duplicate revisit within five minutes, and exit before threshold.
- [x] Add an identity result type that contains only an already-salted hash plus an evidence/confidence enum; it must not carry raw tokens into `ReelDetector` or storage.
- [x] Use a per-app, per-profile salted digest; discard the opaque input token after hashing. Keep duplicate hashes in process memory and remove legacy persisted keys on store open; cross-process deduplication remains a confirmation gate because idle SharedPreferences cleanup cannot guarantee physical deletion at expiry.
- [x] Remove pager index from the stable dedupe identity. Use an opaque stable token when the profile exposes one; otherwise require a profile's two independent structural signals and rederive its bounded root signature at the dwell deadline. Pager position remains transition evidence, never identity.
- [x] Set the candidate threshold to `1_000L`; use monotonic elapsed time and recheck foreground package and feed signature before committing. Stable tokens and the estimated structural node-handle/topology pair are rederived and matched from the current root. A bounded transition fingerprint alone cannot revalidate a candidate or produce a count.
- [x] Cancel the candidate on feed exit, app switch, permission/service interruption, profile change, or selected-app removal.
- [x] Preserve the five-minute duplicate window from FR-015 and ensure same-item content-change events cannot increment twice.

### Task 4: Seed feed-entry items and guard the Accessibility service

**Files:**
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/SelectedAppAccessibilityService.kt`
- Modify: `android/app/src/test/kotlin/com/appylab/syncscroll/DetectorProfilesTest.kt`
- Add or modify: Android service instrumentation/fixture tests for feed-entry and foreground lifecycle behavior

**Interfaces:**
- Consumes: candidate and identity APIs from Task 3.
- Produces: sanitized `ReelObservation` inputs only while a selected, supported package and its recognized feed are foreground.

- [ ] Validate first-item feed-entry seeding against a supported app profile; generic state-machine coverage exists, but the RMX2156 samples did not expose the identity signal needed to enable a profile.
- [x] Revalidate a candidate at its deadline according to its identity strategy. Stable tokens or a structural node-handle/topology pair are rederived from one visible profile-configured root node and must match; missing, ambiguous, unsupported-API, incomplete, or changed identities cancel. Structural identity remains estimated-only and later candidates also require an observed pager transition. Bounded transition fingerprints cannot revalidate at the root. No observed app/version currently supplies validated item identity, so no counting profile is active.
- [x] Keep event throttling, Accessibility node recycling, consent checks, and selected-package scoping intact; audit newly visited nodes for recycling on every early return.
- [ ] Verify comments, search, long video, app background, launcher, and permission revocation against a supported app profile. Deterministic guards exist, but no profile is enabled for this device pass.

### Task 5: Add evidence-backed profiles for the onboarding apps

**Files:**
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/DetectorProfiles.kt`
- Modify: `android/app/src/test/kotlin/com/appylab/syncscroll/DetectorProfilesTest.kt`
- Update: `docs/qa/detector-validation-matrix.md`

**Interfaces:**
- Consumes: profile strategy from Task 2 and tested signals from Task 4.
- Produces: estimate-only or confirmed profiles for exact versions of YouTube, Instagram, TikTok, Facebook, and Snapchat; unsupported versions remain absent.

- [x] Inspect the installed Instagram and YouTube versions under the existing consent and user-enabled Accessibility flow. Collect only structural view IDs, event types, indexes, coarse timestamps, and node features; no opaque item identity was available in the captured fields.
- [ ] Add an evidence-backed exact-version profile only after a usable item identity and accuracy gate exist. Currently no profile qualifies; Instagram's historical profile is disabled for new counts, and YouTube plus absent target apps remain unsupported.
- [x] Verify an installed but unprofiled version remains unsupported/partial through exact-version profile lookup and the typed tracking status path.
- [x] Do not create a generic cross-app selector or broaden one profile to untested versions.

### Task 6: Keep Today and limits tied to committed confidence

**Files:**
- Review/modify: `android/app/src/main/kotlin/com/appylab/syncscroll/MainActivity.kt`
- Review/modify: `lib/core/platform/tracking_platform.dart`
- Review/modify: `lib/features/today/today_home_screen.dart`
- Modify: relevant Kotlin and Flutter snapshot tests

**Interfaces:**
- Consumes: atomic local aggregate updates from Task 3 and profile confidence from Task 5.
- Produces: typed daily counts and freshness status where confirmed totals alone drive limits; Today refreshes when the app resumes.

- [x] Keep confirmed and estimated totals separate in the versioned tracking snapshot; do not add a sum that lets estimates appear as confirmed.
- [ ] Verify Today refresh-on-resume for a committed count; RMX2156 displayed tracking on and both selected versions unsupported, but no active profile can produce an event for this check yet.
- [x] Verify limit crossing reads only confirmed aggregate events. History and Settings screens are outside this plan.
- [x] Do not add an EventChannel or overlay implementation; the optional live surface remains after the accuracy gate.

### Task 7: Validate each profile against the M0 gate

**Files:**
- Update: `docs/qa/detector-validation-matrix.md`
- Add/modify: deterministic Kotlin tests and Android device QA scripts/fixtures
- Update: `progress.md`

**Interfaces:**
- Consumes: complete app/version profiles and candidate behavior from Tasks 2–6.
- Produces: a completed evidence row per app/version with measured precision, recall, stationary repeats, device/API coverage, and final confidence status.

- [ ] Collect the full 200-transition and 100 stationary/non-feed corpus per profile across at least three device families. The current RMX2156 single-device sample is a signal-feasibility pass only.
- [ ] Run the full scenario matrix after a profile has a usable identity signal; deterministic unit coverage exists for timing, repeat, exit/loss, and unknown-version behavior.
- [ ] Compute precision and recall from the labeled corpus; require precision ≥98%, recall ≥90%, and zero repeated stationary increments before setting any profile to `CONFIRMED`.
- [x] Where identity evidence is absent, retain unsupported status and document uncovered cases. Do not lower the gate to complete coverage claims.
- [x] Record exact observed app versions, Android API/device family, probe setup, sample counts, and gaps without storing screenshots or feed content.
- [x] Add a separately gated, debug-only API 33+ node-ID continuity harness with process-memory-only HMAC comparison and relation-label output; tracker/formatter tests pass, and the strict UTF-8 output ceiling is covered by a boundary test.
- [x] Run the harness on the API 36 `sync-scroll-preview` emulator after app installation and user-controlled Accessibility setup. Instagram `454.0.0.54.77` produced 26 candidate observations, all `no_value`; YouTube `21.32.4` produced one `no_value` candidate and no candidate event after the second swipe. Both versions remain unsupported; only aggregate labels were retained and temporary markers/output were removed.
- [x] Implement and run two debug-only alternatives: an HMAC relation for `AccessibilityNodeInfo.hashCode()` and independent bounded child-topology and visible-state signatures. On API 36, Instagram's three signals stayed `same` across two observed pager advances. On YouTube, node-handle/topology labels changed during two swipe attempts then stabilized, but no pager-scroll event confirmed the item transition; visible-state labels were noisier. These remain feasibility-only and do not enter counting.

### Task 8: Add the optional live floating counter after the accuracy gate

**Files:**
- Create: `android/app/src/main/kotlin/com/appylab/syncscroll/FloatingCounterOverlay.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/SelectedAppAccessibilityService.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/core/platform/tracking_platform.dart`
- Modify: `lib/features/today/today_home_screen.dart`
- Add/modify: Android overlay and Flutter opt-in tests

**Interfaces:**
- Consumes: confirmed local totals and profile/coverage state from Tasks 3–7.
- Produces: an opt-in `setFloatingCounterEnabled(enabled: Boolean)` control and an overlay that displays committed confirmed counts only while a selected, confirmed-profile app is foreground.

- [ ] Add an explicit Today opt-in action. Request `SYSTEM_ALERT_WINDOW` only after the user enables the feature; denial leaves detection and Today unchanged.
- [ ] Render a compact, draggable, dismissible counter from `WindowManager` with non-focusing behavior that does not block target-app navigation or taps.
- [ ] Show the confirmed daily count with an explicit Today/count label; hide the overlay when the selected app is not foreground, the feed is unrecognized, the profile is estimated/unsupported, or access is revoked.
- [ ] Stop and remove the overlay on opt-out, permission revocation, service interruption, app deselection, or teardown. Do not retain events or identities in the overlay component.
- [ ] Verify Android 29+ permission grant/decline/revoke, target-app interaction, TalkBack labels, and system navigation. Recheck current Android and Play overlay policy before release.
- [ ] Keep the visual treatment minimal; a separate design review can tune placement and styling without changing detector semantics.

## Handoff

The one-second candidate state machine, confidence separation, exact-version fail-closed behavior, and typed Today/limit snapshot handling are implemented and deterministically verified. Stable tokens and an estimated-only node-handle/topology pair are rederived from the active root at dwell confirmation; bounded transition fingerprints alone cannot pass the deadline. Structural changes do not count without a recognized feed entry or observed pager transition. This makes a future root-derived profile path testable but does not produce an active profile. Alternative API 36 probes show no usable Instagram item identity and only an inconclusive YouTube handle/topology change; neither app profile is active. The user re-enabled Accessibility after the setup issue, and probe files are removed. TikTok, Facebook, and Snapchat remain untested; TikTok Lite remains a separate scope decision. The full three-device corpus and optional M2 floating counter remain gated; Task 8 overlay work stays deferred.

### Counting-logic follow-up ruling

Ruling: reject cached fingerprint/index as dwell revalidation and add a root-derived structural pair for future estimated profiles, with later structural candidates also requiring a pager transition — this aligns the deadline with the current-root identity contract and prevents topology churn alone from incrementing; cost if wrong: node-handle/topology pairs may still fail to identify actual feed items, so current profiles remain disabled until app/version evidence passes the SRS gate.
