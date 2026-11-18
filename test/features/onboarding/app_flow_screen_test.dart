import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rooko/core/design_system/app_typography.dart';
import 'package:rooko/core/models/progress.dart';
import 'package:rooko/core/platform/tracking_platform.dart';
import 'package:rooko/features/onboarding/app_flow_screen.dart';
import 'package:rooko/features/onboarding/onboarding_screens.dart';
import 'package:rooko/features/onboarding/onboarding_question_screen.dart';
import 'package:rooko/features/onboarding/onboarding_story_screen.dart';
import 'package:rooko/features/onboarding/rook_intro_screen.dart';
import 'package:rooko/features/onboarding/rook_setup_intro_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('onboarding privacy policy opens the published page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_onboarding_page': 'permissionExplanation',
    });
    final opened = <Uri>[];
    await tester.pumpWidget(
      _testApp(
        AppFlowScreen(
          launchPrivacyPolicy: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(
      opened.single.toString(),
      'https://sites.google.com/view/rooko/home',
    );
    expect(find.text('Privacy'), findsNothing);
  });

  testWidgets('shows onboarding instead of a second Flutter splash', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const AppFlowScreen()));

    expect(find.byKey(const ValueKey('splash')), findsNothing);
    expect(find.byType(CounterPreviewScreen), findsOneWidget);
    expect(find.text('Your feed, on your terms.'), findsNothing);
    expect(find.bySemanticsLabel('Instagram Reels'), findsOneWidget);
    expect(find.bySemanticsLabel('YouTube Shorts'), findsOneWidget);
    expect(find.textContaining('Facebook'), findsNothing);
    expect(
      find.text('Illustrative preview only · It won’t change your count.'),
      findsNothing,
    );
    final heading = tester.widget<Text>(
      find.text('See the counter in action.'),
    );
    expect(heading.style?.fontSize, 32);
    expect(heading.style?.fontWeight, FontWeight.w700);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(RookIntroScreen), findsOneWidget);
    expect(find.text("I'm Rook"), findsOneWidget);
    expect(find.text('Tap to continue'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Blurred Rook')), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(find.text('Tap to continue'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Ready Rook')), findsOneWidget);
    expect(find.text("I'm Rook"), findsOneWidget);
    expect(find.text('Hi, Rook'), findsOneWidget);
    expect(
      find.textContaining('I count your Reels and Shorts'),
      findsOneWidget,
    );
    await tester.tap(find.text('Hi, Rook'));
    await tester.pumpAndSettle();
    expect(find.byType(RookSetupIntroScreen), findsOneWidget);
    expect(find.text("I'm Rook"), findsOneWidget);
    expect(
      find.textContaining('I count your Reels and Shorts'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Before I start counting, let’s set up access.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Okay'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingQuestionScreen), findsOneWidget);
    expect(find.text('When do you usually watch reels?'), findsOneWidget);
    await _answerQuestions(tester);
    expect(
      find.text('A clear count, with your content left alone.'),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rook-privacy-bridge')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('story-future-heading')), findsOneWidget);
  });

  testWidgets('page handoff fades out, pauses, then fades in on resume', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: const AppFlowScreen(),
        ),
      ),
    );
    double opacity() => tester
        .widget<FadeTransition>(
          find.byKey(const ValueKey('onboarding-page-fade')),
        )
        .opacity
        .value;

    await tester.tap(find.text('Get started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(opacity(), inExclusiveRange(0, 1));
    expect(find.byType(CounterPreviewScreen), findsOneWidget);
    await tester.tap(find.text('Get started'), warnIfMissed: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(CounterPreviewScreen), findsOneWidget);
    final pausedOpacity = opacity();
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(), pausedOpacity);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(opacity(), 0);
    expect(find.byType(CounterPreviewScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 170));
    expect(find.byType(RookIntroScreen), findsOneWidget);
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacity(), 1);
    expect(find.text('Tap to continue'), findsOneWidget);
  });

  testWidgets('Rook introduction pauses its orbit when backgrounded', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: RookIntroScreen(onContinue: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('Rook greeting rises as counting copy gradually appears', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    Widget intro(RookIntroPhase phase) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: RookIntroScreen(
          key: const ValueKey('rook-intro'),
          phase: phase,
          onContinue: () {},
        ),
      ),
    );

    await tester.pumpWidget(intro(RookIntroPhase.gathering));
    await tester.pump(const Duration(milliseconds: 1500));
    final greeting = find.byKey(const ValueKey('rook-greeting'));
    final initialTop = tester.getTopLeft(greeting).dy;
    await tester.pumpWidget(intro(RookIntroPhase.revealed));
    await tester.pump();
    expect(MediaQuery.of(tester.element(greeting)).disableAnimations, isFalse);
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('rook-count-copy-opacity')),
          )
          .opacity,
      0,
    );

    await tester.pump(const Duration(milliseconds: 180));
    final midwayTop = tester.getTopLeft(greeting).dy;
    final midwayOpacity = tester
        .widget<Opacity>(find.byKey(const ValueKey('rook-count-copy-opacity')))
        .opacity;
    expect(midwayTop, lessThan(initialTop));
    expect(midwayOpacity, greaterThan(0));
    expect(midwayOpacity, lessThan(1));

    await tester.pump(const Duration(milliseconds: 380));
    expect(tester.getTopLeft(greeting).dy, lessThan(midwayTop));
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('rook-count-copy-opacity')),
          )
          .opacity,
      1,
    );
  });

  testWidgets('Rook actions fade out and in with a short gap', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    Widget intro(RookIntroPhase phase) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: RookIntroScreen(
          key: const ValueKey('rook-intro'),
          phase: phase,
          onContinue: () {},
        ),
      ),
    );

    await tester.pumpWidget(intro(RookIntroPhase.gathering));
    expect(_setupOpacity(tester, 'rook-tap-action-opacity'), 1);
    expect(_setupOpacity(tester, 'rook-hi-action-opacity'), 0);
    await tester.pumpWidget(intro(RookIntroPhase.revealed));
    await tester.pump(const Duration(milliseconds: 120));
    expect(_setupOpacity(tester, 'rook-tap-action-opacity'), 0);
    expect(_setupOpacity(tester, 'rook-hi-action-opacity'), 0);
    await tester.pump(const Duration(milliseconds: 220));
    expect(
      _setupOpacity(tester, 'rook-hi-action-opacity'),
      inExclusiveRange(0, 1),
    );
    await tester.pump(const Duration(milliseconds: 220));
    expect(_setupOpacity(tester, 'rook-hi-action-opacity'), 1);
  });

  testWidgets(
    'Hi Rook fades before navigation and Okay appears after a delay',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var continued = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: RookIntroScreen(
              phase: RookIntroPhase.revealed,
              onContinue: () => continued++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Hi, Rook'));
      await tester.pump();
      expect(continued, 0);
      await tester.pump(const Duration(milliseconds: 90));
      expect(
        _setupOpacity(tester, 'rook-hi-action-opacity'),
        inExclusiveRange(0, 1),
      );
      expect(continued, 0);
      await tester.pump(const Duration(milliseconds: 90));
      expect(_setupOpacity(tester, 'rook-hi-action-opacity'), 0);
      await tester.pump(const Duration(milliseconds: 20));
      expect(continued, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: RookSetupIntroScreen(onContinue: () {}),
          ),
        ),
      );
      expect(_setupOpacity(tester, 'setup-okay-opacity'), 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_setupOpacity(tester, 'setup-okay-opacity'), 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        _setupOpacity(tester, 'setup-okay-opacity'),
        inExclusiveRange(0, 1),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(_setupOpacity(tester, 'setup-okay-opacity'), 1);
    },
  );

  testWidgets('Hi Rook handoff pauses in background', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var continued = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: RookIntroScreen(
            phase: RookIntroPhase.revealed,
            onContinue: () => continued++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Hi, Rook'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 300));
    expect(continued, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 20));
    expect(continued, 1);
  });

  testWidgets('revealed Rook remains usable with large text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: RookIntroScreen(
            phase: RookIntroPhase.revealed,
            onContinue: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hi, Rook'), findsOneWidget);
  });

  testWidgets('setup introduction carries copy upward and reveals letters', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: RookSetupIntroScreen(onContinue: () {}),
        ),
      ),
    );

    const message = 'Before I start counting,\nlet’s set up access.';
    expect(_visibleSetupMessage(tester), isEmpty);
    expect(_setupOpacity(tester, 'setup-greeting-opacity'), 1);
    expect(_setupOpacity(tester, 'setup-explanation-opacity'), 1);
    expect(_setupOpacity(tester, 'setup-new-copy-opacity'), 0);
    final greeting = find.byKey(const ValueKey('setup-rook-greeting'));
    final explanation = find.byKey(const ValueKey('setup-count-explanation'));
    final newHeading = find.byKey(const ValueKey('setup-intro-message'));
    expect(
      tester.widget<Text>(explanation).style!.fontSize,
      AppTypeScale.xLarge,
    );
    final greetingStart = tester.getTopLeft(greeting).dy;
    final explanationStart = tester.getTopLeft(explanation).dy;
    await tester.pump(const Duration(milliseconds: 300));
    final greetingMid = tester.getTopLeft(greeting).dy;
    final explanationMid = tester.getTopLeft(explanation).dy;
    expect(greetingMid, lessThan(greetingStart));
    expect(explanationMid, lessThan(explanationStart));
    expect(
      _setupOpacity(tester, 'setup-greeting-opacity'),
      inExclusiveRange(0.26, 1),
    );
    expect(
      _setupOpacity(tester, 'setup-explanation-opacity'),
      inExclusiveRange(0.26, 1),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(greeting).dy, lessThan(greetingMid));
    expect(tester.getTopLeft(explanation).dy, lessThan(explanationMid));
    expect(
      tester.widget<Text>(explanation).style!.fontSize,
      AppTypeScale.large,
    );
    expect(
      tester.widget<Text>(explanation).style!.fontSize,
      tester.widget<Text>(newHeading).style!.fontSize,
    );
    expect(
      tester.widget<Text>(explanation).style!.fontWeight,
      tester.widget<Text>(newHeading).style!.fontWeight,
    );
    expect(
      _setupOpacity(tester, 'setup-greeting-opacity'),
      closeTo(0.26, 0.001),
    );
    expect(
      _setupOpacity(tester, 'setup-explanation-opacity'),
      closeTo(0.26, 0.001),
    );
    expect(
      _setupOpacity(tester, 'setup-new-copy-opacity'),
      inExclusiveRange(0, 1),
    );
    final partial = _visibleSetupMessage(tester);
    expect(partial.length, greaterThan(0));
    expect(partial.length, lessThan(message.length));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_visibleSetupMessage(tester), partial);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    expect(_visibleSetupMessage(tester), message);
    expect(_setupOpacity(tester, 'setup-new-copy-opacity'), 1);
  });

  testWidgets('setup transition starts with the revealed Rook copy in place', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    Widget screen(Widget child) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: child,
      ),
    );

    await tester.pumpWidget(
      screen(
        RookIntroScreen(phase: RookIntroPhase.revealed, onContinue: () {}),
      ),
    );
    final greetingTop = tester
        .getTopLeft(find.byKey(const ValueKey('rook-greeting')))
        .dy;
    final explanationTop = tester
        .getTopLeft(find.byKey(const ValueKey('rook-count-explanation')))
        .dy;

    await tester.pumpWidget(screen(RookSetupIntroScreen(onContinue: () {})));
    final nextGreetingTop = tester
        .getTopLeft(find.byKey(const ValueKey('setup-rook-greeting')))
        .dy;
    final nextExplanationTop = tester
        .getTopLeft(find.byKey(const ValueKey('setup-count-explanation')))
        .dy;
    expect((nextGreetingTop - greetingTop).abs(), lessThan(28));
    expect((nextExplanationTop - explanationTop).abs(), lessThan(28));
  });

  testWidgets('setup introduction shows complete copy for reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: RookSetupIntroScreen(onContinue: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _visibleSetupMessage(tester),
      'Before I start counting,\nlet’s set up access.',
    );
    expect(find.text('Okay'), findsOneWidget);
    expect(
      _setupOpacity(tester, 'setup-greeting-opacity'),
      closeTo(0.26, 0.001),
    );
    expect(
      _setupOpacity(tester, 'setup-explanation-opacity'),
      closeTo(0.26, 0.001),
    );
    expect(_setupOpacity(tester, 'setup-new-copy-opacity'), 1);
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('setup introduction draft returns to Rook reveal on Back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_onboarding_page': 'rookSetupIntro',
    });
    await tester.pumpWidget(_testApp(const AppFlowScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(RookSetupIntroScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hi, Rook'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Ready Rook')), findsOneWidget);
  });

  testWidgets(
    'still finding it skips dream follow-ups and Back returns there',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'rooko_onboarding_page': 'questionnaire',
        'rooko_onboarding_question_index': 3,
      });
      await tester.pumpWidget(_testApp(const AppFlowScreen()));
      await tester.pumpAndSettle();
      expect(
        find.text('Do you have a dream or interest you want to follow?'),
        findsOneWidget,
      );
      await tester.tap(find.text("I'm still finding it"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('What do you think, how many reels did you watch yesterday?'),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.text('Do you have a dream or interest you want to follow?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Yes, I have a dream'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text("What's your dream?"), findsOneWidget);
    },
  );

  testWidgets(
    'system Back fades out a question before showing the previous one',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      SharedPreferences.setMockInitialValues({
        'rooko_onboarding_page': 'questionnaire',
        'rooko_onboarding_question_index': 1,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: false),
            child: const AppFlowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("What's your average screen time?"), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.text("What's your average screen time?"), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('When do you usually watch reels?'), findsOneWidget);
    },
  );

  testWidgets('question draft restores a single revised answer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_onboarding_page': 'questionnaire',
      'rooko_onboarding_question_index': 1,
    });
    await tester.pumpWidget(_testApp(const AppFlowScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Under 3 hours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9+ hours'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_testApp(const AppFlowScreen()));
    await tester.pumpAndSettle();
    expect(find.text("What's your average screen time?"), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNotNull);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('rooko_onboarding_question_draft'),
      contains('9+ hours'),
    );
    expect(
      preferences.getString('rooko_onboarding_question_draft'),
      isNot(contains('Under 3 hours')),
    );
  });

  testWidgets('recall draft restores through Back and its result', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_onboarding_page': 'recall',
      'rooko_onboarding_question_index': 7,
      'rooko_onboarding_question_draft': '{"yesterdayEstimate":["400"],"healthEffects":["Headaches"],"dreamStatus":["Yes, I have an interest"]}',
      'rooko_onboarding_recall_choice': 'Only a few',
    });
    await tester.pumpWidget(_testApp(const AppFlowScreen()));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OnboardingStoryScreen>(find.byType(OnboardingStoryScreen))
          .recallChoice,
      'Only a few',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OnboardingStoryScreen>(find.byType(OnboardingStoryScreen))
          .stage,
      OnboardingStoryStage.projection,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text('What do you think, how many reels did you watch yesterday?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OnboardingStoryScreen>(find.byType(OnboardingStoryScreen))
          .recallChoice,
      'Only a few',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('story-memory-result')), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('rooko_onboarding_recall_choice'),
      'Only a few',
    );
  });

  testWidgets('invalid question draft does not break onboarding restore', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_onboarding_page': 'questionnaire',
      'rooko_onboarding_question_index': 2,
      'rooko_onboarding_question_draft': '{broken',
    });
    await tester.pumpWidget(_testApp(const AppFlowScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text('What health problems do you face because of reels?'),
      findsOneWidget,
    );
  });

  testWidgets('opens Today directly after onboarding has been completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const AppFlowScreen(onboardingComplete: true)),
    );

    expect(find.byKey(const ValueKey('today')), findsOneWidget);
  });

  testWidgets('Android Back returns nested Progress to Today', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      _testApp(
        AppFlowScreen(
          onboardingComplete: true,
          trackingPlatform: FakeTrackingPlatform(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('top-nav-progress')));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('does not open Accessibility Settings before acknowledgement', (
    tester,
  ) async {
    final tracking = FakeTrackingPlatform();
    await tester.pumpWidget(
      _testApp(AppFlowScreen(trackingPlatform: tracking)),
    );

    await _advanceToPermissionAction(tester);

    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue').last,
    );
    expect(continueButton.onPressed, isNull);
    expect(tracking.openCalls, 0);
  });

  testWidgets('permission guide can be dismissed without opening Settings', (
    tester,
  ) async {
    final tracking = FakeTrackingPlatform();
    await tester.pumpWidget(
      _testApp(AppFlowScreen(trackingPlatform: tracking)),
    );
    await _advanceToPermissionAction(tester);
    await tester.ensureVisible(
      find.text('I understand how this access would be used.'),
    );
    await tester.tap(find.text('I understand how this access would be used.'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue').last);
    await tester.pumpAndSettle();
    expect(find.text('Turn on Accessibility for counting'), findsOneWidget);
    await tester.ensureVisible(find.text('Not now').last);
    await tester.tap(find.text('Not now').last);
    await tester.pumpAndSettle();
    expect(tracking.openCalls, 0);
    expect(find.text('Turn on Accessibility for counting'), findsNothing);
    expect(find.text('Ready to turn tracking on?'), findsOneWidget);
  });

  testWidgets('final handoff opens only a selected installed app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_onboarding_page': 'feedHandoff',
      'rooko_selected_supported_apps': ['youtube'],
    });
    final tracking = FakeTrackingPlatform();
    await tester.pumpWidget(
      _testApp(AppFlowScreen(trackingPlatform: tracking)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open YouTube'), findsOneWidget);
    await tester.tap(find.text('Open YouTube'));
    await tester.pumpAndSettle();
    expect(tracking.openedAppIds, ['youtube']);
    expect(find.byKey(const ValueKey('today')), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('rooko_onboarding_complete'), isTrue);
  });

  testWidgets(
    'consent auto-selects installed YouTube when apps were untouched',
    (tester) async {
      final tracking = FakeTrackingPlatform();
      await tester.pumpWidget(
        _testApp(AppFlowScreen(trackingPlatform: tracking)),
      );
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tap to continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hi, Rook'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Okay'));
      await tester.pumpAndSettle();
      await _answerQuestions(tester);
      await tester.tap(find.text('Continue').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('I understand how this access would be used.'),
      );
      await tester.tap(
        find.text('I understand how this access would be used.'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Android settings'));
      await tester.pumpAndSettle();

      expect(tracking.selectedApps, {'youtube'});
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList('rooko_selected_supported_apps'), [
        'youtube',
      ]);
    },
  );

  testWidgets('declining access persists the selected app and reaches Today', (
    tester,
  ) async {
    final tracking = FakeTrackingPlatform();
    await tester.pumpWidget(
      _testApp(AppFlowScreen(trackingPlatform: tracking)),
    );

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tap to continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hi, Rook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Okay'));
    await tester.pumpAndSettle();
    await _answerQuestions(tester);
    expect(
      find.text('A clear count, with your content left alone.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('feed-handoff')), findsOneWidget);
    await tester.tap(find.text('Go to Today'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('rooko_onboarding_complete'), isTrue);
    expect(preferences.getString('rooko_onboarding_question_draft'), isNull);
    expect(preferences.getInt('rooko_onboarding_question_index'), isNull);
    expect(preferences.getStringList('rooko_selected_supported_apps'), [
      'youtube',
    ]);
    expect(tracking.openCalls, 0);
    expect(find.byKey(const ValueKey('today')), findsOneWidget);
  });

  testWidgets('refreshes actual service state after returning from Settings', (
    tester,
  ) async {
    final tracking = FakeTrackingPlatform();
    await tester.pumpWidget(
      _testApp(AppFlowScreen(trackingPlatform: tracking)),
    );
    await _advanceToPermissionAction(tester);

    await tester.ensureVisible(
      find.text('I understand how this access would be used.'),
    );
    await tester.tap(find.text('I understand how this access would be used.'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue').last);
    await tester.pumpAndSettle();
    expect(find.text('Turn on Accessibility for counting'), findsOneWidget);
    await tester.tap(find.text('Open Android settings'));
    await tester.pumpAndSettle();

    expect(tracking.openCalls, 1);
    tracking.serviceEnabled = true;
    tracking.serviceOperational = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Access is on'), findsNWidgets(2));
    expect(find.textContaining('estimate'), findsNothing);
    expect(find.textContaining('partial'), findsNothing);
    expect(find.textContaining('confirm'), findsNothing);
  });

  testWidgets(
    'floating-counter opt-in verifies a grant after system Settings',
    (tester) async {
      final tracking = FakeTrackingPlatform();
      await _reachFloatingCounter(tester, tracking);

      expect(find.text('Floating counter'), findsOneWidget);
      expect(find.text('Estimated counting available'), findsNothing);
      expect(find.text('YouTube Shorts'), findsNothing);
      expect(find.text('Instagram'), findsNothing);
      expect(
        find.textContaining(
          'The floating counter needs separate Android overlay access.',
        ),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Allow'));
      await tester.pumpAndSettle();
      expect(find.text('Show the floating counter over apps'), findsOneWidget);
      await tester.tap(find.text('Open Android settings').last);
      await tester.pumpAndSettle();

      expect(tracking.overlayOpenCalls, 1);
      expect(tracking.bubbleEnabled, isTrue);

      tracking.overlayPermissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Floating counter on'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    },
  );

  testWidgets('overlay denial can be skipped without enabling the counter', (
    tester,
  ) async {
    final tracking = FakeTrackingPlatform();
    await _reachFloatingCounter(tester, tracking);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Allow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Android settings').last);
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Floating counter'), findsOneWidget);
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle();

    expect(tracking.bubbleEnabled, isFalse);
    expect(find.byKey(const ValueKey('feed-handoff')), findsOneWidget);
    await tester.tap(find.text('Go to Today'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today')), findsOneWidget);
  });

  testWidgets(
    'persists floating-counter opt-in when overlay access is already granted',
    (tester) async {
      final tracking = FakeTrackingPlatform()..overlayPermissionGranted = true;
      await _reachFloatingCounter(tester, tracking);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Allow'));
      await tester.pumpAndSettle();
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('feed-handoff')), findsOneWidget);
      await tester.tap(find.text('Go to Today'));
      await tester.pumpAndSettle();

      expect(tracking.bubbleEnabled, isTrue);
      expect(find.byKey(const ValueKey('today')), findsOneWidget);
    },
  );

  testWidgets('onboarding saves apps without collecting a daily limit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final tracking = FakeTrackingPlatform();
    await tester.pumpWidget(
      _testApp(AppFlowScreen(trackingPlatform: tracking)),
    );
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tap to continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hi, Rook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Okay'));
    await tester.pumpAndSettle();
    await _answerQuestions(tester);
    expect(
      find.text('A clear count, with your content left alone.'),
      findsOneWidget,
    );
    expect(find.text('Add'), findsNothing);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('rooko_selected_supported_apps'), [
      'youtube',
    ]);
    expect(preferences.getInt('rooko_daily_limit'), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _testApp(AppFlowScreen(trackingPlatform: tracking)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('A clear count, with your content left alone.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Daily limit'), findsNothing);
  });

  testWidgets(
    'restores the floating-counter draft and Back returns to access',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'rooko_onboarding_page': 'floatingCounter',
        'rooko_selected_supported_apps': ['youtube'],
      });
      await tester.pumpWidget(_testApp(const AppFlowScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Enable access to start counting'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Ready to turn tracking on?'), findsOneWidget);
    },
  );

  testWidgets('old app-selection draft resumes at privacy setup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_onboarding_page': 'supportedAppsSelection',
      'rooko_selected_supported_apps': ['youtube'],
      'rooko_app_selection_touched': true,
    });
    await tester.pumpWidget(_testApp(const AppFlowScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('A clear count, with your content left alone.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('YouTube Shorts is selected for counting'),
      findsOneWidget,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('rooko_onboarding_page'),
      'permissionExplanation',
    );
    expect(preferences.getStringList('rooko_selected_supported_apps'), [
      'youtube',
    ]);
  });

  testWidgets('old app-intro draft resumes at Rook and returns to preview', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_onboarding_page': 'supportedAppsIntro',
    });
    await tester.pumpWidget(_testApp(const AppFlowScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(RookIntroScreen), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('rooko_onboarding_page'), 'rookIntro');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CounterPreviewScreen), findsOneWidget);
  });

  testWidgets('Rook reveal resumes from draft and Back shows blurred Rook', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_onboarding_page': 'rookReveal',
    });
    await tester.pumpWidget(_testApp(const AppFlowScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Rook'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Ready Rook')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Tap to continue'), findsOneWidget);
    expect(find.text("I'm Rook"), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Blurred Rook')), findsOneWidget);
  });
}

