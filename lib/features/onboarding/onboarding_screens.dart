import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';
import '../../core/models/supported_app.dart';
import '../../core/platform/tracking_platform.dart';
import '../today/rook_state.dart';

const _rookLogoAsset = 'assets/rook/rook-app-logo-transparent.png';
const _rookReadyAsset = 'assets/rook/rook-ready.svg';

class CounterPreviewScreen extends StatefulWidget {
  const CounterPreviewScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<CounterPreviewScreen> createState() => _CounterPreviewScreenState();
}

class _CounterPreviewScreenState extends State<CounterPreviewScreen>
    with WidgetsBindingObserver {
  static const _previewCounts = [0, 22, 44, 77, 111, 133, 155, 177, 200, 211];
  static const _sceneLabels = [
    'Morning coffee',
    'City walk',
    'Slow afternoon',
    'On the move',
    'A small reset',
  ];
  static const _sceneAssets = [
    'assets/onboarding/counter-preview/morning-coffee.png',
    'assets/onboarding/counter-preview/city-walk.png',
    'assets/onboarding/counter-preview/quiet-lake.png',
    'assets/onboarding/counter-preview/cycle-path.png',
    'assets/onboarding/counter-preview/park-dog.png',
  ];
  static const _advanceInterval = Duration(milliseconds: 1350);
  static const _feedTransitionDuration = Duration(milliseconds: 420);

  final PageController _feedController = PageController();
  Timer? _advanceTimer;
  int _feedStep = 0;
  bool _isForeground = true;
  bool _reduceMotion = false;

  int get _count => _previewCounts[_feedStep % _previewCounts.length];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _syncAutoAdvance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    _syncAutoAdvance();
  }

  void _syncAutoAdvance() {
    final shouldAdvance = _isForeground && !_reduceMotion;
    if (shouldAdvance && _advanceTimer == null) {
      _advanceTimer = Timer.periodic(_advanceInterval, (_) => _advance());
    } else if (!shouldAdvance) {
      _advanceTimer?.cancel();
      _advanceTimer = null;
    }
  }

  void _advance({bool animate = true}) {
    if (!mounted) return;
    final nextStep = _feedStep + 1;
    setState(() => _feedStep = nextStep);
    if (!_feedController.hasClients) return;
    if (animate) {
      _feedController.animateToPage(
        nextStep,
        duration: _feedTransitionDuration,
        curve: Curves.easeInOutCubic,
      );
    } else {
      _feedController.jumpToPage(nextStep);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _advanceTimer?.cancel();
    _feedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pageHeight = MediaQuery.sizeOf(context).height;
    final safeHeight = MediaQuery.viewPaddingOf(context).vertical;
    final contentHeight =
        (pageHeight - safeHeight - 58.0 - 76.0 - AppSpacing.x3 - AppSpacing.x4)
            .clamp(400.0, 560.0)
            .toDouble();
    final phoneHeight = (contentHeight * 0.7).clamp(280.0, 390.0).toDouble();

    return OnboardingScaffold(
      leadingBrand: const _CounterPreviewBrand(),
      fitContentToViewport: true,
      primaryLabel: 'Get started',
      onPrimary: widget.onContinue,
      child: SizedBox(
        height: contentHeight,
        child: Column(
          children: [
            Semantics(
              header: true,
              child: Text(
                'See the counter in action.',
                textAlign: TextAlign.center,
                style: _onboardingTitle,
              ),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'An example of the count and Rook changing as you scroll.',
              textAlign: TextAlign.center,
              style: AppTypography.supporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Center(
                child: _CounterPreviewPhone(
                  height: phoneHeight,
                  feedController: _feedController,
                  count: _count,
                  sceneLabels: _sceneLabels,
                  sceneAssets: _sceneAssets,
                ),
              ),
            ),
            if (_reduceMotion)
              TextButton(
                onPressed: () => _advance(animate: false),
                child: const Text('Show next example'),
              ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PreviewAppLogo(
                  name: 'Instagram Reels',
                  asset: 'assets/supported-app-icons/instagram.png',
                ),
                SizedBox(width: AppSpacing.x3),
                _PreviewAppLogo(
                  name: 'YouTube Shorts',
                  asset: 'assets/supported-app-icons/youtube-shorts.png',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterPreviewBrand extends StatelessWidget {
  const _CounterPreviewBrand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        _rookLogoAsset,
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        semanticLabel: 'Rooko logo',
      ),
    ],
  );
}

class _PreviewAppLogo extends StatelessWidget {
  const _PreviewAppLogo({required this.name, required this.asset});

  final String name;
  final String asset;

  @override
  Widget build(BuildContext context) => Semantics(
    label: name,
    image: true,
    child: Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(AppSpacing.x2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class _CounterPreviewPhone extends StatelessWidget {
  const _CounterPreviewPhone({
    required this.height,
    required this.feedController,
    required this.count,
    required this.sceneLabels,
    required this.sceneAssets,
  });

  final double height;
  final PageController feedController;
  final int count;
  final List<String> sceneLabels;
  final List<String> sceneAssets;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final phoneWidth = height * 0.515;

    return Semantics(
      label:
          'Illustrative floating counter preview. The example count is $count.',
      child: ExcludeSemantics(
        child: Container(
          width: phoneWidth,
          height: height,
          padding: const EdgeInsets.all(AppSpacing.x1),
          decoration: BoxDecoration(
            color: colors.onSurface,
            borderRadius: BorderRadius.circular(AppRadii.sheet),
            border: Border.all(color: colors.outline, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: feedController,
                  scrollDirection: Axis.vertical,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) => _PreviewReelScene(
                    label: sceneLabels[index % sceneLabels.length],
                    asset: sceneAssets[index % sceneAssets.length],
                  ),
                ),
                Positioned(
                  top: AppSpacing.x2,
                  left: AppSpacing.x2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      border: Border.all(color: colors.outline),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2,
                        vertical: AppSpacing.x1,
                      ),
                      child: Text(
                        'PREVIEW',
                        style: AppTypography.chartLabel.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.x6,
                  left: 0,
                  right: 0,
                  child: Center(child: _PreviewCounter(count: count)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCounter extends StatelessWidget {
  const _PreviewCounter({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = RookState.fromCount(count);
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return SizedBox(
      width: 88,
      height: 110,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Image.asset(
            state.floatingCounterAsset,
            width: 76,
            height: 76,
            fit: BoxFit.contain,
          ),
          Positioned(
            top: 72,
            child: AnimatedSwitcher(
              duration: duration,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Container(
                key: ValueKey(count),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outline, width: 1),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.supporting.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: AppTypeScale.small,
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

class _PreviewReelScene extends StatelessWidget {
  const _PreviewReelScene({required this.label, required this.asset});

  final String label;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover, cacheWidth: 720),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x44000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0x88000000),
              ],
              stops: [0, 0.24, 0.58, 1],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.x3,
          right: AppSpacing.x3,
          bottom: AppSpacing.x3,
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.chartLabel.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class PermissionExplanationScreen extends StatelessWidget {
  const PermissionExplanationScreen({
    super.key,
    required this.selectedAppIds,
    required this.onBack,
    required this.onContinue,
    required this.onPrivacyPolicy,
  });

  final Set<String> selectedAppIds;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final privacyPolicyColor = colors.onSurface;
    final selectedFeeds = [
      if (selectedAppIds.contains('instagram')) 'Instagram Reels',
      if (selectedAppIds.contains('youtube')) 'YouTube Shorts',
    ];
    final feedDescription = switch (selectedFeeds) {
      [] =>
        'No feeds are selected yet. Choose Instagram or YouTube in Settings.',
      [final one] => '$one is selected for counting. Change this in Settings.',
      _ =>
        '${selectedFeeds.join(' and ')} are selected for counting. Change this in Settings.',
    };

    return OnboardingScaffold(
      onBack: onBack,
      primaryLabel: 'Continue',
      onPrimary: onContinue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'A clear count, with your content left alone.',
              textAlign: TextAlign.center,
              style: _onboardingTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            '$feedDescription Posts, messages, images, audio, and video are not saved.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x6),
          Center(
            child: Container(
              width: 274,
              height: 282,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.sheet),
                ),
                border: Border.all(color: colors.outlineVariant, width: 2),
              ),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.x4),
                  Container(
                    width: 66,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 150,
                    height: 145,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Semantics(
                          label: 'Ready Rook',
                          image: true,
                          child: SvgPicture.asset(
                            _rookReadyAsset,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                        Align(
                          alignment: const Alignment(0.72, 0.75),
                          child: AppIcon(
                            icon: AppIcons.lock,
                            size: AppIconSizes.large,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Center(
            child: Semantics(
              link: true,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: privacyPolicyColor,
                ),
                onPressed: onPrivacyPolicy,
                child: const Text('Privacy policy'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final AppIconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x1),
            child: AppIcon(
              icon: icon,
              size: AppIconSizes.large,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.cardTitle.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: AppTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PermissionActionScreen extends StatelessWidget {
  const PermissionActionScreen({
    super.key,
    required this.acknowledged,
    required this.onAcknowledgedChanged,
    required this.onBack,
    required this.onContinue,
    required this.onNotNow,
  });

  final bool acknowledged;
  final ValueChanged<bool> onAcknowledgedChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return OnboardingScaffold(
      onBack: onBack,
      primaryLabel: 'Continue',
      onPrimary: acknowledged ? onContinue : null,
      secondaryLabel: 'Not now',
      onSecondary: onNotNow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ready to turn tracking on?', style: _onboardingTitle),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Accessibility checks selected apps for a recognized Reel or Short feed and estimates time in short intervals while it stays in the foreground. Time checks use only app identity and feed-marker IDs; they do not read item labels. Instagram and YouTube may separately read brief visible labels to estimate item changes. A daily observed-time total stays on this device. This does not show whether a video played or was watched attentively, and feed content is not saved.',
            style: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x4),
          _DisclosureRow(
            icon: AppIcons.privacy,
            title: 'Your content isn’t saved',
            description: 'Post text, messages, images, audio, and video are not stored. Count and approximate observed-time totals stay on your device by default. Overlay access is not needed for time measurement.',
          ),
          _DisclosureRow(
            icon: AppIcons.accessSettings,
            title: 'You can turn it off anytime',
            description: 'Manage access in Android Settings → Accessibility.',
          ),
          const SizedBox(height: AppSpacing.x2),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: acknowledged,
            onChanged: (value) => onAcknowledgedChanged(value ?? false),
            title: Text(
              'I understand how this access would be used.',
              style: AppTypography.cardTitle.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class AccessUnavailableScreen extends StatelessWidget {
  const AccessUnavailableScreen({
    super.key,
    required this.trackingSnapshot,
    required this.floatingCounterOptIn,
    required this.overlayPermissionGranted,
    required this.onBack,
    required this.onContinue,
    required this.onOpenSettings,
    required this.onRequestOverlay,
    required this.onWhyAccess,
  });

  final TrackingSnapshot? trackingSnapshot;
  final bool floatingCounterOptIn;
  final bool overlayPermissionGranted;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onOpenSettings;
  final VoidCallback onRequestOverlay;
  final VoidCallback onWhyAccess;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accessOn =
        trackingSnapshot?.serviceEnabled == true &&
        trackingSnapshot?.consentAcknowledged == true;
    final serviceOperational = trackingSnapshot?.serviceOperational == true;
    return OnboardingScaffold(
      onBack: onBack,
      primaryLabel: 'Continue',
      onPrimary: onContinue,
      fitContentToViewport: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Text(
              !accessOn
                  ? 'Enable access to start counting'
                  : serviceOperational
                  ? 'Access is on'
                  : 'Access needs attention',
              textAlign: TextAlign.center,
              style: _onboardingTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            !accessOn
                ? 'You can skip this and turn it on later in Settings.'
                : !serviceOperational
                ? 'Reopen Accessibility settings to restart Rooko.'
                : 'Rooko is ready to watch for recognized feeds in your selected apps.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x6),
          _AccessStepRow(
            title: 'Accessibility',
            subtitle: accessOn
                ? serviceOperational
                      ? 'Access is on'
                      : 'Service needs to reconnect'
                : 'Recognizes selected Reels and Shorts feeds',
            granted: accessOn && serviceOperational,
            onAllow: accessOn && serviceOperational ? null : onOpenSettings,
          ),
          const SizedBox(height: AppSpacing.x2),
          _AccessStepRow(
            title: 'Floating counter',
            subtitle: accessOn
                ? 'Optional. Shows your combined count over recognized feeds.'
                : 'Optional. Turn on Accessibility first.',
            granted: overlayPermissionGranted && floatingCounterOptIn,
            onAllow:
                accessOn &&
                    serviceOperational &&
                    !(overlayPermissionGranted && floatingCounterOptIn)
                ? onRequestOverlay
                : null,
          ),
          const SizedBox(height: AppSpacing.x4),
          Center(
            child: TextButton.icon(
              onPressed: onWhyAccess,
              icon: AppIcon(
                icon: AppIcons.privacyCheck,
                size: AppIconSizes.standard,
                color: colors.onSurface,
              ),
              label: const Text('Why does Rooko need access?'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessStepRow extends StatelessWidget {
  const _AccessStepRow({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onAllow,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback? onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.cardTitle),
                Text(
                  subtitle,
                  style: AppTypography.supporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          if (granted)
            AppIcon(
              icon: AppIcons.success,
              size: AppIconSizes.large,
              color: colors.onSurface,
              semanticLabel: '$title on',
            )
          else if (onAllow != null)
            OutlinedButton(onPressed: onAllow, child: const Text('Allow'))
          else
            Text(
              'Next',
              style: AppTypography.supporting.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class FeedHandoffScreen extends StatelessWidget {
  const FeedHandoffScreen({
    super.key,
    required this.selectedAppIds,
    required this.trackingSnapshot,
    required this.onOpenApp,
    required this.onContinueToToday,
    required this.onBack,
  });

  final Set<String> selectedAppIds;
  final TrackingSnapshot? trackingSnapshot;
  final ValueChanged<String> onOpenApp;
  final VoidCallback onContinueToToday;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final launchApp =
        [SupportedApp.byId('instagram')!, SupportedApp.byId('youtube')!]
            .where(
              (app) =>
                  selectedAppIds.contains(app.id) &&
                  trackingSnapshot?.apps[app.id]?.installed == true,
            )
            .firstOrNull;
    final appLabel = launchApp?.id == 'instagram' ? 'Instagram' : 'YouTube';

    return OnboardingScaffold(
      onBack: onBack,
      fitContentToViewport: true,
      primaryLabel: launchApp == null ? 'Go to Today' : 'Open $appLabel',
      onPrimary: launchApp == null
          ? onContinueToToday
          : () => onOpenApp(launchApp.id),
      secondaryLabel: launchApp == null ? null : 'Go to Today',
      onSecondary: launchApp == null ? null : onContinueToToday,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ready to see your count?',
            textAlign: TextAlign.center,
            style: _onboardingTitle,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Open a selected Reels or Shorts feed. Rooko counts recognized item changes and shows your total in Today.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.x8),
          SizedBox(
            width: 260,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 260,
                  height: 170,
                  margin: const EdgeInsets.only(top: AppSpacing.x6),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Center(
                    child: launchApp == null
                        ? AppIcon(
                            icon: AppIcons.insight,
                            size: 72,
                            color: colors.onSurface,
                            semanticLabel: 'Combined count',
                          )
                        : Semantics(
                            label: launchApp.name,
                            image: true,
                            child: Image.asset(
                              launchApp.iconAsset,
                              width: 76,
                              height: 76,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 104,
                    height: 100,
                    child: Semantics(
                      label: 'Ready Rook',
                      image: true,
                      child: SvgPicture.asset(
                        _rookReadyAsset,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            launchApp == null
                ? 'You can choose and enable feeds later in Settings.'
                : 'Counting requires consent, Accessibility access, and a recognized feed.',
            textAlign: TextAlign.center,
            style: AppTypography.supporting.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.brandLabel,
    this.leadingBrand,
    this.onBack,
    this.fitContentToViewport = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? brandLabel;
  final Widget? leadingBrand;
  final VoidCallback? onBack;
  final bool fitContentToViewport;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  double _scrollContentMinHeight(BoxConstraints constraints) {
    if (!fitContentToViewport) return constraints.maxHeight - 58;

    final footerHeight =
        AppSpacing.x2 +
        56.0 +
        AppSpacing.x3 +
        (secondaryLabel == null ? 0.0 : AppSpacing.x1 + 48.0);
    final scrollPaddingHeight = AppSpacing.x3 + AppSpacing.x4;
    return (constraints.maxHeight - 58 - footerHeight - scrollPaddingHeight)
        .clamp(0.0, constraints.maxHeight)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              SizedBox(
                height: 58,
                child: leadingBrand == null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          if (onBack != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                tooltip: 'Back',
                                onPressed: onBack,
                                icon: AppIcon(
                                  icon: AppIcons.back,
                                  size: AppIconSizes.large,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (brandLabel != null)
                                Text(
                                  brandLabel!,
                                  style: AppTypography.cardTitle,
                                ),
                            ],
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x4,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: leadingBrand!,
                        ),
                      ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x6,
                    AppSpacing.x3,
                    AppSpacing.x6,
                    AppSpacing.x4,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: _scrollContentMinHeight(constraints),
                    ),
                    child: child,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x4,
                  AppSpacing.x3,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: onPrimary,
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                          textStyle: AppTypography.button,
                        ),
                        child: Text(primaryLabel),
                      ),
                    ),
                    if (secondaryLabel != null) ...[
                      const SizedBox(height: AppSpacing.x1),
                      TextButton(
                        onPressed: onSecondary,
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          textStyle: AppTypography.button,
                        ),
                        child: Text(secondaryLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle get _onboardingTitle => AppTypography.pageTitle.copyWith(
  fontSize: AppTypeScale.xxLarge,
  fontWeight: FontWeight.w700,
  height: 1.12,
);
