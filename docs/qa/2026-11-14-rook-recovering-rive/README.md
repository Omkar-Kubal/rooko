# Recovering Rook asset check

Date: 2026-11-14

`assets/rook/rook-recovering.riv` is a dedicated review asset for the transparent Recovering pose. It opens on the matching SVG render: State 2's half-lidded eyes with a small calm smile and faint under-eye lines. The eyelids briefly close and reopen; the mouth, silhouette, and other details stay still. `tool/patch_rook_recovering_rive.mjs` reproduces it from the verified shared Rive binary. The shared `rook.riv` is unchanged and Flutter still selects Ready.

| SRS ID | Acceptance behavior | Evidence | Result | Gap or follow-up |
| --- | --- | --- | --- | --- |
| FR-056 | Transparent Rive pose and matching static SVG | Runtime open frame visually matches `rook-recovering.svg`; the binary embeds the exact 1254×1254 SVG render. | Passed for this pose. | Final state-set reconciliation remains open. |
| FR-057 | Visible eye-only motion | `flutter test --no-pub tool/qa/rook_recovering_rive_runtime_test.dart`: 5,588 changed pixels at 300×300, zero outside the eye region. | Passed for asset motion. | Flutter state selection and count routing remain later work. |
| FR-059 | Transparent static frame | `flutter test --no-pub tool/qa/rook_recovering_svg_test.dart` and the Rive runtime test: rendered corners have alpha 0. | Passed for assets. | Reduced-motion routing remains later work. |

The Rive runtime check ran on Windows with the local `rive_native` release DLL added to that test process's PATH. Shared `rook.riv` SHA-256: `6cdb023f9c949112c7478d11c0d21d97c3e70c2309fef52d21f977adf960635a`. Recovering `.riv` SHA-256: `aec0e04268ac843292202b9dd6136708e157a410184a0a5f07c3c57c060fa572`. No Android device or release check is claimed.

![Recovering Rook resting pose](recovering-open.png)

![Recovering Rook eye blink](recovering-blink.png)
