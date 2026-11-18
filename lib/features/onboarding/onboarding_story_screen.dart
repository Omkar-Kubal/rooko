import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';
import 'onboarding_particle_field.dart';

enum OnboardingStoryStage { projection, recall, memory, impact, future }

const onboardingRecallOptions = ["I don't remember any", 'Only a few'];

class OnboardingProjection {
  const OnboardingProjection(this.daily);

  factory OnboardingProjection.fromAnswer(String? answer) {
    final value = int.tryParse(
      (answer ?? '300').replaceAll(',', '').replaceAll('+', ''),
    );
    return OnboardingProjection(value ?? 300);
  }

  final int daily;

  int get weekly => daily * 7;
  int get monthly => daily * 30;
  int get yearly => daily * 365;

  // An illustrative 35 seconds per reel, rounded to half months.
  double get monthsPerYear =>
      ((yearly * 35 / (30 * 24 * 60 * 60)) * 2).round() / 2;
  int get monthsInTenYears => (monthsPerYear * 10).round();
}

String formatStoryNumber(num value) {
  final parts =
      (value is double && value == value.roundToDouble()
              ? value.toInt().toString()
              : value.toString())
          .split('.');
  final digits = parts.first;
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.insert(0, digits.substring(math.max(0, end - 3), end));
  }
  return '${groups.join(',')}${parts.length > 1 ? '.${parts.last}' : ''}';
}

class OnboardingStoryScreen extends StatefulWidget {
  const OnboardingStoryScreen({
    super.key,
    required this.stage,
    required this.projection,
    required this.recallChoice,
    required this.healthEffects,
    required this.dreamStatus,
    required this.onRecallChanged,
    required this.onContinue,
  });

  final OnboardingStoryStage stage;
  final OnboardingProjection projection;
  final String? recallChoice;
  final Set<String> healthEffects;
  final String? dreamStatus;
  final ValueChanged<String> onRecallChanged;
  final VoidCallback onContinue;

  @override
  State<OnboardingStoryScreen> createState() => OnboardingStoryScreenState();
}

