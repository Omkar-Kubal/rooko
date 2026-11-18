import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rooko/features/onboarding/onboarding_question_screen.dart';
import 'package:rooko/features/today/rook_state.dart';

void main() {
  test('all eight questions and answer sets match the supplied sequence', () {
    expect(onboardingQuestions.map((question) => question.prompt), [
      'When do you usually watch reels?',
      "What's your average screen time?",
      'What health problems do you face because of reels?',
      'Do you have a dream or interest you want to follow?',
      "What's your dream?",
      'Do you get enough time to follow your dream?',
      'Does watching reels help you achieve your dream?',
      'What do you think, how many reels did you watch yesterday?',
    ]);
    expect(onboardingQuestions[0].options, [
      'All day',
      "When I'm bored",
      'During study or work',
      'After dinner',
      'Late at night',
    ]);
    expect(onboardingQuestions[1].options, [
      'Under 3 hours',
      '3–6 hours',
      '6–9 hours',
      '9+ hours',
    ]);
    expect(onboardingQuestions[2].options, [
      'Lack of sleep',
      'Headaches',
      'Unable to focus',
      'Poor memory',
      'Feel low',
      'Feel depressed',
    ]);
    expect(onboardingQuestions[3].options, [
      'Yes, I have a dream',
      'Yes, I have an interest',
      "I'm still finding it",
    ]);
    expect(onboardingQuestions[4].options, [
      'Studies',
      'Fitness',
      'Music',
      'Art',
      'Business',
      'A new skill',
    ]);
    expect(onboardingQuestions[5].options, [
      'No, not at all',
      "I don't know where my time goes",
      'Yes, but very little',
    ]);
    expect(onboardingQuestions[6].options, ['Not at all', 'Yes, a little']);
    expect(onboardingQuestions[7].options, [
      '300',
      '400',
      '600',
      '800',
      '1,000+',
    ]);
    expect(onboardingQuestions[0].multiSelect, isTrue);
    expect(onboardingQuestions[2].multiSelect, isTrue);
    for (final index in [1, 3, 4, 5, 6, 7]) {
      expect(onboardingQuestions[index].multiSelect, isFalse);
    }
  });

  test('still finding a dream skips only the three dream follow-ups', () {
    final answers = <String, Set<String>>{
      'dreamStatus': {"I'm still finding it"},
    };
    expect(nextQuestionIndex(3, answers), 7);
    expect(previousQuestionIndex(7, answers), 3);
    answers['dreamStatus'] = {'Yes, I have a dream'};
    expect(nextQuestionIndex(3, answers), 4);
    expect(previousQuestionIndex(7, answers), 6);
  });

  testWidgets('screen-time choices update the heading Rook SVG', (
    tester,
  ) async {
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) => OnboardingQuestionScreen(
              question: onboardingQuestions[1],
              questionIndex: 1,
              questionCount: onboardingQuestions.length,
              selectedOptions: selected,
              onToggleOption: (option) => setState(() => selected = {option}),
              onContinue: () {},
            ),
          ),
        ),
      ),
    );

    void expectHeadingRook(RookState state) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '${state.label} Rook',
        ),
        findsOneWidget,
      );
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
      expect((svg.bytesLoader as SvgAssetLoader).assetName, state.svgAsset);
    }

    expectHeadingRook(RookState.ready);
    for (final (option, state) in [
      ('Under 3 hours', RookState.ready),
      ('3–6 hours', RookState.strained),
      ('6–9 hours', RookState.injured),
      ('9+ hours', RookState.queasy),
    ]) {
      await tester.tap(find.text(option));
      await tester.pump();
      expectHeadingRook(state);
    }
  });

  testWidgets('restored screen-time answer restores the matching Rook', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingQuestionScreen(
          question: onboardingQuestions[1],
          questionIndex: 1,
          questionCount: onboardingQuestions.length,
          selectedOptions: const {'6–9 hours'},
          onToggleOption: (_) {},
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Injured Rook',
      ),
      findsOneWidget,
    );
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
    expect(
      (svg.bytesLoader as SvgAssetLoader).assetName,
      RookState.injured.svgAsset,
    );
  });

  testWidgets('multi-select question requires an answer and allows toggling', (
    tester,
  ) async {
    var selected = <String>{};
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => OnboardingQuestionScreen(
            question: onboardingQuestions.first,
            questionIndex: 0,
            questionCount: onboardingQuestions.length,
            selectedOptions: selected,
            onToggleOption: (option) => setState(() {
              selected = {...selected};
              if (!selected.add(option)) selected.remove(option);
            }),
            onContinue: () => continued = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('All day'));
    await tester.pump();
    await tester.tap(find.text("When I'm bored"));
    await tester.pump();
    expect(selected, {'All day', "When I'm bored"});
    await tester.tap(find.text('All day'));
    await tester.pump();
    expect(selected, {"When I'm bored"});
    await tester.tap(find.text('Continue'));
    expect(continued, isTrue);
  });

  testWidgets('question heading and answers fade in after the page handoff', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final screenKey = GlobalKey<OnboardingQuestionScreenState>();
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: StatefulBuilder(
            builder: (context, setState) => OnboardingQuestionScreen(
              key: screenKey,
              question: onboardingQuestions[index],
              questionIndex: index,
              questionCount: onboardingQuestions.length,
              selectedOptions: const {'All day'},
              onToggleOption: (_) {},
              onContinue: () => setState(() => index++),
            ),
          ),
        ),
      ),
    );
    double opacity(String key) =>
        tester.widget<FadeTransition>(find.byKey(ValueKey(key))).opacity.value;

    expect(opacity('question-heading-fade'), 0);
    expect(opacity('question-answers-fade'), 0);
    await tester.pump(const Duration(milliseconds: 180));
    expect(opacity('question-heading-fade'), greaterThan(0));
    expect(opacity('question-answers-fade'), 0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(index, 0);
    expect(find.text('When do you usually watch reels?'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(index, 1);
    expect(find.text("What's your average screen time?"), findsOneWidget);
    expect(opacity('question-heading-fade'), 1);
    expect(opacity('question-answers-fade'), 1);
  });

  testWidgets('reduced motion changes question immediately', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: OnboardingQuestionScreen(
            question: onboardingQuestions.first,
            questionIndex: 0,
            questionCount: onboardingQuestions.length,
            selectedOptions: const {'All day'},
            onToggleOption: (_) {},
            onContinue: () => continued = true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('question-heading-fade')),
          )
          .opacity
          .value,
      1,
    );
    await tester.tap(find.text('Continue'));
    expect(continued, isTrue);
  });

  testWidgets('question handoff pauses while the app is backgrounded', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: OnboardingQuestionScreen(
            question: onboardingQuestions.first,
            questionIndex: 0,
            questionCount: onboardingQuestions.length,
            selectedOptions: const {'All day'},
            onToggleOption: (_) {},
            onContinue: () => continued = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(continued, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(continued, isTrue);
  });

  testWidgets('long question remains usable at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: StatefulBuilder(
            builder: (context, setState) => OnboardingQuestionScreen(
              question: onboardingQuestions[2],
              questionIndex: 2,
              questionCount: onboardingQuestions.length,
              selectedOptions: selected,
              onToggleOption: (option) => setState(() {
                selected = {...selected, option};
              }),
              onContinue: () {},
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feel depressed'));
    await tester.pumpAndSettle();
    expect(selected, {'Feel depressed'});
    expect(tester.takeException(), isNull);
  });
}
