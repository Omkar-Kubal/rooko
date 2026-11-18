# Full Progress naming — RMX2156, 2026-11-16

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-035, FR-038 | Progress names the screen, Flutter models and paths, bridge operation, Android repository and DAO, and current Room tables | Source search, `queryProgress` bridge test, generated Room schema `3.json` | Passed | Old names remain in versioned migration SQL and historical schema files |
| FR-033, FR-038, FR-055 | Existing v1/v2 rows, counts, coverage, and verification survive the database rename | `ProgressMigrationTest`: v1→v3 and v2 file→v3 with saved counts and verification; Android unit suite | Passed | Device had a zero-count current week, so nonzero live data preservation was proved by the synthetic migration test |
| FR-038 | Installed app opens Today and Progress after migration, with Back returning to Today | RMX2156 / Android 12; `today.png`, `progress.png`, `progress-final.xml`, `back-to-today.xml` | Passed | No live feed counting test |

`dart format --output=none --set-exit-if-changed lib test` reported zero changes. Targeted `flutter analyze --no-pub` found no issues. The full Flutter suite passed 125 tests. The Android `:app:testDebugUnitTest` suite passed 136 tests, with zero failures, errors, or skips; it used Android Studio JBR, non-incremental Kotlin/KSP, and `org.sqlite.tmpdir=D:/appylab/sync-rot/build/sqlite-temp`.

The final `flutter build apk --debug --no-pub --android-project-arg=kotlin.incremental=false --android-project-arg=ksp.incremental=false --android-project-arg=kotlin.compiler.execution.strategy=in-process` succeeded. `adb -s X4GEAYDMWGAUI7WG install -r -d build/app/outputs/flutter-apk/app-debug.apk` returned `Success`, preserving app data. Final APK SHA-256: `3A8A9B81D923DD468BC2878E2BE969F61B8932A722ADCF736BF246976DEF09A4`.

Before installation, the device had `sync_scroll_history.db`. After installation and launch it had both `sync_scroll_history.db` (retained backup) and the active `sync_scroll_progress.db`. Progress loaded its empty current week without a storage error. The device was left on Today. No Instagram Reels or YouTube Shorts were opened.
