import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_typography.dart';

const _readyRookSvg = 'assets/rook/rook-ready.svg';

enum RookIntroPhase { gathering, revealed }

class RookIntroScreen extends StatefulWidget {
  const RookIntroScreen({
    super.key,
    this.phase = RookIntroPhase.gathering,
    required this.onContinue,
  });

  final RookIntroPhase phase;
  final VoidCallback onContinue;

  @override
  State<RookIntroScreen> createState() => _RookIntroScreenState();
}

class _RookIntroScreenState extends State<RookIntroScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _gatherController;
  late final AnimationController _orbitController;
  late final AnimationController _revealController;
  late final AnimationController _handoffController;
  bool _isForeground = true;
  bool _reduceMotion = false;
  bool _handoffPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gatherController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
          value: widget.phase == RookIntroPhase.revealed ? 1 : 0,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _syncMotion();
        });
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
      animationBehavior: AnimationBehavior.preserve,
      value: widget.phase == RookIntroPhase.revealed ? 1 : 0,
    );
    _handoffController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed &&
              _handoffPending &&
              widget.phase == RookIntroPhase.revealed) {
            _handoffPending = false;
            widget.onContinue();
          }
        });
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
  void didUpdateWidget(covariant RookIntroScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase &&
        widget.phase == RookIntroPhase.gathering) {
      _handoffPending = false;
      _handoffController.value = 0;
    }
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (_reduceMotion) {
      _gatherController.value = 1;
      _revealController.value = widget.phase == RookIntroPhase.revealed ? 1 : 0;
      _orbitController.stop();
      if (_handoffPending) _handoffController.value = 1;
      return;
    }
    if (!_isForeground) {
      _gatherController.stop();
      _revealController.stop();
      _orbitController.stop();
      _handoffController.stop();
      return;
    }
    if (widget.phase == RookIntroPhase.revealed) {
      if (_revealController.status != AnimationStatus.forward &&
          _revealController.value < 1) {
        _revealController.forward();
      }
    } else {
      if (_revealController.status != AnimationStatus.reverse &&
          _revealController.value > 0) {
        _revealController.reverse();
      }
    }
    if (_gatherController.value < 1) {
      if (!_gatherController.isAnimating) _gatherController.forward();
      _orbitController.stop();
    } else if (!_orbitController.isAnimating) {
      _orbitController.repeat();
    }
    if (_handoffPending && _handoffController.value < 1) {
      _handoffController.forward();
    }
  }

  void _startHandoff() {
    if (_handoffPending || widget.phase != RookIntroPhase.revealed) return;
    if (_reduceMotion) {
      widget.onContinue();
      return;
    }
    _handoffPending = true;
    _handoffController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gatherController.dispose();
    _orbitController.dispose();
    _revealController.dispose();
    _handoffController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final revealed = widget.phase == RookIntroPhase.revealed;

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: revealed ? null : widget.onContinue,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final orbitSize = math.min(
                  constraints.maxWidth,
                  math.min(390.0, constraints.maxHeight * 0.46),
                );
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(flex: 2),
                          SizedBox(
                            height:
                                150 * MediaQuery.textScalerOf(context).scale(1),
                            child: AnimatedBuilder(
                              animation: _revealController,
                              builder: (context, _) {
                                final progress = Curves.easeInOutCubic
                                    .transform(_revealController.value);
                                final copyProgress = Curves.easeOutCubic
                                    .transform(
                                      ((_revealController.value - 0.28) / 0.72)
                                          .clamp(0.0, 1.0),
                                    );
                                final gatheringStyle = AppTypography.pageTitle
                                    .copyWith(
                                      color: colors.onSurface,
                                      fontSize: AppTypeScale.xLarge,
                                    );
                                final revealedStyle = AppTypography.supporting
                                    .copyWith(color: colors.onSurfaceVariant);
                                return Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(0, 38 * (1 - progress)),
                                      child: Semantics(
                                        header: true,
                                        child: Text(
                                          "I'm Rook",
                                          key: const ValueKey('rook-greeting'),
                                          textAlign: TextAlign.center,
                                          style: TextStyle.lerp(
                                            gatheringStyle,
                                            revealedStyle,
                                            progress,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top:
                                          38 *
                                          MediaQuery.textScalerOf(context)
                                              .scale(1),
                                      left: 0,
                                      right: 0,
                                      child: Transform.translate(
                                        offset: Offset(
                                          0,
                                          12 * (1 - copyProgress),
                                        ),
                                        child: Opacity(
                                          key: const ValueKey(
                                            'rook-count-copy-opacity',
                                          ),
                                          opacity: copyProgress,
                                          child: ExcludeSemantics(
                                            excluding: copyProgress < 1,
                                            child: Text(
                                              'I count your Reels and Shorts so you can see your day clearly.',
                                              key: const ValueKey(
                                                'rook-count-explanation',
                                              ),
                                              textAlign: TextAlign.center,
                                              style: AppTypography.pageTitle
                                                  .copyWith(
                                                    color: colors.onSurface,
                                                    fontSize:
                                                        AppTypeScale.xLarge,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: SizedBox.square(
                              dimension: orbitSize,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: ExcludeSemantics(
                                      child: CustomPaint(
                                        painter: _GatheringRookOrbitPainter(
                                          gathering: _gatherController,
                                          orbit: _orbitController,
                                          reveal: _revealController,
                                          color: colors.onSurfaceVariant,
                                          viewportSize: MediaQuery.sizeOf(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  AnimatedBuilder(
                                    animation: _revealController,
                                    builder: (context, _) => Semantics(
                                      label: revealed
                                          ? 'Ready Rook'
                                          : 'Blurred Rook',
                                      image: true,
                                      child: ImageFiltered(
                                        imageFilter: ui.ImageFilter.blur(
                                          sigmaX:
                                              7 * (1 - _revealController.value),
                                          sigmaY:
                                              7 * (1 - _revealController.value),
                                        ),
                                        child: SvgPicture.asset(
                                          _readyRookSvg,
                                          width: orbitSize * 0.36,
                                          height: orbitSize * 0.36,
                                          fit: BoxFit.contain,
                                          excludeFromSemantics: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(flex: 2),
                          SizedBox(
                            height: 56,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                _revealController,
                                _handoffController,
                              ]),
                              builder: (context, _) {
                                final reveal = _revealController.value;
                                final tapOpacity =
                                    1 -
                                    Curves.easeInOut.transform(
                                      (reveal / 0.20).clamp(0.0, 1.0),
                                    );
                                final hiEntrance = Curves.easeOut.transform(
                                  ((reveal - 0.45) / 0.55).clamp(0.0, 1.0),
                                );
                                final hiOpacity =
                                    hiEntrance *
                                    (1 -
                                        Curves.easeInOut.transform(
                                          _handoffController.value,
                                        ));
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Opacity(
                                      key: const ValueKey(
                                        'rook-tap-action-opacity',
                                      ),
                                      opacity: tapOpacity,
                                      child: IgnorePointer(
                                        ignoring: revealed || tapOpacity < 0.99,
                                        child: ExcludeSemantics(
                                          excluding:
                                              revealed || tapOpacity < 0.99,
                                          child: Center(
                                            child: TextButton(
                                              onPressed: widget.onContinue,
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    colors.onSurfaceVariant,
                                                minimumSize: const Size(
                                                  160,
                                                  48,
                                                ),
                                              ),
                                              child: Text(
                                                'Tap to continue',
                                                style: AppTypography.supporting
                                                    .copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Opacity(
                                      key: const ValueKey(
                                        'rook-hi-action-opacity',
                                      ),
                                      opacity: hiOpacity,
                                      child: IgnorePointer(
                                        ignoring:
                                            !revealed ||
                                            hiOpacity < 0.99 ||
                                            _handoffPending,
                                        child: ExcludeSemantics(
                                          excluding:
                                              !revealed || hiOpacity < 0.99,
                                          child: FilledButton(
                                            onPressed: _startHandoff,
                                            style: FilledButton.styleFrom(
                                              shape: const StadiumBorder(),
                                              textStyle: AppTypography.button,
                                            ),
                                            child: const Text('Hi, Rook'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GatheringRookOrbitPainter extends CustomPainter {
  _GatheringRookOrbitPainter({
    required this.gathering,
    required this.orbit,
    required this.reveal,
    required this.color,
    required this.viewportSize,
  }) : super(repaint: Listenable.merge([gathering, orbit, reveal]));

  final Animation<double> gathering;
  final Animation<double> orbit;
  final Animation<double> reveal;
  final Color color;
  final Size viewportSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final diameter = size.shortestSide;
    final dotRadius = diameter * 0.0048;
    final progress = Curves.easeInOutCubic.transform(gathering.value);
    final energy = Curves.easeOutCubic.transform(reveal.value);
    final paint = Paint()..style = PaintingStyle.fill;
    final extraX = math.max(0.0, (viewportSize.width - size.width) / 2);
    final extraY = math.max(0.0, (viewportSize.height - size.height) / 2);

    for (var ring = 0; ring < 6; ring++) {
      final radius = diameter * (0.22 + ring * 0.044);
      final dotCount = 76 + ring * 9;
      final direction = ring.isEven ? 1.0 : -1.0;
      final rotation = orbit.value * math.pi * 2 * direction / (ring + 1);

      for (var dot = 0; dot < dotCount; dot++) {
        final angle =
            math.pi * 2 * dot / dotCount +
            rotation +
            energy * math.sin(dot * 0.31 + orbit.value * math.pi * 4) * 0.11;
        final pulse = math.sin(dot * 0.53 + orbit.value * math.pi * 6);
        final target = Offset(
          center.dx + math.cos(angle) * radius * (1 + energy * pulse * 0.09),
          center.dy + math.sin(angle) * radius * (1 + energy * pulse * 0.09),
        );
        final corner = dot % 4;
        final insetX = diameter * (0.02 + 0.34 * ((dot * 37 % 97) / 97));
        final insetY = diameter * (0.02 + 0.34 * ((dot * 53 % 89) / 89));
        final start = Offset(
          corner == 0 || corner == 2
              ? insetX - extraX
              : size.width + extraX - insetX,
          corner == 0 || corner == 1
              ? insetY - extraY
              : size.height + extraY - insetY,
        );
        final wave = (1 + math.cos(angle - orbit.value * math.pi * 2)) / 2;
        paint.color = color.withValues(alpha: 0.20 + 0.58 * wave);
        final path = Offset.lerp(start, target, progress)!;
        final bend = math.sin(progress * math.pi) * diameter * 0.20;
        canvas.drawCircle(
          path + Offset(-math.sin(angle), math.cos(angle)) * bend,
          dotRadius * (0.75 + (dot % 4) * 0.17),
          paint,
        );
      }
    }

    for (var dot = 0; dot < 260; dot++) {
      final angle = dot * 2.399963229728653 + orbit.value * math.pi * 3;
      final radius =
          diameter * (0.12 + (dot * 29 % 97) / 97 * (0.50 + energy * 0.18));
      final corner = dot % 4;
      final start = Offset(
        corner == 0 || corner == 2 ? -extraX : size.width + extraX,
        corner == 0 || corner == 1 ? -extraY : size.height + extraY,
      );
      final target = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final stagger = (dot * 13 % 71) / 71 * 0.35;
      final arrival = Curves.easeOut.transform(
        ((progress - stagger) / (1 - stagger)).clamp(0.0, 1.0),
      );
      if (arrival <= 0) continue;
      paint.color = color.withValues(alpha: (0.16 + energy * 0.22) * arrival);
      canvas.drawCircle(
        Offset.lerp(start, target, arrival)!,
        dotRadius * (0.4 + (dot % 3) * 0.18),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GatheringRookOrbitPainter oldDelegate) =>
      oldDelegate.gathering != gathering ||
      oldDelegate.orbit != orbit ||
      oldDelegate.reveal != reveal ||
      oldDelegate.color != color ||
      oldDelegate.viewportSize != viewportSize;
}
