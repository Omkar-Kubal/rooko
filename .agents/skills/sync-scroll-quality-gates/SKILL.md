---
name: sync-scroll-quality-gates
description: Use when checking Rooko changes against the SRS, preparing Android or web-preview builds, gathering device evidence, or assessing a release milestone; ties claims to observable acceptance evidence.
---

# Rooko quality gates

Use this skill to decide what evidence a product change needs. A clean analyzer or build does not prove detector accuracy, permission recovery, privacy behavior, or a complete user flow.

## Required reading

- Read `AGENTS.md` and the PRD/SRS sections for the changed feature.
- Read related findings in `analysis/` when a requirement depends on reverse-engineering evidence.
- Check the target milestone and device/API assumptions before calling work release-ready.

## Workflow

1. Create an acceptance map with the changed behavior, SRS IDs, and evidence required by each criterion.
2. Choose checks that match the change: formatter and analyzer for Dart structure; platform builds for compilation; unit or widget tests for deterministic logic and UI states; emulator/device checks for Android permission, lifecycle, accessibility, overlay, sensor, and background behavior.
3. For detector changes, use fixtures and supported app/OS combinations to report confirmed, estimated, and uncovered cases. Include false-positive and false-negative outcomes; do not infer accuracy from a successful build.
4. For policy-sensitive behavior, check consent, decline, revoke, data retention, and the current Play declaration/disclosure requirements.
5. Record the exact command or device setup, target/version, result, and any unsupported state. Keep estimates and coverage gaps visible.
6. Recheck free access, privacy, large text, TalkBack, theme variants, and reduced motion when those areas are affected.
7. Separate verified results from unresolved gates. Do not label a milestone releasable while a required acceptance criterion lacks evidence.

## Evidence record

Use a compact table with these columns:

| SRS ID | Acceptance behavior | Evidence (command/device/version) | Result | Gap or follow-up |
|---|---|---|---|---|

Map each important product claim to evidence. If the result is not measured, label it as an assumption or open gate.

## Deliverable

Return the acceptance map, exact check results, unsupported combinations, unresolved release gates, and follow-up work. Preserve prior REA artifacts and add new evidence without overwriting source observations.
