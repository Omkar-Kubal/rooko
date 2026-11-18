# Onboarding, History, and Settings Implementation Plan

> **For agentic workers:** execute inline with `superpowers:executing-plans`; the current executor is already running inline.

**Goal:** Implement the approved four-stage onboarding, functional Settings, and real History with corrections, while migrating existing daily totals into Room.

**Architecture:** Flutter owns onboarding, navigation, themes, Settings, and History presentation. Kotlin owns Room, the compatibility import from SharedPreferences, count aggregation, correction validation, coverage markers, and typed MethodChannel operations. Existing estimate data remains estimate-only and transient text-derived keys never enter persistent storage.

**Tech Stack:** Flutter/Dart, SharedPreferences for existing setup preferences, Kotlin, Android Room, MethodChannel, Flutter widget tests, Android local unit/instrumented tests.

**Spec:** `docs/PRD.md` UX-01–UX-06/UX-10 and `docs/SRS.md` FR-001–008, FR-030–038, FR-050–051, FR-055, §4–5.2.

## Global Constraints

- Obtain affirmative in-app disclosure before opening Accessibility Settings and verify actual Android state on return.
- Request overlay access separately only after floating-counter opt-in; both permission paths can be skipped.
- Do not persist feed text, media, or debug text-derived keys; estimates do not activate limits.
- Keep Today free of permission CTAs and keep Settings/History usable when access is off.
- Do not show example data; do not assert timezone, coverage, or verified-limit facts absent stored evidence.
- Keep M1 export, deletion, and diagnostics requirements open and clearly unavailable in this UI pass.

## Review Focus

- Legacy aggregate import interrupted or run twice — preserve counts and prevent duplicates with transactional import marker tests.
- Service writes during app startup — initialize the same Room source for MainActivity and AccessibilityService before either reads/writes totals.
- Overlay permission declined or revoked — retain tracking and display the actual overlay state after return.
- Correction subtracts below zero or undo repeats — reject invalid subtract and allow each original correction to be reversed once.
- Old days have no timezone/coverage metadata — mark unknown and never award “Limit held.”

---

### Task 1: Product contract and work ledger

**Files:** `docs/PRD.md`, `docs/SRS.md`, `context.md`, `progress.md`, this plan, `.superpowers/sdd/2026-11-10-onboarding-history-settings/progress.md`.

- [x] Update PRD and SRS before source implementation.
- [x] Record user-selected permission/settings/history behavior in context.
- [x] Record active work and note that no Git metadata is available.

### Task 2: Room persistence, migration, and bridge

**Files:** Android Gradle configuration; Kotlin history entities/database/DAO/repository; `LocalCountStore.kt`; `SelectedAppAccessibilityService.kt`; `MainActivity.kt`; Flutter `tracking_platform.dart`; Android history tests.

**Interfaces:** `queryHistory(startLocalDate, endLocalDate) -> HistoryRange`; `addCorrection(date, appId, signedDelta, reason?) -> CorrectionResult`; `undoCorrection(correctionId) -> CorrectionResult`. `HistoryRange` contains per-day/per-app confirmed, estimated, correction, timezone-quality, and coverage-quality values.

- [x] Add tests for idempotent aggregate import, Room count updates, date-range reads, app-scoped corrections, below-zero rejection, append-only undo, and unknown legacy metadata.
- [x] Implement a versioned Room database. Import existing daily confirmed/estimated keys and last-detection times transactionally; mark legacy timezone/coverage unknown and migrate the existing interruption date as partial. Keep source preferences intact until import commits and make retry idempotent.
- [x] Route detector and debug estimate aggregates through Room; retain duplicate hashes only in process memory and never persist debug text-derived digests.
- [x] Add stable correction rows with optional reversal references. Validate adjusted confirmed totals transactionally; undo appends one inverse row and cannot repeat.
- [x] Add typed history/correction bridge methods and map results/errors in Flutter.
- [x] Run focused repository tests and the full Android app unit suite (95 tests passed).

### Task 3: History UI

**Files:** new `lib/features/history/history_screen.dart`; shared navigation wiring in `today_home_screen.dart`; Flutter tracking/history models and tests.

- [x] Add widget coverage for empty history, seven-day totals, selected-day app split, separate estimates, partial/unknown markers, correction validation, and undo.
- [x] Implement the approved week overview and selected-day detail using actual Room-backed range data, with previous/next week and day selection.
- [x] Show confirmed bars and estimates separately, omit example values, and require a stored cap snapshot plus verified coverage for any under-limit record.
- [x] Add inline app-scoped add/subtract correction and append-only undo, with optional reason and refresh after bridge success.
- [x] Run History widget coverage and the full Flutter suite (49 tests passed after the 200% text-scale regression was added).

### Task 4: Settings, themes, and Today CTA removal

**Files:** new `lib/features/settings/settings_screen.dart`; `lib/app.dart`; `lib/features/today/today_home_screen.dart`; theme preference/model; Settings and Today widget tests.

