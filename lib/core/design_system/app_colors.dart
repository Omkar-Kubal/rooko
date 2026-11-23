import 'package:flutter/material.dart';

/// Canonical Rooko color palette.
///
/// Keep the matching CSS custom properties in `web/global.css` in sync with
/// these values. Flutter widgets should use semantic roles from this class,
/// not inline color literals.
abstract final class AppColors {
  static const Color canvasLight = Color(0xFFFFFFFF);
  static const Color canvasDark = Color(0xFF080808);
  static const Color canvasAmoled = Color(0xFF000000);
  static const Color ink = Color(0xFF000000);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textSecondaryLight = Color(0xFF595959);
  static const Color textSecondaryDark = Color(0xFFBDBDBD);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightSecondary = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF171717);
  static const Color surfaceDarkSecondary = Color(0xFF171717);

  static const Color accentLight = ink;
  static const Color accentDark = Color(0xFF303030);
  static const Color celebrationPink = Color(0xFFF5A0AD);

  // Outlines used for interactive controls meet 3:1 against their surfaces.
  static const Color outlineLight = Color(0xFF8A8A8A);
  static const Color outlineDark = Color(0xFF757575);
  static const Color dividerLight = Color(0xFFD9D9D9);
  static const Color dividerDark = Color(0xFF404040);

  static const Color scrim = Color(0xB8000000);
}

/// Shared layout spacing in logical pixels.
abstract final class AppSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x6 = 24;
  static const double x8 = 32;
}

/// Shared corner radii in logical pixels.
abstract final class AppRadii {
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;
}
