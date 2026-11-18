# Onboarding, History, and Settings implementation review

**Review date:** 2026-11-11  
**Device:** RMX2156, Android 12 / API 31  
**Installed build:** debug, version 1.0.0 (version code 33)  
**Scope:** user-approved onboarding, Today, History, Settings, Room migration/corrections, and Flutter/native integration.

## Review outcome

An independent source review found six integration defects. They were reproduced with regression tests, fixed, and passed in the fresh Flutter suite:

1. Today now displays adjusted confirmed totals from Room, including History corrections.
2. Today refreshes its snapshot when returning to the tab.
3. Settings re-reads actual Android permission state on every app resume.
4. Floating-counter opt-in persists when overlay permission was already granted.
5. History navigation uses calendar-date arithmetic across DST boundaries.
6. Onboarding saves app/limit drafts when leaving app selection; the limit dialog owns and disposes its text controller.

No unresolved code-review findings remain for the approved UI/data pass. This does not establish release readiness; device and product gates below remain open.

A follow-up 200% text-scale pass found a History chart layout overflow in the selected-day view. The chart now lets its bars grow with scaled labels, and the coverage badge and legend wrap. A regression test reproduced the selected-day layout at 200% text scale and passes after the fix.

## Acceptance evidence

| SRS ID | Acceptance behavior | Evidence | Result and remaining gap |
| --- | --- | --- | --- |
| FR-001, FR-003, FR-007 | Four labeled onboarding stages; affirmative Accessibility disclosure; optional separate overlay setup; actual state rechecked on return; skip/decline routes remain usable | Fresh `flutter test`: 49 passed. Dedicated Android 16/API 36 x86_64 AVDs exercised Accessibility consent → Android Settings grant → verified return; decline → Off; optional counter skip → usable Today; overlay denial and grant through Android Settings; external Accessibility/overlay revocation → Settings showed the current state on resume. | Grant, decline, skip, denial, grant, verified return, and revocation recovery were observed on device. |
| FR-030, FR-032, FR-033 | Room aggregates; app-attributed correction rows; transactional zero-boundary validation; append-only undo | Android `:app:testDebugUnitTest`: 95 passed. Relevant suites include `HistoryRepositoryTest` (7), `LegacyHistoryImporterTest` (3), `LocalCountStoreTest` (4), and `RoomCountStoreTest` (1). Flutter suite covers bridge mapping and correction UI. | Unit coverage passes. Add an interrupted-import rollback/retry test and concurrent provider-startup/write test before treating migration concurrency as fully proven. |
| FR-031 | Today shows corrected confirmed totals and still separates estimates and coverage | Platform snapshot regression test, Today refresh regression tests, Today widget tests, and RMX2156 UI review | Passed. Today has no permission/debug-consent CTA; status and coverage remain visible. |
| FR-034 | Preserve event timezone/offset without silently reassigning dates | Room data model and history tests; legacy rows remain without invented timezone metadata | Partial. Multi-event date records with differing offsets and travel/DST persistence are not fully demonstrated; retain as an open requirement gate. |
| FR-035 | Seven-day real totals, selected-day per-app counts, separate estimates, coverage/correction markers, no fabricated data | Fresh Flutter suite (49 passed), History calendar/widget coverage, selected-day 200% text-scale regression test, and RMX2156 History review | Passed for displayed behavior. Empty history showed no sample counts and unknown coverage. Ninety-day query latency was not measured. |
| FR-038 | Three persistent destinations: Today, History, Settings | Flutter navigation/widget coverage and RMX2156 screen review | Passed. |
| FR-050, FR-051 | Floating-counter opt-in is separate; preference and overlay grant are distinct; actual overlay state is reported | Settings/onboarding widget tests; Android 16 AVD grant, denial, skip, and revocation flows | Opt-in, grant, denial, skip, and actual-state recovery were observed. Full live hide/occlusion matrix was not repeated in this review. |
| NFR-06 | Light, dark, AMOLED; large text, TalkBack, reduced motion, target sizing, contrast | RMX2156 light/dark/AMOLED visual review; dedicated Android 16 AVD at 200% font scale, build 4033; selected-day overflow regression test | Themes passed visual review. At 200%, Today, Settings, and History week and selected-day views opened and scrolled without overflow. TalkBack focus navigation reached Settings controls, but spoken announcements could not be captured; an Android Accessibility Suite notification prompt was denied, and notification access was not granted. The AVD was restored to font scale `1.0`, TalkBack off, floating-counter preference off, and overlay denied, then shut down. Reduced motion and the manual 48 dp target/contrast audit remain open. |
| NFR-03 | Cold-open to cached Today under 2 seconds; 90-day History query under 500 ms | RMX2156 / API 31: code 31 cold launches 8.63 s and 5.46 s; code 32 cold launches 7.10 s and 4.41 s (`adb shell am start -W`). Code 33 was installed, but startup timing was not repeated. | Prior debug observations exceed the two-second target; they are not a midrange-device benchmark. Ninety-day query performance remains unmeasured. |

