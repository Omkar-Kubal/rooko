import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/features/onboarding/onboarding_story_screen.dart';

void main() {
  test('projection follows the chosen daily answer', () {
    final projection = OnboardingProjection.fromAnswer('400');
    expect(projection.daily, 400);
    expect(projection.weekly, 2800);
    expect(projection.monthly, 12000);
    expect(projection.yearly, 146000);
    expect(projection.monthsPerYear, 2);
    expect(projection.monthsInTenYears, 20);
    expect(OnboardingProjection.fromAnswer('1,000+').daily, 1000);
    expect(formatStoryNumber(projection.yearly), '146,000');
    expect(formatStoryNumber(projection.monthsPerYear), '2');
  });

  testWidgets('story selections use near-black fills and white foreground', (
    tester,
  ) async {
    await tester.pumpWidget(
      _storyApp(
        const OnboardingStoryScreen(
          stage: OnboardingStoryStage.recall,
          projection: OnboardingProjection(400),
          recallChoice: "I don't remember any",
          healthEffects: {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: _unusedChoice,
          onContinue: _unusedContinue,
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    final fill = button.style!.backgroundColor!.resolve({})!;
    expect(fill, isNot(Colors.white));
    expect(fill.computeLuminance(), lessThan(0.05));
    expect(button.style!.foregroundColor!.resolve({}), Colors.white);
    expect(
      tester.widget<Text>(find.text("I don't remember any")).style!.color,
      Colors.white,
    );
  });

  test(
    'every yesterday answer projects exact week, month, and year counts',
    () {
      for (final (answer, daily) in [
        ('300', 300),
        ('400', 400),
        ('600', 600),
        ('800', 800),
        ('1,000+', 1000),
      ]) {
        final projection = OnboardingProjection.fromAnswer(answer);
        expect(projection.daily, daily);
        expect(projection.weekly, daily * 7);
        expect(projection.monthly, daily * 30);
        expect(projection.yearly, daily * 365);
      }
    },
  );

  testWidgets('projection animates day through year before Continue', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var continued = false;
    await tester.pumpWidget(
      _storyApp(
        OnboardingStoryScreen(
          stage: OnboardingStoryStage.projection,
          projection: const OnboardingProjection(400),
          recallChoice: null,
          healthEffects: const {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: (_) {},
          onContinue: () => continued = true,
        ),
        reduceMotion: false,
      ),
    );
    expect(find.text('reels a day'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.text('400'), findsOneWidget);
    expect(find.text('reels a day'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('reels a week'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 8000));
    expect(find.text('146,000'), findsOneWidget);
    expect(find.text('reels a year'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(continued, isFalse);
    await tester.pump(const Duration(milliseconds: 280));
    expect(continued, isFalse);
    expect(
      tester
          .widget<FadeTransition>(find.byKey(const ValueKey('story-exit-fade')))
          .opacity
          .value,
      0,
    );
    await tester.pump(const Duration(milliseconds: 580));
    await tester.pump();
    expect(continued, isTrue);
  });

  testWidgets('recall dots scatter away while the memory result appears', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      _storyApp(
        const OnboardingStoryScreen(
          stage: OnboardingStoryStage.memory,
          projection: OnboardingProjection(400),
          recallChoice: "I don't remember any",
          healthEffects: {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: _unusedChoice,
          onContinue: _unusedContinue,
        ),
        reduceMotion: false,
      ),
    );
    double dotOpacity() => tester
        .widget<Opacity>(find.byKey(const ValueKey('story-memory-dots')))
        .opacity;
    await tester.pump(const Duration(milliseconds: 200));
    final earlyOpacity = dotOpacity();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(dotOpacity(), lessThan(earlyOpacity));
  });

  testWidgets('one revolving sphere travels through projection and recall', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var stage = OnboardingStoryStage.projection;
    await tester.pumpWidget(
      _storyApp(
        StatefulBuilder(
          builder: (context, setState) => OnboardingStoryScreen(
            key: const ValueKey('continuous-story'),
            stage: stage,
            projection: const OnboardingProjection(1000),
            recallChoice: "I don't remember any",
            healthEffects: const {'Headaches'},
            dreamStatus: 'Yes, I have an interest',
            onRecallChanged: (_) {},
            onContinue: () => setState(() {
              stage = OnboardingStoryStage.values[stage.index + 1];
            }),
          ),
        ),
        reduceMotion: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 11000));
    final orbit = tester
        .widget<RotationTransition>(find.byKey(const ValueKey('story-orbit')))
        .turns;
    final projectionCenter = tester.getCenter(
      find.byKey(const ValueKey('story-shared-orb')),
    );
    final firstTurn = orbit.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(orbit.value, isNot(firstTurn));
    expect(find.text('365,000'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(stage, OnboardingStoryStage.projection);
    expect(find.byKey(const ValueKey('story-shared-orb')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    final travelingCenter = tester.getCenter(
      find.byKey(const ValueKey('story-shared-orb')),
    );
    expect(travelingCenter.dy, isNot(projectionCenter.dy));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(stage, OnboardingStoryStage.recall);
    expect(
      tester
          .widget<RotationTransition>(find.byKey(const ValueKey('story-orbit')))
          .turns,
      same(orbit),
    );
    final recallCenter = tester.getCenter(
      find.byKey(const ValueKey('story-shared-orb')),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    expect(orbit.value, isNot(firstTurn));

    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final leftCenter = tester.getCenter(
      find.byKey(const ValueKey('story-shared-orb')),
    );
    expect(leftCenter.dx, lessThan(recallCenter.dx));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(stage, OnboardingStoryStage.memory);
    final memoryStart = tester.getCenter(
      find.byKey(const ValueKey('story-shared-orb')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final memoryMiddle = tester.getCenter(
      find.byKey(const ValueKey('story-shared-orb')),
    );
    expect(memoryMiddle.dx, greaterThan(memoryStart.dx));
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('story-memory-result')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity,
      0,
    );
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('story-memory-dots')))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('story-memory-result')),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity,
      1,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('sphere handoff waits for resume before opening recall', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var continued = false;
    await tester.pumpWidget(
      _storyApp(
        OnboardingStoryScreen(
          stage: OnboardingStoryStage.projection,
          projection: const OnboardingProjection(600),
          recallChoice: null,
          healthEffects: const {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: (_) {},
          onContinue: () => continued = true,
        ),
        reduceMotion: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 11000));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 500));
    expect(continued, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));
    expect(continued, isFalse);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(continued, isTrue);
  });

  testWidgets('recall answer is required and reduced motion is immediate', (
    tester,
  ) async {
    String? choice;
    var continued = false;
    await tester.pumpWidget(
      _storyApp(
        StatefulBuilder(
          builder: (context, setState) => OnboardingStoryScreen(
            stage: OnboardingStoryStage.recall,
            projection: const OnboardingProjection(400),
            recallChoice: choice,
            healthEffects: const {'Headaches'},
            dreamStatus: 'Yes, I have an interest',
            onRecallChanged: (value) => setState(() => choice = value),
            onContinue: () => continued = true,
          ),
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Only a few'));
    await tester.tap(find.text('Only a few'));
    await tester.pump();
    expect(choice, 'Only a few');
    await tester.tap(find.text('Continue'));
    expect(continued, isTrue);
  });

  testWidgets('story motion pauses in the background', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      _storyApp(
        OnboardingStoryScreen(
          stage: OnboardingStoryStage.projection,
          projection: const OnboardingProjection(400),
          recallChoice: null,
          healthEffects: const {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: (_) {},
          onContinue: () {},
        ),
        reduceMotion: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 11000));
    expect(find.text('reels a year'), findsOneWidget);
  });

  testWidgets('impact reveals months, selected symptom, then interest', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      _storyApp(
        const OnboardingStoryScreen(
          stage: OnboardingStoryStage.impact,
          projection: OnboardingProjection(400),
          recallChoice: "I don't remember any",
          healthEffects: {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: _unusedChoice,
          onContinue: _unusedContinue,
        ),
        reduceMotion: false,
      ),
    );
    double opacity(String key) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    await tester.pump(const Duration(milliseconds: 2100));
    expect(opacity('story-impact-months'), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 2700));
    expect(opacity('story-impact-health'), greaterThan(0));
    await tester.pumpAndSettle();
    expect(opacity('story-impact-interest'), 1);
    expect(opacity('story-impact-health'), 0);
  });

  testWidgets('impact and future use the selected answers', (tester) async {
    await tester.pumpWidget(
      _storyApp(
        const OnboardingStoryScreen(
          stage: OnboardingStoryStage.impact,
          projection: OnboardingProjection(400),
          recallChoice: 'I don\'t remember any',
          healthEffects: {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: _unusedChoice,
          onContinue: _unusedContinue,
        ),
        reduceMotion: true,
      ),
    );
    expect(find.text('Your interest never grows'), findsOneWidget);
    expect(find.textContaining('146,000 reels'), findsOneWidget);
    await tester.pumpWidget(
      _storyApp(
        const OnboardingStoryScreen(
          stage: OnboardingStoryStage.future,
          projection: OnboardingProjection(400),
          recallChoice: 'I don\'t remember any',
          healthEffects: {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: _unusedChoice,
          onContinue: _unusedContinue,
        ),
        reduceMotion: true,
      ),
    );
    expect(find.textContaining('20 months of your life'), findsOneWidget);
    expect(
      find.bySemanticsLabel('20 of 120 months highlighted'),
      findsOneWidget,
    );
  });

  testWidgets('story pages remain usable at 200% text on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _storyApp(
        const OnboardingStoryScreen(
          stage: OnboardingStoryStage.recall,
          projection: OnboardingProjection(400),
          recallChoice: null,
          healthEffects: {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: _unusedChoice,
          onContinue: _unusedContinue,
        ),
        reduceMotion: true,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.ensureVisible(find.text('Only a few'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      _storyApp(
        const OnboardingStoryScreen(
          stage: OnboardingStoryStage.future,
          projection: OnboardingProjection(400),
          recallChoice: null,
          healthEffects: {'Headaches'},
          dreamStatus: 'Yes, I have an interest',
          onRecallChanged: _unusedChoice,
          onContinue: _unusedContinue,
        ),
        reduceMotion: true,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void _unusedChoice(String _) {}
void _unusedContinue() {}

Widget _storyApp(
  Widget screen, {
  required bool reduceMotion,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: textScaler,
    ),
    child: screen,
  ),
);
