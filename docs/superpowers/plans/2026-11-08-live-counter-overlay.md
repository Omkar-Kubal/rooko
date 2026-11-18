# Live Counter Overlay Implementation Plan

**Goal:** Show a truthful live per-app counter over recognized short-form viewers and verify it on RMX2156 before testing another device.

**Architecture:** Flutter Settings exposes an opt-in and actual overlay permission state through the existing tracking channel. Kotlin's Accessibility service manages one small application overlay and updates it from the existing local aggregate when a recognized feed is foreground. The debug estimate path remains separate from confirmed counting.

**Spec:** [Live counter overlay design](../specs/2026-11-08-live-counter-overlay-design.md)

## Tasks

- [x] Add persistent off-by-default bubble setting, actual overlay permission query, and Settings intent to the Android bridge; expose typed fields and methods in Flutter.
- [x] Add a Settings control with disclosure, separate setup action, pending-permission state, and a turn-off path.
- [x] Add a movable, dismissible Kotlin overlay with app name, daily count, and quality marker. Hide on feed/permission/service loss and unsupported versions.
- [x] Connect debug estimated and future confirmed count commits to the overlay without altering counting rules or limit eligibility.
- [x] Verify bridge/UI checks and Android build, install on RMX2156 without clearing data, then test recognized viewer, increment, stationary, Home/system exit, drag, dismiss, and permission state. Record outcomes and gaps in a QA ledger. RMX2156 build 22 preview and both live viewer sequences are recorded in [the QA ledger](../../qa/2026-11-08-live-counter-overlay-rmx2156.md); a three-device count-accuracy qualification remains a separate SRS gate.
- [x] Match the counter medallion to the reference composition while retaining original Ready Rook and using only monochrome global design tokens. Build 26 was installed in place on RMX2156 and the Settings preview was verified; live-view verification remains gated on Sync Scroll Accessibility being enabled by the user.
- [x] Smoke-check build 26 preview rendering and 10-second auto-hide on a Samsung SM-M325F running Android 13/API 33. The device had no apps selected; its YouTube version is unsupported, so live counting was not tested. Evidence is in the QA ledger.

## Gate

Overlay success means the visual count reflects the current local aggregate and lifecycle rules on RMX2156. It does not make Instagram or YouTube confirmed-supported. The existing SRS three-device accuracy corpus remains required before that claim.
