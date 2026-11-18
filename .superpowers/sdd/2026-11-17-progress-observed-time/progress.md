# SDD ledger — plan: docs/superpowers/plans/2026-11-17-progress-observed-time.md

Pre-flight: Task 1 produces `ProgressRepository.recordObservedFeedDuration(...)` and nullable `ProgressDay.observedFeedDurationMillis`; Task 2 consumes the repository writer; Task 4 consumes the day field through `MainActivity.progressDayMap`; interfaces are consistent.

Ruling: No isolated Git worktree can be created because `D:\appylab\sync-rot` has no Git metadata; proceed in the user-authorized shared workspace — cost if wrong: edits have no branch isolation or Git diff history here.

Ruling: Do not add or run automated tests because the session developer instruction forbids tests unless the user asks; use code review and non-test compiler/static checks only — cost if wrong: lifecycle and migration behavior receive less verification than TDD would provide.

Ruling: Describe the value as approximate observed feed time because a brief exit/reentry between successful 5-second root checks cannot be proven absent — cost if wrong: an unobserved short interruption could be included in a credited interval.

Task 1: complete — Room v6 adds nullable daily duration, the 5→6 migration is registered, and repository accumulation preserves legacy nulls; automated tests not run per ruling.

Ruling: Keep a five-second hard credited-gap limit but schedule the heartbeat every four seconds, giving handler/root-scan overhead margin and preventing normal callbacks from routinely exceeding the tracker cap; cost if wrong: root marker scans run 25% more often than a five-second cadence, with modest additional service work.

Task 2: complete — added monotonic bounded accumulation, marker-only visible feed checks, four-second heartbeats, screen-off stop/screen-on revalidation, immediate host-resume stop, target/version/consent/access checks, synchronous batched writes, and lifecycle flushes. No count/dedupe/overlay logic was changed; automated tests not run per ruling.

Task 3: complete — consent version is `tracking_consent_observed_feed_time_v3`, the onboarding/Settings disclosures and privacy copy describe the measurement, and Android's Accessibility Settings description now matches transient label handling and observed-time sampling.

Task 4: complete — native bridge and Dart model carry nullable duration; Progress Day pairs Total Count with Time spent and announces both values. Flutter format/analyze and Android Kotlin compilation provide static evidence; no runtime UI check was done.

Task 5: complete — AGENTS, context, progress, PRD, and SRS reflect the observed-time scope and renewed consent. Room schema 6 JSON was generated during KSP compilation.

Verification: `dart format lib/features/onboarding/onboarding_screens.dart lib/features/settings/settings_screen.dart lib/core/models/progress.dart lib/features/progress/progress_screen.dart` → formatted 4 files, 0 changed. `flutter analyze --no-pub` → exit 0, three pre-existing Rive deprecation infos outside changed files. `:app:compileDebugKotlin --no-daemon -Pkotlin.incremental=false -Dorg.sqlite.tmpdir=<workspace temp>` → BUILD SUCCESSFUL; Room v6 schema emitted. The first Android compile attempt exposed that `C:\WINDOWS\TEMP` was not usable by Room's verifier; redirecting its temp directory to `android/.gradle/sqlite-tmp` resolved compilation without changing project environment. Automated tests and device checks were not run.

Final review: a fresh reviewer found timing cadence, host Activity resume, invisible feed markers, and stale Android permission-description copy issues. The implementation corrected all four; source inspection confirms host resume stops and flushes observed time, and the final Kotlin compile succeeded. The first review's host-resume note was stale relative to the current source. No second review or automated test run was performed, per the execution skill's one-review gate and developer test restriction.

Final: Ruling: Live Instagram/YouTube marker accuracy and OEM lifecycle behavior remain unverified — these require device observations, which were not run in this pass — cost if wrong: Time spent could undercount or misclassify feed presence on a particular app version/device.

Final: Ruling: Room migration runtime preservation, TalkBack output, and large-text presentation remain unexercised — only schema generation and code structure were checked — cost if wrong: a legacy database or accessibility setting could expose a runtime issue despite successful compilation.

Final: Ruling: Existing count deduplication and detector accuracy were not independently revalidated — they were outside this time-metric change and their logic was left unchanged — cost if wrong: an integration side effect could affect counts even though no count code path was intentionally altered.

Final: Ruling: Release/store policy acceptance was not assessed — this pass implemented the updated in-app and Android disclosures but was not a release review — cost if wrong: additional policy wording or declaration work could still be required before publication.
