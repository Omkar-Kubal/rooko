# New connected device launch — 2026-11-16

| SRS ID | Acceptance behavior | Evidence | Result | Gap |
| --- | --- | --- | --- | --- |
| FR-001 | The current APK installs and Sync Scroll opens on the connected Android device | CPH2733 / Android 16; `adb -s X4CYXC4H898P6LSS install -r -d build/app/outputs/flutter-apk/app-debug.apk` returned `Success`; `am start` and `dumpsys window` showed `com.appylab.syncscroll/.MainActivity` focused; `launch.png` | Passed; saved onboarding resumed at “Before I start” | No onboarding completion or live Reels/Shorts count test |

The current debug APK was built on 2026-11-16 and has SHA-256 `9553E8A630097A7869A1C3EE22A0F9B0A407EF173A59446BE28AB376507C8726`. Installation preserved existing app data and permissions. The notification shade was dismissed to capture the app in the foreground; no onboarding answer or permission was changed.
