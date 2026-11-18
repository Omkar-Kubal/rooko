# Rooko Firebase setup

Historical design: superseded by the user's 2026-11-19 direction to initialize Analytics and Crashlytics automatically and hide the Settings control. See `progress.md` and current PRD/SRS. The privacy-policy copy was not edited in that revision and needs reconciliation before release.

## Intent

Register Android package `com.appylab.rooko` in the existing Firebase project `toki-0001` and add the same Firebase Core, Analytics, and Crashlytics foundation used by Sync Spend. Rooko remains local-first unless the user enables sharing in Settings.

## Goals and constraints

- Use Firebase project Toki; add an Android app registration for Rooko.
- Initialize Firebase on Android without making startup depend on network availability.
- Keep Analytics and Crashlytics collection disabled by default, including native auto-collection.
- Add one explicit Settings control for anonymous diagnostics and generic app-open analytics.
- Do not send counts, selected apps, Accessibility state/content, observed-time totals, feed text, item identifiers, screenshots, or support diagnostics.
- Update the in-app and public privacy-policy sources and resolve the SRS analytics/crash-reporting decision.

## Approaches

1. Mirror Sync Spend with collection always on. Rejected because Rooko's PRD requires a clear user control and no Accessibility content.
2. Install Core, Analytics, and Crashlytics with collection off until the user opts in. Selected because it matches the requested Firebase services while preserving the privacy contract.
3. Install Core only. Rejected because it does not provide the Analytics and Crashlytics setup the user asked to mirror.

## Behavior

The preference defaults off. When enabled, Firebase may receive a parameter-free `rooko_app_open` event, standard Firebase app/session events, crash stack traces, and technical app/device diagnostics. Automatic Activity screen reporting is disabled. No user activity or Accessibility data is added to custom events or Crashlytics keys/logs. Turning the setting off disables both collection paths. Firebase initialization failures must not block onboarding or Today.

## Acceptance evidence

- Firebase CLI lists the new Android app under Toki with package `com.appylab.rooko`.
- Android Google Services configuration matches that app ID and project ID.
- Source review confirms the diagnostic preference defaults off and persists explicit choices.
- Flutter analysis and Android debug build succeed.
- Manual config review confirms native auto-collection defaults off, one parameter-free custom app-open event, no automatic Activity screen reporting, and no content-bearing custom events or Crashlytics keys/logs.

