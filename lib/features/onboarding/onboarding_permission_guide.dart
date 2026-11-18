import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';

enum OnboardingPermissionKind { accessibility, overlay }

Future<bool> showOnboardingPermissionGuide(
  BuildContext context,
  OnboardingPermissionKind kind,
) async {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: reduceMotion
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 280),
            reverseDuration: Duration(milliseconds: 260),
          ),
    builder: (context) => _PermissionGuide(kind: kind),
  );
  return result == true;
}

class _PermissionGuide extends StatelessWidget {
  const _PermissionGuide({required this.kind});

  final OnboardingPermissionKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accessibility = kind == OnboardingPermissionKind.accessibility;
    final title = accessibility
        ? 'Turn on Accessibility for counting'
        : 'Show the floating counter over apps';
    final steps = accessibility
        ? const [
            'Open Android Accessibility settings.',
            'Find Rooko under downloaded apps.',
            'Turn on its service and confirm Android’s prompt.',
          ]
        : const [
            'Open Android’s display-over-other-apps settings.',
            'Find Rooko and allow the overlay.',
            'Return here so Rooko can check the grant.',
          ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x1,
        AppSpacing.x6,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x6,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppIcon(
              icon: accessibility ? AppIcons.permission : AppIcons.phone,
              size: 40,
              color: colors.onSurface,
              semanticLabel: accessibility
                  ? 'Accessibility settings'
                  : 'Display over other apps settings',
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(title, style: AppTypography.pageTitle),
            const SizedBox(height: AppSpacing.x2),
            Text(
              accessibility
                  ? 'Rooko needs this access to recognize selected Reels and Shorts feeds. You can turn it off in Android Settings.'
                  : 'This optional access shows the counter on a recognized feed. Counting can work without the floating counter.',
              style: AppTypography.body.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            for (var index = 0; index < steps.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.onSurface,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: AppTypography.supporting.copyWith(
                          color: colors.surface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(
                      child: Text(steps[index], style: AppTypography.body),
                    ),
                  ],
                ),
              ),
            Text(
              'Android settings may look different on your device.',
              style: AppTypography.supporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Open Android settings'),
              ),
            ),
            const SizedBox(height: AppSpacing.x1),
            SizedBox(
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