String _visibleSetupMessage(WidgetTester tester) {
  final text = tester.widget<Text>(
    find.byKey(const ValueKey('setup-intro-message')),
  );
  return (text.textSpan! as TextSpan).children!.first.toPlainText();
}

double _setupOpacity(WidgetTester tester, String key) =>
    tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;

Widget _testApp(Widget screen) => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: screen,
  ),
);

Future<void> _reachFloatingCounter(
  WidgetTester tester,
  FakeTrackingPlatform tracking,
) async {
  await tester.pumpWidget(_testApp(AppFlowScreen(trackingPlatform: tracking)));
  await _advanceToPermissionAction(tester);
  await tester.ensureVisible(
    find.text('I understand how this access would be used.'),
  );
  await tester.tap(find.text('I understand how this access would be used.'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Continue').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Android settings'));
  await tester.pumpAndSettle();
  tracking
    ..serviceEnabled = true
    ..serviceOperational = true;
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

Future<void> _advanceToPermissionAction(WidgetTester tester) async {
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tap to continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hi, Rook'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Okay'));
  await tester.pumpAndSettle();
  await _answerQuestions(tester);
  await tester.tap(find.text('Continue').last);
  await tester.pumpAndSettle();
}

Future<void> _answerQuestions(WidgetTester tester) async {
  const choices = [
    'All day',
    'Under 3 hours',
    'Lack of sleep',
    'Yes, I have a dream',
    'Studies',
    'No, not at all',
    'Not at all',
    '300',
  ];
  for (final choice in choices) {
    expect(find.byType(OnboardingQuestionScreen), findsOneWidget);
    await tester.tap(find.text(choice));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle();
  }
  await _advanceStory(tester);
}

