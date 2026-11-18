# Help & Feedback with local diagnostics

**Status:** approved for implementation by the user's “Start building this” direction.

## Intent

Give Settings a simple Support entry point for release notes and help. Let users
understand local counting setup and open the relevant Android settings screen,
then contact support or request a feature through their own email app. Do not
upload diagnostic data.

## User-visible behavior

- Settings > Support contains **What's New** and **Help & Feedback**.
- What's New shows bundled release notes for the installed app version. It is
  local content; no release-note service is added.
- Help & Feedback opens a compact sheet with **Troubleshoot counting**,
  **Feature Requests**, and **Support Email**.
- Troubleshoot counting opens a screen with separate tracking-consent,
  Accessibility, selected-app/version, and floating-counter statuses. It
  refreshes when opened and when the app resumes. Recovery actions open
  Accessibility or overlay settings, or the selected installed app's Android
  app-info screen. Returning from Android settings always triggers a fresh
  status query.
- A diagnostic summary is shown for review before the user copies it. It may
  contain Sync Scroll version, Android release/API level, consent and actual
  Accessibility status, selected app names and installed versions, coarse
  counting-availability status, and floating-counter/overlay state.
- Email actions open the user's external email composer at
  `omkarkubal@protonmail.com` with the subjects `Sync Scroll Feature Request`
  and `Sync Scroll Support`. The app never sends email itself.

## Privacy and product constraints

- No automatic upload, analytics, telemetry, or email send.
- The diagnostic summary excludes counts, observed-time totals, feed text or
  labels, messages, URLs, screenshots, media, full Accessibility trees, raw or
  hashed item identifiers, and persistent device identifiers.
- Do not imply that an enabled permission or matching version means a feed is
  currently recognized or that counting is accurate. Do not expose internal
  debug field names.
- The screen remains useful offline. Use existing monochrome design tokens and
  support TalkBack, large text, and light, dark, and AMOLED themes.

## Implementation choices

- Reuse the existing typed tracking snapshot and permission methods; add only
  Android release/API fields and allowlisted email/app-info actions to the
  method channel.
- Use local release-note content and an in-app status screen; do not add a
  backend, account, package dependency, or diagnostic event store.
- Keep the feature in the current Android-first Flutter app and route from the
  existing Settings Support group.

## Acceptance evidence

Check consent-needed, Accessibility-off, enabled-but-nonoperational,
no-app-selected, not-installed, unavailable-version, overlay-off,
overlay-grant-missing, and all-access-ready states. Confirm Android settings
actions and status refresh after return, email URI subjects/recipient, report
preview and clipboard contents, offline behavior, TalkBack labels, large text,
and all supported themes. Verify by formatter, analyzer, and Android debug build;
do not exercise or claim detector accuracy.
