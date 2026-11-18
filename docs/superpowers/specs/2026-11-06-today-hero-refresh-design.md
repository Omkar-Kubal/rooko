# Today Hero Refresh Design

## Intent

Make Today’s first view scan like the supplied BrainPal example: Rook, one large daily metric, its label, and a compact per-app split. Keep Rook at its current size and placement. Move access status, limit controls, app coverage, and timestamps below the hero.

## Goals

- Use confirmed events as the primary count and display estimates separately.
- Keep app identities colored and the rest of the interface monochrome.
- Use the existing `assets/rook/rook.riv` state machine on Today, with matching SVG frames when reduced motion is enabled or Rive cannot render.
- Select Ready, Strained, or Injured only when a saved limit is active and coverage is verified; estimates never change Rook’s limit state.
- Give the access action an unambiguous label and show detection freshness in the lower details.

## Non-goals

- Do not change History, Settings, bottom navigation, Rook artwork, or Rook’s size/placement.
- Do not copy BrainPal branding, mascot, account prompts, paid offer, or navigation.
- Do not add trends to Today.
- Do not fabricate correction values. The current tracking snapshot has no correction/adjustment fields or correction store; raw/adjusted detail requires that data contract and remains open.

## Selected approach

Reorder and restyle the existing Today screen. Keep its header and Rook dimensions, replace the count headline with the large confirmed metric, use one horizontally scrollable app-count pill, then place access, limit, app-coverage, and freshness information below. A separate new screen or chart is unnecessary for this request.

## Constraints

- Reuse `AppTypography`, `AppColors`, `AppSpacing`, `AppRadii`, and approved app icons.
- Preserve honest confirmed, estimated, unsupported, and unavailable states.
- Follow PRD UX-05 and SRS FR-031, FR-056–FR-059 where current data supports them.
- Use the Rive `Rook` state machine bool inputs and static SVG fallback; pause motion when the app is backgrounded and honor `MediaQuery.disableAnimations`.