class OnboardingStoryScreenState extends State<OnboardingStoryScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _enter;
  late final AnimationController _exit;
  late final AnimationController _orbit;
  late final AnimationController _orbTransfer;
  late final AnimationController _handoffPause;
  bool _reduceMotion = false;
  bool _isForeground = true;
  bool _leaving = false;
  bool _forwardExit = false;
  VoidCallback? _pendingNavigation;

  Duration get _stageDuration => switch (widget.stage) {
    OnboardingStoryStage.projection => const Duration(milliseconds: 10400),
    OnboardingStoryStage.recall => const Duration(milliseconds: 950),
    OnboardingStoryStage.memory => const Duration(milliseconds: 1900),
    OnboardingStoryStage.impact => const Duration(milliseconds: 9000),
    OnboardingStoryStage.future => const Duration(milliseconds: 1800),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _enter =
        AnimationController(
          vsync: this,
          duration: _stageDuration,
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed &&
              widget.stage == OnboardingStoryStage.memory) {
            _orbit.stop();
          }
        });
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      animationBehavior: AnimationBehavior.preserve,
      value: 1,
    );
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
      animationBehavior: AnimationBehavior.preserve,
    );
    _orbTransfer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
      animationBehavior: AnimationBehavior.preserve,
    );
    _handoffPause = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion != reduceMotion ||
        !_enter.isAnimating && _enter.value == 0) {
      _reduceMotion = reduceMotion;
      if (_reduceMotion) {
        _enter.value = 1;
        _orbit.stop();
        _orbit.value = 0;
        if (_leaving) {
          _exit.value = 0;
          _orbTransfer.value = 1;
          _handoffPause.value = 1;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _completeNavigation(),
          );
        }
      } else if (_isForeground) {
        if (!_leaving && _enter.value < 1) _enter.forward();
        _startOrbit();
      }
    }
  }

  @override
  void didUpdateWidget(covariant OnboardingStoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage == widget.stage) return;
    _leaving = false;
    _forwardExit = false;
    _pendingNavigation = null;
    _exit.value = 1;
    _orbTransfer.value = 0;
    _handoffPause.value = 0;
    _enter.duration = _stageDuration;
    _enter.value = _reduceMotion ? 1 : 0;
    if (widget.stage.index > OnboardingStoryStage.memory.index) {
      _orbit.stop();
    }
    if (!_reduceMotion && _isForeground) {
      _enter.forward();
      _startOrbit();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _enter.stop();
      _exit.stop();
      _orbit.stop();
      _orbTransfer.stop();
      _handoffPause.stop();
    } else if (_leaving) {
      _startOrbit();
      _runExit();
    } else if (!_reduceMotion) {
      if (_enter.value < 1) _enter.forward();
      _startOrbit();
    }
  }

  void _startOrbit() {
    if (!_reduceMotion &&
        _isForeground &&
        !_orbit.isAnimating &&
        widget.stage.index <= OnboardingStoryStage.memory.index &&
        (widget.stage != OnboardingStoryStage.memory || !_enter.isCompleted)) {
      _orbit.repeat();
    }
  }

  void exitThen(VoidCallback navigate, {bool forward = false}) {
    if (_leaving) return;
    setState(() {
      _leaving = true;
      _forwardExit = forward;
    });
    _pendingNavigation = navigate;
    if (_reduceMotion) {
      _completeNavigation();
      return;
    }
    _enter.stop();
    if (_isForeground) _runExit();
  }

  Future<void> _runExit() async {
    try {
      if (!_exit.isDismissed) await _exit.reverse().orCancel;
      if (_forwardExit &&
          (widget.stage == OnboardingStoryStage.projection ||
              widget.stage == OnboardingStoryStage.recall) &&
          _orbTransfer.value < 1) {
        await _orbTransfer.forward().orCancel;
      } else if (_handoffPause.value < 1) {
        await _handoffPause.forward().orCancel;
      }
    } on TickerCanceled {
      return;
    }
    if (mounted && _isForeground) _completeNavigation();
  }

  void _completeNavigation() {
    final navigate = _pendingNavigation;
    _pendingNavigation = null;
    if (mounted) navigate?.call();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enter.dispose();
    _exit.dispose();
    _orbit.dispose();
    _orbTransfer.dispose();
    _handoffPause.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _enter.value >= 0.98 &&
      (widget.stage != OnboardingStoryStage.recall ||
          widget.recallChoice != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasAmoled,
      body: IgnorePointer(
        ignoring: _leaving,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x6),
            child: AnimatedBuilder(
              animation: _enter,
              builder: (context, _) {
                final progress = _enter.value;
                return Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          children: [
                            if (widget.stage.index <=
                                OnboardingStoryStage.memory.index)
                              Positioned.fill(
                                child: FadeTransition(
                                  opacity: _forwardExit
                                      ? const AlwaysStoppedAnimation(1)
                                      : _exit,
                                  child: _sharedOrb(constraints, progress),
                                ),
                              ),
                            FadeTransition(
                              key: const ValueKey('story-exit-fade'),
                              opacity: _exit,
                              child: SingleChildScrollView(
                                child: _content(constraints, progress),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    FadeTransition(
                      opacity: _exit,
                      child: AnimatedOpacity(
                        opacity: progress >= 0.90 ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _canContinue
                                ? () =>
                                      exitThen(widget.onContinue, forward: true)
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accentDark,
                              foregroundColor: AppColors.textOnDark,
                              disabledBackgroundColor: AppColors.surfaceDark,
                              disabledForegroundColor:
                                  AppColors.textSecondaryDark,
                              shape: const StadiumBorder(),
                              textStyle: AppTypography.button,
                            ),
                            child: const Text('Continue'),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _sharedOrb(BoxConstraints constraints, double progress) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final orbSize = math.min(width * 0.82, 310.0);
    final recallY = math.min(
      height * 0.55,
      AppSpacing.x1 +
          AppSpacing.x8 +
          90 +
          math.max(AppSpacing.x6, width * 0.08) +
          orbSize / 2,
    );
    final memoryY = height * 0.52;
    return AnimatedBuilder(
      animation: _orbTransfer,
      builder: (context, _) {
        var centerX = width / 2;
        var centerY = height / 2;
        if (widget.stage == OnboardingStoryStage.projection) {
          centerY = _forwardExit && _leaving
              ? (height / 2) + (recallY - height / 2) * _orbTransfer.value
              : height / 2;
        } else if (widget.stage == OnboardingStoryStage.recall) {
          centerX = _forwardExit && _leaving
              ? width / 2 - width * 0.32 * _orbTransfer.value
              : width / 2;
          centerY = _forwardExit && _leaving
              ? recallY + (memoryY - recallY) * _orbTransfer.value
              : recallY;
        } else {
          centerX = width * (0.18 + 0.32 * _reveal(progress, 0, 0.34));
          centerY = memoryY;
        }
        final isMemory = widget.stage == OnboardingStoryStage.memory;
        final scatter = isMemory ? _reveal(progress, 0.34, 0.92) : 0.0;
        final opacity = isMemory ? 1 - _reveal(progress, 0.44, 0.96) : 1.0;
        return Stack(
          children: [
            Positioned(
              left: centerX - orbSize / 2,
              top: centerY - orbSize / 2,
              child: Opacity(
                key: isMemory ? const ValueKey('story-memory-dots') : null,
                opacity: opacity,
                child: Semantics(
                  label: widget.stage == OnboardingStoryStage.projection
                      ? '${formatStoryNumber(widget.projection.yearly)} reels a year, illustrated from your answer'
                      : 'A field of dots representing the projected reels',
                  child: ExcludeSemantics(
                    child: SizedBox.square(
                      key: const ValueKey('story-shared-orb'),
                      dimension: orbSize,
                      child: RotationTransition(
                        key: const ValueKey('story-orbit'),
                        turns: _orbit,
                        child: RepaintBoundary(
                          child: OnboardingParticleField(
                            size: Size.square(orbSize),
                            formation:
                                widget.stage == OnboardingStoryStage.projection
                                ? 0.12 + progress * 0.88
                                : 1,
                            flow:
                                widget.stage == OnboardingStoryStage.projection
                                ? progress
                                : 1,
                            turbulence:
                                widget.stage == OnboardingStoryStage.projection
                                ? math.sin(progress * math.pi * 4) * 0.35
                                : 0,
                            scatter: scatter,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _content(BoxConstraints constraints, double progress) {
    final width = constraints.maxWidth;
    return switch (widget.stage) {
      OnboardingStoryStage.projection => _projectionContent(
        width,
        constraints.maxHeight,
        progress,
      ),
      OnboardingStoryStage.recall => _recallContent(width, progress),
      OnboardingStoryStage.memory => _memoryContent(
        width,
        constraints.maxHeight,
        progress,
      ),
      OnboardingStoryStage.impact => _impactContent(
        width,
        constraints.maxHeight,
        progress,
      ),
      OnboardingStoryStage.future => _futureContent(
        width,
        constraints.maxHeight,
        progress,
      ),
    };
  }

  Widget _projectionContent(double width, double height, double progress) {
    final projection = widget.projection;
    final targets = [
      projection.daily,
      projection.weekly,
      projection.monthly,
      projection.yearly,
    ];
    const labels = [
      'reels a day',
      'reels a week',
      'reels a month',
      'reels a year',
    ];
    final phase = math.min(3, (progress * 4).floor());
    final phaseProgress = (progress * 4 - phase).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(
      (phaseProgress / 0.78).clamp(0.0, 1.0),
    );
    final start = phase == 0 ? 0 : targets[phase - 1];
    final value = (start + (targets[phase] - start) * eased).round();
    return SizedBox(
      height: math.max(height, 430),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatStoryNumber(value),
              key: const ValueKey('story-projection-count'),
              style: AppTypography.pageTitle.copyWith(
                color: AppColors.textOnDark,
                fontSize: AppTypeScale.xxLarge,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              labels[phase],
              key: const ValueKey('story-projection-period'),
              style: AppTypography.body.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recallContent(double width, double progress) {
    final fadeHeader = _reveal(progress, 0.08, 0.48);
    final fadeChoices = _reveal(progress, 0.58, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: fadeHeader,
          child: LinearProgressIndicator(
            value: 0.92,
            minHeight: AppSpacing.x1,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            color: AppColors.textOnDark,
            backgroundColor: AppColors.dividerDark,
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        Opacity(
          opacity: fadeHeader,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Ready Rook',
                image: true,
                child: Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(AppSpacing.x2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceDark,
                    border: Border.all(color: AppColors.dividerDark),
                  ),
                  child: Image.asset(
                    'assets/rook/rook-ready-transparent.png',
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text:
                              '${formatStoryNumber(widget.projection.yearly)} reels\n',
                        ),
                        const TextSpan(text: 'How many do you remember?'),
                      ],
                    ),
                    style: AppTypography.body.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: math.max(AppSpacing.x6, width * 0.08)),
        SizedBox(height: math.min(width * 0.82, 310)),
        const SizedBox(height: AppSpacing.x6),
        Opacity(
          opacity: fadeChoices,
          child: IgnorePointer(
            ignoring: fadeChoices < 1,
            child: Column(
              children: [
                for (final choice in onboardingRecallOptions) ...[
                  _RecallOption(
                    label: choice,
                    selected: widget.recallChoice == choice,
                    onTap: () => widget.onRecallChanged(choice),
                  ),
                  if (choice != onboardingRecallOptions.last)
                    const SizedBox(height: AppSpacing.x2),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _memoryContent(double width, double height, double progress) {
    final result = widget.recallChoice == onboardingRecallOptions.first
        ? 'Not one stayed'
        : 'Only a few stayed';
    return SizedBox(
      height: math.max(height, 430),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.45),
            child: Opacity(
              opacity: _reveal(progress, 0.52, 0.88),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$result\n'),
                    TextSpan(
                      text:
                          'Out of ${formatStoryNumber(widget.projection.yearly)} reels',
                    ),
                  ],
                ),
                key: const ValueKey('story-memory-result'),
                textAlign: TextAlign.center,
                style: AppTypography.pageTitle.copyWith(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactContent(double width, double height, double progress) {
    final monthLabel = formatStoryNumber(widget.projection.monthsPerYear);
    final symptom = _healthLine(widget.healthEffects);
    final interest = widget.dreamStatus == "I'm still finding it"
        ? 'Finding your interest takes time'
        : 'Your interest never grows';
    final monthOpacity =
        _reveal(progress, 0.15, 0.30) * (1 - _reveal(progress, 0.39, 0.52));
    final healthOpacity =
        _reveal(progress, 0.47, 0.58) * (1 - _reveal(progress, 0.65, 0.73));
    final interestOpacity = _reveal(progress, 0.70, 0.83);
    return SizedBox(
      height: math.max(height, 440),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0, -0.55),
            child: Opacity(
              opacity: _reveal(progress, 0, 0.20),
              child: Text(
                'But all these ${formatStoryNumber(widget.projection.yearly)} reels\nare costing you',
                key: const ValueKey('story-impact-heading'),
                textAlign: TextAlign.center,
                style: AppTypography.pageTitle.copyWith(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                OnboardingParticleField(
                  key: const ValueKey('story-human-particles'),
                  size: Size(
                    math.min(width * 0.85, 330),
                    math.min(width * 0.95, 370),
                  ),
                  formation: 1,
                  flow: progress * 0.6,
                  turbulence: math.sin(progress * math.pi) * 0.35,
                  headMorph: _reveal(progress, 0.30, 0.60),
                ),
                Opacity(
                  opacity: monthOpacity,
                  child: Text(
                    '$monthLabel ${widget.projection.monthsPerYear == 1 ? 'month' : 'months'}\nevery year',
                    key: const ValueKey('story-impact-months'),
                    textAlign: TextAlign.center,
                    style: AppTypography.pageTitle.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Opacity(
                  opacity: healthOpacity,
                  child: Text(
                    symptom,
                    key: const ValueKey('story-impact-health'),
                    textAlign: TextAlign.center,
                    style: AppTypography.pageTitle.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Opacity(
                  opacity: interestOpacity,
                  child: SizedBox(
                    width: math.min(width * 0.72, 280),
                    child: Text(
                      interest,
                      key: const ValueKey('story-impact-interest'),
                      textAlign: TextAlign.center,
                      style: AppTypography.pageTitle.copyWith(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _futureContent(double width, double height, double progress) {
    final months = widget.projection.monthsInTenYears.clamp(0, 120);
    final shown = (months * Curves.easeOutCubic.transform(progress)).round();
    const columns = 12;
    const gap = 5.0;
    final dotSize = math.min(18.0, (width - (columns - 1) * gap) / columns);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: _reveal(progress, 0, 0.35),
            child: Text(
              "Over the next 10 years\nthat's $months months of your life",
              key: const ValueKey('story-future-heading'),
              textAlign: TextAlign.center,
              style: AppTypography.pageTitle.copyWith(
                color: AppColors.textOnDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
          Semantics(
            label: '$months of 120 months highlighted',
            child: ExcludeSemantics(
              child: SizedBox(
                width: columns * dotSize + (columns - 1) * gap,
                height: 10 * dotSize + 9 * gap,
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                  ),
                  itemCount: 120,
                  itemBuilder: (context, index) => DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < shown
                          ? AppColors.textOnDark
                          : AppColors.dividerDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'Each dot is a month',
            style: AppTypography.supporting.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Illustrative estimate at 35 seconds per reel',
            style: AppTypography.supporting.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

double _reveal(double progress, double start, double end) => Curves.easeOut
    .transform(((progress - start) / (end - start)).clamp(0.0, 1.0));

String _healthLine(Set<String> effects) {
  if (effects.contains('Headaches')) return 'You get\nheadaches';
  if (effects.contains('Lack of sleep')) return 'You lose\nsleep';
  if (effects.contains('Unable to focus')) return 'You lose\nfocus';
  if (effects.contains('Poor memory')) return 'Your memory\nsuffers';
  if (effects.contains('Feel low')) return 'You feel\nlow';
  if (effects.contains('Feel depressed')) return 'You feel\ndepressed';
  return 'You get\nheadaches';
}

class _RecallOption extends StatelessWidget {
  const _RecallOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onTap,
    child: ExcludeSemantics(
      child: Material(
        color: selected ? AppColors.accentDark : AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: selected ? AppColors.accentDark : AppColors.dividerDark,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textOnDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 2,
                        color: selected
                            ? AppColors.textOnDark
                            : AppColors.textSecondaryDark,
                      ),
                      color: selected ? AppColors.textOnDark : null,
                    ),
                    child: selected
                        ? const AppIcon(
                            icon: AppIcons.check,
                            size: 16,
                            color: AppColors.ink,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
