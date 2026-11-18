# Sync Scroll Project Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize a runnable Sync Scroll Flutter Android + web scaffold with project instructions, local skills, semantic design tokens, `global.css`, and a HugeIcons registry.

**Architecture:** Flutter owns the shared UI and design tokens. Kotlin/Android remains available for later native features, but this plan adds no detector or platform service. Dart semantic tokens drive Flutter at runtime; `web/global.css` mirrors the same token names and values for the web shell and browser tooling.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5, Material 3, `hugeicons ^4.4.0`, Google Sans Flex fonts from Sync Focus after license review, Android API 29 minimum, web platform support.

**Spec:** `docs/superpowers/specs/2026-11-04-sync-scroll-project-foundation-design.md`

## Global Constraints

- App identifier: Flutter project `sync_scroll`; Android namespace and application ID `com.appylab.syncscroll`, matching sibling Sync app namespace conventions.
- Product release target stays Android; Flutter web is included for token preview and the requested CSS surface only.
- Product scope and privacy rules come from `docs/PRD.md` and `docs/SRS.md`.
- Every feature is free; add no billing, purchase, entitlement, paywall, or advertising dependency.
- Do not overwrite the existing `analysis/` REA evidence or the existing PRD/SRS in `docs/`.
- Do not add Accessibility detection, counting, blocking, account, networking, database, challenge, or battle behavior in this foundation task.
- Dart design tokens are canonical; CSS custom properties mirror their names and values.
- HugeIcons are referenced through `AppIcons` and rendered through `AppIcon`; do not use raw glyph constants in app screens.
- There is no Git repository. Work in the current workspace and do not initialize Git as part of this plan.
- Do not add automated tests for this foundation task. Verify with formatter, analyzer, and debug builds.

## Review Focus

- **Existing evidence/specs in the non-empty root:** Flutter generation must leave `analysis/` and prior `docs/PRD.md` / `docs/SRS.md` unchanged. Check their existence and compare file hashes before and after generation.
- **Android package identity:** generated Kotlin paths and Gradle namespace/application ID must all be `com.appylab.syncscroll`; inspect the Android debug build output.
- **API floor:** Android `minSdk` must be 29 or greater and declared consistently. Inspect Gradle configuration and successful Android build.
- **Token drift:** Dart and CSS color, spacing, radius, and typography tokens must match by name/value. Manually compare the token tables in `AppColors`, `AppTypography`, CSS, and the design-system skill.
- **Icon accessibility and package drift:** the registry must compile against resolved HugeIcons 4.x glyph symbols; decorative use is excluded from semantics and icon-only use can receive a label. Confirm analyzer/build succeeds and inspect wrapper call sites.

---

## File Map

- `AGENTS.md` — repo-wide coding rules, spec authority, technology and privacy boundaries, skill routing.
- `.agents/skills/sync-scroll-product-contract/SKILL.md` — trigger and workflow for product-scope work.
- `.agents/skills/sync-scroll-flutter-design-system/SKILL.md` — typography, theme, CSS parity, and HugeIcons conventions.
- `.agents/skills/sync-scroll-android-accessibility/SKILL.md` — permission/disclosure and future detector implementation constraints.
- `.agents/skills/sync-scroll-quality-gates/SKILL.md` — build/analyzer/device evidence and SRS acceptance mapping.
- `README.md` — local setup commands, platform purpose, and directory pointers.
- `pubspec.yaml` / lockfile — app identity and Flutter dependencies.
- `android/**` — generated Android host with `com.appylab.syncscroll` ID and API 29 minimum.
- `web/index.html` — load web token CSS before Flutter bootstrap.
- `web/global.css` — CSS custom properties mirroring Dart tokens and reduced-motion defaults.
- `lib/main.dart` — Flutter entry point.
- `lib/app.dart` — Material 3 `MaterialApp` with light, dark, and AMOLED themes.
- `lib/core/design_system/app_colors.dart` — canonical color and spacing/radius tokens.
- `lib/core/design_system/app_typography.dart` — font scale and semantic type roles.
- `lib/core/design_system/app_theme.dart` — token-to-Material theme mapping.
- `lib/core/design_system/app_icons.dart` — HugeIcons glyph registry, icon size tokens, and accessible `AppIcon` wrapper.
- `lib/features/foundation/foundation_screen.dart` — small preview screen that demonstrates tokens and registry without mock tracker behavior.
- `assets/fonts/**` — licensed Google Sans Flex weights and license notice if reuse is confirmed.

