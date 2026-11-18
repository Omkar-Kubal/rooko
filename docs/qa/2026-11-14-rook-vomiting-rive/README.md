# Vomiting Rook Rive asset check

Date: 2026-11-14

`assets/rook/rook-vomiting.riv` opens on the muted-green fifth pose and loops an eye-only blink. Its full artwork is the exact transparent 1254×1254 PNG rendered from `rook-vomiting.svg`; the two eyelid fills match the new skin tint. This is a dedicated review asset. The shared `rook.riv`, Flutter state selection, and count routing remain unchanged. The dedicated binary still contains dormant earlier states inherited from the shared base; a clean export can remove them when the full set is assembled.

`tool/patch_rook_vomiting_rive.mjs` reproducibly builds the dedicated binary from the verified shared file because local Rive export is account gated. Source `rook.riv` SHA-256: `6cdb023f9c949112c7478d11c0d21d97c3e70c2309fef52d21f977adf960635a`. Dedicated `rook-vomiting.riv` SHA-256: `0265adabbaf0597ea0fb34b8267170a0a1499d2cefecd33eb0a1532b4ecf4cc8`.

| SRS ID | Acceptance behavior | Evidence | Result | Gap or follow-up |
| --- | --- | --- | --- | --- |
| FR-056 | Local Rive pose with matching SVG | Embedded PNG bytes match `rook-vomiting-transparent.png`; static `rook-vomiting.svg` exists. | Passed for this asset. | Full staged state set remains open. |
| FR-057 | Eye-only motion | `flutter test --no-pub tool/qa/rook_vomiting_rive_runtime_test.dart`: 5,787 changed pixels at 300×300 between open and blink, 0 outside the eyes. | Passed for this dedicated pose. | Flutter count/state routing remains later work. |
| FR-059 | Transparent art and static fallback | All four rendered corners have alpha 0 in open and blink frames; matching SVG remains transparent. | Asset passed. | Reduced-motion routing is not yet wired. |

The Windows Flutter test used a temporary copy of the release Rive DLL under the workspace test lookup path; the copy and its empty directories were removed after the test. `flutter analyze --no-pub` reported no issues. This is asset evidence, not a device or release check.

![Vomiting Rook resting pose](vomiting-open.png)

![Vomiting Rook eye blink](vomiting-blink.png)
