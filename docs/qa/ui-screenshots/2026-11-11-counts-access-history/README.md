# Current UI screenshots — one count, access wall, Week/Month History

Captured from debug build 1.0.0 / version code 35 on the isolated Android 16, API 36 AVD (`emulator-5554`, 1080×1920). Screens 24–26 were freshly recaptured during the interaction review. The physical RMX2156 was not changed.

The app's Room database has no sample History records. Screens 13–14 show the real empty History states. Screens 19–21 are separate, in-memory chart fixtures used only to show the populated chart layouts; their example values are not app records and should not be compared as one continuous dataset.

## Onboarding

- [Welcome](01-welcome.png)
- [Supported-app introduction](02-apps-intro.png)
- [App selection](03-app-selection.png)
- [App selection with one app](04-app-selection-active.png)
- [Accessibility explanation](05-accessibility-explainer.png)
- [Accessibility consent](06-accessibility-consent.png)
- [Consent acknowledged](07-accessibility-consent-checked.png)
- [Return with access still off](08-accessibility-return-off.png)
- [Optional floating-counter setup](09-floating-counter.png)

## Today and access recovery

- [Today permission wall](24-today-permission-wall-verified.png)
- [Allow opens the in-app Settings destination](25-today-wall-allow-settings.png)
- [Dismissed wall becomes the top banner; Today remains usable](26-today-dismissed-access-banner.png)

The Allow route and X-to-banner behavior were checked on the AVD. The Today accessibility tree contained no access-check or detection-time fields.

## History

- [Empty Week](13-history-week-empty.png)
- [Empty Month](14-history-month-empty.png)
- [Week bars with labels](19-history-week-layout-fixture.png) — in-memory fixture
- [Month heatmap with count marks and intensity guide](20-history-month-layout-fixture.png) — in-memory fixture
- [Month totals by app](21-history-month-totals.png) — a separate in-memory fixture capture

## Settings

- [Settings top: limit, apps, access, debug control, floating counter, appearance](12-settings-top.png)
- [Settings lower groups](15-settings-bottom.png)
- [About and app version](16-settings-about.png)
- [In-app Privacy Policy](17-privacy-policy.png)
- [Daily limit editor](18-limit-editor.png)
- [App selection from Settings](22-settings-app-selection.png)
- [Appearance choices](23-appearance-options.png)

## Earlier captures

- [Earlier wall capture](10-today-permission-wall.png)
- [Earlier Today banner capture](11-today-banner.png)

These are retained as additional examples; screenshots 24–26 are the fresh behavior-check captures.