## Tasks

### Task 1: Scaffold Flutter Android and web hosts

**Files:**
- Create: Flutter scaffold in project root (`pubspec.yaml`, `android/**`, `web/index.html`, `web/manifest.json`, `.gitignore`, etc.)
- Modify: `android/app/build.gradle.kts` and package source paths for `com.appylab.syncscroll`
- Preserve: `analysis/**`, `docs/PRD.md`, `docs/SRS.md`
- Create: `README.md`

**Interfaces:**
- Produces project name `sync_scroll`, Android package ID `com.appylab.syncscroll`, Flutter Android/web platform targets, and documented commands for later tasks.

- [x] Record SHA-256 for `docs/PRD.md` and `docs/SRS.md`; record that `analysis/` exists before generation.
- [x] Run `flutter create --project-name sync_scroll --org com.appylab --platforms 'android,web' .` from `D:\appylab\sync-rot`. PowerShell split an unquoted platform comma; quoting fixed the CLI argument.
- [x] Set Android namespace/application ID to `com.appylab.syncscroll`; set `minSdk` to 29 or greater in the generated Gradle file.
- [x] Replace generated README with setup instructions. State Android is the product target and web is for token preview/tooling.
- [x] Compare recorded hashes and `analysis/` existence; the hashes match and both evidence subdirectories remain.
- [x] Run `flutter pub get` and `flutter analyze` to confirm the generated baseline resolves.

**Expected result:** Flutter reports Android and web targets, dependencies resolve, analyzer passes, package identity is consistent, and existing research/spec documents are unchanged.

### Task 2: Add semantic colors, typography, themes, and CSS mirror

**Files:**
- Create: `lib/core/design_system/app_colors.dart`
- Create: `lib/core/design_system/app_typography.dart`
- Create: `lib/core/design_system/app_theme.dart`
- Create: `web/global.css`
- Modify: `web/index.html`
- Create: `assets/fonts/google_sans_flex_*.ttf` and `assets/fonts/OFL.txt` only if reuse license check passes
- Modify: `pubspec.yaml` font declarations and assets

**Interfaces:**
- `AppColors`: constants for light/dark canvas, ink, card surfaces, progress blue, success, warning, spacing, and radii.
- `AppTypography`: semantic styles `pageTitle`, `sectionTitle`, `cardTitle`, `body`, `supporting`, `button`, `metric`, and `chartLabel`.
- `AppTheme.light`, `AppTheme.dark`, `AppTheme.amoledBlack`: `ThemeData` values built from the same tokens.
- `web/global.css`: corresponding `--color-*`, `--space-*`, `--radius-*`, and font variables.

- [x] Check `D:\appylab\sync-focus\assets\fonts\OFL.txt`; copy the font weights and license notice only if the license clearly permits reuse. Otherwise use a system sans stack and omit bundled fonts.
- [x] Define shared scale values at 12, 14, 16, 22, 28, 32, and 56 sp; map the eight semantic roles to those sizes and appropriate line heights/weights.
- [x] Define the PRD palette: `#FFFFFF`, `#000000`, `#171717`, `#1C1C1E`, `#F2F2F7`, `#70A9F7`, `#248A3D`, `#C2410C`.
- [x] Build light, dark, and AMOLED Material 3 themes using these tokens, and add system font fallback.
- [x] Mirror names and values in `web/global.css`, including `prefers-reduced-motion` defaults and minimal global reset rules.
- [x] Add the CSS stylesheet link in `web/index.html` before Flutter bootstrap. Add comments identifying Dart as canonical and CSS as its mirror.
- [x] Run `dart format lib` and `flutter analyze`; manually compare Dart and CSS token names and values.

**Expected result:** Flutter surfaces and web CSS share matching semantic values, font fallback works, and light/dark/AMOLED theme objects analyze cleanly.

### Task 3: Add HugeIcons semantic registry and foundation preview

**Files:**
- Create: `lib/core/design_system/app_icons.dart`
- Create: `lib/features/foundation/foundation_screen.dart`
- Create: `lib/app.dart`
- Modify: `lib/main.dart`
- Modify: `pubspec.yaml` dependency `hugeicons: ^4.4.0`

