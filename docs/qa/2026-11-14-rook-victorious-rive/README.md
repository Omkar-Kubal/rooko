# Victorious Rook asset check

Date: 2026-11-14

The user supplied a close face screenshot and directed Ready Rook as the base, without hands. The current pose preserves Ready's transparent brain silhouette, color, and folds while matching the screenshot's wide slanted sunglasses, subdued brow arcs, and small closed smile. It has no added hands, visible eye dots, pricing UI, or claims. `assets/rook/rook-victorious.svg` embeds `rook-victorious-ready-base.png`, whose interior is identical to Ready; only the empty four-pixel canvas edge was cleared. The SVG adds vector face details and has no background rectangle. `assets/rook/rook-victorious.riv` is a dedicated review asset that opens on the matching pose and briefly shows closed-eye lines inside the fixed lenses.

The Rive file is built by `tool/patch_rook_victorious_rive.mjs` from the verified shared binary because local export is account gated. It embeds the exact 1254×1254 transparent SVG render and the transparent eye overlay. The shared `rook.riv` is unchanged; the dedicated binary retains dormant legacy states and is not yet selected by Flutter. Source SHA-256: `6cdb023f9c949112c7478d11c0d21d97c3e70c2309fef52d21f977adf960635a`. Victorious Rive SHA-256: `6d19c931aefd02172390deac4ecf7a5e7111101bad59e7c7563ddaee8e5b62a2`.

| SRS ID | Acceptance behavior | Evidence | Result | Gap or follow-up |
| --- | --- | --- | --- | --- |
| FR-056 | Transparent Rive pose and matching static SVG | SVG XML has one embedded Ready-derived image and no background rectangle. Binary contains the exact rendered PNG. | Passed for this pose. | Other staged states and final set reconciliation remain open. |
| FR-057 | Eye-only animation | `flutter test --no-pub tool/qa/rook_victorious_rive_runtime_test.dart`: 148 changed pixels at 300×300 between open and blink, 0 outside the eye region. | Passed for asset motion. | Flutter selection and count routing remain later work. |
| FR-059 | Transparent reduced-motion frame | `flutter test --no-pub tool/qa/rook_victorious_ready_base_test.dart` and `flutter test --no-pub tool/qa/rook_victorious_svg_test.dart` passed; all four 1254×1254 PNG corners and Rive rendered corners have alpha 0. | Passed for assets. | Reduced-motion routing is not wired. |

The Windows Rive runtime test used a temporary release DLL copy under the workspace test lookup path; it was removed afterward. `flutter analyze --no-pub` reported no issues. No device or release claim is implied.


![Victorious Rook resting pose](victorious-open.png)

![Victorious Rook eye blink](victorious-blink.png)
