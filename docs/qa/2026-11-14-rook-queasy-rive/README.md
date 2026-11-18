# Queasy Rook Rive asset check

Date: 2026-11-14

The shared `assets/rook/rook.riv` embeds the exact transparent 1254×1254 render of `rook-about-to-vomit.svg`. Its `isQueasy` state-machine input selects the user-directed fourth pose. The Rive blink changes only the eyes, using the pale closed-eye overlay shared with Injured. Flutter still selects Ready; count-based state selection and reduced-motion routing for Queasy remain later work.

The editable `assets/rook/scene.rml` describes Ready, Strained, Injured, and Queasy. Local `.riv` export is account gated, so `tool/patch_rook_queasy_rive.mjs` reproduces this binary from the archived, verified three-state asset. It temporarily uses a dormant legacy image slot for Queasy's art; a clean export can remove unused states when the staged set is complete.

| SRS ID | Acceptance behavior | Evidence | Result | Gap or follow-up |
| --- | --- | --- | --- | --- |
| FR-056 | Local Rive state with matching static SVG | Exact new PNG embedded once in the shared `.riv`; `rive assets/rook --verify --format=json`: 0 errors/warnings. | Passed for state 4 asset. | Remaining states are staged. |
| FR-057 | Eye-only animation and state selection | Flutter Rive runtime check set `isQueasy=true`, captured open and blink frames, then switched to Injured, Strained, and Ready. Open/blink changed 8,304 pixels at 300×300, with 0 outside the eye region. | Passed for asset behavior. | Flutter count routing remains later work. |
| FR-059 | Transparent art and static fallback | Rendered PNG is 1254×1254 with alpha 0 at all four corners; Rive open/blink frames also have transparent corners; matching SVG exists. | Asset passed. | App reduced-motion routing for Queasy is not yet wired. |

`flutter build bundle --no-pub` succeeded. Bundled and source `.riv` SHA-256: `6cdb023f9c949112c7478d11c0d21d97c3e70c2309fef52d21f977adf960635a`. `flutter analyze --no-pub` found no issues. The focused runtime check is `tool/qa/rook_injured_rive_runtime_test.dart`; on this Windows machine it temporarily substituted the release Rive DLL for the debug DLL, then restored the original. This is asset evidence, not an app-flow or release claim.

![Queasy Rook with eyes open](queasy-open.png)

![Queasy Rook blinking](queasy-blink.png)

![Injured Rook after switching back](injured-return.png)
