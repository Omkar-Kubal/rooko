---
name: sync-scroll-flutter-design-system
description: Use when building or changing Rooko Flutter screens, typography, colors, themes, CSS tokens, HugeIcons, mascot visuals, or motion; keeps UI consistent with the Sync design language and accessible across themes.
---

# Rooko Flutter design system

Use this skill for presentation work. Dart tokens are canonical for Flutter; `web/global.css` mirrors them for browser previews.

Global UI typeface: **Google Sans**, bundled from the Google Sans Project under the SIL Open Font License. Keep the OFL and trademark notice with the font files. Use `AppTypography`/`AppTheme` as the Flutter source and the matching CSS `@font-face` declarations and system fallbacks in `web/global.css`.

## Required reading

- Read `AGENTS.md` and the relevant parts of `docs/PRD.md` and `docs/SRS.md`.
- Inspect `lib/core/design_system/` and `web/global.css` before adding or changing a token.
- For Rook, read PRD section 1.2 and SRS section 3.6 before changing artwork, state, or motion.

## Workflow

1. Identify the screen, semantic roles, theme behavior, and accessibility needs.
2. Reuse `AppTypography`, `AppColors`, `AppSpacing`, `AppRadii`, and `AppTheme`. Add a shared token when a value has repeated meaning; avoid local look-alike constants.
3. Use `AppIcons` and `AppIcon` for every HugeIcons glyph. Use a semantic label for a standalone icon control; keep decorative icons out of the accessibility tree.
4. Keep layouts responsive, readable at large text sizes, and usable with TalkBack. Maintain sufficient contrast in light, dark, and AMOLED modes.
5. When changing a shared token, update `web/global.css` in the same change and compare the Dart and CSS value.
6. For motion, provide a static state with the same meaning when reduced motion is enabled. Do not let an animation delay a count, limit, or navigation action.

## Current shared scales

| Token group | Canonical roles and values |
|---|---|
| Type sizes | 12, 14, 16, 22, 28, 32, and 56 sp (`AppTypeScale`) |
| Type roles | page title, section title, card title, body, supporting, button, metric, chart label (`AppTypography`) |
| Spacing | 4, 8, 12, 16, 24, 32 dp (`AppSpacing`) |
| Radii | card 16 dp, sheet 24 dp, pill 999 dp (`AppRadii`) |
| UI colors | Light canvas/card `#FFFFFF`, Dark canvas `#080808` and card `#171717`, AMOLED canvas/card `#000000`; black/white primary text, Dark/AMOLED selected control fill `#303030` with white foreground, supporting text `#595959` / `#BDBDBD`, dividers `#D9D9D9` / `#404040` (`AppColors`) |

When a value changes, update this reference table if needed, the Dart token, and its CSS mirror together.

Keep the application UI black and white dominant across surfaces, text, controls, and progress. Use neutral gray for Dark/AMOLED selected control fills, supporting text, outlines, dividers, and disabled states. Only Rook art and supported-app logos retain color; status icons and text use monochrome roles.

## Rook and motion

- Rook is an original, minimal geometric brain in the Sync visual language. Do not reuse the reference app's character or Sync Focus's cat.
- The wired typed states are Ready (0–49), Strained (50–99), Injured (100–149), Queasy (150–199), Vomiting (200+), Recovering (Today-only after validated feed exit), Victorious (verified personal best in Progress), and Sleeping (Today-only when monitoring is unavailable). Every state has transparent SVG art and eye-only Rive motion. Ready through Queasy share `assets/rook/rook.riv`; the remaining states have dedicated Rive files. The floating counter uses static images for the five count poses.
- Keep expression game-like and neutral. Describe Rook's state, never the user's health or character.
- Respect the system reduced-motion setting and stop idle motion when the app is backgrounded.
- Keep motion brief and non-blocking; the SRS caps state transitions at 600 ms.

## Deliverable

Provide the changed screen or shared component, note the token roles it uses, include a11y labels and reduced-motion behavior where relevant, and list any Dart/CSS token pair that changed.
