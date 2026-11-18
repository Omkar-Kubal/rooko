# UX-07 Limit Bottom Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Execute inline with `superpowers:executing-plans`.

**Goal:** Complete the user-approved UX-07 limit sheet and wire it to Today’s local settings.

**Architecture:** Extract the sheet into a focused Flutter component that returns an immutable settings result. Today owns SharedPreferences persistence and passes saved values into the sheet. Changes remain local and visibly inactive until tracking is connected.

**Tech Stack:** Flutter, Dart, SharedPreferences, existing Sync Scroll design tokens.

**Spec:** `assets/design/ux-07-limit-bottom-sheet-light.png`, `assets/design/ux-07-limit-bottom-sheet-dark.png`, PRD §4 / §4.1, SRS FR-038, FR-040, FR-041.

## Global Constraints

- Daily cap is 1–500; 30 is a suggestion and a limit is not saved until the user taps Save.
- The user can select active weekdays, pause length, and a short override.
- Midday edits default to tomorrow; “Apply today” records today’s local date.
- Dismissal discards unsaved edits; all features remain free.
- State clearly that tracking is disconnected and the saved limit does not interrupt apps yet.
- Use shared design tokens and support light, dark, large text, and TalkBack.

## Review Focus

- Dismiss/back/drag must leave saved settings unchanged.
- Cap controls and numeric entry must enforce 1–500.
- Custom weekdays and legacy `Every day`/`Weekdays` preferences must load and save predictably.
- “Apply today” must save today’s local date; the default must save tomorrow’s date.
- Preview and permission copy must not imply monitoring is active.

## Tasks

### Task 1: Build the focused limit sheet — complete

**Files:** Create `lib/features/today/limit_settings_sheet.dart`; modify `lib/features/today/today_home_screen.dart`.

- Keep the approved hierarchy: cap, active days, pause, override, one-line preview, effective-date choice, permission note, Save.
- Add accessible cap editing, 1–500 validation, and custom weekday selection with all-days and weekdays presets.
- Return edited settings only from Save; dismissal returns null.

### Task 2: Persist and display settings from Today — complete

**Files:** Modify `lib/features/today/today_home_screen.dart`.

- Load the shared onboarding cap, migrate legacy active-day strings, and read/write weekday selection, pause, override, and effective local date.
- Keep the Today summary explicit that the saved limit is inactive until tracking exists.

### Task 3: Compile and review — complete

**Files:** `lib/features/today/limit_settings_sheet.dart`, `lib/features/today/today_home_screen.dart`, `context.md`, `progress.md`.

- Run Dart formatting, `flutter analyze`, and a debug APK build. Automated tests are outside this task’s authorized checks.
- Record the evidence and the disconnected-tracking limitation in project progress.

## Completion record

- `dart format lib/features/today/today_home_screen.dart lib/features/today/limit_settings_sheet.dart` — completed.
- `flutter analyze` — no issues found.
- `flutter build apk --debug` — succeeded.
- No automated tests or interactive device review were run. The saved config still needs to be consumed by the Android tracking bridge before a limit can affect supported apps.
