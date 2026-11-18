import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';
import '../today/rook_state.dart';

const _screenTimeIllustrations = <String, RookState>{
  'Under 3 hours': RookState.ready,
  '3–6 hours': RookState.strained,
  '6–9 hours': RookState.injured,
  '9+ hours': RookState.queasy,
};

class OnboardingQuestion {
  const OnboardingQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    this.multiSelect = false,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final bool multiSelect;
}

const onboardingQuestions = <OnboardingQuestion>[
  OnboardingQuestion(
    id: 'viewTiming',
    prompt: 'When do you usually watch reels?',
    multiSelect: true,
    options: [
      'All day',
      "When I'm bored",
      'During study or work',
      'After dinner',
      'Late at night',
    ],
  ),
  OnboardingQuestion(
    id: 'screenTime',
    prompt: "What's your average screen time?",
    options: ['Under 3 hours', '3–6 hours', '6–9 hours', '9+ hours'],
  ),
  OnboardingQuestion(
    id: 'healthEffects',
    prompt: 'What health problems do you face because of reels?',
    multiSelect: true,
    options: [
      'Lack of sleep',
      'Headaches',
      'Unable to focus',
      'Poor memory',
      'Feel low',
      'Feel depressed',
    ],
  ),
  OnboardingQuestion(
    id: 'dreamStatus',
    prompt: 'Do you have a dream or interest you want to follow?',
    options: [
      'Yes, I have a dream',
      'Yes, I have an interest',
      "I'm still finding it",
    ],
  ),
  OnboardingQuestion(
    id: 'dreamCategory',
    prompt: "What's your dream?",
    options: ['Studies', 'Fitness', 'Music', 'Art', 'Business', 'A new skill'],
  ),
  OnboardingQuestion(
    id: 'dreamTime',
    prompt: 'Do you get enough time to follow your dream?',
    options: [
      'No, not at all',
      "I don't know where my time goes",
      'Yes, but very little',
    ],
  ),
  OnboardingQuestion(
    id: 'dreamImpact',
    prompt: 'Does watching reels help you achieve your dream?',
    options: ['Not at all', 'Yes, a little'],
  ),
  OnboardingQuestion(
    id: 'yesterdayEstimate',
    prompt: 'What do you think, how many reels did you watch yesterday?',
    options: ['300', '400', '600', '800', '1,000+'],
  ),
];

int? nextQuestionIndex(int current, Map<String, Set<String>> answers) {
  if (current >= onboardingQuestions.length - 1) return null;
  if (current == 3 &&
      answers['dreamStatus']?.contains("I'm still finding it") == true) {
    return 7;
  }
  return current + 1;
}

int? previousQuestionIndex(int current, Map<String, Set<String>> answers) {
  if (current <= 0) return null;
  if (current == 7 &&
      answers['dreamStatus']?.contains("I'm still finding it") == true) {
    return 3;
  }
  return current - 1;
}

class OnboardingQuestionScreen extends StatefulWidget {
  const OnboardingQuestionScreen({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.questionCount,
    required this.selectedOptions,
    required this.onToggleOption,
    required this.onContinue,
  });

  final OnboardingQuestion question;
  final int questionIndex;
  final int questionCount;
  final Set<String> selectedOptions;
  final ValueChanged<String> onToggleOption;
  final VoidCallback onContinue;

  @override
  State<OnboardingQuestionScreen> createState() =>
      OnboardingQuestionScreenState();
}

