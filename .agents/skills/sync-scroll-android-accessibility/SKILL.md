---
name: sync-scroll-android-accessibility
description: Use when implementing or reviewing Rooko Android Accessibility monitoring, feed detection, permissions, service lifecycle, interruptions, overlays, notifications, or NFC and step challenges; protects informed consent, privacy, and measurement accuracy.
---

# Rooko Android Accessibility and monitoring

Use this skill for Android-only observation and platform behavior. Native Kotlin owns service lifecycle, permission checks, detector profiles, overlays, notifications, local persistence, and the typed Flutter bridge.

## Required reading

1. Read `AGENTS.md`, the relevant SRS requirements, and the associated PRD milestone.
2. For AccessibilityService or interruption changes, read SRS sections 3.1–3.4 and the current Android and Google Play policy pages linked from the SRS.
3. Recheck current platform and Play policy before release work; policy and OS behavior can change.

## Workflow

1. Map the change to SRS IDs and name the supported app/version and Android API assumptions.
2. Define the permission/disclosure state, the user's grant/decline/revoke paths, and observed failure states before implementing the happy path.
3. Keep Android platform work in Kotlin and expose typed, versioned data to Flutter. Verify actual permission/service state after returning from system Settings.
4. Scope observations to selected packages. Retain only the minimum transient signal needed by the detector. After the updated in-app tracking disclosure and consent, Instagram/YouTube estimated counting may briefly inspect bounded visible labels and hash them in process memory. Never log or persist raw labels, messages, images, audio, or video.
5. Retain event categories and coverage gaps internally for QA and release gates. The user-facing count uses one total of events the counter records. A validated profile is required for confirmed events; the user-approved Instagram/YouTube fallback may record estimates only when its feed and item signals are recognized. Missing signals fail closed.
6. Explain permission loss, unsupported app versions, service death, OEM restrictions, and unavailable interruption surfaces with a clear next action. Do not promise uninterrupted monitoring or imply a request succeeded because a Settings screen opened.
7. For NFC, steps, overlays, or notifications, include denial, cancellation, timeout, and non-sensor fallback behavior. A challenge must never be required for emergency access.

## Non-negotiable constraints

- Show a prominent in-app disclosure before requesting Accessibility access; explain accessed signals, purpose, sharing, and retention, then obtain affirmative consent with a clear decline route.
- Do not set `isAccessibilityTool=true` for this productivity app unless its primary purpose changes and the product is reviewed against that claim.
- Do not use Accessibility to read content, take screenshots, issue synthetic taps, or resume media in another app.
- Do not persist plain accessible item tokens. Follow the SRS's local hashing and transient-storage rules for validated stable tokens.
- Keep the app usable when access is declined or unavailable. Never claim data stays on-device if an enabled service sends it elsewhere.
- Do not treat a coverage gap as zero activity or as a verified win.

## Deliverable

Report the affected SRS IDs, permissions and disclosure states, supported package/version assumptions, privacy-retained data, confidence/coverage behavior, failure paths, and the platform or device evidence gathered.
