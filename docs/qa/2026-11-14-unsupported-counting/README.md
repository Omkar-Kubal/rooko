# Accessibility on, counting unavailable

Date: 2026-11-14. Device: RMX2156 / Android 12 (API 31), Sync Scroll 1.0.0 debug. The user reported Sleeping Rook and no live floating counter/count while Accessibility and the counter toggle were on.

## Diagnosis

| SRS ID | Check | Evidence | Result |
| --- | --- | --- | --- |
| FR-011, FR-058 | Monitoring access and selected versions | Android secure setting reports Accessibility enabled; `dumpsys accessibility` shows Sync Scroll tracking enabled and bound. [App picker](app-support.png) shows YouTube Shorts `21.45.82` and Instagram `455.0.0.51.72` selected, both **Not supported**. `DetectorProfiles` has no bundled production profiles; the live signed registry's sequence 1 has zero profiles. | Access is working, but neither selected version can be monitored. Sleeping follows the approved unavailable-monitoring precedence. No count is recorded for unsupported versions. |
| FR-050–051 | Overlay permission and drawing | Android app-op `SYSTEM_ALERT_WINDOW: allow`; Settings shows the counter enabled and overlay access on. Tapping **Preview counter** rendered the [transparent Ready Rook and zero badge](counter-preview.png) on-device. | Overlay drawing works. Live display is correctly withheld because an unsupported version has no validated profile or recognized feed. |
| FR-010–021 | Production support gate | Existing [registry device evidence](../2026-11-13-remote-rules-on-device/README.md) and `DetectorProfiles.forVersion` require a signed supported entry and per-version validation. Prior pilot found duplicate debug signals; it did not establish release accuracy. | No validated Instagram or YouTube profile can be published from this device screenshot or the available one-device pilot. The SRS requires at least 200 transitions and 100 stationary/non-feed cases per exact version across three device families, precision ≥98%, recall ≥90%, and zero stationary repeats. |

No feed content, post text, media, or messages were captured for this diagnosis. The user's app selection, Accessibility grant, counter preference, and overlay grant were left intact.

## User-facing change

Settings now distinguishes granted permissions from detector support: the Apps row shows the selected and supported counts, and an enabled counter explains that it remains hidden on feeds when no selected app version is supported. The Apps picker continues to show the exact installed versions and their support status. Today retains Sleeping because the eight-state plan explicitly selects it when every selected validated profile is unavailable. This change does not enable unvalidated counting.

## Verification

- Focused Settings widget test first failed against the old copy, then passed after the change. Full `flutter test --no-pub`: **76 passed**.
- `dart format` checked both changed Dart files with zero changes. `flutter analyze --no-pub --no-fatal-infos`: exit 0, no errors/warnings, three existing Rive boolean-input deprecation infos.
- Android `:app:assembleDebug`: passed with non-incremental Kotlin/KSP and a workspace-local SQLite temp directory. APK SHA-256: `F22FBC6A946D27A937C32643EFD72A00D2388390D05F60031D4B39900EF1AE1E`.
- `adb install -r` succeeded without clearing app data. The phone switched to another foreground app before the post-install Settings capture, so the revised copy is verified by the widget test but has no new device screenshot.

## Remaining work

Create and validate detector profiles for the exact installed app versions using the SRS corpus and accuracy gate, then publish them through the signed registry. Until then, the live count and feed overlay cannot safely activate on these versions. Review the revised Settings copy on-device when the phone is available without interrupting other use.
