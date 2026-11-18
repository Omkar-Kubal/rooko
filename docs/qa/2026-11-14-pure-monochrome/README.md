# Pure monochrome palette QA

Date: 2026-11-14. Target: Sync Scroll debug build on RMX2156, Android 12/API 31. Scope: color roles, contrast, theme surfaces, selected and disabled controls, and native counter styling. Rook and supported-app artwork were preserved.

## Acceptance evidence

| SRS ID | Acceptance behavior | Evidence | Result and gap |
| --- | --- | --- | --- |
| NFR-06 | Light uses white canvas/cards and black primary controls; Dark uses `#080808` canvas and `#171717` cards; AMOLED uses black canvas/cards. All shared UI colors are achromatic. | `AppColors`, `AppTheme`, `app_theme_test.dart`; [Light Today](light-today-final.png), [Dark Settings](dark-settings-final.png), [AMOLED Today](amoled-today.png), [AMOLED Settings and menu](amoled-menu-final.png). | Passed for inspected surfaces. The AMOLED appearance menu received an outline so it remains bounded on black. |
| NFR-06 | Supporting text meets WCAG AA text contrast; interactive outlines meet 3:1 against their surfaces. | Token contrast test and direct WCAG luminance calculation. | Light `#595959`/white: 7.00:1; Dark `#BDBDBD`/`#171717`: 9.54:1; AMOLED `#BDBDBD`/black: 11.18:1. Light outline `#8A8A8A`/white: 3.45:1; Dark `#757575`/`#171717`: 3.89:1; AMOLED outline/black: 4.56:1. Black/white controls: 21:1. Disabled controls are marked unavailable in text and are not active. This measures token pairings, not every rendered pixel pair. |
| NFR-06 | Dart palette and browser-preview CSS remain in sync; no colored status text or glyph accents remain. | `app_theme_test.dart` checks CSS parity and achromatic shared roles; source scan found no colored Flutter UI literals. `web/manifest.json` uses white launch colors. | Passed at source/token level. Colored Rook and supported-app logos remain intentional exceptions. |
| NFR-06, FR-050–051 | History, Settings, onboarding, and native floating-counter styling use neutral boundaries and controls. | [Light History empty state](light-history.png), [Dark Welcome](dark-welcome.png), [Dark Settings](dark-settings-final.png), [AMOLED Settings](amoled-settings.png); Kotlin overlay `Palette` uses black badge and white text/outline/dismiss glyph. | Inspected available device states. History had no counts, so populated Week bars and Month heatmap were covered by Flutter widget tests, not device screenshots. No apps were selected and tracking access was off, so the floating-counter preview and app-count pill were not displayed on this device. |

## Checks

- `flutter test --no-pub`: **75 passed** after the final appearance-menu edit.
- `dart format --output=none --set-exit-if-changed lib test`: exit 0; 29 files checked, 0 changed.
- `flutter analyze --no-pub --no-fatal-infos`: exit 0; no errors or warnings, three existing Rive boolean-input deprecation infos.
- Android `:app:testDebugUnitTest` and `:app:assembleDebug`: passed with Kotlin/KSP incremental processing disabled and `org.sqlite.tmpdir` set inside the workspace, avoiding the C:/D: incremental-cache path issue. The unit-test reports contain 130 tests, 0 failures/errors/skips. APK SHA-256: `90636B0D09F215F5F921942094CD14CD9260CE76BF7B14A4FB4F142C57C7FD5E`.
- The APK was installed in place on RMX2156. Light, Dark, and AMOLED Today/Settings appearances were reviewed. Appearance was restored to System and the app returned to Today; [final device capture](system-restored.png). No app data or permissions were reset.

## Open device checks

- Review the floating-counter preview, app-count pill with selected logos, and populated History charts in all three appearances when a consented setup and representative saved data are available. Do not bypass monitoring consent or insert synthetic counts on this user's device.
- TalkBack spoken output and 200% text scaling were not rerun for this color-only pass; earlier general UI checks do not establish final theme-specific accessibility evidence.

Later on 2026-11-14, the user enabled the counter and overlay access. A manual preview rendered correctly on RMX2156; see the [counting-availability follow-up](../2026-11-14-unsupported-counting/README.md). Live feed display remains unavailable because the selected exact app versions have no validated profiles.

This is palette acceptance evidence, not a detector or release-readiness claim.
