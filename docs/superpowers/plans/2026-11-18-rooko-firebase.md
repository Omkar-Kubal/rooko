# Rooko Firebase implementation plan

Historical plan: superseded by the user's 2026-11-19 direction to initialize Analytics and Crashlytics automatically and hide the Settings control. See `progress.md` and current PRD/SRS.

1. Register Android package `com.appylab.rooko` in Firebase project `toki-0001`; download its Android SDK config without printing keys.
2. Add Firebase Core, Analytics, and Crashlytics using Sync Spend's compatible Gradle and Flutter setup. Keep native Analytics and Crashlytics collection off by default.
3. Add a local opt-in preference and a Settings switch. On opt-in, initialize Firebase, enable both collections, log a parameter-free Rooko app-open event, and allow standard Firebase app/session events. Disable Activity screen reporting. On opt-out, disable both. Firebase errors must not block app startup.
4. Confirm the preference defaults off, persists explicit choices, and gates all Firebase initialization and event reporting.
5. Update the in-app privacy policy, Google Sites HTML source, PRD, SRS, AGENTS.md, context.md, and progress.md to describe the choice and data boundary.
6. Run formatter, targeted tests, Flutter analyzer, and Android debug build. Verify Firebase app registration and config IDs without outputting the API key.

## Verification map

| Requirement | Evidence |
|---|---|
| Toki has the Rooko Android app | `firebase apps:list ANDROID --project toki-0001 --json`, inspect package and app ID |
| Collection starts disabled | Default-off source review; manifest metadata review |
| Choice persists | SharedPreferences integration source review |
| No sensitive product payloads | Review the sole custom Analytics event and absence of Crashlytics keys/logs |
| Android integration compiles | `flutter analyze`; `flutter build apk --debug` |

