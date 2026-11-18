# RMX2156 current build run

- Date: 2026-11-13 (Asia/Calcutta)
- Device: RMX2156, Android 12 / API 31
- App: `com.appylab.syncscroll`, version `1.0.0` (version code 1)
- Install: `adb -s X4GEAYDMWGAUI7WG install -r build/app/outputs/flutter-apk/app-debug.apk`
- Launch: `adb -s X4GEAYDMWGAUI7WG shell am start -S -W -n com.appylab.syncscroll/.MainActivity`
- Result: the cold launch completed and Today remained foregrounded. The screenshot shows the existing Today layout, one shared total (`9`), and the access wall.
- State: Accessibility is off; overlay access is on per the existing device status. No app data or permission settings were changed. The access wall is therefore expected. This run did not exercise detector counting or the floating overlay in another app.
- Acceptance evidence: screenshot [`today.png`](today.png); Today layout/shared-count/access-wall behavior corresponds to SRS FR-004, FR-031, and FR-033.

The initial post-install launch returned to the launcher. Android's exit history recorded the process as `TOO MANY EMPTY PROCS` with no crash trace. A subsequent cold launch succeeded and the app remained foregrounded for the screenshot.
