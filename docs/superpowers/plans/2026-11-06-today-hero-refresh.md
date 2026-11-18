# Today Hero Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorder Today into a BrainPal-inspired count-and-app hero while preserving Rook and Sync Scroll’s confidence and access disclosures.

**Architecture:** Keep the current Today route and lower status actions. Add one focused Rook widget that loads the existing local Rive state machine and falls back to the matching SVG; update `_TodayContent` to render a confirmed primary total, a separate estimate disclosure, and an app-count pill.

**Tech Stack:** Flutter/Dart, `rive` Flutter runtime, existing design tokens, local SVG and app-icon assets.

**Spec:** `docs/superpowers/specs/2026-11-06-today-hero-refresh-design.md`

## Global Constraints

- Preserve the current Rook box (196×184 dp) and its centered placement.
- Keep confirmed and estimated counts separate; estimates do not activate limits or change Rook’s state.
- Preserve exactly three bottom destinations and do not edit History or Settings.
- Use static SVG frames for reduced motion and failed Rive loading; stop Rive when the app backgrounds.
- Do not expose raw feed content or claim correction support where no correction data exists.

## Review Focus

- Zero confirmed with non-zero estimates must still show estimates separately from the primary zero.
- Unsupported or uninstalled selected apps must not appear as zero counts.
- Strained/Injured states require an effective active limit and verified coverage.
- Rive failure, reduced motion, and app backgrounding must leave a useful static Rook frame.
- The long access action must remain readable in the card at narrow widths and large text scale.

---

### Task 1: Rook runtime and state mapping

**Files:**
- Create: `lib/features/today/rook_mascot.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`, `lib/features/today/today_home_screen.dart`

**Interfaces:**
- Produces `RookState` and `RookMascot(state:, reducedMotion:)` for Today.
- Reads `assets/rook/rook.riv` state machine `Rook`, its five named boolean state inputs, and the corresponding static SVGs.

- [x] Add the current stable `rive` runtime and resolve package metadata.
- [x] Build the mascot component with Ready/Strained/Injured state selection, SVG fallback, reduced-motion handling, app lifecycle pause, and accessible labeling.
- [x] Compute Today’s Rook state only when a saved limit is effective for the current date and weekday, tracking coverage is verified, and the confirmed count crosses the PRD thresholds.

### Task 2: Today hero and below-hero details

**Files:**
- Modify: `lib/features/today/today_home_screen.dart`

- [x] Keep the current header and 196×184 Rook placement; show the confirmed total as a large metric with a clear label.
- [x] Show estimated totals separately and render one horizontally scrollable app/icon split that preserves unavailable support states.
- [x] Move tracking, limit, app coverage, last access check, and last detection below the hero; rename the access action to “Open access settings.”
- [x] Keep the layout theme-aware and responsive using existing tokens.

### Task 3: Project notes

**Files:**
- Modify: `context.md`, `progress.md`

- [x] Record the approved hero hierarchy and note that raw/adjusted totals await a correction data source.

No tests or device run are included in this task unless the user asks for verification.

Implementation note: `flutter pub get` resolved `rive 0.14.11`; `dart format` completed for the changed Dart files. Analyzer, build, and device verification were not run.
