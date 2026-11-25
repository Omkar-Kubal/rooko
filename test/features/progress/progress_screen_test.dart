import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/core/design_system/app_theme.dart';
import 'package:rooko/core/models/progress.dart';
import 'package:rooko/core/platform/tracking_platform.dart';
import 'package:rooko/features/progress/progress_screen.dart';
import 'package:rooko/features/today/rook_mascot.dart';
import 'package:rooko/features/today/rook_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Day is first and opens the selected date without Month', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final platform = FakeProgressPlatform(_fixture());

    await _pumpProgress(tester, platform);

    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsNothing);
    expect(find.byKey(const ValueKey('progress-day-summary')), findsOneWidget);
    expect(find.text('Total Count'), findsOneWidget);
    expect(find.text('Top apps'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Time spent'), findsOneWidget);
    expect(find.textContaining('Pro'), findsNothing);
    expect(find.text('6'), findsWidgets);
    expect(platform.lastStart, _today());
    expect(platform.lastEnd, _today());
  });

  testWidgets('Day arrows move one day and Week arrows move seven', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final platform = FakeProgressPlatform(_fixture());

    await _pumpProgress(tester, platform);
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();
    expect(platform.lastStart, _today().subtract(const Duration(days: 1)));
    expect(find.text('No counts recorded this day'), findsOneWidget);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(
      platform.lastStart,
      _startOfWeek(_today().subtract(const Duration(days: 1)))
          .subtract(const Duration(days: 7)),
    );
    await tester.tap(find.byTooltip('Previous period'));
    await tester.pumpAndSettle();
    expect(
      platform.lastStart,
      _startOfWeek(_today().subtract(const Duration(days: 1)))
          .subtract(const Duration(days: 14)),
    );
  });

  testWidgets('Day shows recorded hourly activity and app attribution', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final hours = List<int>.filled(24, 0);
    hours[8] = 3;
    hours[21] = 2;
    final platform = FakeProgressPlatform(
      ProgressRange(
        checkedAtMillis: 0,
        days: [
          ProgressDay(
            localDate: _today(),
            timeZoneId: 'Asia/Kolkata',
            offsetSeconds: 19800,
            coverage: ProgressCoverage.partial,
            coverageReason: null,
            lastDetectionAtMillis: 0,
            hourlyCounts: hours,
            hasHourlyBreakdown: true,
            apps: const [
              ProgressAppTotal(
                appId: 'instagram',
                confirmedCount: 3,
                estimatedCount: 0,
                correctionDelta: 0,
                adjustedConfirmedCount: 3,
                correctionCount: 0,
                pendingUndoCorrectionId: null,
              ),
              ProgressAppTotal(
                appId: 'youtube',
                confirmedCount: 2,
                estimatedCount: 0,
                correctionDelta: 0,
                adjustedConfirmedCount: 2,
                correctionCount: 0,
                pendingUndoCorrectionId: null,
              ),
            ],
          ),
        ],
      ),
    );
    await _pumpProgress(tester, platform);
    expect(find.byKey(const ValueKey('progress-day-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('progress-hour-8')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('progress-hour-8'))).width,
      lessThanOrEqualTo(4),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('progress-hour-8'))).height,
      greaterThan(100),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('progress-hour-21'))).height,
      greaterThan(50),
    );
    expect(find.text('Active hours'), findsNothing);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('YouTube Shorts'), findsOneWidget);
    expect(find.text('Time spent'), findsOneWidget);
  });

  testWidgets('Day chart keeps its dotted baseline while selecting hours', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final semantics = tester.ensureSemantics();
    final hours = List<int>.filled(24, 0);
    hours[8] = 3;
    hours[21] = 2;
    final platform = FakeProgressPlatform(
      ProgressRange(
        checkedAtMillis: 0,
        days: [
          ProgressDay(
            localDate: _today(),
            timeZoneId: 'Asia/Kolkata',
            offsetSeconds: 19800,
            coverage: ProgressCoverage.partial,
            coverageReason: null,
            lastDetectionAtMillis: 0,
            hourlyCounts: hours,
            hasHourlyBreakdown: true,
            apps: const [],
          ),
        ],
      ),
    );
    await _pumpProgress(tester, platform);
    final plot = find.byKey(const ValueKey('progress-hour-plot'));
    expect(
      find.byKey(const ValueKey('progress-chart-baseline')),
      findsOneWidget,
    );
    final bounds = tester.getRect(plot);
    final sixPmLabel = tester.getRect(
      find.byKey(const ValueKey('progress-axis-18')),
    );
    expect(
      sixPmLabel.center.dx,
      closeTo(bounds.left + bounds.width * 18 / 24, 0.5),
    );
    await tester.tapAt(
      Offset(bounds.left + bounds.width * 8.5 / 24, bounds.center.dy),
    );
    await tester.pump();
    expect(find.text('8:00–8:59am · 3 counted'), findsOneWidget);
    expect(
      find.text('Exact times are unavailable for these counts.'),
      findsOneWidget,
    );
    expect(find.text('Other exact times are unavailable.'), findsNothing);
    expect(await _chartPixelAlpha(tester, 1, 98), greaterThan(0));
    await tester.tapAt(
      Offset(bounds.left + bounds.width * 21.5 / 24, bounds.center.dy),
    );
    await tester.pump();
    expect(find.text('9:00–9:59pm · 2 counted'), findsOneWidget);
    await tester.dragFrom(
      Offset(bounds.left + bounds.width * 21.5 / 24, bounds.center.dy),
      Offset(-bounds.width * 13 / 24, 0),
    );
    await tester.pump();
    expect(find.text('8:00–8:59am · 3 counted'), findsOneWidget);
    await tester.tapAt(
      Offset(bounds.left + bounds.width * 18.5 / 24, bounds.center.dy),
    );
    await tester.pump();
    expect(find.text('6:00–6:59pm · 0 counted'), findsOneWidget);
    expect(await _chartPixelAlpha(tester, 190, 50), 0);
    expect(await _chartPixelAlpha(tester, 1, 98), greaterThan(0));
    final chartNode = tester.getSemantics(
      find.byKey(const ValueKey('progress-hour-semantics')),
    );
    expect(
      chartNode.getSemanticsData().hasAction(SemanticsAction.increase),
      isTrue,
    );
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      chartNode.id,
      SemanticsAction.increase,
    );
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('progress-selected-hour')))
          .data,
      '7:00–7:59pm · 0 counted',
    );
    expect(find.byKey(const ValueKey('progress-hour-19')), findsNothing);
    semantics.dispose();
  });

  testWidgets('Day reveals exact saved times for the selected count hour', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final date = _today();
    final first =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
          17,
          12,
          34,
        ).millisecondsSinceEpoch -
        19_800_000;
    final second =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
          17,
          58,
          6,
        ).millisecondsSinceEpoch -
        19_800_000;
    final hours = List<int>.filled(24, 0)..[17] = 2;
    await _pumpProgress(
      tester,
      FakeProgressPlatform(
        ProgressRange(
          checkedAtMillis: 0,
          days: [
            ProgressDay(
              localDate: date,
              timeZoneId: 'Asia/Kolkata',
              offsetSeconds: 19_800,
              coverage: ProgressCoverage.partial,
              coverageReason: null,
              lastDetectionAtMillis: second,
              hourlyCounts: hours,
              hasHourlyBreakdown: true,
              countedTimes: [
                ProgressCountTime(
                  appId: 'instagram',
                  wallClockMillis: first,
                  offsetSeconds: 19_800,
                ),
                ProgressCountTime(
                  appId: 'youtube',
                  wallClockMillis: second,
                  offsetSeconds: 19_800,
                ),
              ],
              apps: const [],
            ),
          ],
        ),
      ),
    );
    expect(find.text('5:00–5:59pm · 2 counted'), findsOneWidget);
    final plot = tester.getRect(
      find.byKey(const ValueKey('progress-hour-plot')),
    );
    await tester.tapAt(
      Offset(plot.left + plot.width * 17.5 / 24, plot.center.dy),
    );
    await tester.pump();
    expect(find.text('5:00–5:59pm · 2 counted'), findsOneWidget);
    expect(find.text('Latest count: 5:58:06pm'), findsOneWidget);
    await tester.tap(find.text('View 2 counted times'));
    await tester.pumpAndSettle();
    expect(find.text('5:12:34pm'), findsOneWidget);
    expect(find.text('5:58:06pm'), findsOneWidget);
  });

  testWidgets('Day does not invent exact times for older counts', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final date = _today();
    final last =
        DateTime.utc(
          date.year,
          date.month,
          date.day,
          17,
          58,
          6,
        ).millisecondsSinceEpoch -
        19_800_000;
    final hours = List<int>.filled(24, 0)..[17] = 3;
    await _pumpProgress(
      tester,
      FakeProgressPlatform(
        ProgressRange(
          checkedAtMillis: 0,
          days: [
            ProgressDay(
              localDate: date,
              timeZoneId: 'Asia/Kolkata',
              offsetSeconds: 19_800,
              coverage: ProgressCoverage.partial,
              coverageReason: null,
              lastDetectionAtMillis: last,
              hourlyCounts: hours,
              hasHourlyBreakdown: true,
              apps: const [],
            ),
          ],
        ),
      ),
    );
    final plot = tester.getRect(
      find.byKey(const ValueKey('progress-hour-plot')),
    );
    await tester.tapAt(
      Offset(plot.left + plot.width * 17.5 / 24, plot.center.dy),
    );
    await tester.pump();
    expect(find.text('Latest known count: 5:58:06pm'), findsOneWidget);
    expect(find.text('Other exact times are unavailable.'), findsOneWidget);
    expect(find.textContaining('View 3 counted times'), findsNothing);
  });

  testWidgets('Progress panels and Day/Week control have no strokes', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await _pumpProgress(tester, FakeProgressPlatform(_fixture()));
    final context = tester.element(
      find.byKey(const ValueKey('progress-day-chart')),
    );
    final shape = Theme.of(context).cardTheme.shape as RoundedRectangleBorder;
    expect(shape.side, BorderSide.none);
    final control = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(
      control.style?.side?.resolve({WidgetState.selected}),
      BorderSide.none,
    );
    expect(control.style?.side?.resolve({}), BorderSide.none);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('dark Day selection uses a near-black fill with readable text', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ProgressScreen(
            trackingPlatform: FakeProgressPlatform(_fixture()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final control = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    final selected = {WidgetState.selected};
    final fill = control.style!.backgroundColor!.resolve(selected)!;
    final foreground = control.style!.foregroundColor!.resolve(selected)!;
    expect(fill, isNot(Colors.white));
    expect(fill.computeLuminance(), lessThan(0.05));
    expect(foreground, Colors.white);
    expect(1.05 / (fill.computeLuminance() + 0.05), greaterThanOrEqualTo(4.5));
  });

  testWidgets('an older Day response cannot replace the selected Week', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final platform = ControlledProgressPlatform();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProgressScreen(trackingPlatform: platform)),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Week'));
    await tester.pump();

    platform.complete(1, _fixture());
    await tester.pump();
    expect(find.byKey(const ValueKey('progress-week-chart')), findsOneWidget);

    platform.complete(0, const ProgressRange(checkedAtMillis: 0, days: []));
    await tester.pump();
    expect(find.byKey(const ValueKey('progress-week-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('progress-empty-state')), findsNothing);
  });

  testWidgets('Week integrates the combined total above seven daily bars', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final platform = FakeProgressPlatform(_fixture());

    await _pumpProgress(tester, platform);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(find.text('Week'), findsOneWidget);
    expect(find.text('Month'), findsNothing);
    expect(find.byKey(const ValueKey('progress-week-chart')), findsOneWidget);
    expect(find.text('Total Count'), findsOneWidget);
    expect(find.byKey(const ValueKey('progress-week-totals')), findsNothing);
    expect(
      find.byKey(
        ValueKey(
          'progress-week-bar-${_dateKey(DateTime.now().subtract(const Duration(days: 3)))}',
        ),
      ),
      findsNothing,
    );
    expect(find.text('This week'), findsNothing);
    expect(find.text('Instagram'), findsNothing);
    expect(find.text('YouTube'), findsNothing);
    expect(find.text('6'), findsWidgets);
    expect(find.text('No totals recorded this week.'), findsNothing);
    expect(
      platform.lastStart,
      _startOfWeek(DateTime.now()).subtract(const Duration(days: 7)),
    );
  });

  testWidgets(
    'Week keeps an unverified saved zero unknown and distinct from a missing day',
    (tester) async {
      _usePhoneViewport(tester);
      final monday = _startOfWeek(DateTime.now());
      final zeroDate = monday.add(const Duration(days: 1));
      final missingDate = monday.add(const Duration(days: 2));
      final platform = FakeProgressPlatform(
        ProgressRange(
          checkedAtMillis: 0,
          days: [_day(monday, count: 7), _day(zeroDate, count: 0)],
        ),
      );

      await _pumpProgress(tester, platform);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('progress-week-count-${_dateKey(zeroDate)}')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(ValueKey('progress-week-count-${_dateKey(zeroDate)}')),
            )
            .data,
        '—',
      );
      expect(
        find.byKey(ValueKey('progress-week-bar-${_dateKey(zeroDate)}')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('progress-week-count-${_dateKey(missingDate)}')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('progress-week-bar-${_dateKey(missingDate)}')),
        findsNothing,
      );
    },
  );

  testWidgets('a week of saved zero days is not an empty period', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final platform = FakeProgressPlatform(
      ProgressRange(
        checkedAtMillis: 0,
        days: [_day(_startOfWeek(DateTime.now()), count: 0)],
      ),
    );

    await _pumpProgress(tester, platform);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('progress-week-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('progress-empty-state')), findsNothing);
  });

  testWidgets('Day shows a saved zero count without an empty state', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final platform = FakeProgressPlatform(
      ProgressRange(checkedAtMillis: 0, days: [_day(_today(), count: 0)]),
    );

    await _pumpProgress(tester, platform);

    expect(find.byKey(const ValueKey('progress-day-summary')), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.byKey(const ValueKey('progress-empty-state')), findsNothing);
  });

  testWidgets('an empty Week shows Rook without a chart', (tester) async {
    _usePhoneViewport(tester);
    final platform = FakeProgressPlatform(
      const ProgressRange(checkedAtMillis: 0, days: []),
    );

    await _pumpProgress(tester, platform);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('progress-empty-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('progress-week-chart')), findsNothing);
    expect(find.text('No counts recorded this week'), findsOneWidget);
  });
  testWidgets(
    'Progress does not expose manual count editing or confidence copy',
    (tester) async {
      _usePhoneViewport(tester);
      final platform = FakeProgressPlatform(_fixture());

      await _pumpProgress(tester, platform);

      expect(find.text('Add a missed count?'), findsNothing);
      expect(find.text('Subtract an extra count?'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(find.text('+ 1'), findsNothing);
      expect(find.textContaining('estimated'), findsNothing);
      expect(find.textContaining('partial'), findsNothing);
      expect(find.textContaining('confirmed'), findsNothing);
      expect(find.text('Capture paused'), findsNothing);
      expect(find.text('Capture details unavailable'), findsNothing);
      expect(find.text('!'), findsNothing);
      expect(find.text('?'), findsNothing);
      expect(platform.addCorrectionCalls, 0);
      expect(platform.undoCorrectionCalls, 0);
    },
  );

  testWidgets('Progress remains overflow-free at 200% text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final monday = _startOfWeek(DateTime.now());
    final platform = FakeProgressPlatform(
      ProgressRange(
        checkedAtMillis: 0,
        days: [
          for (var i = 0; i < 7; i++)
            _day(monday.add(Duration(days: i)), count: 1234 + i),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(body: ProgressScreen(trackingPlatform: platform)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Progress shows the latest verified personal best with Victorious',
    (tester) async {
      _usePhoneViewport(tester);
      final start = _startOfWeek(DateTime.now());
      final platform = FakeProgressPlatform(
        ProgressRange(
          checkedAtMillis: 0,
          days: [
            _personalBestDay(start, count: 4),
            _personalBestDay(start.add(const Duration(days: 1)), count: 2),
          ],
        ),
      );

      await _pumpProgress(tester, platform);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('progress-personal-best')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('progress-week-totals')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('progress-personal-best')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Personal best ·'), findsOneWidget);
      expect(find.text('2 counted'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('progress-personal-best')))
            .dy,
        greaterThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('progress-week-chart')))
              .dy,
        ),
      );
      final mascot = tester.widget<RookMascot>(find.byType(RookMascot));
      expect(mascot.state, RookState.victorious);
    },
  );

  testWidgets('Day shows Victorious only for the selected best date', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final today = _today();
    final platform = FakeProgressPlatform(
      ProgressRange(
        checkedAtMillis: 0,
        days: [
          _personalBestDay(today, count: 4),
          _personalBestDay(today.add(const Duration(days: 1)), count: 2),
        ],
      ),
    );

    await _pumpProgress(tester, platform);
    expect(find.text('4 counted'), findsOneWidget);
    expect(find.text('2 counted'), findsNothing);
    expect(
      find.byKey(const ValueKey('progress-personal-best')),
      findsOneWidget,
    );
  });

  testWidgets('an unverified or baseline day does not show Victorious', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final date = _today();
    final platform = FakeProgressPlatform(
      ProgressRange(
        checkedAtMillis: 0,
        days: [
          ProgressDay(
            localDate: date,
            timeZoneId: null,
            offsetSeconds: null,
            coverage: ProgressCoverage.unknown,
            coverageReason: null,
            lastDetectionAtMillis: 0,
            apps: const [],
          ),
        ],
      ),
    );

    await _pumpProgress(tester, platform);

    expect(find.byKey(const ValueKey('progress-personal-best')), findsNothing);
    expect(find.bySemanticsLabel('Victorious Rook'), findsNothing);
  });

  testWidgets('zero-count personal best still appears in Progress', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final platform = FakeProgressPlatform(
      ProgressRange(
        checkedAtMillis: 0,
        days: [_personalBestDay(_today(), count: 0)],
      ),
    );

    await _pumpProgress(tester, platform);

    expect(
      find.byKey(const ValueKey('progress-personal-best')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('progress-personal-best')),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 counted'), findsOneWidget);
    final mascot = tester.widget<RookMascot>(find.byType(RookMascot));
    expect(mascot.state, RookState.victorious);
  });
}

