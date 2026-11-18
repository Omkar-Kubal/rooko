# SDD ledger — plan: docs/superpowers/plans/2026-11-07-exposure-counter.md

## Setup

- Spec: `docs/superpowers/specs/2026-11-07-exposure-counter-design.md` read and used as design authority.
- Worktree: unavailable because `D:/appylab/sync-rot` has no `.git` metadata. User explicitly asked to implement in the shared project workspace.
- Baseline: `android/gradlew.bat :app:testDebugUnitTest '-Pkotlin.incremental=false'` — BUILD SUCCESSFUL. The unmodified invocation failed due Kotlin incremental caches crossing `C:` and `D:`.

## Interface preflight

- Task 1 → Tasks 2/5: the validation matrix schema records app/version/device/signature/identity/metrics/status. Compatible.
- Task 2 → Tasks 3/4: profiles provide feed, transition, and identity evidence. Compatible; absent evidence must remain unsupported.
- Tasks 3/4 → Task 6: atomic local count writes feed the existing MethodChannel snapshot. Compatible; Today refreshes on resume.
- Tasks 5/6 → Task 7: exact version confidence and aggregate counts are testable against the corpus gate. Compatible.
- Task 7 → Task 8: floating overlay is gated by confirmed profiles. Current baseline has no profile through the corpus gate, so Task 8 must remain deferred.

## Decisions and rulings

- Ruling: implement available infrastructure and keep app profiles without live structural evidence unsupported/estimate-only — the RM has only Instagram and YouTube installed and no three-family corpus; adding guessed profiles would violate FR-010/021.
- Ruling: use existing Today refresh-on-resume for the core count work; implement the optional floating overlay only if profile validation passes. No overlay permission should be requested during this implementation pass before that gate.

## Tasks

- Task 1: in progress — PRD/SRS and validation matrix updated.
- Task 2: pending.
- Task 3: pending.
- Task 4: pending.
- Task 5: blocked pending app versions and Accessibility structure observations for TikTok, Facebook, Snapchat; existing Instagram/YouTube profiles remain below gate.
- Task 6: pending.
- Task 7: blocked pending the required corpus across three device families.
- Task 8: deferred pending Task 7 pass and separate UX/permission review.
