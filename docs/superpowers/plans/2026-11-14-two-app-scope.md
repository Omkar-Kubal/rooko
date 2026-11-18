# Two-App Scope Implementation Plan

**Goal:** Restrict active Sync Scroll tracking, app selection, registry publishing, and current product requirements to YouTube Shorts and Instagram Reels.

**Architecture:** Keep the existing Flutter and Kotlin app allowlists synchronized. Filter retired saved selections at startup without deleting historical local data. Restrict the registry publisher and schema to the same two packages. Preserve dated research and QA artifacts as historical evidence.

**Tech Stack:** Flutter/Dart, Kotlin Android, Node registry tooling, PRD/SRS.

**Spec:** User request on 2026-11-14, confirming that only YouTube Shorts and Instagram Reels remain in scope.

## Tasks

- [x] Change the Flutter app list and current onboarding app artwork/copy to two apps; filter retired IDs from saved selections.
- [x] Change Android package visibility and the monitored app allowlist to two packages; sanitize previously saved retired IDs at service startup.
- [x] Restrict registry publisher/schema and move retired app logos out of the Flutter bundle.
- [x] Update PRD scope, SRS FR-001/FR-021, AGENTS, context, and progress. Preserve historical research captures, dated QA, and earlier execution records.
- [ ] Run Flutter tests/analyzer and Android/registry tests; build APKs if checks pass. **Deferred per user's standing instruction not to run tests unless asked.**

## Separate onboarding text review

Use the BrainPal first-launch screenshots only as an observed pacing reference. The user selected guided setup with one optional habit question and then requested the counter preview immediately after Welcome. Sequence: existing Welcome/value → simulated counter preview → one optional habit reflection (inside the Welcome stage, with a clear skip) → choose YouTube Shorts and Instagram Reels → explain tracking and request consent/access → separate optional floating-counter setup. Keep the existing consent and overlay decisions intact. Review only the current screen's original copy at a time. The existing Welcome was accepted as-is; the counter preview is implemented; the optional habit reflection is next.

### Counter preview — implemented

- The preview advances a simulated vertical feed and cycles counts 0, 22, 44, 77, 111, 133, 155, 177, 200, and 211 before repeating.
- A static transparent Rook count pose and count badge update together. The preview is illustrative only and does not access live feeds, request overlay permission, or write usage data.
- Auto-advance pauses when the app is backgrounded or reduced motion is enabled; reduced-motion users can step through examples manually.
- `flutter build web --no-pub` succeeded. Automated tests and live-feed checks were not run for this screen.

### Screen 1 draft — review only

- Headline: “Your feed, on your terms.”
- Body: “See one daily count across Instagram Reels and YouTube Shorts.”
- Privacy line: “No account needed · Feed content isn’t saved.”
- Actions: “Get started” / “Explore without access.”
- Status: proposed copy only; not implemented pending the user's screen-by-screen review.
