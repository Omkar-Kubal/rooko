import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_typography.dart';
import 'onboarding_screens.dart';

/// A quiet handoff from the story to the practical feed setup.
class RookPrivacyBridgeScreen extends StatefulWidget {
  const RookPrivacyBridgeScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  State<RookPrivacyBridgeScreen> createState() =>
      _RookPrivacyBridgeScreenState();
}

class _RookPrivacyBridgeScreenState extends State<RookPrivacyBridgeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _reveal;
  bool _reduceMotion = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isForeground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      animationBehavior: AnimationBehavior.preserve,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _reveal.value = 1;
    } else if (_isForeground && _reveal.value < 1) {
      _reveal.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _reveal.stop();
    } else if (!_reduceMotion && _reveal.value < 1) {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OnboardingScaffold(
      onBack: widget.onBack,
      fitContentToViewport: true,
      primaryLabel: 'Continue',
      onPrimary: widget.onContinue,
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          final progress = _reveal.value;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                key: const ValueKey('privacy-bridge-heading-opacity'),
                opacity: Curves.easeOut.transform((progress * 1.7).clamp(0, 1)),
                child: Text(
                  'Keep the count in sight.',
                  textAlign: TextAlign.center,
                  style: AppTypography.pageTitle.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Opacity(
                opacity: ((progress - 0.18) * 1.6).clamp(0, 1),
                child: Text(
                  'Rook shows what Rooko counts in your selected feeds.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x8),
              Semantics(
                label: 'Ready Rook within a dotted shield',
                image: true,
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 292,
                    height: 310,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(292, 310),
                          painter: _DottedShieldPainter(
                            progress: progress,
                            color: colors.onSurface,
                          ),
                        ),
                        SizedBox(
                          width: 136,
                          height: 132,
                          child: SvgPicture.asset(
                            'assets/rook/rook-ready.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DottedShieldPainter extends CustomPainter {
  const _DottedShieldPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (var ring = 0; ring < 4; ring++) {
      final inset = 9.0 + ring * 8;
      final left = inset;
      final right = size.width - inset;
      final top = inset;
      final bottom = size.height - inset;
      final centerX = size.width / 2;
      final shoulderY = top + 54;
      final sideEndY = top + (bottom - top) * 0.62;
      final path = Path()
        ..moveTo(centerX, top)
        ..cubicTo(right - 42, top, right, top + 22, right, shoulderY)
        ..lineTo(right, sideEndY)
        ..cubicTo(
          right,
          bottom - 62,
          centerX + 48,
          bottom - 20,
          centerX,
          bottom,
        )
        ..cubicTo(centerX - 48, bottom - 20, left, bottom - 62, left, sideEndY)
        ..lineTo(left, shoulderY)
        ..cubicTo(left, top + 22, left + 42, top, centerX, top)
        ..close();
      final metric = path.computeMetrics().first;
      for (var dot = 0; dot < 92; dot++) {
        final t = dot / 92;
        final arrival = ((progress - t * 0.52 - ring * 0.055) * 2.5).clamp(
          0.0,
          1.0,
        );
        if (arrival == 0) continue;
        final point = metric.getTangentForOffset(t * metric.length)!.position;
        canvas.drawCircle(
          point,
          1.15 + ring * 0.16,
          Paint()
            ..color = color.withValues(alpha: arrival * (0.72 - ring * 0.12)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedShieldPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
