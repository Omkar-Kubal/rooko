# SDD ledger — plan: docs/superpowers/plans/2026-11-11-counts-access-history-settings-update.md

## Setup

- Workspace isolation is unavailable: this project directory has no `.git` metadata. Per the plan note, continue in the shared workspace and record evidence here; no commits or PR can be created.
- Plan interfaces checked: Today and History consume `countedCount` from the existing bridge models; Settings and Today share limit preferences through callbacks; onboarding selection draft persists through `_persistPage`.
- User-approved rule: render all saved counter events as one count, omit count-quality terminology in UI, and keep detector QA fields internal. The attached images are layout references only.

## Tasks

- Task 1: in progress — Today permission wall/banner, combined counts, and refresh behavior.
- Task 2: pending — Settings-only limit controls and onboarding cleanup.
- Task 3: pending — Week bars, Month heatmap, period totals, and empty states.
- Task 4: pending — Settings/privacy/debug/floating-counter copy and permission state refresh.
- Task 5: pending — source scan, verification, emulator captures, and progress record.
