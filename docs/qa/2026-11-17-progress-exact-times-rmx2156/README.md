# Progress Day aligned time axis and exact count observations — RMX2156

| SRS | Check | Evidence | Result | Limit |
| --- | --- | --- | --- | --- |
| FR-035 | A 5pm count bar sits within the 5:00–5:59pm plot interval, before the 6pm axis mark | `progress-day.png`; plot/axis geometry widget assertion | Pass in AMOLED on RMX2156 / Android 12 | Physical Light and Dark appearances were not checked |
| FR-035 | The Day readout starts at the latest counted hour and names its full window | `progress-day.png`, UI hierarchy, widget test | Shows “5:00–5:59pm · 13 counted” on open | The saved 13 counts predate per-event timestamp storage |
| FR-035 | New counts expose exact accepted times with their original UTC offset; old or expired event times are not invented | Progress repository, Room migration, bridge parser, and widget tests | Pass: per-event seconds, seven-day expiry, legacy fallback, and count totals | No new live Reel or Short was created for this check; the device's older 13 counts correctly show that exact individual times are unavailable |

The full Flutter suite passed 136 tests after the final default-hour and copy refinements; the focused Progress suite passed 19. The full Android unit suite, including Room migration and timestamp retention, passed. Targeted Flutter analysis found no issues, and Dart formatting was checked. The debug APK built with non-incremental Kotlin/KSP settings and a workspace-local SQLite temp directory, then installed in place with data preserved. The device's Progress screen opened against the migrated Room v5 database. The screenshot does not establish feed-detector accuracy or physical TalkBack speech.
