# Aligned top navigation, RMX2156

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-038 | Today, Progress, and Settings titles align with 28 dp icon-only navigation; selected states and Back remain | Focused Today widget suite: 13 passed. RMX2156 Android 12 captures: [Today](today.png), [Progress](progress.png), [Settings](settings.png). UI tree title and icon centers share the same row. | Pass | TalkBack spoken output not checked on device. |
| FR-038 | 48 dp targets and narrow 200% text layout | Widget assertions at 320 dp and 200% text; targeted `flutter analyze` on four files: no issues. | Pass | Physical large-text device setting not checked. |

Built with `android/gradlew.bat assembleDebug '-Pkotlin.incremental=false'` using `JAVA_TOOL_OPTIONS=-Dorg.sqlite.tmpdir=D:\appylab\sync-rot\.tmp` to work around local Kotlin cross-drive incremental-cache and SQLite temp restrictions. `adb install -r` succeeded and preserved app data. The device's Accessibility service was off during capture, so Today shows Sleeping Rook and the existing permission banner. No live feed counting was tested.
