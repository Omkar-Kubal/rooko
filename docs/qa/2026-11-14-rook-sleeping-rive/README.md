# Sleeping Rook asset check

Date: 2026-11-14

`assets/rook/rook-sleeping.riv` is a dedicated review file for the user-selected Sleeping pose: closed eyes, blush, small smile, foreground cloud, and tiny “z.” It opens on that pose with a transparent canvas. The only moving parts are the two closed eyelids, which briefly flatten and return. `tool/patch_rook_sleeping_rive.mjs` builds the file from the verified shared binary and embeds the exact `rook-sleeping-transparent.png` render plus a transparent eye overlay. The shared `rook.riv` is unchanged; Flutter still selects Ready.

| SRS ID | Acceptance behavior | Evidence | Result | Gap or follow-up |
| --- | --- | --- | --- | --- |
| FR-056 | Sleeping Rive pose matches its static SVG | The patch script embeds the SVG-derived transparent PNG; runtime open frame was visually compared with the selected artwork. | Passed for this pose. | Final state-set reconciliation remains open. |
| FR-057 | Visible eye-only motion | `flutter test --no-pub tool/qa/rook_sleeping_rive_runtime_test.dart`: 1,046 changed pixels at 300×300, zero outside the eye region. | Passed for asset motion. | Flutter state selection remains later work. |
| FR-059 | Transparent static frame | `flutter test --no-pub tool/qa/rook_sleeping_svg_test.dart` and the Rive runtime test: all rendered canvas corners have alpha 0. | Passed for assets. | Reduced-motion routing remains later work. |

The Rive runtime check ran on Windows with the local `rive_native` release DLL added to that test process's PATH. Source `rook.riv` SHA-256: `6cdb023f9c949112c7478d11c0d21d97c3e70c2309fef52d21f977adf960635a`. Sleeping `.riv` SHA-256: `796e754f5ac8795965594a1f6d8d99f13a197d766c6595f9fb99a5a8af257627`. No Android device or release check is claimed.

![Sleeping Rook resting pose](sleeping-open.png)

![Sleeping Rook eye motion](sleeping-blink.png)