Future<int> _chartPixelAlpha(WidgetTester tester, int x, int y) async {
  return (await tester.runAsync(() async {
    final painter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('progress-chart-baseline')),
        )
        .painter!;
    final recorder = ui.PictureRecorder();
    painter.paint(ui.Canvas(recorder), const ui.Size(240, 100));
    final image = await recorder.endRecording().toImage(240, 100);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.getUint8((y * 240 + x) * 4 + 3);
  }))!;
}

Future<void> _pumpProgress(
  WidgetTester tester,
  TrackingPlatform platform,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ProgressScreen(trackingPlatform: platform)),
    ),
  );
  await tester.pumpAndSettle();
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(432, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ProgressRange _fixture() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final previousWeek = today.subtract(const Duration(days: 10));
  return ProgressRange(
    checkedAtMillis: 1_800_000_000_000,
    days: [
      ProgressDay(
        localDate: today,
        timeZoneId: null,
        offsetSeconds: null,
        coverage: ProgressCoverage.partial,
        coverageReason: 'Service interrupted',
        lastDetectionAtMillis: 1_800_000_000_000,
        apps: const [
          ProgressAppTotal(
            appId: 'instagram',
            confirmedCount: 2,
            estimatedCount: 4,
            correctionDelta: -1,
            adjustedConfirmedCount: 1,
            correctionCount: 1,
            pendingUndoCorrectionId: 'correction-1',
          ),
        ],
      ),
      ProgressDay(
        localDate: previousWeek,
        timeZoneId: null,
        offsetSeconds: null,
        coverage: ProgressCoverage.unknown,
        coverageReason: null,
        lastDetectionAtMillis: 0,
        apps: const [
          ProgressAppTotal(
            appId: 'youtube',
            confirmedCount: 3,
            estimatedCount: 0,
            correctionDelta: 0,
            adjustedConfirmedCount: 3,
            correctionCount: 0,
            pendingUndoCorrectionId: null,
          ),
        ],
      ),
    ],
  );
}

