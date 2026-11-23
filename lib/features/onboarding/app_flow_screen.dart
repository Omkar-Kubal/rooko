import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design_system/app_theme.dart';
import '../../core/platform/privacy_policy_link.dart';
import '../../core/platform/tracking_platform.dart';
import '../../core/models/supported_app.dart';
import '../today/today_home_screen.dart';
import 'onboarding_screens.dart';
import 'onboarding_question_screen.dart';
import 'onboarding_story_screen.dart';
import 'onboarding_permission_guide.dart';
import 'rook_intro_screen.dart';
import 'rook_setup_intro_screen.dart';
import 'rook_privacy_bridge_screen.dart';

enum _FlowPage {
  counterPreview,
  rookIntro,
  rookReveal,
  rookSetupIntro,
  questionnaire,
  projection,
  recall,
  memory,
  impact,
  future,
  rookPrivacyBridge,
  permissionExplanation,
  permissionAction,
  accessUnavailable,
  feedHandoff,
  today,
}

enum _PageTransitionPhase { idle, fadingOut, pausing, fadingIn }

class AppFlowScreen extends StatefulWidget {
  const AppFlowScreen({
    super.key,
    this.onboardingComplete = false,
    this.trackingPlatform = const MethodChannelTrackingPlatform(),
    this.appearance = AppAppearance.system,
    this.onAppearanceChanged,
    this.launchPrivacyPolicy,
  });

  final bool onboardingComplete;
  final TrackingPlatform trackingPlatform;
  final AppAppearance appearance;
  final ValueChanged<AppAppearance>? onAppearanceChanged;
  final PrivacyPolicyLauncher? launchPrivacyPolicy;

  @override
  State<AppFlowScreen> createState() => _AppFlowScreenState();
}