- [x] Add widget coverage for app selection sync, permission recovery, floating-counter opt-in, persisted appearance modes, privacy policy, debug-only visibility, and unavailable rows.
- [x] Implement UX-10 groups for Tracking, Preferences, Privacy & Data, Support, About, and the in-app privacy policy.
- [x] Hide Notifications and battery optimization. Move the debug-only estimate consent action into Settings with debug/release gating.
- [x] Remove permission/debug CTAs from Today while retaining tracking status, count quality, and coverage information.
- [x] Persist appearance at app root and apply system/light/dark/AMOLED modes.
- [x] Run affected widget coverage and the full Flutter suite (49 tests passed).

### Task 5: Four-stage onboarding and overlay verification

**Files:** `lib/features/onboarding/app_flow_screen.dart`; `lib/features/onboarding/onboarding_screens.dart`; tracking platform interface; onboarding widget tests; Android overlay status in `MainActivity.kt` as needed.

- [x] Add widget coverage for four-stage progress, Accessibility consent gate, grant/decline/skip, overlay opt-in/denial, actual-state refresh, Back, and draft restoration.
- [x] Add the optional floating-counter disclosure/action/status after Accessibility verification; persist opt-in separately from the Android permission grant and query actual permission on return.
- [x] Keep setup independently skippable, provide retry from Settings, and let every path reach Today.
- [x] Update stage labels and Android Back mapping while preserving Welcome and app-selection behavior.
- [x] Run onboarding coverage and the full Flutter suite (49 tests passed).

### Task 6: Integration and verification record

**Files:** relevant tests, `docs/qa/` evidence, `progress.md`, `context.md`.

- [x] Run Dart formatting check (28 files, no changes), `flutter analyze --no-pub` (0 errors/warnings; 5 existing Rive deprecation info notices), and `flutter test` (49 passed).
- [x] Run Android unit suite (95 passed), assemble the debug APK, and build `flutter build apk --debug --no-pub` using the machine's writable Room temp directory.
- [x] Install the debug APK in place on RMX2156 / Android 12 / API 31; verify Today, History, Settings, light/dark/AMOLED modes, return to System appearance, and unchanged font scale `1.0`.
- [x] Exercise Accessibility grant/decline, optional overlay skip, overlay denial/grant through Android Settings, and permission-state refresh after external revocation on dedicated Android 16 AVDs.
- [x] Review Today, Settings, and History week and selected-day views at 200% font scale on an AVD; restore font scale to `1.0`, TalkBack off, floating-counter preference off, overlay denied, then shut it down.
- [ ] Complete reliable TalkBack spoken-output review, reduced-motion review, and the manual 48 dp target/contrast audit.
- [x] Record evidence and unresolved release gates in `docs/qa/2026-11-11-onboarding-history-settings-review.md`. Export, deletion, diagnostics, detector accuracy, complete-coverage scoring, and the NFR-03 startup target remain open.

## Execution Notes

- This workspace contains no `.git` metadata; worktree isolation and commits are unavailable. Changes are made in the supplied project directory.
- Existing SharedPreferences are retained as a migration source. Do not clear device/app data during verification.
- If Room/database inspection shows that complete coverage cannot be established, keep all affected days explicitly unverified and omit verified-day claims.

## Review outcome and remaining gates (2026-11-11)

- The implementation is complete for this UI/data pass. The independent review's six integration findings were corrected and regression-tested: adjusted Today totals, Today refresh on return, Settings permission refresh, already-granted overlay opt-in persistence, calendar-safe History navigation, and onboarding draft persistence/controller lifecycle. A 200% text-scale History overflow was found in the selected-day chart, fixed by allowing labels/bars and coverage elements to wrap, and covered by a regression test.
- Cold launch on RMX2156 / Android 12 / API 31 measured 8.63/5.46 seconds on code 31 and 7.10/4.41 seconds on code 32. All exceed SRS NFR-03's two-second target; performance readiness is not established.
- Dedicated Android 16/API 36 AVDs exercised Accessibility grant/verified return, decline, optional overlay skip, overlay denial and grant, and Settings refresh after external revocation. At 200% font scale Today, Settings, and History week/selected-day views remained inspectable and scrollable on build 4033. The AVD was restored to font scale `1.0`, TalkBack off, floating-counter preference off, overlay denied, then shut down. TalkBack focus navigation reached Settings controls, but spoken announcements could not be captured; an Android Accessibility Suite notification prompt was denied, and notification access was not granted. Reduced motion and manual target/contrast audits remain open. RMX2156 was not changed.
- Temporary review captures and UI hierarchy files remain in `build/qa`; cleanup commands were rejected by the command safety layer as blocked by policy. The build's SQLite temp directory remains in `build/sqlite-tmp`.
- See the linked QA record for acceptance evidence, environmental build workarounds, and the complete open-gate list.
