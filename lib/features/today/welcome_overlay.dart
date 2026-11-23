import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';

/// Presents the one-time note as a modal sheet over Today.
Future<void> showWelcomeBottomSheet(BuildContext context) {
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    barrierColor: AppColors.scrim,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: reduceMotion
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 320),
            reverseDuration: Duration(milliseconds: 260),
          ),
    builder: (sheetContext) => const FractionallySizedBox(
      heightFactor: 0.86,
      child: WelcomeBottomSheet(),
    ),
  );
}

class WelcomeBottomSheet extends StatefulWidget {
  const WelcomeBottomSheet({super.key});

  @override
  State<WelcomeBottomSheet> createState() => _WelcomeBottomSheetState();
}

class _WelcomeBottomSheetState extends State<WelcomeBottomSheet>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _confetti;
  bool _reduceMotion = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      animationBehavior: AnimationBehavior.preserve,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_reduceMotion && _foreground) _confetti.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) _confetti.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _confetti.stop();
    } else if (!_reduceMotion && _confetti.value < 1) {
      _confetti.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Welcome to Rooko',
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: Stack(
        key: const ValueKey('new-user-welcome'),
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x6,
                    AppSpacing.x2,
                    AppSpacing.x6,
                    AppSpacing.x8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          key: const ValueKey('welcome-close'),
                          tooltip: 'Close welcome',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: AppIcon(
                            icon: AppIcons.closeCircle,
                            size: AppIconSizes.large,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      Center(
                        child: Semantics(
                          label: 'Rooko logo',
                          image: true,
                          child: Image.asset(
                            'assets/rook/rook-app-logo-transparent.png',
                            width: 104,
                            height: 104,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x8),
                      Text(
                        'Welcome to\nRooko',
                        textAlign: TextAlign.center,
                        style: AppTypography.pageTitle.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x8),
                      _Paragraph(
                        'Hey, this is Omkar, the developer behind Rooko.',
                        color: colors.onSurface,
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      _Paragraph(
                        'Thank you for giving Rooko a try. I would love to hear what you think.',
                        color: colors.onSurface,
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      _Paragraph(
                        'Rooko brings your Reels and Shorts count into one place. Rook reacts to the count, and Progress lets you look back at your day.',
                        color: colors.onSurface,
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      _Paragraph(
                        'Counting depends on the access you choose and a recognized feed. Your counts stay on this device. You can change your selected apps in Settings.',
                        color: colors.onSurface,
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      _Paragraph(
                        'If you have an idea or run into an issue, reach us through Settings > Help & Feedback > Support Email.',
                        color: colors.onSurface,
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      _Paragraph(
                        'We hope Rooko helps you see your day more clearly.',
                        color: colors.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x6,
                  AppSpacing.x3,
                  AppSpacing.x6,
                  AppSpacing.x6,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    key: const ValueKey('welcome-continue'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.onSurface,
                      foregroundColor: colors.surface,
                      shape: const StadiumBorder(),
                      textStyle: AppTypography.button,
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ],
          ),
          if (!_reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _confetti,
                    builder: (context, _) => CustomPaint(
                      key: const ValueKey('welcome-confetti'),
                      painter: _WelcomeConfettiPainter(
                        progress: _confetti.value,
                        foreground: colors.onSurface,
                        neutral: colors.onSurfaceVariant,
                      ),
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

class _WelcomeConfettiPainter extends CustomPainter {
  const _WelcomeConfettiPainter({
    required this.progress,
    required this.foreground,
    required this.neutral,
  });

  final double progress;
  final Color foreground;
  final Color neutral;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final random = math.Random(608);
    final colors = [AppColors.celebrationPink, foreground, neutral];
    for (var index = 0; index < 72; index++) {
      final startX = random.nextDouble() * size.width;
      final startY = -random.nextDouble() * 90;
      final drift = (random.nextDouble() - 0.5) * 105;
      final fall = size.height * (0.52 + random.nextDouble() * 0.38);
      final delay = random.nextDouble() * 0.22;
      final phase = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      final width = 3.0 + random.nextDouble() * 3.0;
      final height = 5.0 + random.nextDouble() * 6.0;
      final turn = (random.nextDouble() - 0.5) * math.pi * 3;
      final color = colors[index % colors.length];
      if (phase <= 0) continue;
      final opacity = ((1 - phase) / 0.38).clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      final x = startX + drift * phase + math.sin(phase * math.pi * 4) * 8;
      final y = startY + fall * Curves.easeIn.transform(phase);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(turn * phase);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: width, height: height),
        Paint()..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.foreground != foreground ||
      oldDelegate.neutral != neutral;
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.body.copyWith(color: color));
}
