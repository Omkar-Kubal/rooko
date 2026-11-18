import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';
import 'local_release_notes.dart';

enum HelpFeedbackAction { troubleshoot, featureRequest, supportEmail }

Future<void> showWhatsNewSheet(
  BuildContext context, {
  required String appVersion,
}) async {
  final notes = LocalReleaseNotes.forVersion(appVersion);
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x2,
        AppSpacing.x6,
        AppSpacing.x8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("What's New", style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.x1),
          Text('Version $appVersion', style: AppTypography.supporting),
          const SizedBox(height: AppSpacing.x4),
          if (notes.isEmpty)
            Text(
              'No release notes are bundled for this version.',
              style: AppTypography.body,
            )
          else
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: AppIcon(icon: AppIcons.check),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(child: Text(note, style: AppTypography.body)),
                  ],
                ),
              ),
          const SizedBox(height: AppSpacing.x2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<HelpFeedbackAction?> showHelpFeedbackSheet(BuildContext context) =>
    showModalBottomSheet<HelpFeedbackAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x2,
          AppSpacing.x4,
          AppSpacing.x6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
              child: Text('Help & Feedback', style: AppTypography.sectionTitle),
            ),
            const SizedBox(height: AppSpacing.x1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
              child: Text(
                'What would you like to do?',
                style: AppTypography.supporting,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            _HelpActionTile(
              icon: AppIcons.help,
              title: 'Troubleshoot counting',
              subtitle: 'Check setup and find recovery steps',
              onTap: () =>
                  Navigator.of(sheetContext)
                      .pop(HelpFeedbackAction.troubleshoot),
            ),
            _HelpActionTile(
              icon: AppIcons.featureRequest,
              title: 'Feature Requests',
              subtitle: 'Suggest an improvement by email',
              onTap: () =>
                  Navigator.of(sheetContext)
                      .pop(HelpFeedbackAction.featureRequest),
            ),
            _HelpActionTile(
              icon: AppIcons.email,
              title: 'Support Email',
              subtitle: 'Contact Rooko support',
              onTap: () =>
                  Navigator.of(sheetContext)
                      .pop(HelpFeedbackAction.supportEmail),
            ),
          ],
        ),
      ),
    );

class _HelpActionTile extends StatelessWidget {
  const _HelpActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final AppIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
    leading: AppIcon(icon: icon, size: AppIconSizes.standard),
    title: Text(title, style: AppTypography.cardTitle),
    subtitle: Text(subtitle, style: AppTypography.supporting),
    trailing: const AppIcon(icon: AppIcons.next),
    onTap: onTap,
  );
}
