# SDD ledger — plan: docs/superpowers/plans/2026-11-06-onboarding-today-integration.md

Ruling: this workspace has no `.git` repository, so a git worktree, task-start/task-done scripts, and commits cannot be created; the user explicitly asked for implementation in this workspace, so continue in place and keep a manual ledger.

Pre-flight: detector rules feed the native service; local count storage implements the detector's dedupe interface; the Flutter bridge consumes service, support, and count snapshots; onboarding persists the selected IDs before Settings opens; Today renders snapshots. No History/Settings screen work is planned.
