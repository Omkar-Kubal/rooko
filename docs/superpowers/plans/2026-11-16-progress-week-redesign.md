# Progress Week Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the user-selected Week layout with one combined total, seven daily bars, and a conditional compact personal-best callout.

**Architecture:** Keep data loading and Month UI in `ProgressScreen`. Refactor only the Week rendering in `lib/features/progress/progress_screen.dart`, using existing `ProgressRange` records and design tokens. Retain existing Rook assets and day-verification logic.

**Tech Stack:** Flutter/Dart, Android device capture.

**Spec:** `docs/superpowers/specs/2026-11-16-progress-week-redesign.md`

## Global Constraints

- No per-app values, manual count changes, count-quality labels, limits, or sample data in production Progress.
- Missing days have no mark; stored zero days show `0`; Victorious appears only for a qualifying verified personal best.
- Month view and top navigation behavior remain functional.

## Review Focus

- A count of zero with a saved day record should be distinguishable from a missing date.
- Longer counts should fit seven columns at narrow widths and 200% text.
- A personal best must be scoped to the visible period and use approved Victorious art.
- Light and AMOLED bars should retain sufficient contrast.
- Returning from Week to Month must not duplicate the weekly total.

---

### Task 1: Build the Week overview

**Files:** `lib/features/progress/progress_screen.dart`, `test/features/progress/progress_screen_test.dart`

**Interfaces:** `_WeekChart(weekStart, range)` renders total and seven bars; `_WeekBar(date, day, maximum)` renders date, count, and optional bar.

- [ ] Update the existing focused Week test to assert one total, exact count labels, and no separate Week total card.
- [ ] Replace the Week card/grid with an open weekly total and seven-bar chart; use neutral bar intensity and maintain semantics.
- [ ] Show stored zero-day labels while leaving missing dates blank; preserve empty-week Rook behavior.
- [ ] Run focused Progress widget tests and targeted analyzer.

### Task 2: Place the personal best and preserve Month

**Files:** `lib/features/progress/progress_screen.dart`, `test/features/progress/progress_screen_test.dart`, `docs/PRD.md`, `docs/SRS.md`, `context.md`, `progress.md`

**Interfaces:** `_ProgressPersonalBest(day, compact: true)` for Week; existing card for Month.

- [ ] Place Week's compact Victorious callout after the chart and retain the Month card before its heatmap.
- [ ] Verify zero-count, missing-day, personal-best, and Month states with focused tests.
- [ ] Update product/context documentation; format and analyze changed Dart files.
- [ ] Build and install on RMX2156, inspect populated and empty weeks, and record screen evidence.
