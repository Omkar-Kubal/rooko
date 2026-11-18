# Story sphere continuity — 2026-11-15

Target: RMX2156 (`X4GEAYDMWGAUI7WG`), Android 12/API 31. The final debug APK was installed with `adb install -r -d`, preserving onboarding data. The device was left on the recall result page. No Reels or Shorts feeds were opened.

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-002A | The completed projection sphere keeps revolving until Continue. | Widget test compares the same orbit controller before and after a settled wait; `projection.png` and `projection-later.png` show changed spiral orientation with the same count. | Passed | Continuous device video was unavailable. |
| FR-002A | Continue carries the same rotating sphere to recall. | Widget test checks one orbit controller and the sphere position through the stage change; `recall-settled.png` shows the final layout. | Passed | Frame timing is widget-tested. |
| FR-002A | On Continue, the sphere moves left, returns to center, scatters, and leaves result text on black. | Widget test checks both positions, delayed result text, zero dot opacity, and stopped idle animation. Final APK device frames: `final-memory-early.png`, `final-memory-middle.png`, `final-memory.png`. | Passed | TalkBack spoken output remains open. |
| FR-002A | Reduced motion and background pause. | Existing and updated story widget tests. | Passed | Device reduced-motion setting was not changed in this pass. |

Verification: 47 targeted onboarding tests passed; targeted Flutter analysis found no issues; Dart formatting was clean; `flutter build apk --debug --no-pub` succeeded with non-incremental Kotlin/KSP arguments; final `adb install -r -d` succeeded. The screenshots `memory-early.png`, `memory-middle.png`, and `memory-settled.png` were captured before the final delayed-text adjustment and are retained as comparison evidence. No design tokens or CSS values changed.
