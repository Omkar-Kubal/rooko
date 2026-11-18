# Live counter overlay design

## Decision and scope

The user directed Sync Scroll to build a visible counter before testing another device. This advances the optional M2 bubble for a device pilot. BrainPal and BrainRotty show floating counters, but this design uses Sync Scroll's own typography, grayscale palette, data contract, and permission flow.

The overlay is a compact movable counter on a recognized selected Reels or Shorts viewer. Its visual reference is a small circular mascot medallion with the daily count and quality marker (`Confirmed` or `Est.`) in a badge beneath it. The app name is included in the accessibility description. It never turns an estimate into a confirmed count or activates a limit. The counter can be dismissed, which turns the feature off. It does not cover system navigation by default.

The user asked for Rook to appear as the counter illustration because the text-only counter read as a box. Use the existing transparent Ready frame, `assets/rook/rook-ready-transparent.png`, centered in an 80 dp circle with a 64 dp image and a 48 dp close target. Keep the count and quality marker in a 36 dp badge beneath it. The user's attached images guide this arrangement only; keep Rook's original artwork and follow the app's global monochrome palette. The native colors mirror `AppColors` and the corresponding `web/global.css` properties: `surface-dark` `#1C1C1E`, `outline-dark` `#48484A`, `surface-light` `#FFFFFF`, `outline-light` `#D8DADD`, `ink` `#171717`, `text-secondary-light` `#6B6B70`, `surface-dark-secondary` `#2C2C2E`, and `text-on-dark` `#FFFFFF`. This is a static Ready illustration only; the counter does not infer or animate Rook's game state.

## Permission and coverage

- Off by default. A Settings control explains the overlay and enables it separately from Accessibility and the debug text-key consent.
- Enabling opens Android's “Display over other apps” settings. Returning to Sync Scroll checks `Settings.canDrawOverlays`; opening Settings alone never implies permission.
- The Kotlin Accessibility service owns the Android window. It shows only while the foreground root is an exact-version recognized feed with a selected profile and consent. It hides on feed exit, foreign/system windows, access loss, consent loss, unsupported versions, service interruption, and service destruction.
- In debug builds, the already approved text-key research profile may supply an `Est.` value. Release builds exclude that path. If no profile produces a count, no pill appears. Historical debug aggregates remain labeled test data.
- The window contains only app name, local aggregate, and confidence. It never reads or stores additional feed text, images, audio, video, or screenshots.

## Acceptance

On RMX2156/API 31, verify separate opt-in and overlay permission, appearance only on a recognized Instagram Reels or YouTube Shorts viewer, count refresh after an eligible debug estimate, no stationary repeat, hiding on Home/system screens and when consent/permission is removed, drag, dismiss, and no limit activation from estimates. This is an overlay pilot under FR-007 and FR-050–051, not an app-version accuracy qualification under FR-010–020.
