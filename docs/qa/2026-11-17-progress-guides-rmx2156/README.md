# Progress chart guides and borderless UI — RMX2156

| SRS | Check | Evidence | Result | Limit |
| --- | --- | --- | --- | --- |
| FR-035 | Selecting an hour updates the vertical marker, dotted count guide, and readout | `day-selected-hour-amoled.png`, RMX2156 / Android 12, 2026-11-17; `progress_screen_test.dart` tap, drag, and accessibility-adjustment cases | The device displayed “5pm · 13 counted” with both guides at the selected hour and count | Physical TalkBack speech was not checked |
| FR-035 | Progress cards, Day/Week control, and separators have no visible strokes | `day-amoled.png`, `day-selected-hour-amoled.png`, `week-amoled.png`; widget border assertions | Borderless in the AMOLED device captures | Light and Dark physical appearances were not checked |
| FR-035 | Recorded hourly counts remain visible as chart bars | `day-selected-hour-amoled.png`; widget bar-height assertions | The selected nonzero hour displays its bar at the chart height for 13 counted items | No live Reels or Shorts feed was opened in this check |

The focused Progress widget suite passed 17 tests after the chart refinements, and targeted Flutter analysis reported no issues. An Android debug APK was built with one Gradle worker and Kotlin incremental compilation disabled, then installed in place on RMX2156. The full Flutter suite passed 134 tests before the final chart rendering refinements; its later focused suite passed, but the full suite was not rerun afterward. These captures show saved local counts and do not establish feed-detector accuracy.
