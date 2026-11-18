# Event-Driven Counter Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a debug-only, consent-gated Reels/Shorts estimate using transient keyed text identity.

**Architecture:** Kotlin scans a narrow Accessibility subtree and sends only a process-local digest to a small event counter. The existing aggregate store records estimated increments. Flutter Today exposes a debug consent control and displays the estimate separately.

**Tech Stack:** Android Kotlin/JUnit, Flutter/Dart, existing MethodChannel and local aggregate store.

**Spec:** `docs/superpowers/specs/2026-11-08-event-counter-prototype-design.md`

## Global Constraints

- Debug builds only; release builds have no active text-key profiles.
- Instagram `454.0.0.54.77` and YouTube `21.44.534` only for the RMX2156 pilot.
- No raw feed text, digest, images, audio, or video in files, logs, bridge payloads, or persistent preferences.
- Only estimated aggregates are stored; estimates never drive limits.
- Consent and Accessibility grant are independently revocable.

## Review Focus

- A stationary viewer with changing controls must not double count.
- A home feed, comment panel, or another package must not count.
- A missing label or ambiguous item subtree must cancel the pending candidate.
- Consent revocation or service interruption must clear transient identities immediately.
- Release builds must exclude active profiles, scanning, and the consent control.

## Tasks

- [x] Add failing Kotlin tests for event candidate timing, first item, transition, stationary, revisit, and cancellation; implement a focused event counter.
- [x] Add failing tests for allowlisted item-label hashing and exact-version debug profile lookup; implement a bounded, content-discarding scanner and debug gates.
- [x] Replace the active service path with the debug event counter, schedule settled rescans, clear state on exit/revocation, and store estimates only.
- [x] Add failing Flutter platform/UI tests for separate test consent and estimated status; implement Today consent control and native bridge gate. The consent dialog is isolated for widget testing because the full Today widget test hits the existing Windows Rive DLL failure.
- [x] Update `AGENTS.md`, `context.md`, `progress.md`, and debug disclosure/requirement notes for the approved temporary test exception.
- [x] Run Android/Flutter tests, analyzer, debug build, and release compilation check; install on RMX2156. Run supervised app-level count comparison only after the user enables Sync Scroll Accessibility and the in-app test consent. Results and failures are in `docs/qa/2026-11-08-event-counter-pilot.md`.
- [x] Investigate build 9 YouTube misses with categorical-only scan evidence; add bounded 150 ms missing-key rescans for 1,200 ms, preserve accepted identity/spacing, and preserve startup baseline suppression until a key appears. Validate on RMX2156 and remove all temporary probe logging. Results are recorded in the pilot ledger.
