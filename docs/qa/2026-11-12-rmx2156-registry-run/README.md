# RMX2156 registry build run

- Date: 2026-11-12 (device local time, Asia/Kolkata)
- Device: realme RMX2156, Android 12 / API 31
- ADB serial: `X4GEAYDMWGAUI7WG`
- App: `com.appylab.syncscroll`, version `1.0.0` (version code `1`)
- Artifact: `build/app/outputs/flutter-apk/app-debug.apk`
- Install: `adb -s X4GEAYDMWGAUI7WG install -r build/app/outputs/flutter-apk/app-debug.apk` — succeeded; existing app data was preserved.
- Launch: `adb -s X4GEAYDMWGAUI7WG shell am start -n com.appylab.syncscroll/.MainActivity` — succeeded; `MainActivity` resumed and app process was alive (PID 14890 at capture).
- Visual result: after startup settled, Today rendered with the access wall, counter, centered Ready Rook, selected-app row, and bottom navigation. Accessibility access was off, and the wall remained visible. No permission settings were changed.
- Startup note: a capture two seconds after launch showed a transient black frame; after waiting eight more seconds the app rendered normally.
- Crash buffer: empty at the time of the check.
- Evidence: [main.png](main.png), [ui.xml](ui.xml).
- Scope: install/launch smoke check only. No test suite or detector/version-registry network request was run. The default registry configuration is not live until an HTTPS endpoint and pinned public key are supplied; see [registry setup](../../../tool/detector_registry/README.md).

The app is left open on the RMX2156.
