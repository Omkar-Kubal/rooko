import 'package:flutter/material.dart';

/// Semantic type sizes shared with the CSS custom properties in
/// `web/global.css`.
abstract final class AppTypeScale {
  static const double xSmall = 12;
  static const double small = 14;
  static const double medium = 16;
  static const double large = 22;
  static const double xLarge = 28;
  static const double xxLarge = 32;
  static const double metric = 56;
}

/// Semantic text roles. Screens should use these roles instead of defining
/// local sizes and font weights.
abstract final class AppTypography {
  static const String fontFamily = 'Google Sans';
  static const String fallbackFontFamily = 'Roboto';
  static const List<String> fontFamilyFallback = [
    fallbackFontFamily,
    'sans-serif',
  ];

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: AppTypeScale.large,
    fontWeight: FontWeight.w600,
    height: 28 / 22,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: AppTypeScale.medium,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: AppTypeScale.medium,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: AppTypeScale.medium,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const TextStyle supporting = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: AppTypeScale.xSmall,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: AppTypeScale.small,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  );

  static const TextStyle metric = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: AppTypeScale.metric,
    fontWeight: FontWeight.w600,
    height: 62 / 56,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle chartLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: AppTypeScale.xSmall,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  static const TextTheme textTheme = TextTheme(
    displayLarge: metric,
    headlineLarge: pageTitle,
    headlineMedium: sectionTitle,
    titleLarge: pageTitle,
    titleMedium: cardTitle,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: supporting,
    labelLarge: button,
    labelMedium: button,
    labelSmall: chartLabel,
  );
}
