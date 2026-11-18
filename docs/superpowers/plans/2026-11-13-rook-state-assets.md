# Rook State Assets Implementation Plan

**Current execution status:** The user directed staged work. Prior non-Ready state art is under the repository-root `archive/rook/`; Ready remains active. The Ready SVG and PNG fallback now have warm pink skin with the original shape and face. Rive and the other state artwork and wiring tasks below await later user-directed steps.

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task by task.

**Goal:** Replace the Rook artwork with eight transparent colored states, each available as an SVG frame and an eye-animated Rive state, then show count-stage art in Today and the floating counter.

**Architecture:** Keep one local `rook.riv` state machine and one SVG frame per state. The Flutter mascot selects a named Rive state or its SVG frame; the Kotlin floating counter uses the static count-band SVG because its native overlay already rasterizes SVG into a transparent bitmap.

**Tech Stack:** Flutter/Dart, Kotlin, SVG, Rive RML/CLI.

**Spec:** `docs/superpowers/specs/2026-11-13-rook-count-visual-redesign-design.md` (Phase 1).

## Global Constraints

- Keep the active asset paths `assets/rook/rook-ready.svg` and `assets/rook/rook.riv` stable.
- Use transparent backgrounds for all SVG frames and all Rive states.
- Animate eyes only; keep Rook's body and any pose details still.
- Daily count bands are 0–49 Ready, 50–99 Strained, 100–149 Injured, 150–199 Ashamed, and 200+ Overextended.
- Today uses Sleeping when required monitoring is unavailable; the floating counter remains hidden on permission loss.
- Preserve a rollback copy of the old Rive and archive legacy state artwork. Do not remove app-logo or launcher assets.
- Do not change the broader UI palette, limit controls, interruption flow, or screen layout in this phase.

## Review Focus

- Transparent edges: SVG and Rive output must have no canvas/background rectangle.
- Count boundaries: verify the displayed count-stage path at 49/50, 99/100, 149/150, and 199/200.
- Eye-only motion: verify no body, lobe, outline, mouth, or pose element changes during a blink.
- Permission loss: Today uses Sleeping and Android hides the floating counter as it does today.
- Reduced motion/load failure: every Rook state resolves to its matching SVG frame.

---

### Task 1: Create the static state artwork

**Files:**
- Modify: `assets/rook/rook-ready.svg`
- Modify: `assets/rook/rook-strained.svg`
- Modify: `assets/rook/rook-injured.svg`
- Modify: `assets/rook/rook-ashamed.svg`
- Create: `assets/rook/rook-overextended.svg`
- Modify: `assets/rook/rook-recovering.svg`
- Modify: `assets/rook/rook-victorious.svg`
- Create: `assets/rook/rook-sleeping.svg`

**Interfaces:**
- Produces eight transparent SVG frames using the same Rook silhouette and color treatment, with per-state eye/mouth expression. Ready is redrawn in color. Victorious uses the sunglasses/raised-hand pose without pricing copy; only its eyes animate.

- [ ] Author the shared brain silhouette, color fills, outline, folds, and eye geometry in the state SVGs.
- [ ] Make every SVG self-contained and transparent; keep the 200+ Overextended art pink and weary without aging, grayscale, medical damage, or a background.
- [ ] Review the eight frames together at the current Today and floating-counter sizes.

### Task 2: Build the transparent Rive state machine

**Files:**
- Modify: `assets/rook/scene.rml`
- Modify: `assets/rook/rook.riv`
- Modify: `assets/rook/rive.yaml` only if required by the artboard/state-machine build.

**Interfaces:**
- State machine name remains `Rook` and exposes the eight states: Ready, Strained, Injured, Ashamed, Overextended, Recovering, Victorious, and Sleeping.
- Each state has an eye-only looping blink. No background is authored on the artboard.

- [ ] Replace the embedded legacy state images with vector art matching the new SVG frames.
- [ ] Add the Overextended and Sleeping states and eye-only blink timelines for all eight states.
- [ ] Preserve the Ready default state and the `Rook` state-machine name used by Flutter.
- [ ] Run `rive assets/rook --once --format=json` and `rive inspect assets/rook --summary`; confirm zero errors/warnings and eight state animations.
- [ ] Render the eight Rive states to preview images and compare the open-eye frame to its corresponding SVG.

### Task 3: Wire state selection to Today and the floating counter

**Files:**
- Modify: `lib/features/today/rook_mascot.dart`
- Modify: `lib/features/today/today_home_screen.dart`
- Modify: `android/app/src/main/kotlin/com/appylab/syncscroll/FloatingCounterOverlay.kt`
- Modify: `pubspec.yaml`

**Interfaces:**
- `RookState` adds `overextended` and `sleeping`; each enum state resolves to its SVG frame and matching Rive machine state.
- Today uses the fixed daily count bands and selects `sleeping` when required monitoring is unavailable.
- The floating counter uses the same count bands to select one static SVG frame; it does not embed a second Rive runtime.

- [ ] Add the two new states to the typed Flutter enum, semantic label, SVG lookup, and Rive input mapping.
- [ ] Update Today state selection to use fixed count bands and Sleeping on unavailable tracking, without changing the screen layout.
- [ ] Update the Kotlin overlay to cache/render the matching static SVG for the current count band while preserving its existing badge, position, and permission behavior.
- [ ] Declare the new SVG assets in `pubspec.yaml`; remove active pubspec declarations for archived source cutouts.
- [ ] Review manual boundaries 49/50, 99/100, 149/150, and 199/200 in the Dart and Kotlin mappings.

### Task 4: Archive legacy artwork and align product guidance

**Files:**
- Create: `archive/rook/legacy-state-art/` (completed in the user's archive-first step)
- Modify: `AGENTS.md`
- Modify: `.agents/skills/sync-scroll-flutter-design-system/SKILL.md`
- Modify: `docs/PRD.md` Rook sections
- Modify: `docs/SRS.md` FR-056–FR-059
- Modify: `context.md`
- Modify: `progress.md`

**Interfaces:**
- The old state SVGs, transparent PNG cutouts, concept art, and a byte-for-byte backup of the prior `rook.riv` are preserved under the archive. Current app-logo, launcher, and brand-study assets remain in place.

- [x] Move legacy state sources and old Rive binary backup into the root archive before replacing or removing their active references.
- [ ] Update PRD/SRS to document the colored eight-state Rook and count bands, while leaving limit-feature requirements for the later product phase.
- [ ] Update AGENTS/context/skill wording so future work uses the new colored, transparent, eye-only state system.
- [ ] Record the asset build and visual review evidence in `progress.md`.

## Execution choice

Implement natively in the current workspace. The Rive state source, SVG frames, Flutter state enum, and Kotlin overlay selection share one asset interface and are simplest to keep synchronized in one pass.
