# Onboarding particle motion — 2026-11-15

The root `onboarding.mp4` is the user-supplied pacing reference. It was inspected locally at two-second intervals; the source was not changed. The UI keeps Sync Scroll's monochrome palette and colored Ready Rook.

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-001 | Corner scatter gathers on Tap to continue and flows more strongly on Hi, Rook without resetting on an early tap | `rook-transition-rmx2156.mp4`; `rook-gathering-device.png`; `rook-revealed-device.png`; Rook flow widget tests | Passed on RMX2156 / Android 12 | Reduced-motion visual state covered by widget tests, not device accessibility settings |
| FR-002A | Question 8 answer drives exact day, 7-day, 30-day, and 365-day figures | Tests for 300, 400, 600, 800, and 1,000+; `story-transition-rmx2156.mp4` uses 400 → 2,800 → 12,000 → 146,000 | Passed | Values are illustrative self-reports, not detector counts |
| FR-002A | Staggered dots form a dense sphere, black handoff precedes recall, recall dots disperse, then dots morph into a human profile | `story-transition-rmx2156.mp4`; `projection-device.png`; `impact-device.png`; timing, fade, and background-pause widget tests | Passed on RMX2156 / Android 12 | TalkBack spoken output remains untested |

Final verification: `dart format --output=none --set-exit-if-changed` changed no files; targeted `flutter analyze --no-pub` found no issues; the three targeted onboarding test files passed 45 tests. The debug APK built with non-incremental Kotlin/KSP arguments and installed via `adb -s X4GEAYDMWGAUI7WG install -r -d`, preserving data. Two host-side `scrcpy` recordings capture the physical-device motion. No Instagram Reels or YouTube Shorts counting was tested.
