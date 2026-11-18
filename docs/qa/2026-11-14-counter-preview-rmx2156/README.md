# Counter preview on RMX2156 — 2026-11-14

## Device run

- Device: RMX2156 (`X4GEAYDMWGAUI7WG`), Android 12 / API 31.
- Built the debug APK with Android Studio JBR, a workspace-local SQLite temporary directory, and Kotlin/KSP incremental processing disabled:

  ```powershell
  $env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
  $env:JAVA_TOOL_OPTIONS = '-Dorg.sqlite.tmpdir=D:/appylab/sync-rot/build/sqlite-temp'
  flutter build apk --debug --no-pub `
    --android-project-arg=kotlin.incremental=false `
    --android-project-arg=ksp.incremental=false `
    --android-project-arg=kotlin.compiler.execution.strategy=in-process
  ```

- A plain `flutter build apk --debug` first failed in Kotlin incremental-cache finalization. The cache tried to relativize plugin sources under `C:\Users\omkar\AppData\Local\Pub\Cache` against the project on `D:`. The documented non-incremental workaround completed successfully.
- A read-only package check found Sync Scroll was not installed before this run. `adb install -r build/app/outputs/flutter-apk/app-debug.apk` succeeded as a fresh install; there was no prior Sync Scroll app data to replace.
- `com.appylab.syncscroll/.MainActivity` resolved, launched, and was confirmed resumed with process ID `24594`.
- Navigated from Welcome to the counter preview using the visible **Get started** control. Android's UI tree exposed “Illustrative floating counter preview,” **Pause preview**, **Continue**, and an example count. A prior UI-tree snapshot showed 155; the saved screenshot shows 211.
- No Instagram/YouTube feed was opened and no Accessibility or overlay permission was granted during this run. No automated tests were run.

## Screenshot

![Counter preview on RMX2156](counter-preview.png)
