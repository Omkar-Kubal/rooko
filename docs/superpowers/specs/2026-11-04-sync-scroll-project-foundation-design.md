# Sync Scroll Project Foundation Design

**Date:** 2026-11-04  
**Status:** Approved for implementation  
**Scope:** Flutter Android + web foundation; no feature implementation

## Intent

Prepare the existing `sync-rot` workspace for Sync Scroll development by adding project instructions and local agent skills, scaffolding Flutter for Android and web, and setting up the shared design layer: semantic typography and theme tokens, CSS custom properties in `web/global.css`, and a HugeIcons semantic registry.

The folder currently contains the REA findings under `analysis/` and product documents under `docs/`, but no Flutter project or Git repository. The existing Sync apps are Flutter projects. Sync Focus and Sync Task use semantic typography roles and `hugeicons`; Sync Focus also provides the closest current pattern for theme tokens and a concise icon registry.

## Goals

- Initialize a runnable Flutter project named `sync_scroll` with Android and web targets.
- Keep Android as the product release platform. The web target exists for browser previews and the requested CSS token file; it does not expand the product scope to web.
- Add a root `AGENTS.md` that points builders to the PRD/SRS and project skills, and preserves the free-feature, Sync visual, accessibility, and privacy requirements.
- Add four repo-local skills under `.agents/skills/`:
  - `sync-scroll-product-contract`: use the PRD/SRS and honor product constraints.
  - `sync-scroll-flutter-design-system`: use typography, theme, CSS, and icon tokens.
  - `sync-scroll-android-accessibility`: implement Android Accessibility and detection work within the consent, privacy, and detector accuracy rules.
  - `sync-scroll-quality-gates`: verify app behavior against the SRS acceptance criteria and update evidence.
- Create semantic type roles and scale consistent with the other Sync apps, a light/dark/AMOLED theme token layer, CSS custom properties in `web/global.css`, and an accessible HugeIcons registry/wrapper.
- Replace the generated Flutter counter sample with a small Sync Scroll foundation screen that demonstrates the theme, typography, and icon registry without pretending the tracker is implemented.

## Non-goals

- No reel detector, Accessibility service, counter, onboarding, blocking, database, networking, account, sync, challenge, battle, or billing implementation.
- No paid feature, paywall, advertising, or purchase dependency.
- No web product or promise of web parity.
- No icon-font substitution or direct HugeIcons calls scattered through screens; icons go through the semantic registry.

## Constraints and assumptions

- The user's “schemanic typography” means **semantic typography**.
- Use Android and web Flutter platforms. CSS custom properties are a parallel token surface for the web shell and browser tooling; Dart design tokens remain the runtime source for Flutter widgets. Token names and values must match across files and the setup guide must say how to maintain them together.
- Follow the established Sync palette: black/white foundations, restrained Sync Focus blue, semantic success/warning colors, rounded surfaces, and Google Sans Flex where the existing font assets and their license allow reuse.
- Use the newest HugeIcons release already demonstrated in a sibling project, currently `hugeicons ^4.4.0`, and verify chosen glyph symbols against the resolved package before building.
- Retain existing `analysis/` and `docs/` content. Flutter scaffolding must not overwrite the PRD, SRS, REA evidence, or attachments.
- There is no Git repository, so this setup will be made in the current workspace rather than in a worktree. Do not initialize Git unless asked.
- The prior SRS proposes Android 10 / API 29 as the minimum. Set the scaffold to that minimum if the generated Android template supports it cleanly; document any template constraint rather than silently lowering it.
- Follow the sibling Sync app namespace pattern with `com.appylab.syncscroll`; the package ID can be changed before initial store publication if the branding decision changes.

## Approaches considered

1. **Android + web Flutter scaffold with mirrored CSS variables — selected.** This meets the explicit request for `global.css` and gives a browser token surface while Android remains the shipping platform. It creates a small synchronization obligation between Dart and CSS tokens.
2. **Android-only Flutter scaffold with a reference CSS file.** Simpler platform output, but the CSS is unused by the generated web runtime and less useful for preview tooling.
3. **Separate web app and Flutter Android app.** This creates two application surfaces, duplicated presentation code, and extra maintenance without a product requirement for web. Not selected.

