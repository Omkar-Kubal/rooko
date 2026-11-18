# Help & diagnostics proposal

**Status:** proposed; not implemented

## Purpose

Help & diagnostics should help a user explain why counting is unavailable and
recover permission or configuration problems without collecting feed content
or uploading a device report.

## Proposed first version

1. **A short troubleshooting guide:** explain Accessibility setup, overlay setup,
   supported-app selection, recognized Reels/Shorts feeds, and common reasons
   counts may pause. Use direct, user-controlled recovery actions.
2. **A local status summary:** show Rooko version, Android version, consent
   status, Accessibility enabled/operational status, overlay grant and toggle
   status, selected app names, installed app versions, and whether a matching
   detector profile is available. Refresh these values when the page opens and
   after returning from Android Settings.
3. **Recovery actions:** open Accessibility Settings, overlay Settings, or the
   selected target app's Android app-info page. Recheck the actual grant state
   when Rooko resumes; never treat a Settings return as proof of access.
4. **User-reviewed diagnostic summary:** offer a preview and a Copy action for a
   concise text summary containing app/build version, Android version,
   permission state, selected target-app names and versions, and safe categorical
   service status. The user reviews it before copying or choosing another app
   to share it.

## Privacy boundaries

- No automatic upload, background report, telemetry, or email send.
- Never include post text or labels, messages, screenshots, media, full
  Accessibility trees, visible URLs, raw or hashed item identifiers, or
  persistent device identifiers.
- Do not include daily counts or observed-time totals in the copied report by
  default. If support later needs those values, make them a separate explicit
  user choice with an explanation.
- Keep the feature usable offline. Any share action is started by the user and
  uses Android's standard share sheet.

## Out of scope

- Remote support sessions, screen recording, automatic log upload, user accounts,
  and raw detector traces.
- Automated count correction or claims that a particular app version is
  accurate merely because its version is recognized.

## Acceptance questions for a later implementation pass

- Can users identify whether consent, Accessibility, selected-app availability,
  or overlay access is the current blocker?
- Do recovery actions open the correct Android settings screen and refresh on
  return?
- Does the previewed summary contain only the approved fields and remain
  entirely user-initiated?
- Are the guide and actions understandable with TalkBack, large text, and
  light, dark, and AMOLED appearances?
