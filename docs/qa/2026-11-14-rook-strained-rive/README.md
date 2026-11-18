# Strained Rook Rive asset check

Date: 2026-11-14

The existing shared `assets/rook/rook.riv` now embeds the exact transparent Strained PNG from `assets/rook/rook-strained-transparent.png`. Its `isStrained` input selects the Strained blink state; Ready remains the default. The two Strained blink masks match the pink skin. The legacy `countPulse` track's two body-scale keyframes were set to 1.0, so firing it no longer enlarges Rook. `assets/rook/scene.rml` now describes the Ready and Strained states, although the binary still retains dormant legacy states pending the rest of the staged redesign.

| SRS ID | Acceptance behavior | Evidence | Result | Gap or follow-up |
| --- | --- | --- | --- | --- |
| FR-056 | Local Rive state with matching static SVG | Binary asset inspection confirms exact Ready and Strained PNG bytes; `rive . --verify` reports 0 errors and 0 warnings; `rook-strained.svg` exists. | Passed for Ready and Strained assets. | Remaining states are staged. |
| FR-057 | Eye-only Strained motion and state selection | Flutter Rive runtime test loaded `rook.riv`, set `isStrained=true`, captured open and blink frames, then set it false and captured Ready. The open/blink images differ at 5,649 pixels, with 0 changed pixels outside the eye region (`x=65..225`, `y=95..190`) at 300×300. A second runtime test fired the legacy `countPulse` trigger after neutralizing its body-scale keys and found 0 changed pixels outside the eye region. | Passed for this asset. | App count-trigger integration and transition timing remain for a later step. |
| FR-059 | Transparent art and static fallback | Rive open/blink and Ready-return frames have zero alpha at both inspected corners; matching transparent Strained SVG/PNG are present. | Asset ready. | Strained is not yet selected by Flutter, so reduced-motion routing is not exercised. |

`flutter build bundle --no-pub` succeeded; the bundled `.riv` SHA-256 matched the source asset. The Windows runtime test used the release Rive DLL temporarily in place of the debug DLL because this machine lacks debug C++ runtime dependencies. The original debug DLL was restored after the check.

![Strained Rook with eyes open](strained-open.png)

![Strained Rook blinking](strained-blink.png)

![Ready Rook after switching back](ready-return.png)
