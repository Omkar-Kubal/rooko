# Injured Rook Rive asset check

Date: 2026-11-14

The shared `assets/rook/rook.riv` now embeds the exact `rook-injured-transparent.png` artwork and a transparent closed-eye overlay. The `isInjured` state-machine input selects state 3. Only its eyes animate; the face outline, expression, and body remain fixed. `assets/rook/scene.rml` describes the three approved states: Ready, Strained, and Injured. Flutter still selects Ready alone, so count-based state selection and reduced-motion routing for Injured remain later work.

The current Rive CLI verifies and previews local source but requires an account for local `.riv` export. `tool/patch_rook_injured_rive.mjs` therefore reproduces the runtime asset from the archived, verified Ready/Strained binary. The binary temporarily uses a dormant legacy image node behind the Injured eye overlay to preserve draw order; that legacy state is not selected in Flutter. A later clean export can remove dormant states.

| Check | Result |
| --- | --- |
| `rive assets/rook --verify --format=json` | 0 errors, 0 warnings |
| Rive runtime state changes | Ready → Injured → Strained → Ready rendered successfully |
| Injured open versus blink | 8,304 changed pixels at 300×300; 0 changed pixels outside the eye region |
| Transparency | Both inspected corner alpha values were 0 |
| Embedded image bytes | Exact current Injured PNG and eye-overlay PNG found once in `rook.riv` |
| `flutter build bundle --no-pub` | Passed; bundled `.riv` SHA-256 matched source |

The focused Flutter runtime check is `tool/qa/rook_injured_rive_runtime_test.dart`. It temporarily substituted the release Rive DLL for the debug DLL because this Windows machine lacks debug C++ dependencies. The original debug DLL was restored afterward and its hash matched the backup. `flutter analyze --no-pub` found no issues.

![Injured Rook, eyes open](injured-open.png)

![Injured Rook, eyes closed](injured-blink.png)

![Strained Rook after switching away](strained-return.png)

![Ready Rook after switching back](ready-return.png)
