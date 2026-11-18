# Dizzy Rook App Icon Implementation Plan

**Goal:** Use the user-selected Dizzy Rook art as the Rooko app icon across Android, onboarding branding, and the web preview/PWA.

**Architecture:** Keep the generated transparent concept as the source of truth. Derive surface-specific PNG sizes from its alpha-cropped artwork, update the shared app-logo image used by onboarding and Settings, and retain the existing Ready art for expression-led onboarding screens and runtime states.

**Tech Stack:** Flutter assets, Android PNG resources, web/PWA PNG icons, PowerShell/.NET for deterministic file handling, Pillow for alpha-cropped resizing.

**Spec:** `docs/PRD.md` §1.2 and §1.4; user direction dated 2026-11-18.

## Global Constraints

- The app remains Android-first; Flutter web remains a preview and tooling surface.
- Rook's eight runtime states and their state selection remain unchanged.
- Keep mascot art transparent; keep the UI palette unchanged.
- Preserve the previous provisional icon source under brand studies.

## Review Focus

- App identity changes in onboarding and Settings; Ready expression illustrations stay Ready.
- Android launcher masks and splash safe areas retain the existing fitted proportions.
- Web standard and maskable icon sizes and manifest paths remain unchanged.
- All updated source and generated icon assets retain transparent pixels outside the mark.

## Tasks

### Task 1: Update shared app branding

- [x] Back up the current `assets/rook/rook-app-logo-transparent.png` under `assets/rook/brand-studies/`.
- [x] Crop the transparent bounds from `assets/rook/rook-dizzy-concept.png`, scale it to the existing app-logo footprint, and write the result to `assets/rook/rook-app-logo-transparent.png`.
- [x] Keep `assets/rook/rook-app-mark.svg` pointed at the shared source; this updates Flutter app-logo use in onboarding and Settings.

### Task 2: Propagate platform icons

- [x] Regenerate Android `ic_launcher.png` density images and both native splash PNGs using their existing dimensions and visual fit.
- [x] Regenerate web favicon, standard icons, and maskable icons using their existing dimensions and safe-area fit.
- [x] Keep `web/manifest.json`, `web/index.html`, and Android resource references stable.

### Task 3: Record the decision and inspect outputs

- [x] Update PRD §1.4, root context, and progress to distinguish the app icon from Rook's runtime expression states.
- [x] Check PNG dimensions/alpha, SVG XML, asset paths, and manifest references. Do not change onboarding Ready illustrations or add a new runtime state.
