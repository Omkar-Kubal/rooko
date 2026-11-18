import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/core/design_system/app_colors.dart';
import 'package:rooko/core/design_system/app_theme.dart';

double _contrast(Color a, Color b) {
  final light = a.computeLuminance() > b.computeLuminance() ? a : b;
  final dark = identical(light, a) ? b : a;
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}

void main() {
  test('light, dark, and AMOLED use the approved monochrome surfaces', () {
    expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    expect(AppTheme.light.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(AppTheme.light.colorScheme.primary, const Color(0xFF000000));
    expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF080808));
    expect(AppTheme.dark.colorScheme.surface, const Color(0xFF171717));
    expect(AppTheme.amoledBlack.scaffoldBackgroundColor, Colors.black);
    expect(AppTheme.amoledBlack.colorScheme.surface, Colors.black);
  });

  test('supporting text meets AA contrast on its theme surface', () {
    for (final theme in [AppTheme.light, AppTheme.dark, AppTheme.amoledBlack]) {
      expect(
        _contrast(
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.surface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(theme.colorScheme.outline, theme.colorScheme.surface),
        greaterThanOrEqualTo(3),
      );
    }
  });

  test('every shared UI palette color is achromatic', () {
    final colors = <Color>[
      AppColors.canvasLight,
      AppColors.canvasDark,
      AppColors.canvasAmoled,
      AppColors.surfaceLight,
      AppColors.surfaceDark,
      AppColors.ink,
      AppColors.textSecondaryLight,
      AppColors.textSecondaryDark,
      AppColors.outlineLight,
      AppColors.outlineDark,
    ];
    for (final theme in [AppTheme.light, AppTheme.dark, AppTheme.amoledBlack]) {
      final scheme = theme.colorScheme;
      colors.addAll([
        scheme.primary,
        scheme.primaryContainer,
        scheme.secondary,
        scheme.secondaryContainer,
        scheme.tertiary,
        scheme.error,
        scheme.errorContainer,
        scheme.surface,
        scheme.surfaceContainer,
        scheme.inverseSurface,
        scheme.inversePrimary,
      ]);
    }
    for (final color in colors) {
      final rgb = color.toARGB32();
      expect((rgb >> 16) & 0xff, (rgb >> 8) & 0xff);
      expect((rgb >> 8) & 0xff, rgb & 0xff);
    }
  });

  test('CSS preview tokens mirror the Dart palette', () {
    final css = File('web/global.css').readAsStringSync().toLowerCase();
    final roles = {
      '--color-canvas': AppColors.canvasLight,
      '--color-canvas-dark': AppColors.canvasDark,
      '--color-canvas-amoled': AppColors.canvasAmoled,
      '--color-ink': AppColors.ink,
      '--color-on-dark': AppColors.textOnDark,
      '--color-text-secondary-light': AppColors.textSecondaryLight,
      '--color-text-secondary-dark': AppColors.textSecondaryDark,
      '--color-surface-light': AppColors.surfaceLight,
      '--color-surface-light-secondary': AppColors.surfaceLightSecondary,
      '--color-surface-dark': AppColors.surfaceDark,
      '--color-surface-dark-secondary': AppColors.surfaceDarkSecondary,
      '--color-accent-light': AppColors.accentLight,
      '--color-accent-dark': AppColors.accentDark,
      '--color-outline-light': AppColors.outlineLight,
      '--color-outline-dark': AppColors.outlineDark,
      '--color-divider-light': AppColors.dividerLight,
      '--color-divider-dark': AppColors.dividerDark,
    };
    for (final entry in roles.entries) {
      final hex = entry.value.toARGB32().toRadixString(16).substring(2);
      expect(css, contains('${entry.key}: #$hex;'));
    }
  });
}
