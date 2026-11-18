import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_typography.dart';

const _readyRookSvg = 'assets/rook/rook-ready.svg';
const _setupMessage = 'Before I start counting,\nlet’s set up access.';

class RookSetupIntroScreen extends StatefulWidget {
  const RookSetupIntroScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<RookSetupIntroScreen> createState() => _RookSetupIntroScreenState();
}

class _RookSetupIntroScreenState extends State<RookSetupIntroScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _transitionController;
  bool _reduceMotion = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
      animationBehavior: AnimationBehavior.preserve,
    );
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (_reduceMotion) {
      _transitionController.value = 1;
    } else if (!_isForeground) {
      _transitionController.stop();
    } else if (_transitionController.value < 1) {
      _transitionController.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final settledRingSize = math.min(
                constraints.maxWidth,
                math.min(270.0, constraints.maxHeight * 0.45),
              );
              final initialRingSize = math.min(
                constraints.maxWidth,
                math.min(390.0, constraints.maxHeight * 0.46),
              );
              final contentHeight = math.max(
                constraints.maxHeight,
                520 * textScale,
              );
              final initialGreetingTop = math.max(
                0.0,
                (contentHeight - 400 * textScale) * 0.24,
              );
              final titleOffset =
                  40 * textScale + math.max(0, 640 - contentHeight) * 0.4;

              return SingleChildScrollView(
                child: SizedBox(
                  height: contentHeight,
                  child: AnimatedBuilder(
                    animation: _transitionController,
                    builder: (context, _) {
                      final shift = Curves.easeInOutCubic.transform(
                        (_transitionController.value / 0.24).clamp(0.0, 1.0),
                      );
                      final previousCopyOpacity = 1 - 0.74 * shift;
                      final newCopyOpacity =
                          ((_transitionController.value - 0.12) / 0.35).clamp(
                            0.0,
                            1.0,
                          );
                      final okayOpacity = Curves.easeOut.transform(
                        ((_transitionController.value - 0.08) / 0.16).clamp(
                          0.0,
                          1.0,
                        ),
                      );
                      final ringSize =
                          initialRingSize * (1 - shift) +
                          settledRingSize * shift;
                      final rookSize =
                          initialRingSize * 0.36 * (1 - shift) +
                          settledRingSize * 0.56 * shift;
                      final letterProgress =
                          ((_transitionController.value - 0.18) / 0.82).clamp(
                            0.0,
                            1.0,
                          );
                      final visibleCount =
                          (letterProgress * _setupMessage.length).floor();

                      return Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Spacer(flex: 2),
                              Transform.translate(
                                offset: Offset(0, titleOffset),
                                child: Opacity(
                                  key: const ValueKey('setup-new-copy-opacity'),
                                  opacity: newCopyOpacity,
                                  child: Semantics(
                                    header: true,
                                    label: _setupMessage.replaceAll('\n', ' '),
                                    child: ExcludeSemantics(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: _setupMessage.substring(
                                                0,
                                                visibleCount,
                                              ),
                                            ),
                                            TextSpan(
                                              text: _setupMessage.substring(
                                                visibleCount,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.transparent,
                                              ),
                                            ),
                                          ],
                                        ),
                                        key: const ValueKey(
                                          'setup-intro-message',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: AppTypography.pageTitle.copyWith(
                                          color: colors.onSurface,
                                          fontSize: AppTypeScale.large,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Center(
                                child: SizedBox.square(
                                  dimension: ringSize,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: ExcludeSemantics(
                                          child: CustomPaint(
                                            painter: _SetupOrbitPainter(
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Semantics(
                                        label: 'Ready Rook',
                                        image: true,
                                        child: SvgPicture.asset(
                                          _readyRookSvg,
                                          width: rookSize,
                                          height: rookSize,
                                          fit: BoxFit.contain,
                                          excludeFromSemantics: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(flex: 2),
                              SizedBox(
                                height: 56,
                                child: Opacity(
                                  key: const ValueKey('setup-okay-opacity'),
                                  opacity: okayOpacity,
                                  child: IgnorePointer(
                                    ignoring: okayOpacity < 0.99,
                                    child: ExcludeSemantics(
                                      excluding: okayOpacity < 0.99,
                                      child: FilledButton(
                                        onPressed: widget.onContinue,
                                        style: FilledButton.styleFrom(
                                          shape: const StadiumBorder(),
                                          textStyle: AppTypography.button,
                                        ),
                                        child: const Text('Okay'),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: initialGreetingTop * (1 - shift),
                            child: Opacity(
                              key: const ValueKey('setup-greeting-opacity'),
                              opacity: previousCopyOpacity,
                              child: Semantics(
                                header: true,
                                child: Text(
                                  "I'm Rook",
                                  key: const ValueKey('setup-rook-greeting'),
                                  textAlign: TextAlign.center,
                                  style: AppTypography.supporting.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top:
                                (initialGreetingTop + 38 * textScale) *
                                    (1 - shift) +
                                40 * textScale * shift,
                            child: Opacity(
                              key: const ValueKey('setup-explanation-opacity'),
                              opacity: previousCopyOpacity,
                              child: Text(
                                'I count your Reels and Shorts so you can see your day clearly.',
                                key: const ValueKey('setup-count-explanation'),
                                textAlign: TextAlign.center,
                                style: AppTypography.pageTitle.copyWith(
                                  color: colors.onSurface,
                                  fontSize:
                                      AppTypeScale.xLarge +
                                      (AppTypeScale.large -
                                              AppTypeScale.xLarge) *
                                          shift,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SetupOrbitPainter extends CustomPainter {
  const _SetupOrbitPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final diameter = size.shortestSide;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var ring = 0; ring < 4; ring++) {
      final radius = diameter * (0.34 + ring * 0.035);
      final dotCount = 50 + ring * 6;
      paint.color = color.withValues(alpha: 0.38 + ring * 0.08);
      for (var dot = 0; dot < dotCount; dot++) {
        final angle = math.pi * 2 * dot / dotCount;
        canvas.drawCircle(
          Offset(
            center.dx + math.cos(angle) * radius,
            center.dy + math.sin(angle) * radius,
          ),
          diameter * 0.0065,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SetupOrbitPainter oldDelegate) =>
      oldDelegate.color != color;
}
