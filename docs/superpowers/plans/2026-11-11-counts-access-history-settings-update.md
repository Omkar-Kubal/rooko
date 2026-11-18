# Count, Access, History, and Settings Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Today and History show the counter’s recorded events as one count, move limit editing to Settings, replace the access-off state with a dismissible permission wall/banner, and give Week and Month distinct charts.

**Architecture:** Flutter continues to own screen presentation and shared preferences for the limit. Kotlin continues to own Android access state and Room records. Internal event categories remain for detector QA, but Today, History, and the floating counter present one combined event total; History does not issue manual count corrections.

**Tech Stack:** Flutter/Dart, Kotlin, Room, SharedPreferences, existing `TrackingPlatform` bridge, existing Sync Scroll design tokens and Rook artwork.

**Spec:** `docs/PRD.md` UX-02/05/06/07/10 and PR-01/02/03/04/06/09; `docs/SRS.md` FR-004/010/017/031–038 and the user-facing count-language rule.

## Global Constraints

- Do not copy BrainPal wording, branding, artwork, or colored UI treatment from the attached references.
- Do not display “estimate,” “est.,” “partial,” or “confirmed” as user-facing count-quality labels.
- Keep the debug text-key path debug-only and release-disabled; preserve its existing privacy boundary.
- Preserve Room event records and legacy date metadata; do not invent history values.
- Do not expose add, subtract, or undo count controls in History.
- Use `AppTypography`, `AppColors`, `AppSpacing`, `AppRadii`, `AppIcons`, and `AppIcon` for screen UI.
- Preserve the three navigation destinations: Today, History, Settings.

## Review Focus

- Accessibility access is missing on first launch: wall appears; X collapses it to a persistent banner; Allow opens Settings.
- Accessibility is revoked after dismissal: Settings and Today refresh on resume without stale access state.
- A recorded event exists only in an internal non-primary event category: the visible total still includes it once.
- A Week/Month contains some empty dates: those dates have no bar/heat cell mark or fabricated zero record.
- The complete selected period is empty: show the Rook empty illustration, not an empty chart grid or example values.

---

### Task 1: Update Today access and count presentation

**Files:**
- Modify: `lib/features/today/today_home_screen.dart`
- Modify: `lib/core/platform/tracking_platform.dart`
- Test: `test/features/today/today_home_screen_test.dart`

**Interfaces:**
- `AppTrackingSnapshot` exposes a derived `countedCount` equal to its stored counter event categories.
- `_TodayContent` receives `onOpenSettings` and `permissionWallDismissed`; it renders the wall or banner based on actual access state.

- [x] **Step 1: Add failing widget tests** for combined counts, wall/Allow/X behavior, no confidence vocabulary, and absent access/detection timestamps.
- [x] **Step 2: Run the tests** and confirm they fail because current Today shows separate count categories and diagnostics.
- [ ] **Step 3: Implement** the single visible count, first-run wall, X-to-banner persistence, Allow-to-Settings route, and removal of the two timestamp cards.
- [ ] **Step 4: Run Today tests** and confirm the new behavior passes.

### Task 2: Move limit controls into Settings and remove onboarding entry

**Files:**
- Modify: `lib/features/today/today_home_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/features/onboarding/app_flow_screen.dart`
- Modify: `lib/features/onboarding/onboarding_screens.dart`
- Test: `test/features/settings/settings_screen_test.dart`
- Test: `test/features/onboarding/app_flow_screen_test.dart`

**Interfaces:**
- `SettingsScreen` receives the current limit settings and an `onEditLimit` callback.
- Today keeps a read-only limit summary; onboarding no longer captures a limit.

- [x] **Step 1: Add failing tests** proving Settings owns the limit action and onboarding has no daily-limit editor.
- [x] **Step 2: Run the focused tests** and confirm the current routes fail those expectations.
- [ ] **Step 3: Implement** the Settings limit section and remove limit entry from onboarding and Today.
- [ ] **Step 4: Run Settings and onboarding tests** and confirm save/persistence still works.

### Task 3: Replace Day/Week History with Week bars and Month heatmap

**Files:**
- Modify: `lib/features/history/history_screen.dart`
- Modify: `lib/core/models/history.dart`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/HistoryRepository.kt`
- Test: `test/features/history/history_screen_test.dart`

**Interfaces:**
- `HistoryAppTotal.countedCount` returns stored event categories, excluding legacy manual correction deltas.
- History queries the selected week or calendar month and renders a period-specific per-app total list.
- No History action calls `addCorrection` or `undoCorrection`.

- [x] **Step 1: Add failing tests** for Week bars, Month heatmap, period-specific app totals, empty individual dates, fully empty periods, and no correction controls.
- [x] **Step 2: Run the tests** and confirm current Day/Week History does not satisfy them.
- [ ] **Step 3: Implement** range navigation, graph labels, grayscale intensity, single-date empties, full-range Rook empty state, and captured-event totals.
- [ ] **Step 4: Run History tests** including 200% text scale.

### Task 4: Align Settings, disclosures, and floating counter copy

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/features/today/debug_text_test_dialog.dart`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/SelectedAppAccessibilityService.kt`
- Modify: `android/app/src/main/res/values/strings.xml`
- Test: `test/features/settings/settings_screen_test.dart`

- [ ] **Step 1: Add failing checks** that visible settings/privacy/accessibility/bubble copy has no banned confidence words and the counter shows the combined count.
- [ ] **Step 2: Run focused tests** and confirm current visible copy fails.
- [ ] **Step 3: Implement** concise Sync Scroll copy and one floating-counter number while retaining debug-only consent behavior.
- [ ] **Step 4: Run the focused Settings and counter tests.**

### Task 5: Review and verify the changed flow

**Files:**
- Modify: `context.md`
- Modify: `progress.md`
- Update: `docs/qa/ui-screenshots/2026-11-11-onboarding-history-settings/README.md` and screenshots after an isolated Android 16 capture pass.

- [ ] **Step 1: Search user-facing Flutter and Android resources** for the banned terminology and removed actions.
- [ ] **Step 2: Run Flutter analyzer, Flutter tests, Android unit tests, and debug APK build** after the focused task tests pass.
- [ ] **Step 3: Capture wall, banner, Settings limits, Week, Month, and both empty-history states** on an isolated AVD; do not alter the physical phone.
- [ ] **Step 4: Update the gallery index and progress evidence, then shut down the AVD and verify the device list.**

## Workspace note

This workspace has no Git metadata, so commits and Git worktree isolation are unavailable. Implementation and evidence files remain in the existing workspace.
