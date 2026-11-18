# Rook count and visual redesign

**Status:** The user requested staged execution. Archive step 1 and the exact Ready SVG skin-color step are complete. Rive recoloring, other state artwork, app wiring, and wider product/UI changes are later steps.

## Intent

Create the new Rook state artwork first. Redraw and color Ready too, then build transparent SVG frames and eye-only Rive animation for all states. The count-stage art should follow the supplied progression, with Sleeping for unavailable tracking and the sunglasses pose retained as a mascot state without a pricing experience.

## Inputs and source classification

- **User-approved direction:** The monochrome UI should have stronger contrast and clearer surface separation, drawing on Sync Task/Spend; Rook is colored; official supported-app logos retain their brand colors.
- **User-approved scope change:** Defer user-set limits for now and use fixed daily count bands: 0, 50, 100, 150, and 200+. The user also approved removing limit-triggered interruptions and overrides for now.
- **User-approved asset direction:** All Rook states use transparent artwork and have eye-only animation. The user leaves one or multiple Rive files to implementation judgment.
- **User-approved exceptions:** Use the sleeping Rook only when tracking is unavailable. Do not add a pricing feature, but retain the Rook pose from the pricing reference as a mascot state.
- **Phase 1 execution boundary:** Create and archive Rook assets, update the Rive state machine, and wire existing Rook rendering to the new transparent state frames. Do not remove limit controls, redesign other screens, or implement the broader UI palette in this asset pass.
- **Reference images:** Mood and pose references only. New artwork must be original and must not trace the supplied images or another app's character.
- **Existing requirements to revise:** PRD 1.2–1.3, SRS FR-031, FR-038–055, FR-056–059, NFR-06, and matching `AGENTS.md`, context, and design-system skill language where these conflict with the approved direction.

## Phase 1 goals

- Redraw Ready in color and keep the active `rook-ready.svg` and `rook.riv` paths stable.
- Create separate transparent SVG frames for Ready, Strained, Injured, Ashamed, Overextended, Recovering, Victorious, and Sleeping.
- Add a transparent Rive state for every Rook state, each with eye-only animation; body and other artwork remain still.
- Preserve the existing reduced-motion path by selecting the matching SVG state frame.
- Archive prior non-Ready art, with a backup of the replaced Ready source and Rive binary for rollback. Keep launcher/app-logo assets outside the state-art archive.
- Reuse the sunglasses/hand pose as Victorious, without pricing UI or copy.

## Phase 1 non-goals

- Pricing, subscriptions, paid features, purchase flows, or a “Plus” screen.
- Redesigning the app-wide palette, controls, count labels, progress indicators, onboarding accents, or backgrounds.
- Removing limit controls or limit-driven interruptions in this phase; that product change is a later step.
- Changing detector behavior, app support claims, count-quality labels, or the Today app-attribution model.
- Replacing official supported-app logos or altering the app icon/launcher identity.

## Approaches considered

1. **Keep the six-state, limit-driven model.** Smallest implementation, but conflicts with the user's selected fixed daily bands and no-limit scope.
2. **Use fixed bands but keep only six total states.** Lower asset cost, but at least one of the five count stages, the unavailable sleep pose, or the victory pose would need to share artwork or lose a distinct trigger.
3. **Recommended: separate count stages from event/display states.** Use five count stages plus Recovering, Victorious, and Sleeping/unavailable. This matches all supplied visual roles and keeps the user's count progression separate from recovery, celebration, and permission status. It requires eight animated/static states and revised product requirements.

## Proposed behavior

### Daily count stages

Use five bands against the combined daily event count across selected apps:

| Daily total | Proposed Rook state |
|---|---|
| 0–49 | Ready |
| 50–99 | Strained |
| 100–149 | Injured |
| 150–199 | Ashamed |
| 200+ | Overextended (new state; name approved) |

The count bands are proposed as daily totals, not all-time totals. They do not create a second sequence or app-specific Rook state. Count labels remain neutral and generic; do not label the shared total “Reels.” Keep Rook the same base color in every band and communicate state through expression, not age, desaturation, medical-looking damage, or progressively harsher shading.

