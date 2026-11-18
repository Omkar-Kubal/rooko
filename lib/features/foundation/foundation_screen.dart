import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/app_typography.dart';

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({
    super.key,
    required this.previewTheme,
    required this.onPreviewThemeChanged,
  });

  final AppAppearance previewTheme;
  final ValueChanged<AppAppearance> onPreviewThemeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooko'),
        actions: [
          PopupMenuButton<AppAppearance>(
            tooltip: 'Preview theme',
            initialValue: previewTheme,
            onSelected: onPreviewThemeChanged,
            icon: const AppIcon(icon: AppIcons.settings),
            itemBuilder: (context) => [
              for (final mode in AppAppearance.values)
                PopupMenuItem(value: mode, child: Text(_themeName(mode))),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: [
                _PreviewNotice(colorScheme: colorScheme),
                const SizedBox(height: AppSpacing.x6),
                Text('Design system', style: AppTypography.pageTitle),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'A compact preview of Rooko’s shared type, color, and icon tokens.',
                  style: AppTypography.body.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),
                _MetricPreview(colorScheme: colorScheme),
                const SizedBox(height: AppSpacing.x6),
                Text('Color roles', style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.x2),
                _ColorSwatches(colorScheme: colorScheme),
                const SizedBox(height: AppSpacing.x6),
                Text('Icon registry', style: AppTypography.sectionTitle),
                const SizedBox(height: AppSpacing.x2),
                _IconSamples(colorScheme: colorScheme),
                const SizedBox(height: AppSpacing.x6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _themeName(AppAppearance theme) => switch (theme) {
    AppAppearance.system => 'System theme',
    AppAppearance.light => 'Light theme',
    AppAppearance.dark => 'Dark theme',
    AppAppearance.amoled => 'AMOLED theme',
  };
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(
              icon: AppIcons.insight,
              size: AppIconSizes.standard,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Foundation preview', style: AppTypography.cardTitle),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'Tracking and product data are not connected.',
                    style: AppTypography.supporting.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPreview extends StatelessWidget {
  const _MetricPreview({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Typography scale', style: AppTypography.cardTitle),
            const SizedBox(height: AppSpacing.x3),
            Text('56', style: AppTypography.metric),
            Text(
              '56 sp metric sample · type scale only',
              style: AppTypography.supporting.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final roles = [
      ('Canvas', Theme.of(context).scaffoldBackgroundColor),
      ('Surface', colorScheme.surfaceContainer),
      ('Ink', AppColors.ink),
      ('Progress', colorScheme.secondary),
      ('Supporting text', colorScheme.onSurfaceVariant),
      ('Outline', colorScheme.outline),
      ('Divider', colorScheme.outlineVariant),
    ];

    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: [
        for (final (label, color) in roles)
          _ColorRole(label: label, color: color),
      ],
    );
  }
}

class _ColorRole extends StatelessWidget {
  const _ColorRole({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;

    return Container(
      width: 108,
      padding: const EdgeInsets.all(AppSpacing.x2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadii.card / 2),
              border: Border.all(color: borderColor),
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(label, style: AppTypography.supporting),
        ],
      ),
    );
  }
}

class _IconSamples extends StatelessWidget {
  const _IconSamples({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    const samples = [
      (AppIcons.home, 'Home'),
      (AppIcons.progress, 'Progress'),
      (AppIcons.settings, 'Settings'),
      (AppIcons.privacy, 'Privacy'),
      (AppIcons.permission, 'Permission'),
      (AppIcons.success, 'Success'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Wrap(
          spacing: AppSpacing.x6,
          runSpacing: AppSpacing.x4,
          children: [
            for (final (icon, label) in samples)
              SizedBox(
                width: 72,
                child: Column(
                  children: [
                    AppIcon(
                      icon: icon,
                      size: AppIconSizes.standard,
                      color: colorScheme.onSurface,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTypography.supporting,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
