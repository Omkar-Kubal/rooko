# Today count note removal, RMX2156

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-031, FR-058 | Today shows the combined count and Rook without the estimated-count disclaimer | Focused Today widget suite: 13 passed, including an eligible estimated path with no note. Targeted Flutter analysis and formatting: clean. [RMX2156 screenshot](today.png) after an in-place debug install. | Pass | The device's Accessibility service was off, so the capture shows Sleeping Rook and a permission banner. Live feed counting was not tested. |

The Android debug build succeeded using `android/gradlew.bat assembleDebug '-Pkotlin.incremental=false'` with `JAVA_TOOL_OPTIONS=-Dorg.sqlite.tmpdir=D:\appylab\sync-rot\.tmp`. `adb install -r` preserved app data. The optional floating-counter explanation in Settings was outside this Today change.