**Interfaces:**
- `typedef AppIconData = List<List<dynamic>>`.
- `abstract final class AppIcons` maps semantic roles for navigation, history, battle, limits, settings, source app, insight, permission, warning, success, privacy, export, sync, NFC, steps, pause, and close to installed HugeIcons glyphs.
- `AppIcon` accepts `icon`, optional `semanticLabel`, `size`, `color`, and `strokeWidth`. It excludes decorative icons from semantics and exposes labels for meaningful icon-only controls.
- `Sync Scroll` `MaterialApp` selects `AppTheme.light`, `AppTheme.dark`, and `AppTheme.amoledBlack` based on a small local preview theme setting or system brightness.

- [x] Add `hugeicons: ^4.4.0`, then run `flutter pub get` to resolve exact glyph API.
- [x] Confirm every selected `HugeIcons.strokeRounded*` symbol exists in resolved package sources before adding it to the registry.
- [x] Implement `AppIcons` and the accessible `AppIcon` wrapper. Screens use only the registry.
- [x] Add a static foundation screen with one page title, body, 56 sp sample metric, token color surfaces, and a few registry icons. Do not label sample values as live counts.
- [x] Build `MaterialApp` in `app.dart`; update `main.dart` to call `runApp(const SyncScrollApp())`.
- [x] Run `dart format lib` and `flutter analyze`; inspect a decorative icon and an icon-only button call to confirm semantics behavior.

**Expected result:** App launches to a styled design-system preview; all glyph symbols resolve and no product feature is implied.

### Task 4: Add AGENTS.md and the four project skills

**Files:**
- Create: `AGENTS.md`
- Create: `.agents/skills/sync-scroll-product-contract/SKILL.md`
- Create: `.agents/skills/sync-scroll-flutter-design-system/SKILL.md`
- Create: `.agents/skills/sync-scroll-android-accessibility/SKILL.md`
- Create: `.agents/skills/sync-scroll-quality-gates/SKILL.md`

**Interfaces:**
- Root `AGENTS.md` links PRD/SRS as product authorities, describes the app layout, lists non-negotiable free/privacy rules, and routes relevant work to the corresponding local skill.
- Each skill has YAML frontmatter with `name` and concise `description`, then triggers, required reading, workflow, constraints, and outputs.

- [x] Write `AGENTS.md` with Flutter/Dart conventions, Android native code boundary, token source-of-truth, no paid gates, no Accessibility content logging, and a requirement to preserve REA evidence.
- [x] Write product-contract skill: read PRD/SRS, distinguish REA observations from new requirements, preserve final v2 scope and free access.
- [x] Write design-system skill: use `AppTypography`, `AppTheme`, `AppColors`, CSS mirror, and HugeIcons registry; do not inline raw values or glyphs.
- [x] Write Android-accessibility skill: require in-app disclosure and affirmative consent, use package-scoped handling, avoid raw text/media persistence, maintain confidence and coverage status, and refer to current Play policy.
- [x] Write quality-gates skill: map work to SRS IDs, use analyzer/build/device evidence appropriate to the change, and record unsupported detector versions and permission failures.
- [x] Manually inspect frontmatter and relative links; confirm all four skill directories and root `AGENTS.md` exist.

**Expected result:** Later agents can find the product rules and invoke a narrow, relevant local skill without changing the REA workflow.

### Task 5: Integrated build and setup handoff

**Files:**
- Modify: `README.md` if needed
- No new tests or feature implementation

**Interfaces:** Uses outputs from Tasks 1–4.

- [x] Run `dart format lib` and `flutter analyze`.
- [x] Run `flutter build apk --debug` and confirm Android manifest/package metadata identifies `com.appylab.syncscroll` with minimum API 29 or greater.
- [x] Run `flutter build web` and confirm `web/global.css` is loaded by `web/index.html`.
- [x] Check Dart/CSS parity for named palette, type scale, spacing, and radius tokens.
- [x] Check no billing/ad packages, no live detector implementation, and no product data claims in the foundation screen.
- [x] Summarize generated structure, chosen font fallback/assets, build results, and any unresolved font/license or Android template constraints in the final handoff.

**Expected result:** Android debug APK and web preview build successfully; project instructions, local skills, design tokens, and icon registry are ready for feature implementation.

## Execution Notes

- `flutter` 3.47.7 and Dart 3.13.5 are available on the machine.
- No Git metadata exists in this workspace. Do not include `git add`, commits, branches, or worktrees in execution.
- Existing PRD and SRS identify the final app scope; this plan only establishes the project foundation.