class _AppFlowScreenState extends State<AppFlowScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _completedKey = 'rooko_onboarding_complete';
  static const _draftPageKey = 'rooko_onboarding_page';
  static const _selectedAppsKey = 'rooko_selected_supported_apps';
  static const _selectionTouchedKey = 'rooko_app_selection_touched';
  static const _questionIndexKey = 'rooko_onboarding_question_index';
  static const _questionAnswersKey = 'rooko_onboarding_question_draft';
  static const _recallChoiceKey = 'rooko_onboarding_recall_choice';

  late _FlowPage _page;
  final Set<String> _selectedApps = {};
  final Map<String, Set<String>> _questionAnswers = {};
  final GlobalKey<OnboardingQuestionScreenState> _questionScreenKey =
      GlobalKey();
  final GlobalKey<OnboardingStoryScreenState> _storyScreenKey = GlobalKey();
  int _questionIndex = 0;
  String? _recallChoice;
  Future<void> _draftWrite = Future<void>.value();
  bool _selectionWasSaved = false;
  bool _acknowledgedDisclosure = false;
  bool _trackingConsentAcknowledged = false;
  bool _awaitingAccessibilityReturn = false;
  bool _awaitingOverlayReturn = false;
  bool _floatingCounterOptIn = false;
  TrackingSnapshot? _trackingSnapshot;
  late final Future<void> _draftReady;
  late final AnimationController _pageFade;
  late final AnimationController _pagePause;
  _FlowPage? _pendingPage;
  _PageTransitionPhase _transitionPhase = _PageTransitionPhase.idle;
  bool _reduceMotion = false;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _pageFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 260),
      animationBehavior: AnimationBehavior.preserve,
      value: 1,
    )..addStatusListener(_onPageFadeStatus);
    _pagePause = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_onPagePauseStatus);
    _page = widget.onboardingComplete
        ? _FlowPage.today
        : _FlowPage.counterPreview;
    _draftReady = widget.onboardingComplete
        ? Future<void>.value()
        : _restoreOnboardingDraft();
    _refreshTrackingSnapshot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageFade.dispose();
    _pagePause.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion && _pendingPage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _reduceMotion && _pendingPage != null) {
          _showPageImmediately(_pendingPage!);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _pageFade.stop();
      _pagePause.stop();
    } else {
      switch (_transitionPhase) {
        case _PageTransitionPhase.fadingOut:
          _pageFade.reverse();
        case _PageTransitionPhase.pausing:
          _pagePause.forward();
        case _PageTransitionPhase.fadingIn:
          _pageFade.forward();
        case _PageTransitionPhase.idle:
          break;
      }
    }
    if (state == AppLifecycleState.resumed) {
      if (_awaitingAccessibilityReturn) {
        _awaitingAccessibilityReturn = false;
        _refreshTrackingSnapshot(showStatusPage: true);
      } else if (_awaitingOverlayReturn) {
        _awaitingOverlayReturn = false;
        _refreshTrackingSnapshot(showStatusPage: true);
      }
    }
  }

  void _setPage(_FlowPage page) {
    if (page == _page || _pendingPage != null) return;
    // These are two phases of one mounted Rook screen and one particle field.
    if (_reduceMotion ||
        (_page == _FlowPage.rookIntro && page == _FlowPage.rookReveal) ||
        (_isStoryPage(_page) && _isStoryPage(page))) {
      _showPageImmediately(page);
      return;
    }
    setState(() {
      _pendingPage = page;
      _transitionPhase = _PageTransitionPhase.fadingOut;
    });
    if (_isForeground) _pageFade.reverse();
  }

  void _showPageImmediately(_FlowPage page) {
    _transitionPhase = _PageTransitionPhase.idle;
    _pageFade.stop();
    _pagePause.stop();
    _pageFade.value = 1;
    _pagePause.value = 0;
    setState(() {
      _page = page;
      _pendingPage = null;
      _transitionPhase = _PageTransitionPhase.idle;
    });
    _queueDraftWrite(page);
  }

  void _onPageFadeStatus(AnimationStatus status) {
    if (!mounted || !_isForeground) return;
    if (status == AnimationStatus.dismissed &&
        _transitionPhase == _PageTransitionPhase.fadingOut) {
      _transitionPhase = _PageTransitionPhase.pausing;
      _pagePause.forward(from: 0);
    } else if (status == AnimationStatus.completed &&
        _transitionPhase == _PageTransitionPhase.fadingIn) {
      setState(() {
        _pendingPage = null;
        _transitionPhase = _PageTransitionPhase.idle;
      });
    }
  }

  void _onPagePauseStatus(AnimationStatus status) {
    if (!mounted ||
        !_isForeground ||
        status != AnimationStatus.completed ||
        _transitionPhase != _PageTransitionPhase.pausing) {
      return;
    }
    final next = _pendingPage;
    if (next == null) return;
    setState(() {
      _page = next;
      _transitionPhase = _PageTransitionPhase.fadingIn;
    });
    _queueDraftWrite(next);
    _pageFade.forward(from: 0);
  }

  void _queueDraftWrite(_FlowPage page) {
    _draftWrite = _draftWrite.then((_) => _persistPage(page));
  }

  void _beginQuestions() {
    _questionIndex = 0;
    _setPage(_FlowPage.questionnaire);
  }

  void _toggleQuestionOption(String option) {
    final question = onboardingQuestions[_questionIndex];
    if (!question.options.contains(option)) return;
    setState(() {
      final selected = _questionAnswers.putIfAbsent(question.id, () => {});
      if (question.multiSelect) {
        if (!selected.add(option)) selected.remove(option);
      } else {
        selected
          ..clear()
          ..add(option);
      }
      if (question.id == 'dreamStatus' && option == "I'm still finding it") {
        for (final index in [4, 5, 6]) {
          _questionAnswers.remove(onboardingQuestions[index].id);
        }
      }
    });
    _queueDraftWrite(_FlowPage.questionnaire);
  }

  void _continueQuestion() {
    final question = onboardingQuestions[_questionIndex];
    if (_questionAnswers[question.id]?.isNotEmpty != true) return;
    final next = nextQuestionIndex(_questionIndex, _questionAnswers);
    if (next == null) {
      _setPage(_FlowPage.projection);
      return;
    }
    setState(() => _questionIndex = next);
    _queueDraftWrite(_FlowPage.questionnaire);
  }

  void _setRecallChoice(String choice) {
    if (!onboardingRecallOptions.contains(choice)) return;
    setState(() => _recallChoice = choice);
    _queueDraftWrite(_FlowPage.recall);
  }

  void _continueStory() {
    final next = switch (_page) {
      _FlowPage.projection => _FlowPage.recall,
      _FlowPage.recall when _recallChoice != null => _FlowPage.memory,
      _FlowPage.memory => _FlowPage.impact,
      _FlowPage.impact => _FlowPage.future,
      _FlowPage.future => _FlowPage.rookPrivacyBridge,
      _ => null,
    };
    if (next != null) _setPage(next);
  }

  Future<void> _persistPage(_FlowPage page) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        _selectedAppsKey,
        _selectedApps.toList()..sort(),
      );
      await preferences.setBool(_selectionTouchedKey, _selectionWasSaved);
      if (page == _FlowPage.today) {
        await preferences.remove(_draftPageKey);
        await preferences.remove(_questionIndexKey);
        await preferences.remove(_questionAnswersKey);
        await preferences.remove(_recallChoiceKey);
        return;
      }
      await preferences.setInt(_questionIndexKey, _questionIndex);
      await preferences.setString(
        _questionAnswersKey,
        jsonEncode(
          _questionAnswers.map(
            (id, answers) => MapEntry(id, answers.toList()..sort()),
          ),
        ),
      );
      if (_recallChoice == null) {
        await preferences.remove(_recallChoiceKey);
      } else {
        await preferences.setString(_recallChoiceKey, _recallChoice!);
      }
      await preferences.setString(_draftPageKey, page.name);
    } catch (_) {
      // The current process can still complete onboarding without a draft.
    }
  }

  Future<void> _restoreOnboardingDraft() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedPageName = preferences.getString(_draftPageKey);
      final normalizedPageName = switch (savedPageName) {
        'welcome' => _FlowPage.counterPreview.name,
        'supportedAppsIntro' => _FlowPage.rookIntro.name,
        'supportedAppsSelection' => _FlowPage.permissionExplanation.name,
        'floatingCounter' => _FlowPage.accessUnavailable.name,
        _ => savedPageName,
      };
      _FlowPage? savedPage;
      for (final page in _FlowPage.values) {
        if (page.name == normalizedPageName && page != _FlowPage.today) {
          savedPage = page;
          break;
        }
      }
      if (savedPage != null && savedPage.name != savedPageName) {
        await preferences.setString(_draftPageKey, savedPage.name);
      }
      final selectedApps = preferences.getStringList(_selectedAppsKey) ?? [];
      final supportedSelection = selectedApps
          .where((id) => SupportedApp.byId(id) != null)
          .toSet();
      final normalizedSelection = supportedSelection.toList()..sort();
      final normalizedSavedSelection = selectedApps.toSet().toList()..sort();
      if (!listEquals(normalizedSelection, normalizedSavedSelection)) {
        await preferences.setStringList(_selectedAppsKey, normalizedSelection);
      }
      _selectionWasSaved = preferences.getBool(_selectionTouchedKey) ?? false;
      final restoredAnswers = <String, Set<String>>{};
      final savedAnswers = preferences.getString(_questionAnswersKey);
      if (savedAnswers != null) {
        Object? decoded;
        try {
          decoded = jsonDecode(savedAnswers);
        } on FormatException {
          decoded = null;
        }
        if (decoded is Map<String, dynamic>) {
          for (final question in onboardingQuestions) {
            final values = decoded[question.id];
            if (values is! List) continue;
            final allowed = values
                .whereType<String>()
                .where(question.options.contains)
                .toSet();
            if (allowed.isNotEmpty) {
              restoredAnswers[question.id] = question.multiSelect
                  ? allowed
                  : {allowed.first};
            }
          }
        }
      }
      var restoredQuestionIndex = (preferences.getInt(_questionIndexKey) ?? 0)
          .clamp(0, onboardingQuestions.length - 1)
          .toInt();
      if (restoredQuestionIndex >= 4 &&
          restoredQuestionIndex <= 6 &&
          restoredAnswers['dreamStatus']?.contains("I'm still finding it") ==
              true) {
        restoredQuestionIndex = 7;
      }
      final savedRecallChoice = preferences.getString(_recallChoiceKey);
      if (_isStoryPage(savedPage ?? _FlowPage.counterPreview) &&
          restoredAnswers['yesterdayEstimate']?.isNotEmpty != true) {
        savedPage = _FlowPage.questionnaire;
        restoredQuestionIndex = onboardingQuestions.length - 1;
      } else if ((savedPage == _FlowPage.memory ||
              savedPage == _FlowPage.impact ||
              savedPage == _FlowPage.future) &&
          !onboardingRecallOptions.contains(savedRecallChoice)) {
        savedPage = _FlowPage.recall;
      }
      if (_isStoryPage(savedPage ?? _FlowPage.counterPreview)) {
        restoredQuestionIndex = onboardingQuestions.length - 1;
      }
      if (savedPage != null && savedPage.name != savedPageName) {
        await preferences.setString(_draftPageKey, savedPage.name);
      }
      if (!mounted) return;
      setState(() {
        _selectedApps
          ..clear()
          ..addAll(supportedSelection);
        _questionAnswers
          ..clear()
          ..addAll(restoredAnswers);
        _questionIndex = restoredQuestionIndex;
        _recallChoice = onboardingRecallOptions.contains(savedRecallChoice)
            ? savedRecallChoice
            : null;
        if (savedPage != null) _page = savedPage;
      });
    } catch (_) {
      // The first-run flow remains usable if draft restoration fails.
    }
  }

  _FlowPage? _previousOnboardingPage(_FlowPage page) => switch (page) {
    _FlowPage.counterPreview => null,
    _FlowPage.rookIntro => _FlowPage.counterPreview,
    _FlowPage.rookReveal => _FlowPage.rookIntro,
    _FlowPage.rookSetupIntro => _FlowPage.rookReveal,
    _FlowPage.questionnaire => _FlowPage.rookSetupIntro,
    _FlowPage.projection => _FlowPage.questionnaire,
    _FlowPage.recall => _FlowPage.projection,
    _FlowPage.memory => _FlowPage.recall,
    _FlowPage.impact => _FlowPage.memory,
    _FlowPage.future => _FlowPage.impact,
    _FlowPage.rookPrivacyBridge => _FlowPage.future,
    _FlowPage.permissionExplanation => _FlowPage.rookPrivacyBridge,
    _FlowPage.permissionAction => _FlowPage.permissionExplanation,
    _FlowPage.accessUnavailable => _FlowPage.permissionAction,
    _FlowPage.feedHandoff => _FlowPage.accessUnavailable,
    _FlowPage.today => null,
  };

  void _goBack() {
    if (_page == _FlowPage.questionnaire) {
      final screen = _questionScreenKey.currentState;
      if (screen != null) {
        screen.exitThen(_goBackNow);
        return;
      }
    }
    if (_isStoryPage(_page)) {
      final screen = _storyScreenKey.currentState;
      if (screen != null) {
        screen.exitThen(_goBackNow);
        return;
      }
    }
    _goBackNow();
  }

  bool _isStoryPage(_FlowPage page) => switch (page) {
    _FlowPage.projection ||
    _FlowPage.recall ||
    _FlowPage.memory ||
    _FlowPage.impact ||
    _FlowPage.future => true,
    _ => false,
  };

  void _goBackNow() {
    if (_page == _FlowPage.projection) {
      _questionIndex = onboardingQuestions.length - 1;
    }
    if (_page == _FlowPage.questionnaire) {
      final previous = previousQuestionIndex(_questionIndex, _questionAnswers);
      if (previous != null) {
        setState(() => _questionIndex = previous);
        _queueDraftWrite(_FlowPage.questionnaire);
        return;
      }
    }
    final previousPage = _previousOnboardingPage(_page);
    if (previousPage != null) _setPage(previousPage);
  }

  Future<void> _finishOnboarding() async {
    await _saveSetup(complete: true);
    await _refreshTrackingSnapshot();
    if (!mounted) return;
    _setPage(_FlowPage.today);
  }

  Future<void> _saveSetup({bool complete = false}) async {
    try {
      if (complete) await _draftWrite;
      final preferences = await SharedPreferences.getInstance();
      if (complete) {
        await preferences.setBool(_completedKey, true);
        await preferences.setBool('rooko_home_welcome_pending', true);
        await preferences.remove(_draftPageKey);
        await preferences.remove(_questionIndexKey);
        await preferences.remove(_questionAnswersKey);
        await preferences.remove(_recallChoiceKey);
      } else {
        await preferences.setString(_draftPageKey, _page.name);
      }
      await preferences.setStringList(
        _selectedAppsKey,
        _selectedApps.toList()..sort(),
      );
      await preferences.setBool(_selectionTouchedKey, _selectionWasSaved);
    } catch (_) {
      // Local persistence is best-effort; the user can still reach Today.
    }

    try {
      await widget.trackingPlatform.setSelectedApps(_selectedApps);
    } catch (_) {
      // Today retries native synchronization when it loads.
    }
  }

  Future<void> _refreshTrackingSnapshot({bool showStatusPage = false}) async {
    try {
      await _draftReady;
      final snapshot = await widget.trackingPlatform.getSnapshot(_selectedApps);
      if (!mounted) return;
      setState(() {
        if (!widget.onboardingComplete && !_selectionWasSaved) {
          _selectedApps.addAll(
            const [
              'youtube',
              'instagram',
            ].where((id) => snapshot.apps[id]?.installed == true),
          );
          _selectionWasSaved = true;
          _queueDraftWrite(_page);
        }
        _trackingSnapshot = snapshot;
        _trackingConsentAcknowledged = snapshot.consentAcknowledged;
        _floatingCounterOptIn = snapshot.bubbleEnabled;
      });
      if (showStatusPage) _showPageImmediately(_FlowPage.accessUnavailable);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trackingSnapshot = null;
      });
      if (showStatusPage) _showPageImmediately(_FlowPage.accessUnavailable);
    }
  }

  Future<void> _openAccessibilitySettings() async {
    if (!_trackingConsentAcknowledged && !_acknowledgedDisclosure) {
      _setPage(_FlowPage.permissionAction);
      return;
    }

    final openSettings = await showOnboardingPermissionGuide(
      context,
      OnboardingPermissionKind.accessibility,
    );
    if (!mounted || !openSettings) return;

    if (_selectedApps.isEmpty && !_selectionWasSaved) {
      final snapshot =
          _trackingSnapshot ??
          await widget.trackingPlatform.getSnapshot(_selectedApps);
      _selectedApps.addAll(
        const [
          'youtube',
          'instagram',
        ].where((id) => snapshot.apps[id]?.installed == true),
      );
      _selectionWasSaved = true;
    }
    await _saveSetup();
    try {
      await widget.trackingPlatform.setConsentAcknowledged(true);
      _trackingConsentAcknowledged = true;
    } catch (_) {
      await _refreshTrackingSnapshot(showStatusPage: true);
      return;
    }

    // Android Settings can background Flutter before a page animation finishes.
    _showPageImmediately(_FlowPage.accessUnavailable);
    _awaitingAccessibilityReturn = true;
    var opened = false;
    try {
      opened = await widget.trackingPlatform.openAccessibilitySettings();
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      _awaitingAccessibilityReturn = false;
      await _refreshTrackingSnapshot(showStatusPage: true);
    }
  }

  Future<void> _setFloatingCounterOptIn(bool optedIn) async {
    setState(() => _floatingCounterOptIn = optedIn);
    try {
      await widget.trackingPlatform.setBubbleEnabled(optedIn);
    } catch (_) {
      // The user can still skip onboarding and manage the setting later.
    }
  }

  Future<void> _requestFloatingCounter() async {
    if (!_trackingConsentAcknowledged) return;
    await _setFloatingCounterOptIn(true);
    if (mounted &&
        _floatingCounterOptIn &&
        _trackingSnapshot?.overlayPermissionGranted != true) {
      await _openOverlaySettings();
    }
  }

  Future<void> _continueAfterAccess() async {
    if (_floatingCounterOptIn &&
        _trackingSnapshot?.overlayPermissionGranted != true) {
      await _setFloatingCounterOptIn(false);
    }
    if (mounted) _setPage(_FlowPage.feedHandoff);
  }

  Future<void> _openOverlaySettings() async {
    if (!_trackingConsentAcknowledged || !_floatingCounterOptIn) return;
    final openSettings = await showOnboardingPermissionGuide(
      context,
      OnboardingPermissionKind.overlay,
    );
    if (!mounted || !openSettings) return;
    try {
      await widget.trackingPlatform.setBubbleEnabled(true);
      await widget.trackingPlatform.setSelectedApps(_selectedApps);
      _awaitingOverlayReturn = true;
      final opened = await widget.trackingPlatform.openOverlaySettings();
      if (!opened) {
        _awaitingOverlayReturn = false;
        await _refreshTrackingSnapshot(showStatusPage: true);
      }
    } catch (_) {
      _awaitingOverlayReturn = false;
      await _refreshTrackingSnapshot();
    }
  }

  Future<void> _finishAndOpenSupportedApp(String appId) async {
    await _finishOnboarding();
    if (!_reduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (!mounted) return;
    var opened = false;
    try {
      opened = await widget.trackingPlatform.openSupportedApp(appId);
    } catch (_) {
      // Today remains available when the selected app cannot be opened.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open that app. Your count is in Today.'),
        ),
      );
    }
  }

  Future<void> _showPrivacyNotice() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy'),
        content: const Text(
          'If you enable tracking, Rooko checks feed structure and page '
          'changes only in the apps you select. On Instagram and YouTube, it '
          'may briefly read short visible labels to estimate item changes. '
          'Labels are hashed in memory and never saved. Daily counts stay on '
          'this device by default. You can turn access off in Android Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    bool opened = false;
    try {
      opened = await (widget.launchPrivacyPolicy ?? launchPublicPrivacyPolicy)(
        publicPrivacyPolicyUri,
      );
    } catch (_) {
      // The browser may be unavailable; onboarding remains usable.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Privacy Policy. Try again.'),
        ),
      );
    }
  }

  Widget _buildStoryPage(OnboardingStoryStage stage) => OnboardingStoryScreen(
    key: _storyScreenKey,
    stage: stage,
    projection: OnboardingProjection.fromAnswer(
      _questionAnswers['yesterdayEstimate']?.first,
    ),
    recallChoice: _recallChoice,
    healthEffects: _questionAnswers['healthEffects'] ?? const {},
    dreamStatus: _questionAnswers['dreamStatus']?.first,
    onRecallChanged: _setRecallChoice,
    onContinue: _continueStory,
  );

  Widget _buildCurrentPage() => switch (_page) {
    _FlowPage.counterPreview => CounterPreviewScreen(
      key: const ValueKey('counter-preview'),
      onContinue: () => _setPage(_FlowPage.rookIntro),
    ),
    _FlowPage.rookIntro => RookIntroScreen(
      key: const ValueKey('rook-intro'),
      onContinue: () => _setPage(_FlowPage.rookReveal),
    ),
    _FlowPage.rookReveal => RookIntroScreen(
      key: const ValueKey('rook-intro'),
      phase: RookIntroPhase.revealed,
      onContinue: () => _setPage(_FlowPage.rookSetupIntro),
    ),
    _FlowPage.rookSetupIntro => RookSetupIntroScreen(
      key: const ValueKey('rook-setup-intro'),
      onContinue: _beginQuestions,
    ),
    _FlowPage.questionnaire => OnboardingQuestionScreen(
      key: _questionScreenKey,
      question: onboardingQuestions[_questionIndex],
      questionIndex: _questionIndex,
      questionCount: onboardingQuestions.length,
      selectedOptions:
          _questionAnswers[onboardingQuestions[_questionIndex].id] ?? const {},
      onToggleOption: _toggleQuestionOption,
      onContinue: _continueQuestion,
    ),
    _FlowPage.projection => _buildStoryPage(OnboardingStoryStage.projection),
    _FlowPage.recall => _buildStoryPage(OnboardingStoryStage.recall),
    _FlowPage.memory => _buildStoryPage(OnboardingStoryStage.memory),
    _FlowPage.impact => _buildStoryPage(OnboardingStoryStage.impact),
    _FlowPage.future => _buildStoryPage(OnboardingStoryStage.future),
    _FlowPage.rookPrivacyBridge => RookPrivacyBridgeScreen(
      key: const ValueKey('rook-privacy-bridge'),
      onBack: _goBack,
      onContinue: () => _setPage(_FlowPage.permissionExplanation),
    ),
    _FlowPage.permissionExplanation => PermissionExplanationScreen(
      key: const ValueKey('permission-explanation'),
      selectedAppIds: _selectedApps,
      onBack: _goBack,
      onContinue: () {
        _acknowledgedDisclosure = false;
        _setPage(_FlowPage.permissionAction);
      },
      onPrivacyPolicy: _openPrivacyPolicy,
    ),
    _FlowPage.permissionAction => PermissionActionScreen(
      key: const ValueKey('permission-action'),
      acknowledged: _acknowledgedDisclosure,
      onAcknowledgedChanged: (value) {
        setState(() => _acknowledgedDisclosure = value);
      },
      onBack: _goBack,
      onContinue: _openAccessibilitySettings,
      onNotNow: () async {
        _acknowledgedDisclosure = false;
        _setPage(_FlowPage.accessUnavailable);
        await _saveSetup();
        await _refreshTrackingSnapshot();
      },
    ),
    _FlowPage.accessUnavailable => AccessUnavailableScreen(
      key: const ValueKey('access-unavailable'),
      trackingSnapshot: _trackingSnapshot,
      onBack: _goBack,
      onContinue: _continueAfterAccess,
      onOpenSettings: _openAccessibilitySettings,
      floatingCounterOptIn: _floatingCounterOptIn,
      overlayPermissionGranted:
          _trackingSnapshot?.overlayPermissionGranted == true,
      onRequestOverlay: _requestFloatingCounter,
      onWhyAccess: _showPrivacyNotice,
    ),
    _FlowPage.feedHandoff => FeedHandoffScreen(
      key: const ValueKey('feed-handoff'),
      selectedAppIds: _selectedApps,
      trackingSnapshot: _trackingSnapshot,
      onOpenApp: _finishAndOpenSupportedApp,
      onContinueToToday: _finishOnboarding,
      onBack: _goBack,
    ),
    _FlowPage.today => TodayHomeScreen(
      key: const ValueKey('today'),
      trackingPlatform: widget.trackingPlatform,
      appearance: widget.appearance,
      onAppearanceChanged: widget.onAppearanceChanged,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final previousPage = _previousOnboardingPage(_page);
    final isOnboarding = _page != _FlowPage.today;

    return PopScope<Object?>(
      canPop: _pendingPage == null && (!isOnboarding || previousPage == null),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && previousPage != null && _pendingPage == null) _goBack();
      },
      child: ColoredBox(
        color:
            _isStoryPage(_page) ||
                (_pendingPage != null && _isStoryPage(_pendingPage!))
            ? Colors.black
            : Theme.of(context).scaffoldBackgroundColor,
        child: FadeTransition(
          key: const ValueKey('onboarding-page-fade'),
          opacity: _pageFade,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.018),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: _pageFade, curve: Curves.easeOut),
                ),
            child: IgnorePointer(
              ignoring: _pendingPage != null,
              child: _buildCurrentPage(),
            ),
          ),
        ),
      ),
    );
  }
}