class OnboardingQuestionScreenState extends State<OnboardingQuestionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _entrance;
  late final AnimationController _exit;
  late final AnimationController _handoffPause;
  late final CurvedAnimation _chromeOpacity;
  late final CurvedAnimation _headingOpacity;
  late final CurvedAnimation _answersOpacity;
  bool _reduceMotion = false;
  bool _started = false;
  bool _leaving = false;
  bool _isForeground = true;
  VoidCallback? _pendingNavigation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      animationBehavior: AnimationBehavior.preserve,
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      animationBehavior: AnimationBehavior.preserve,
      value: 1,
    );
    _handoffPause = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _chromeOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    _headingOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.22, 0.62, curve: Curves.easeOut),
    );
    _answersOpacity = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.50, 1, curve: Curves.easeOut),
    );
    _entrance.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion != _reduceMotion || !_started) {
      _reduceMotion = reduceMotion;
      _started = true;
      if (_reduceMotion) {
        _entrance.value = 1;
        if (_leaving) {
          _exit.value = 0;
          _handoffPause.value = 1;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _completeNavigation();
          });
        } else {
          _exit.value = 1;
        }
      } else if (_isForeground && !_leaving && _entrance.value < 1) {
        _entrance.forward();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _entrance.stop();
      _exit.stop();
      _handoffPause.stop();
    } else if (_leaving) {
      _runExit();
    } else if (!_reduceMotion && _entrance.value < 1) {
      _entrance.forward();
    }
  }

  @override
  void didUpdateWidget(covariant OnboardingQuestionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionIndex == widget.questionIndex &&
        oldWidget.question.id == widget.question.id) {
      return;
    }
    _leaving = false;
    _pendingNavigation = null;
    _exit.value = 1;
    _handoffPause.value = 0;
    _entrance.value = _reduceMotion ? 1 : 0;
    if (!_reduceMotion && _isForeground) _entrance.forward();
  }

  void exitThen(VoidCallback navigate) {
    if (_leaving) return;
    setState(() => _leaving = true);
    _pendingNavigation = navigate;
    if (_reduceMotion) {
      _completeNavigation();
      return;
    }
    _entrance.stop();
    if (_isForeground) _runExit();
  }

  Future<void> _runExit() async {
    try {
      if (!_exit.isDismissed) await _exit.reverse().orCancel;
      if (_handoffPause.value < 1) await _handoffPause.forward().orCancel;
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
    _chromeOpacity.dispose();
    _headingOpacity.dispose();
    _answersOpacity.dispose();
    _entrance.dispose();
    _exit.dispose();
    _handoffPause.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final question = widget.question;
    final questionIndex = widget.questionIndex;
    final questionCount = widget.questionCount;
    final selectedOptions = widget.selectedOptions;
    final onToggleOption = widget.onToggleOption;
    final selectedScreenTime = selectedOptions.isEmpty
        ? null
        : selectedOptions.first;
    final illustrationState = question.id == 'screenTime'
        ? _screenTimeIllustrations[selectedScreenTime] ?? RookState.ready
        : RookState.ready;

    return Scaffold(
      body: FadeTransition(
        opacity: _exit,
        child: IgnorePointer(
          ignoring: _leaving,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeTransition(
                    key: const ValueKey('question-chrome-fade'),
                    opacity: _chromeOpacity,
                    child: Semantics(
                      label: 'Question ${questionIndex + 1} of $questionCount',
                      child: ExcludeSemantics(
                        child: LinearProgressIndicator(
                          value: (questionIndex + 1) / questionCount,
                          minHeight: AppSpacing.x1,
                          backgroundColor: colors.outlineVariant,
                          valueColor: AlwaysStoppedAnimation(colors.onSurface),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        const SizedBox(height: AppSpacing.x8),
                        FadeTransition(
                          key: const ValueKey('question-heading-fade'),
                          opacity: _headingOpacity,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Semantics(
                                label: '${illustrationState.label} Rook',
                                image: true,
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  padding: const EdgeInsets.all(AppSpacing.x2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.surface,
                                    border: Border.all(
                                      color: colors.outlineVariant,
                                    ),
                                  ),
                                  child: SvgPicture.asset(
                                    illustrationState.svgAsset,
                                    fit: BoxFit.contain,
                                    excludeFromSemantics: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.x4),
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    question.prompt,
                                    style: AppTypography.pageTitle.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x8),
                        FadeTransition(
                          key: const ValueKey('question-answers-fade'),
                          opacity: _answersOpacity,
                          child: IgnorePointer(
                            ignoring: !_entrance.isCompleted,
                            child: Column(
                              children: [
                                for (final option in question.options) ...[
                                  Builder(
                                    builder: (context) {
                                      final selected = selectedOptions.contains(
                                        option,
                                      );
                                      final foreground = selected
                                          ? colors.onPrimary
                                          : colors.onSurface;
                                      return Semantics(
                                        button: true,
                                        selected: selected,
                                        label: option,
                                        onTap: () => onToggleOption(option),
                                        child: ExcludeSemantics(
                                          child: Material(
                                            color: selected
                                                ? colors.primary
                                                : colors.surface,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadii.card,
                                                  ),
                                              side: BorderSide(
                                                color: selected
                                                    ? colors.primary
                                                    : colors.outlineVariant,
                                              ),
                                            ),
                                            child: InkWell(
                                              onTap: () =>
                                                  onToggleOption(option),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadii.card,
                                                  ),
                                              child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      minHeight: 72,
                                                    ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal:
                                                            AppSpacing.x4,
                                                        vertical: AppSpacing.x3,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          option,
                                                          style: AppTypography
                                                              .body
                                                              .copyWith(
                                                                color:
                                                                    foreground,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: AppSpacing.x3,
                                                      ),
                                                      selected
                                                          ? AppIcon(
                                                              icon: AppIcons
                                                                  .check,
                                                              size: AppIconSizes
                                                                  .standard,
                                                              color: foreground,
                                                            )
                                                          : Container(
                                                              width:
                                                                  AppIconSizes
                                                                      .standard,
                                                              height:
                                                                  AppIconSizes
                                                                      .standard,
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape
                                                                    .circle,
                                                                border: Border.all(
                                                                  color: colors
                                                                      .outline,
                                                                  width: 2,
                                                                ),
                                                              ),
                                                            ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (option != question.options.last)
                                    const SizedBox(height: AppSpacing.x2),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  FadeTransition(
                    opacity: _chromeOpacity,
                    child: SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed:
                            selectedOptions.isEmpty || !_entrance.isCompleted
                            ? null
                            : () => exitThen(widget.onContinue),
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                          textStyle: AppTypography.button,
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