Future<void> _advanceStory(WidgetTester tester) async {
  for (final stage in [
    OnboardingStoryStage.projection,
    OnboardingStoryStage.recall,
    OnboardingStoryStage.memory,
    OnboardingStoryStage.impact,
    OnboardingStoryStage.future,
  ]) {
    expect(
      tester
          .widget<OnboardingStoryScreen>(find.byType(OnboardingStoryScreen))
          .stage,
      stage,
    );
    if (stage == OnboardingStoryStage.recall) {
      await tester.ensureVisible(find.text("I don't remember any"));
      await tester.tap(find.text("I don't remember any"));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Continue').last);
    await tester.pumpAndSettle();
  }
  expect(find.byKey(const ValueKey('rook-privacy-bridge')), findsOneWidget);
  await tester.tap(find.text('Continue').last);
  await tester.pumpAndSettle();
}

class FakeTrackingPlatform implements TrackingPlatform {
  bool serviceEnabled = false;
  bool serviceOperational = false;
  bool serviceInterruptedToday = false;
  bool consentAcknowledged = false;
  bool bubbleEnabled = false;
  bool overlayPermissionGranted = false;
  int openCalls = 0;
  int overlayOpenCalls = 0;
  final openedAppIds = <String>[];
  Set<String> selectedApps = {};

  @override
  Future<ProgressRange> queryProgress(
    DateTime startDate,
    DateTime endDate,
  ) async => const ProgressRange(checkedAtMillis: 0, days: []);

  @override
  Future<ProgressCorrection> addCorrection({
    required String localDate,
    required String appId,
    required int delta,
    String? reason,
  }) async => ProgressCorrection(
    id: 'correction',
    localDate: DateTime.parse(localDate),
    appId: appId,
    delta: delta,
    reason: reason,
    createdAtMillis: 0,
    reversesCorrectionId: null,
  );

  @override
  Future<ProgressCorrection> undoCorrection(String correctionId) async =>
      ProgressCorrection(
        id: 'reversal',
        localDate: DateTime(2026, 11, 6),
        appId: 'youtube',
        delta: -1,
        reason: null,
        createdAtMillis: 0,
        reversesCorrectionId: correctionId,
      );

  @override
  Future<void> setSelectedApps(Set<String> appIds) async {
    selectedApps = appIds;
  }

  @override
  Future<void> setConsentAcknowledged(bool acknowledged) async {
    consentAcknowledged = acknowledged;
  }

  @override
  Future<void> setBubbleEnabled(bool enabled) async {
    bubbleEnabled = enabled;
  }

  @override
  Future<bool> openOverlaySettings() async {
    overlayOpenCalls++;
    return true;
  }

  @override
  Future<bool> openAccessibilitySettings() async {
    openCalls++;
    return true;
  }

  @override
  Future<bool> openSupportedApp(String appId) async {
    openedAppIds.add(appId);
    return true;
  }

  @override
  Future<bool> openSupportedAppSettings(String appId) async => true;

  @override
  Future<bool> openSupportEmail(SupportEmailKind kind) async => true;

  @override
  Future<TrackingSnapshot> getSnapshot(Set<String> appIds) async {
    return TrackingSnapshot(
      serviceEnabled: serviceEnabled,
      serviceOperational: serviceOperational,
      serviceInterruptedToday: serviceInterruptedToday,
      consentAcknowledged: consentAcknowledged,
      bubbleEnabled: bubbleEnabled,
      overlayPermissionGranted: overlayPermissionGranted,
      checkedAtMillis: 1_800_000_000_000,
      localDate: '2026-11-06',
      apps: {
        'youtube': const AppTrackingSnapshot(
          appId: 'youtube',
          selected: true,
          installed: true,
          versionName: '21.43.523',
          profileAvailable: true,
          confidence: TrackingConfidence.estimated,
          confirmedCount: 0,
          estimatedCount: 0,
        ),
      },
    );
  }
}