## Design decisions

### Project structure

Use Flutter's generated Android and web scaffolds, then organize the app foundation as:

```text
AGENTS.md
.agents/skills/
  sync-scroll-product-contract/SKILL.md
  sync-scroll-flutter-design-system/SKILL.md
  sync-scroll-android-accessibility/SKILL.md
  sync-scroll-quality-gates/SKILL.md
docs/
  PRD.md
  SRS.md
  superpowers/specs/2026-11-04-sync-scroll-project-foundation-design.md
  superpowers/plans/2026-11-04-sync-scroll-project-foundation.md
lib/
  main.dart
  app.dart
  core/design_system/
    app_colors.dart
    app_theme.dart
    app_typography.dart
    app_icons.dart
web/
  global.css
```

Add only the starter files needed to exercise the foundation. Use Flutter Material 3, following Sync Focus conventions. The foundation screen should use one sample heading, body style, metric style, a color surface, and a registry icon.

### Typography and theme tokens

- Semantic scale: 12, 14, 16, 22, 28, and 32 sp, plus a 56 sp metric style for the count display.
- Semantic roles: page title, section title, card title, body, supporting, button, metric, and chart label.
- Font family: Google Sans Flex with system fallback. Reuse the Sync Focus assets only after verifying their license file and compatible weights.
- Palette: light canvas `#FFFFFF`; dark canvas `#000000`; ink `#171717`; dark card `#1C1C1E`; light secondary surface `#F2F2F7`; progress blue `#70A9F7`; success `#248A3D`; warning `#C2410C`.
- Expose Flutter light, dark, and AMOLED `ThemeData` values. Build `web/global.css` with matching CSS custom properties, font stack, spacing and radius foundations, and a reduced-motion media query. Avoid duplicating unrelated component styling in CSS.
- Add short comments explaining that CSS and Dart values are paired tokens and name the canonical source for edits.

### HugeIcons registry

- Add `hugeicons ^4.4.0` and create a semantic registry of icon names used by the current foundation: home/today, history, battle, limits, settings, app/source, count/insight, navigation, permission, warning, success, privacy, export, sync, NFC, steps, pause, and close.
- Provide one small `AppIcon` wrapper that receives registry glyphs, inherits the active icon theme, excludes decorative icons from semantics, and accepts an explicit semantic label for icon-only controls.
- Do not add speculative aliases or use a glyph name before confirming it exists in the resolved package.

### Agent instructions and skills

- `AGENTS.md` names `docs/PRD.md` and `docs/SRS.md` as product authorities, explains the design system, keeps native Android code isolated, forbids monetization and sensitive content logging, and tells agents to use the local skills for matching work.
- Each local skill has frontmatter, clear trigger phrases, a short workflow, relevant files, and required outputs. Skills should reinforce project contracts without replacing the existing REA methodology in `analysis/`.

## Risks and mitigations

- **Token drift:** CSS/Dart tokens can diverge. Use matching names, a token table in the design-system skill, and a focused parity check during verification.
- **Font reuse:** asset licensing may not permit copying. Check the source license; if unclear, use a system sans fallback and document it.
- **HugeIcons version/glyph changes:** lock resolved package version and confirm each glyph in the analyzer/build.
- **Generated file collisions:** scaffold only into the current folder after reviewing Flutter's file actions; preserve existing analysis and docs.
- **Web target confusion:** AGENTS.md and README must state web is a token preview/tooling target, not a product launch commitment.

## What's left to the implementer

- Run Flutter project generation and dependency resolution without overwriting the existing research/spec files.
- Add `AGENTS.md`, the four project skills, the starter app, semantic design files, font assets when licensing checks pass, and web CSS tokens.
- Add concise setup documentation and apply the agreed Android minimum.
- Verify formatting, analyzer output, project generation, and Android/web debug builds. Confirm CSS/Dart token parity and all HugeIcons references. Do not claim detector functionality exists.
