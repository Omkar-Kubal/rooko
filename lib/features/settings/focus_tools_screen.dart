import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';
import 'creator_shelf_screen.dart';

class FocusToolsScreen extends StatelessWidget {
  const FocusToolsScreen({super.key, required this.openInstagramProfile});

  final InstagramProfileOpener openInstagramProfile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
          icon: const AppIcon(
            icon: AppIcons.back,
            semanticLabel: 'Back',
            size: AppIconSizes.large,
          ),
        ),
        title: Text('Focus tools', style: AppTypography.pageTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x3,
          AppSpacing.x4,
          AppSpacing.x8,
        ),
        children: [
          Card(
            color: colors.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: ListTile(
              key: const ValueKey('focus-tools-creator-shelf'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x1,
              ),
              leading: const AppIcon(
                icon: AppIcons.creatorGroup,
                size: AppIconSizes.large,
              ),
              title: Text('Creator shelf', style: AppTypography.cardTitle),
              subtitle: Text(
                'Saved Instagram profiles',
                style: AppTypography.supporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              trailing: const AppIcon(icon: AppIcons.next),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CreatorShelfScreen(
                    openInstagramProfile: openInstagramProfile,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
