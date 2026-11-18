# Shared count and Rook overlay device check

Date: 2026-11-13  
Device: RMX2156, Android 12 / API 31  
App: `com.appylab.syncscroll`, debug build `1.0.0`

## Product behavior checked

- Detection starts automatically after consent and required access only for selected versions with profiles that passed the SRS validation gate. The YouTube `21.45.82` and Instagram `455.0.0.51.72` builds on this phone remain unsupported, so neither records new events.
- Today, History, the saved limit, preview, and live overlay use one combined total across selected apps. All previously saved event categories contribute to that total; new events still require a validated profile.
- The debug counting toggle is absent. The preview uses the transparent Ready Rook SVG and a circular count badge below it. Its initial Y position now starts at the status-bar safe edge.

## Correction follow-up (2026-11-13)

The previous build changed the shared getters to count only one stored category, which made existing counts disappear from Today and History. The correction restores the prior total of both saved categories without changing Today’s layout or copy. The floating counter retains its shared cross-app sequence and now starts at the top safe edge.

The corrected APK was assembled and installed in place on RMX2156 without clearing app data. The app opened in the foreground, and current screenshots were captured without changing permissions or opening feeds. The counter preview showed the Rook and count `9` at the top safe edge; its visible position confirmed that Android already applies the status-bar inset to the overlay window, so the app now uses a zero Y offset.

## Corrected device screenshots

Captured on RMX2156 / Android 12 / API 31 after the corrected APK was installed.

### Today

![Today on RMX2156](../ui-screenshots/2026-11-13-count-overlay-correction/today.png)

Today retains its previous layout and copy and shows the restored saved total `9`.

### Settings

![Settings on RMX2156](../ui-screenshots/2026-11-13-count-overlay-correction/settings.png)

Accessibility remains off, overlay access is on, and no debug counter control appears.

### Floating-counter preview

![Floating-counter preview on RMX2156](../ui-screenshots/2026-11-13-count-overlay-correction/counter-preview.png)

The Rook artwork has no square backing; the circular `9` badge sits beneath it. The visible Rook begins just below the status bar.

### Installed app versions (earlier capture; registry unchanged)

![Installed target-app versions on RMX2156](../ui-screenshots/2026-11-13-shared-count-rook/app-selection.png)

The installed YouTube and Instagram versions are identified locally and shown as unsupported. This matches the empty production profile map.

### Previous-build captures

The older Today and counter-preview captures showed `0` because the previous build excluded the saved event categories. They are retained under [the earlier screenshot folder](../ui-screenshots/2026-11-13-shared-count-rook/) as historical evidence, not as the corrected UI.

## Verification

| Requirement | Evidence | Result |
| --- | --- | --- |
| PR-03 / SRS FR-017: shared count across selected apps | Flutter and Android regression tests include both saved event categories | Pass |
| PR-08: floating Rook with shared total at the top safe edge | RMX2156 screenshot confirms transparent Rook at the top safe edge with a circular shared-count badge | Pass |
| SRS FR-010 / FR-011: exact-version validation and automatic detection | App picker shows both installed versions as unsupported; bundled production profile map remains empty | Correctly fail-closed; no live counting claim |
| User-facing count copy | Today, Settings, and preview screenshots show one total without count-category labels or debug controls | Pass |

- `flutter test --no-pub` — 53 passed.
- `flutter analyze --no-pub` — exit 0; five existing Rive API deprecation info notices.
- `dart format --output=none --set-exit-if-changed lib test` — exit 0; no files changed after formatting.
- Android `:app:testDebugUnitTest` — passed (109 tests). Used Android Studio JBR, `-Pkotlin.incremental=false -Pksp.incremental=false`, and workspace-local `-Dorg.sqlite.tmpdir`.
- Android `:app:assembleDebug` — succeeded.
- `adb install -r -d` and foreground launch on RMX2156 — succeeded without clearing app data; Today, Settings, and counter preview were visible and captured.

## Remaining detector gate

The current YouTube and Instagram versions cannot count until profiles pass the SRS accuracy gate and are published. The RMX2156 Accessibility service is currently off, and there is only one connected device family. This run verifies the UI and fail-closed behavior; it does not validate feed counting accuracy.
