# Progress Observed Time Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local observed-feed-time value to Progress Day beside “Total Count,” without estimating duration from counts.

**Architecture:** Kotlin samples the foreground root only while a selected Instagram Reels or YouTube Shorts feed is recognized, using monotonic time and short bounded intervals. Room stores only a nullable per-day duration aggregate, which the typed progress bridge exposes to Flutter for a paired Day summary metric. A new affirmative-consent version gates the expanded measurement purpose.

**Tech Stack:** Flutter/Dart, Android AccessibilityService/Kotlin, Room/SQLite, MethodChannel.

**Spec:** `docs/superpowers/specs/2026-11-17-progress-observed-time-design.md`

## Global Constraints

- Count only observed foreground time in a recognized selected Instagram or YouTube feed; never infer duration from counts.
- Use `SystemClock.elapsedRealtime()` for intervals and discard uncertain gaps.
- A time pulse checks package and feed-marker IDs only; it does not inspect labels or item identity.
- Store only a daily aggregate; older records keep unknown duration.
- Accessibility consent and service access are required; overlay access is not.
- Counted-event timestamps remain a separate seven-day detail.
- No automated tests are added or run for this change unless the user asks for testing or verification.

## Review Focus

- A service gap or feed transition must not credit the time between uncertain observations; inspect timer reset and flush paths.
- An unselected app, unsupported package/version, or non-feed root must stop accumulation; inspect every entry path.
- Screen-off, consent/access loss, interruption, and service destruction must clear the active interval without backfilling.
- Legacy duration must remain null and render as unavailable; explicit accumulated values must render as elapsed time.
- Consent key migration must require a new affirmative acknowledgement before any observed-time sampling.

---

### Task 1: Persist daily observed duration

**Files:**
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/SyncScrollDatabase.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/ProgressRepository.kt`

**Interfaces:**
- Add nullable `observedFeedDurationMillis: Long?` to `ProgressDayEntity` and Kotlin `ProgressDay`.
- Add `ProgressRepository.recordObservedFeedDuration(localDate: String, durationMillis: Long, timeZoneId: String, offsetSeconds: Int)`.
- The repository ignores nonpositive duration, creates a day with `UNKNOWN` coverage when needed, and accumulates positive milliseconds transactionally. Existing rows remain null after migration.

- [x] Add Room migration 5→6 with nullable `observedFeedDurationMillis` on `progress_day`; bump the database version to 6 and register the migration.
- [x] Implement the repository writer and include the nullable aggregate in `queryProgress` without synthesizing legacy values.
- [x] Review migration ordering and ensure count aggregates, hourly rows, counted timestamps, and verification rows remain untouched.

### Task 2: Observe foreground feed intervals

**Files:**
- Create: `android/app/src/main/kotlin/com/appylab/syncscroll/ObservedFeedTimeTracker.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/SelectedAppAccessibilityService.kt`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/DebugEventEstimate.kt`

**Interfaces:**
- The tracker accepts successful observations `(appId, localDate, timeZoneId, offsetSeconds, elapsedRealtimeMillis)` and returns only bounded elapsed milliseconds between consecutive matching observations.
- The service schedules a 4-second heartbeat while a selected feed is recognized, checks `PowerManager.isInteractive`, current root package, current app version, selection, consent, service state, and visible feed markers, and credits only intervals no longer than five seconds. It persists accumulated positive time in 30-second batches and when stopping a recognized session.
- Validated profiles use their feed marker IDs. The existing consented estimate path uses marker-only traversal; it must not read labels during time checks.

- [x] Add a tracker that caps each credited interval at five seconds and resets on date, offset, app, or feed continuity changes.
- [x] Start/checkpoint the heartbeat for validated and consented estimated feeds, using visible marker-only checks for estimated feeds.
- [x] Stop and flush already bounded time on app/feed exit, screen-off detection, app selection/version changes, consent/access loss, host Activity resume, `onInterrupt`, and `onDestroy`; never credit the gap that caused the stop.
- [x] Batch Room writes to avoid a database write every heartbeat; pending uncommitted time may be lost on abrupt process death and must not be reconstructed.
- [x] Review that the service timer does not change count events, item dedupe, overlay behavior, or personal-best verification.

### Task 3: Require the expanded tracking consent

**Files:**
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/SelectedAppAccessibilityService.kt`
- Modify: `lib/features/onboarding/onboarding_screens.dart`
- Modify: `lib/features/settings/settings_screen.dart`

**Interfaces:**
- Replace the stored consent key `tracking_consent_visible_labels_v2` with a new v3 key so existing users must affirm the revised disclosure again.
- The disclosure says the service measures observed time while a selected supported feed is in the foreground, stores only local daily totals, does not establish playback/attention, and does not save content; overlay access is not needed for this measurement.

- [x] Update onboarding, Android Accessibility Settings, and in-app Settings disclosure copy and preserve the affirmative checkbox/decline route.
- [x] Bump the consent key and inspect all native snapshot, selected-app, service, and onboarding paths to ensure old consent does not authorize duration.
- [x] Update the in-app Privacy Policy description of local duration aggregation.

### Task 4: Expose and present the Day metrics

**Files:**
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/MainActivity.kt`
- Modify: `lib/core/models/progress.dart`
- Modify: `lib/features/progress/progress_screen.dart`

**Interfaces:**
- `progressDayMap` adds nullable `observedFeedDurationMillis`.
- Dart `ProgressDay` adds nullable `observedFeedDurationMillis` parsed from that map key.
- The Day summary renders `Total Count` and `Time spent` as aligned metrics. Null duration renders `—`; positive values under one minute render `<1 min`, otherwise render whole elapsed minutes/hours. Exact count timestamps remain unchanged.

- [x] Add the nullable native bridge field and Dart model parsing.
- [x] Replace the Day count label with “Total Count” and present both metrics in the existing borderless card with combined TalkBack semantics.
- [x] Keep the layout usable at narrow widths and large text sizes without adding borders.
- [x] Inspect the selected-hour readout and counted-time placeholder to ensure the duration metric is not presented as per-event playback time.

### Task 5: Reconcile product documentation

**Files:**
- Modify: `AGENTS.md`
- Modify: `context.md`
- Modify: `progress.md`
- Modify: `docs/PRD.md`
- Modify: `docs/SRS.md`

- [x] Replace the blanket prohibition on viewing duration with the approved observed-feed rule, keeping the prohibition on count-derived duration.
- [x] Update Progress Day UX and FR-035 to cover the paired metrics, nullable legacy data, measurement lifecycle, and updated consent; FR-001/UX-03 also explain the new disclosure purpose.
- [x] Record only evidence actually gathered; do not claim detector accuracy or perfect watch-time measurement.

### Final review

- [x] Review changed source, schema, and documentation against the approved design; no raw feed content or per-item duration was added to persistence. The workspace has no Git metadata, so a VCS diff review is unavailable.
- [x] Leave automated tests and device verification unrun under the current instruction; report this limitation clearly.
