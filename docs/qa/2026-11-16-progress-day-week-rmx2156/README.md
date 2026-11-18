# Progress Day/Week switch — RMX2156, 2026-11-16

Device: RMX2156 / Android 12 (API 31), serial `X4GEAYDMWGAUI7WG`. The debug APK was installed in place with `adb install -r`; app data and permissions were retained. No Instagram or YouTube feed was opened.

| SRS ID | Acceptance behavior | Evidence | Result | Gap or follow-up |
| --- | --- | --- | --- | --- |
| FR-035 | Day appears on the left and opens first; Week appears on the right; Month is absent | `day.png`, `week.png` | Pass on device in System/Dark | Light and AMOLED were covered by existing shared theme tests; this revised selector was not captured in those modes |
| FR-035 | Day shows the selected date's combined saved count; an adjacent date without a record uses Rook's empty state | `day.png` (Nov 16), `day-empty.png` (Nov 15) | Pass on device | The device has no saved zero-count date to inspect |
| FR-035 | Week retains its seven-bar chart after moving right | `week.png` | Pass on device | Only one date in the visible week has a saved count |
| FR-035 | Day and Week navigate by one and seven dates; saved zero, personal-best scope, and stale query responses are correct | `flutter test test/features/progress/progress_screen_test.dart` (14 passed) | Pass in widget fixtures | No qualifying verified personal-best day exists on this device; Victorious remains widget-tested only |
| FR-035 | Narrow, 200% text layout remains overflow-free | Progress widget test at 320 dp with seven four-digit Week values | Pass in widget fixture | Physical large-text and TalkBack spoken output were not measured |

Checks: `flutter test --reporter compact` passed 131 tests; targeted `dart analyze` found no issues in the changed Progress files. Full `flutter analyze` reported only three existing deprecated Rive boolean-input notices in `rook_mascot.dart`. Android `gradlew.bat assembleDebug '-Pkotlin.incremental=false'` succeeded with Android Studio JBR and `JAVA_TOOL_OPTIONS=-Dorg.sqlite.tmpdir=D:\appylab\sync-rot\.tmp`. No shared design tokens changed.