ProgressDay _personalBestDay(DateTime date, {required int count}) =>
    ProgressDay(
      localDate: date,
      timeZoneId: 'Asia/Kolkata',
      offsetSeconds: 19800,
      coverage: ProgressCoverage.verified,
      coverageReason: null,
      lastDetectionAtMillis: 0,
      isPersonalBest: true,
      apps: [
        ProgressAppTotal(
          appId: 'youtube',
          confirmedCount: count,
          estimatedCount: 0,
          correctionDelta: 0,
          adjustedConfirmedCount: count,
          correctionCount: 0,
          pendingUndoCorrectionId: null,
        ),
      ],
    );

ProgressDay _day(DateTime date, {required int count}) => ProgressDay(
  localDate: date,
  timeZoneId: null,
  offsetSeconds: null,
  coverage: ProgressCoverage.unknown,
  coverageReason: null,
  lastDetectionAtMillis: 0,
  apps: [
    ProgressAppTotal(
      appId: 'instagram',
      confirmedCount: count,
      estimatedCount: 0,
      correctionDelta: 0,
      adjustedConfirmedCount: count,
      correctionCount: 0,
      pendingUndoCorrectionId: null,
    ),
  ],
);

DateTime _startOfWeek(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class FakeProgressPlatform implements TrackingPlatform {
  FakeProgressPlatform(this.range);

  ProgressRange range;
  DateTime? lastStart;
  DateTime? lastEnd;
  int addCorrectionCalls = 0;
  int undoCorrectionCalls = 0;

  @override
  Future<void> setSelectedApps(Set<String> appIds) async {}

  @override
  Future<void> setConsentAcknowledged(bool acknowledged) async {}

  @override
  Future<void> setBubbleEnabled(bool enabled) async {}

  @override
  Future<bool> openOverlaySettings() async => true;

  @override
  Future<bool> openAccessibilitySettings() async => true;

  @override
  Future<bool> openSupportedApp(String appId) async => true;

  @override
  Future<bool> openInstagramProfile(String handle) async => true;

  @override
  Future<bool> openInstagramHashtag(String tag) async => true;

  @override
  Future<bool> openSupportedAppSettings(String appId) async => true;

  @override
  Future<bool> openSupportEmail(SupportEmailKind kind) async => true;

  @override
  Future<TrackingSnapshot> getSnapshot(Set<String> appIds) async =>
      const TrackingSnapshot(
        serviceEnabled: false,
        serviceOperational: false,
        checkedAtMillis: 0,
        localDate: '',
        apps: {},
      );

  @override
  Future<ProgressRange> queryProgress(
    DateTime startDate,
    DateTime endDate,
  ) async {
    lastStart = startDate;
    lastEnd = endDate;
    return ProgressRange(
      checkedAtMillis: range.checkedAtMillis,
      days: range.days
          .where(
            (day) =>
                !day.localDate.isBefore(startDate) &&
                !day.localDate.isAfter(endDate),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<ProgressCorrection> addCorrection({
    required String localDate,
    required String appId,
    required int delta,
    String? reason,
  }) async {
    addCorrectionCalls++;
    throw UnimplementedError();
  }

  @override
  Future<ProgressCorrection> undoCorrection(String correctionId) async {
    undoCorrectionCalls++;
    throw UnimplementedError();
  }
}

class ControlledProgressPlatform extends FakeProgressPlatform {
  ControlledProgressPlatform()
    : super(const ProgressRange(checkedAtMillis: 0, days: []));

  final List<Completer<ProgressRange>> pending = [];

  @override
  Future<ProgressRange> queryProgress(DateTime startDate, DateTime endDate) {
    final request = Completer<ProgressRange>();
    pending.add(request);
    return request.future;
  }

  void complete(int index, ProgressRange range) =>
      pending[index].complete(range);
}