### Other Rook states

- **Recovering:** play a one-shot eye-only transition for up to 600 ms after the user leaves a supported feed, then return to the current count-band state.
- **Victorious:** show in History for a completed, verified day whose daily total is strictly lower than every earlier verified daily total. Adapt the supplied sunglasses/raised-hand pose to Rook's artwork. The pose has no pricing association and does not override the live Today/overlay count state.
- **Sleeping/unavailable:** show on Today only when required monitoring access is unavailable or no supported tracking is active. This is an availability state, not a seventh count band. The floating counter remains hidden on permission loss.

Precedence: unavailable overrides the Today Rook state; otherwise a brief Recovering transition follows feed exit; otherwise select the current count band. Victorious is reserved for a completed-day History result.

### Removing limits

Defer user-set limit controls, limit summaries, and limit-triggered interruption/override behavior from the current release. Remove them from Today and Settings for now; revise the PRD/SRS to mark them deferred pending a later user decision. Retain historical preference/database fields inert and migration-compatible; do not silently erase existing local values.

### Later visual-system step

- Adopt the sharper monochrome roles used by Sync Task/Spend: light canvas `#F2F2F7`, white surfaces, secondary `#E5E5EA`; dark canvas `#000000`, surfaces `#1C1C1E` / `#2C2C2E`, white-on-black controls, and contrast-safe grayscale text/outlines.
- Keep charts, progress, controls, count text, and Sync-owned icons grayscale. Keep Rook art and supported-app logos colored.
- Update Dart tokens, `AppTheme`, the foundation preview, and `web/global.css` together. Remove the existing onboarding text-color exceptions and colored semantic icon accents if they are still used.

### Assets and animation

- Use one locally bundled transparent `.riv` state machine with eight named states unless authoring tests show separate files are materially simpler. Every state animates Rook's eyes only; body, limbs, and other artwork remain still.
- Provide one transparent SVG static frame per state for reduced motion, low-power mode, and Rive load failure. SVG frames and Rive artboards have no background rectangle.
- Keep the active Ready SVG path `assets/rook/rook-ready.svg` and the active Rive path `assets/rook/rook.riv`. Redraw Ready in the new color treatment in the later artwork step. Preserve its old source and the old Rive binary under the repository-root `archive/rook/` before replacement.
- The user's first step moved existing non-Ready state SVGs and source artwork to the repository-root `archive/rook/legacy-state-art/`. The app displays Ready until replacements are introduced. Do not delete source art.
- Use the references for expression, color, and pose cues. Create original Rook artwork that remains consistent across states; do not trace or reuse the screenshot artwork.
- Preserve the existing mascot bounds and current Today/overlay layout unless the transparent art requires a narrowly scoped fit adjustment. No count or navigation action may wait for animation.

## Constraints

- Android remains the product platform; web remains a preview/tooling surface.
- All features remain free. No paywall, billing, purchases, advertising, or paid entitlement.
- The counter remains one combined daily sequence; Today may show app-attribution subtotals, while the floating counter shows only the combined total.
- Do not capture or persist feed content. Unsupported app versions continue to fail closed.
- Rook motion must respect reduced motion and stop when the app is backgrounded. State copy and semantics describe Rook, never the user's character or health.

## Phase 1 acceptance evidence

- Rive inspection confirms all eight transparent states and eye-only motion; the Rive artboard has no background shape.
- Each state has a matching transparent SVG frame with the same brain silhouette and expression, including Ready's new colored artwork.
- Rive preview confirms body, outline, and limbs do not move during eye blinks.
- `RookMascot` continues to render the SVG frame for reduced motion and Rive load failure, with no missing asset references.
- Old non-Ready assets and pre-redraw Ready/Rive source are present in the archive; active launcher/logo assets remain untouched.
- Today and the floating counter continue to use their current layout during this step. Fixed-band state selection and the broader no-limits change are later work.

## Implementation call

Use the new colored Ready drawing as the common silhouette and face baseline. Create original soft, expressive variants from it, keeping the supplied stage ordering. Animate eyes only and preserve each pose in a transparent SVG frame. The Rive artboard and SVGs use no background panel.