## Build and static checks

- Fresh verification on 2026-11-11 after the large-text fix: `flutter test` — 49 passed; `flutter analyze --no-pub` — zero errors/warnings and five existing Rive boolean-input deprecation info notices; `dart format --output=none --set-exit-if-changed lib test` — 28 files checked, zero changes.
- Android Studio JBR at `C:\Program Files\Android\Android Studio\jbr`; `:app:testDebugUnitTest :app:assembleDebug --no-daemon -Pkotlin.incremental=false` — succeeded. Parsed JUnit XML: 95 tests, 0 failures, 0 errors, 0 skipped. The build emits existing Gradle/Kotlin deprecation notices.
- Fresh Flutter wrapper build `flutter build apk --debug --no-pub --build-number=33 --android-project-arg=kotlin.incremental=false` — succeeded with `JAVA_TOOL_OPTIONS=-Dorg.sqlite.tmpdir=D:/appylab/sync-rot/build/sqlite-tmp`; artifact: `build/app/outputs/flutter-apk/app-debug.apk`.
- The initial wrapper attempt exposed this machine's Room verifier temp-directory constraint (`C:\Windows\Temp` rejected as non-writable/non-executable). A subsequent run also met stale KSP symbol-cache state; restarting Gradle and using the writable per-run temp path resolved both without changing project build configuration.
- The code 33 APK was installed with `adb install -r` and launched on RMX2156, preserving app data. Android reports version 1.0.0 / code 33 and font scale `1.0`. Permission settings were not changed on the phone.
- Dedicated Android 16/API 36 x86_64 AVDs (`sync-scroll-qa-20261111`, `sync-scroll-skip-qa-20261111`) were used for system permission checks. Accessibility consent/grant/verified return, decline, optional overlay skip, overlay denial/grant, and Settings refresh after external revocation were observed.
- At 200% font scale, Today, Settings, and History week and selected-day views were inspectable and scrollable on AVD build 4033. The selected-day overflow regression test also passes in Flutter. The AVD was restored without clearing data: font scale `1.0`, TalkBack off, floating-counter preference off, overlay denied; it was then shut down.

## Open acceptance and release gates

- Complete a reliable TalkBack spoken-output review, reduced-motion review, 48 dp target audit, and applicable contrast audit.
- Investigate and improve NFR-03 startup latency; measure 90-day History queries against their target.
- Add interrupted Room import rollback/retry and concurrent provider-startup/write tests.
- Demonstrate FR-034 timezone/offset preservation across travel, DST, and records with different offsets.
- Keep export (FR-036), deletion (FR-037), and Help & diagnostics visibly unavailable; their product requirements remain open.
- No detector profile is established as release-confirmed. Accuracy corpus, stationary/non-feed checks, app/version matrix, complete-coverage scoring, and current Play declaration/disclosure review remain release gates.

