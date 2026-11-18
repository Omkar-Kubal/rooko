# SDD ledger — plan: docs/superpowers/plans/2026-11-10-onboarding-history-settings.md

## Status

- Task 1: complete — PRD/SRS updated first, context and project progress updated, execution plan recorded.
- Task 2: implementation and tests complete — Room schema/import, aggregate/correction repository, count-store routing, typed bridge, and migration/correction tests are present. Fresh app unit suite: 95 passed.
- Task 3: implementation and tests complete — History is wired into navigation with real week/day records, separate estimates, coverage quality, and inline corrections/undo. Flutter suite passes.
- Task 4: implementation and tests complete — Settings groups/actions, appearance persistence, Today CTA removal, and debug-only gating are implemented. Flutter suite passes.
- Task 5: implementation and widget tests complete — four stages, consent/optional overlay setup, actual-state refresh, Back, and draft restoration are covered. Dedicated Android 16 AVDs exercised Accessibility grant/decline, optional overlay skip, denial/grant, and state refresh after external revocation.
- Task 6: implementation review and verification complete for this UI/data pass; release acceptance remains partial — see `docs/qa/2026-11-11-onboarding-history-settings-review.md` for exact evidence and remaining gates.

## Rulings

- Ruling: omit Notifications and battery optimization from this pass — user selected these options; notification permission remains contextual to a future feature.
- Ruling: keep export/delete/Help & diagnostics visible but unavailable — user selected a visual pass with real controls where available; existing M1 requirements remain open.
- Ruling: import existing SharedPreferences aggregates transactionally into Room and retain preferences as migration source — preserves user data and allows interrupted migration retry.
- Ruling: legacy timezone and coverage are unknown — the source data does not record either fact, so no backfilled value may be invented.
- Ruling: work in the supplied directory — the workspace has no Git metadata and cannot create an isolated git worktree.
- Ruling: preserve the RMX2156's saved system permission and display setup during review; use dedicated AVDs for permission and accessibility checks. This allowed grant/decline/skip/denial/revocation checks without changing the physical device. Selected-day large-text review passed after a chart overflow fix; reliable TalkBack spoken-output review remains open because a system notification prompt interrupted navigation/announcement capture.
- Ruling: supply Room's writable temp path per build rather than adding a machine path to project configuration — the failure came from this host's `C:\Windows\Temp` access, and a workspace-scoped JVM property allowed the build; the cost is that a clean CI/host build still needs its own temp-path verification.

## Verification

- Initial implementation failures above were fixed and are retained here as historical evidence. Fresh verification on 2026-11-11 after the large-text fix: `flutter test` — 49 passed; `flutter analyze --no-pub` — zero errors/warnings and five existing Rive deprecation info notices; Dart format check — 28 files, zero changed; Android `:app:testDebugUnitTest :app:assembleDebug --no-daemon -Pkotlin.incremental=false` — successful, 95 tests with 0 failures/errors; Flutter APK wrapper build — successful with Android Studio JBR and writable `org.sqlite.tmpdir`. RMX2156 runs version 1.0.0/code 33 with app data preserved.
- RMX2156 theme review covered light, dark, and AMOLED, then restored System appearance; font scale remained `1.0` and phone permissions were not changed during the final install. Dedicated Android 16 AVDs verified Accessibility grant/return, decline, overlay skip/denial/grant, and permission recovery after external revocation. At 200%, Today, Settings, and History week/selected-day views remained inspectable and scrollable on build 4033. The AVD was restored to font scale `1.0`, TalkBack off, floating-counter preference off, overlay denied, then shut down. TalkBack reached Settings controls, but spoken output was not captured; reduced motion and target/contrast audits remain unverified. See the QA record for exact states.
- RMX2156 cold start measured 8.63/5.46 seconds on version code 31 and 7.10/4.41 seconds on version code 32, missing SRS NFR-03's two-second target. Ninety-day History query latency was not measured.
- Remaining technical acceptance gaps: interrupted-import rollback/retry and concurrent provider startup; complete FR-034 timezone preservation; full live bubble hide/occlusion matrix; detector accuracy and current Play disclosure/declaration review. Export, delete, and diagnostics remain unimplemented M1 work.
