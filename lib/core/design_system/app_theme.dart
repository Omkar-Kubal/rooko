import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

enum AppAppearance { system, light, dark, amoled }

/// Material 3 themes built from the canonical Rooko design tokens.
abstract final class AppTheme {
  static final ThemeData light = _build(brightness: Brightness.light);
  static final ThemeData dark = _build(brightness: Brightness.dark);
  static final ThemeData amoledBlack = _build(
    brightness: Brightness.dark,
    amoled: true,
  );

  static ThemeData _build({
    required Brightness brightness,
    bool amoled = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final canvas = amoled
        ? AppColors.canvasAmoled
        : (isDark ? AppColors.canvasDark : AppColors.canvasLight);
    final surface = isDark
        ? (amoled ? AppColors.canvasAmoled : AppColors.surfaceDark)
        : AppColors.surfaceLight;
    final secondarySurface = isDark
        ? (amoled ? AppColors.canvasAmoled : AppColors.surfaceDarkSecondary)
        : AppColors.surfaceLightSecondary;
    final textColor = isDark ? AppColors.textOnDark : AppColors.ink;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final action = isDark ? AppColors.accentDark : AppColors.accentLight;
    final onAction = AppColors.textOnDark;
    final outline = isDark ? AppColors.outlineDark : AppColors.outlineLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: action,
            onPrimary: onAction,
            primaryContainer: action,
            onPrimaryContainer: onAction,
            secondary: action,
            onSecondary: onAction,
            secondaryContainer: action,
            onSecondaryContainer: onAction,
            tertiary: action,
            onTertiary: onAction,
            tertiaryContainer: action,
            onTertiaryContainer: onAction,
            error: action,
            onError: onAction,
            errorContainer: action,
            onErrorContainer: onAction,
            surface: surface,
            onSurface: textColor,
            surfaceDim: surface,
            surfaceBright: surface,
            surfaceContainerLowest: surface,
            surfaceContainerLow: surface,
            surfaceContainer: secondarySurface,
            surfaceContainerHigh: secondarySurface,
            surfaceContainerHighest: secondarySurface,
            onSurfaceVariant: secondaryText,
            outline: outline,
            outlineVariant: divider,
            inverseSurface: AppColors.textOnDark,
            onInverseSurface: AppColors.ink,
            inversePrimary: AppColors.ink,
            surfaceTint: Colors.transparent,
          )
        : ColorScheme.light(
            primary: action,
            onPrimary: onAction,
            primaryContainer: action,
            onPrimaryContainer: onAction,
            secondary: action,
            onSecondary: onAction,
            secondaryContainer: action,
            onSecondaryContainer: onAction,
            tertiary: action,
            onTertiary: onAction,
            tertiaryContainer: action,
            onTertiaryContainer: onAction,
            error: action,
            onError: onAction,
            errorContainer: action,
            onErrorContainer: onAction,
            surface: surface,
            onSurface: textColor,
            surfaceDim: surface,
            surfaceBright: surface,
            surfaceContainerLowest: surface,
            surfaceContainerLow: surface,
            surfaceContainer: secondarySurface,
            surfaceContainerHigh: secondarySurface,
            surfaceContainerHighest: secondarySurface,
            onSurfaceVariant: secondaryText,
            outline: outline,
            outlineVariant: divider,
            inverseSurface: AppColors.ink,
            onInverseSurface: AppColors.textOnDark,
            inversePrimary: AppColors.textOnDark,
            surfaceTint: Colors.transparent,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      canvasColor: surface,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      scaffoldBackgroundColor: canvas,
      dividerColor: divider,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: outline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
    );
  }
}
