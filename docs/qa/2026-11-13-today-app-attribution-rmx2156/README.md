# Today app attribution on RMX2156

- Date: 2026-11-13 (Asia/Calcutta)
- Device: RMX2156, Android 12 / API 31
- App: `com.appylab.syncscroll`, version `1.0.0` (version code 1)
- Result: Today shows the shared total `9` and its persisted per-app breakdown: YouTube Shorts `5`, Instagram `4`. Values come from the app's daily snapshot; the mockup values are not hard-coded.
- Permission state at capture and follow-up check: Android reports `accessibility_enabled=0`, `enabled_accessibility_services=null`, and no Sync Scroll service bound. `SYSTEM_ALERT_WINDOW` is allowed. The access banner is shown because required Accessibility access is off; the overlay permission is separate. No permissions were changed.
- Build: Flutter analyzer exit 0 with five existing Rive deprecation notices. Debug APK assembly succeeded with Android Studio JBR, `org.sqlite.tmpdir` set to `build/sqlite-temp`, Kotlin compiler in-process, Kotlin incremental compilation disabled, and one Gradle worker. The Flutter wrapper first hit the known Room KSP temp-directory initialization error; the direct Gradle build with the project workaround succeeded.
- Device install/launch: `adb install -r build/app/outputs/flutter-apk/app-debug.apk` succeeded; `MainActivity` is resumed on RMX2156. App data was preserved.
- Automated tests were not run for this UI correction.

Screenshot: [`today.png`](today.png). Product and system requirements are UX-05 / PR-03 and FR-017, FR-031, FR-033.
