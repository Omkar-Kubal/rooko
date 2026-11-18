# Rooko

Rooko is an Android app that counts recognized Instagram Reels and YouTube Shorts and shows local progress. Product scope and requirements live in [PRD.md](docs/PRD.md) and [SRS.md](docs/SRS.md). Daily limits are deferred.

Android is the product release target. Flutter web is enabled for the requested CSS token surface and browser previews; it is not a web product commitment.

## Setup

Requires Flutter 3.47 or later and Dart 3.13 or later.

```powershell
flutter pub get
flutter run -d <android-device>
```

To preview the design tokens in a browser:

```powershell
flutter run -d chrome
```

## Checks and builds

```powershell
dart format lib
flutter analyze
flutter build apk --debug
flutter build web
```

## Project map

- `lib/core/design_system/` — semantic colors, typography, Material themes, and HugeIcons registry.
- `lib/features/foundation/` — starter screen used to preview design tokens.
- `web/global.css` — CSS custom properties mirrored from Dart design tokens.
- `android/` — native Android host. Package ID: `com.appylab.rooko`.
- `.agents/skills/` — project-specific agent workflows.
- `analysis/brainpal/` — REA findings for the reference app; preserve this evidence.