## Workspace notes

This workspace has no `.git` metadata, so a Git diff, commit, and pull request are unavailable. Temporary review captures, UI hierarchy XML, and `print_tz.dart` remain under `build/qa`; the command safety layer rejected the cleanup commands as blocked by policy. The per-run Room temp directory also remains under `build/sqlite-tmp`.

## Follow-up: one-count and Week/Month UI revision — 2026-11-12

This user-directed revision supersedes the earlier review's count-quality presentation and editable History UI. The older build 33 captures and acceptance notes above remain historical implementation evidence; they do not describe the current screen requirements.

| SRS ID | Current acceptance behavior | Evidence | Result |
| --- | --- | --- | --- |
| FR-004 | Missing Accessibility access opens a wall on Today; Allow navigates to the in-app Settings tab; X collapses it into a banner while Today remains usable | Build 35 on isolated Android 16/API 36 AVD; screenshots 24–26; accessibility tree checked | Observed. The Today tree contains no access-check or detection-time fields. |
| FR-017, FR-031 | One combined total of counter-recorded events across Today, History, floating counter, and limits; no count-quality labels | Fresh Flutter suite: 48 passed; Today/History widget assertions; screenshot 26 | Passed for the checked UI. Detector accuracy remains a release gate. |
| FR-032, FR-033 | No manual add/subtract/edit; stored counter events are the History source of truth | History widget regression test verifies no correction controls/calls; Flutter suite: 48 passed | Passed in the Flutter UI. Legacy native correction operations/data remain migration-compatible and are not called by History. |
| FR-035 | Week bars and Month heatmap; period-specific app totals; empty dates have no mark; empty periods show Rook | Flutter History tests; screenshots 13–14 are actual empty Room states; screenshots 19–21 are separate in-memory layout fixtures | Passed for UI behavior. Fixture counts are illustrative and were not written to Room. |
| FR-038, UX-10 | Daily limit opens from Settings; full grouped Settings screen and privacy policy | Settings/limit widget tests; screenshots 12, 15–18, 22–23 | Passed for the shown controls and routes. Export, deletion, and diagnostics remain unavailable. |

### Fresh verification

- `flutter test --no-pub` — 48 passed.
- `flutter analyze --no-pub` — exit 0; no warnings or errors, five existing Rive deprecation info notices.
- `dart format --output=none --set-exit-if-changed lib test` — 29 files, zero changes.
- `:app:testDebugUnitTest --no-daemon -Pkotlin.incremental=false` — 96 tests, zero failures, errors, or skips. Run using Android Studio JBR and workspace-local SQLite temp directory.
- `flutter build apk --debug --no-pub --build-number=35 --android-project-arg 'kotlin.incremental=false'` — succeeded; artifact at `build/app/outputs/flutter-apk/app-debug.apk` (version code 35).
- Connected device smoke run (2026-11-12, after user request): installed the code 35 APK with `adb install -r` and launched `com.appylab.syncscroll/.MainActivity` on RMX2156 / Android 12 / API 31. Package reports version 1.0.0/code 35, the process stayed alive, and MainActivity was resumed. Accessibility and overlay settings were checked before and after and not changed; Sync Scroll Accessibility remained off, and overlay access was already allowed. No physical-device screenshot was captured.
- Current screenshots and their fixture/empty-state labels: [`docs/qa/ui-screenshots/2026-11-11-counts-access-history/README.md`](ui-screenshots/2026-11-11-counts-access-history/README.md). The previous gallery README now marks its build 33 History correction/day-view images as superseded.

The physical RMX2156 was not changed. Detector validation, spoken TalkBack output, reduced motion, manual target/contrast review, migration rollback/concurrent-startup testing, timezone travel/DST coverage, 90-day query latency, and complete overlay hide/occlusion behavior remain open release checks.
