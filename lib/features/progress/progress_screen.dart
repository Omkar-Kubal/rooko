import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_typography.dart';
import '../../core/models/progress.dart';
import '../../core/models/supported_app.dart';
import '../../core/platform/tracking_platform.dart';
import '../today/rook_state.dart';
import '../today/rook_mascot.dart';
import 'progress_calendar.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    required this.trackingPlatform,
    this.selectedAppIds = const {},
  });

  final TrackingPlatform trackingPlatform;
  final Set<String> selectedAppIds;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late DateTime _selectedDate;
  ProgressRange? _range;
  bool _weekView = false;
  bool _loading = true;
  String? _loadError;
  int _rangeRequestId = 0;

  @override
  void didUpdateWidget(covariant ProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackingPlatform != widget.trackingPlatform) _loadRange();
  }

  DateTime get _start =>
      _weekView ? ProgressCalendar.startOfWeek(_selectedDate) : _selectedDate;
  DateTime get _end =>
      _weekView ? ProgressCalendar.addDays(_start, 6) : _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadRange();
  }

  Future<void> _loadRange() async {
    final requestId = ++_rangeRequestId;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await widget.trackingPlatform.queryProgress(_start, _end);
      if (!mounted || requestId != _rangeRequestId) return;
      setState(() {
        _range = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _rangeRequestId) return;
      setState(() {
        _loadError = 'Progress is unavailable right now.';
        _loading = false;
      });
    }
  }

  void _movePeriod(int direction) {
    setState(() {
      _selectedDate = ProgressCalendar.addDays(
        _selectedDate,
        direction * (_weekView ? 7 : 1),
      );
    });
    _loadRange();
  }

  void _setWeekView(bool weekView) {
    if (_weekView == weekView) return;
    setState(() => _weekView = weekView);
    _loadRange();
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    final selectedDay = range?.day(_selectedDate);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Theme(
      data: theme.copyWith(
        cardTheme: theme.cardTheme.copyWith(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
            side: BorderSide.none,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x6,
          AppSpacing.x4,
          AppSpacing.x8,
        ),
        children: [
          SegmentedButton<bool>(
            style: ButtonStyle(
              side: const WidgetStatePropertyAll(BorderSide.none),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colors.primary
                    : colors.surfaceContainer,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? colors.onPrimary
                    : colors.onSurface,
              ),
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('Day')),
              ButtonSegment(value: true, label: Text('Week')),
            ],
            selected: {_weekView},
            onSelectionChanged: (value) => _setWeekView(value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.x3),
          _DateNavigation(
            label: _periodLabel(context),
            onPrevious: () => _movePeriod(-1),
            onNext: () => _movePeriod(1),
          ),
          const SizedBox(height: AppSpacing.x2),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.x8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            _ProgressMessage(
              title: 'Progress unavailable',
              message: _loadError!,
              action: TextButton(
                onPressed: _loadRange,
                child: const Text('Retry'),
              ),
            )
          else if (range != null && !_hasCounts(range))
            _EmptyProgressState(weekView: _weekView)
          else if (range != null) ...[
            if (_weekView) ...[
              _WeekChart(weekStart: _start, range: range),
              if (_mostRecentPersonalBest(range) case final personalBest?) ...[
                const SizedBox(height: AppSpacing.x6),
                _ProgressPersonalBest(day: personalBest),
              ],
            ] else if (selectedDay != null) ...[
              _DayDetail(
                day: selectedDay,
                selectedAppIds: widget.selectedAppIds,
              ),
              if (selectedDay.isPersonalBest) ...[
                const SizedBox(height: AppSpacing.x6),
                _ProgressPersonalBest(day: selectedDay),
              ],
            ],
          ],
        ],
      ),
    );
  }

  String _periodLabel(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    if (!_weekView) return localizations.formatMediumDate(_selectedDate);
    return '${localizations.formatMediumDate(_start)} – ${localizations.formatMediumDate(_end)}';
  }
}

bool _hasCounts(ProgressRange range) => range.days.isNotEmpty;

ProgressDay? _mostRecentPersonalBest(ProgressRange range) {
  ProgressDay? newest;
  for (final day in range.days) {
    if (!day.isPersonalBest) continue;
    if (newest == null || day.localDate.isAfter(newest.localDate)) {
      newest = day;
    }
  }
  return newest;
}

class _ProgressPersonalBest extends StatelessWidget {
  const _ProgressPersonalBest({required this.day});

  final ProgressDay day;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(day.localDate);
    return Semantics(
      label:
          'Personal best, $date, ${day.countedCount} Reels and Shorts counted',
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey('progress-personal-best'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: Row(
          children: [
            const SizedBox(
              width: 64,
              height: 60,
              child: RookMascot(
                state: RookState.victorious,
                width: 64,
                height: 60,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personal best · $date', style: AppTypography.cardTitle),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    '${day.countedCount} counted',
                    style: AppTypography.body.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateNavigation extends StatelessWidget {
  const _DateNavigation({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Previous period',
        onPressed: onPrevious,
        icon: const AppIcon(icon: AppIcons.back),
      ),
      Expanded(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.cardTitle,
        ),
      ),
      IconButton(
        tooltip: 'Next period',
        onPressed: onNext,
        icon: const AppIcon(icon: AppIcons.next),
      ),
    ],
  );
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day, required this.selectedAppIds});

  final ProgressDay day;
  final Set<String> selectedAppIds;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(day.localDate);
    final apps =
        SupportedApp.all
            .where(
              (app) =>
                  selectedAppIds.contains(app.id) || day.app(app.id) != null,
            )
            .toList()
          ..sort(
            (a, b) => (day.app(b.id)?.countedCount ?? 0).compareTo(
              day.app(a.id)?.countedCount ?? 0,
            ),
          );
    return Column(
      key: const ValueKey('progress-day-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DayActivityChart(day: day),
        const SizedBox(height: AppSpacing.x4),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x6,
            ),
            child: Semantics(
              label:
                  'Total Count, ${day.countedCount}, on $date. '
                  'Time spent, ${_observedDurationSpeech(day.observedFeedDurationMillis)}.',
              excludeSemantics: true,
              child: Row(
                children: [
                  Expanded(
                    child: _DayMetric(
                      value: day.countedCount.toString(),
                      label: 'Total Count',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x4),
                  Expanded(
                    child: _DayMetric(
                      value: _observedDurationValue(
                        day.observedFeedDurationMillis,
                      ),
                      label: 'Time spent',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (apps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x6),
          Text('Top apps', style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.x2),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Column(
                children: [
                  for (var index = 0; index < apps.length; index++) ...[
                    _DayAppRow(
                      app: apps[index],
                      count: day.app(apps[index].id)?.countedCount ?? 0,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _observedDurationValue(int? durationMillis) {
  if (durationMillis == null) return '—';
  if (durationMillis == 0) return '0m';
  if (durationMillis < Duration.secondsPerMinute * 1000) return '<1m';
  final totalMinutes = durationMillis ~/ (Duration.secondsPerMinute * 1000);
  final hours = totalMinutes ~/ Duration.minutesPerHour;
  final minutes = totalMinutes % Duration.minutesPerHour;
  if (hours == 0) return '${totalMinutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _observedDurationSpeech(int? durationMillis) {
  if (durationMillis == null) return 'unavailable';
  if (durationMillis == 0) return '0 minutes';
  if (durationMillis < Duration.secondsPerMinute * 1000) {
    return 'less than 1 minute';
  }
  final totalMinutes = durationMillis ~/ (Duration.secondsPerMinute * 1000);
  final hours = totalMinutes ~/ Duration.minutesPerHour;
  final minutes = totalMinutes % Duration.minutesPerHour;
  if (hours == 0) return '$totalMinutes minutes';
  if (minutes == 0) return '$hours hours';
  return '$hours hours and $minutes minutes';
}

class _DayMetric extends StatelessWidget {
  const _DayMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: AppTypography.pageTitle),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.supporting.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DayAppRow extends StatelessWidget {
  const _DayAppRow({required this.app, required this.count});
  final SupportedApp app;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${app.name}, $count Reels and Shorts counted',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Row(
        children: [
          Image.asset(
            app.iconAsset,
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(child: Text(app.name, style: AppTypography.body)),
          Text(count.toString(), style: AppTypography.cardTitle),
        ],
      ),
    ),
  );
}

class _DayActivityChart extends StatefulWidget {
  const _DayActivityChart({required this.day});
  final ProgressDay day;

  @override
  State<_DayActivityChart> createState() => _DayActivityChartState();
}

class _DayActivityChartState extends State<_DayActivityChart> {
  late int _selectedHour;

  @override
  void initState() {
    super.initState();
    _selectedHour = _initialHour(widget.day);
  }

  @override
  void didUpdateWidget(covariant _DayActivityChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dateKey(oldWidget.day.localDate) != _dateKey(widget.day.localDate)) {
      _selectedHour = _initialHour(widget.day);
    }
  }

  int _initialHour(ProgressDay day) {
    if (day.hourlyCounts.length == 24) {
      for (var hour = 23; hour >= 0; hour--) {
        if (day.hourlyCounts[hour] > 0) return hour;
      }
    }
    final now = DateTime.now();
    if (_dateKey(day.localDate) == _dateKey(now)) return now.hour;
    return 12;
  }

  void _selectAt(double x, double width) {
    if (width <= 0) return;
    final hour = (x / width * 24).floor().clamp(0, 23);
    if (hour != _selectedHour) setState(() => _selectedHour = hour);
  }

  void _stepHour(int direction) {
    final hour = (_selectedHour + direction).clamp(0, 23);
    if (hour != _selectedHour) setState(() => _selectedHour = hour);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasBreakdown =
        widget.day.hasHourlyBreakdown && widget.day.hourlyCounts.length == 24;
    final maximum = hasBreakdown
        ? widget.day.hourlyCounts.fold<int>(0, math.max)
        : 0;
    final selectedCount = hasBreakdown
        ? widget.day.hourlyCounts[_selectedHour]
        : 0;
    final selectedTimes =
        widget.day.countedTimes
            .where((time) => time.recordedLocalTime.hour == _selectedHour)
            .toList()
          ..sort((a, b) => a.wallClockMillis.compareTo(b.wallClockMillis));
    final lastKnownTime =
        widget.day.lastDetectionAtMillis > 0 && widget.day.offsetSeconds != null
        ? ProgressCountTime(
            appId: '',
            wallClockMillis: widget.day.lastDetectionAtMillis,
            offsetSeconds: widget.day.offsetSeconds!,
          ).recordedLocalTime
        : null;
    final lastKnownInSelectedHour =
        lastKnownTime != null &&
            _dateKey(lastKnownTime) == _dateKey(widget.day.localDate) &&
            lastKnownTime.hour == _selectedHour
        ? lastKnownTime
        : null;
    return Card(
      key: const ValueKey('progress-day-chart'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x4,
          AppSpacing.x4,
          AppSpacing.x3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.x3,
              runSpacing: AppSpacing.x1,
              children: [
                Text('Daily activity', style: AppTypography.cardTitle),
                if (hasBreakdown)
                  Text(
                    '${_hourWindowLabel(_selectedHour)} · $selectedCount counted',
                    key: const ValueKey('progress-selected-hour'),
                    style: AppTypography.supporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
            if (!hasBreakdown)
              SizedBox(
                height: 154,
                child: Center(
                  child: Text(
                    'Hourly activity is available for new counts.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else ...[
              Semantics(
                key: const ValueKey('progress-hour-semantics'),
                container: true,
                label: 'Hourly activity',
                value:
                    '${_hourWindowLabel(_selectedHour)}, $selectedCount counted',
                increasedValue: _selectedHour < 23
                    ? '${_hourWindowLabel(_selectedHour + 1)}, '
                          '${widget.day.hourlyCounts[_selectedHour + 1]} counted'
                    : null,
                decreasedValue: _selectedHour > 0
                    ? '${_hourWindowLabel(_selectedHour - 1)}, '
                          '${widget.day.hourlyCounts[_selectedHour - 1]} counted'
                    : null,
                onIncrease: _selectedHour < 23 ? () => _stepHour(1) : null,
                onDecrease: _selectedHour > 0 ? () => _stepHour(-1) : null,
                excludeSemantics: true,
                child: SizedBox(
                  height: 154,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$maximum',
                              style: AppTypography.chartLabel.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '0',
                              style: AppTypography.chartLabel.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) => GestureDetector(
                            key: const ValueKey('progress-hour-plot'),
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) => _selectAt(
                              details.localPosition.dx,
                              constraints.maxWidth,
                            ),
                            onHorizontalDragUpdate: (details) => _selectAt(
                              details.localPosition.dx,
                              constraints.maxWidth,
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                IgnorePointer(
                                  child: CustomPaint(
                                    key: const ValueKey(
                                      'progress-chart-baseline',
                                    ),
                                    painter: _ChartBaselinePainter(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                for (var hour = 0; hour < 24; hour++)
                                  if (widget.day.hourlyCounts[hour] > 0)
                                    Positioned(
                                      left:
                                          constraints.maxWidth *
                                              (hour + 0.5) /
                                              24 -
                                          math.min(
                                                AppSpacing.x1.toDouble(),
                                                constraints.maxWidth / 24 * 0.4,
                                              ) /
                                              2,
                                      bottom: 2,
                                      width: math.min(
                                        AppSpacing.x1.toDouble(),
                                        constraints.maxWidth / 24 * 0.4,
                                      ),
                                      height:
                                          widget.day.hourlyCounts[hour] /
                                          maximum *
                                          (constraints.maxHeight - 2),
                                      child: DecoratedBox(
                                        key: ValueKey('progress-hour-$hour'),
                                        decoration: BoxDecoration(
                                          color: colors.onSurface,
                                          borderRadius: BorderRadius.circular(
                                            AppRadii.pill,
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Row(
                children: [
                  const SizedBox(width: AppSpacing.x6 + AppSpacing.x2),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final showIntermediate =
                            constraints.maxWidth >=
                            280 * MediaQuery.textScalerOf(context).scale(1);
                        final labelStyle = AppTypography.chartLabel.copyWith(
                          color: colors.onSurfaceVariant,
                        );
                        return SizedBox(
                          height:
                              MediaQuery.textScalerOf(context).scale(
                                AppTypography.chartLabel.fontSize ??
                                    AppTypeScale.xSmall,
                              ) *
                              (AppTypography.chartLabel.height ?? 1.5),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('12am', style: labelStyle),
                              ),
                              for (final hour
                                  in showIntermediate ? [6, 12, 18] : [12])
                                Positioned(
                                  left: constraints.maxWidth * hour / 24,
                                  child: FractionalTranslation(
                                    translation: const Offset(-0.5, 0),
                                    child: Text(
                                      _hourLabel(hour),
                                      key: ValueKey('progress-axis-$hour'),
                                      style: labelStyle,
                                    ),
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text('12am', style: labelStyle),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (selectedCount > 0) ...[
                const SizedBox(height: AppSpacing.x3),
                Text(
                  selectedTimes.isNotEmpty
                      ? 'Latest count: ${_exactTimeLabel(selectedTimes.last.recordedLocalTime)}'
                      : lastKnownInSelectedHour != null
                      ? 'Latest known count: ${_exactTimeLabel(lastKnownInSelectedHour)}'
                      : 'Exact times are unavailable for these counts.',
                  style: AppTypography.supporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (selectedTimes.length < selectedCount &&
                    (selectedTimes.isNotEmpty ||
                        lastKnownInSelectedHour != null)) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'Other exact times are unavailable.',
                    style: AppTypography.chartLabel.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                if (selectedTimes.isNotEmpty)
                  TextButton(
                    onPressed: () => _showCountedTimes(context, selectedTimes),
                    child: Text('View ${selectedTimes.length} counted times'),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showCountedTimes(BuildContext context, List<ProgressCountTime> times) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: Text(
                  'Counted at ${_hourWindowLabel(_selectedHour)}',
                  style: AppTypography.cardTitle,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Expanded(
                child: ListView.builder(
                  itemCount: times.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: Text('${index + 1}'),
                    title: Text(
                      _exactTimeLabel(times[index].recordedLocalTime),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartBaselinePainter extends CustomPainter {
  const _ChartBaselinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final y = size.height - 2;
    final dotted = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var start = 0.0; start < size.width; start += 8) {
      canvas.drawLine(
        Offset(start, y),
        Offset(math.min(start + 3, size.width), y),
        dotted,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartBaselinePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.weekStart, required this.range});
  final DateTime weekStart;
  final ProgressRange range;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dates = List.generate(
      7,
      (i) => ProgressCalendar.addDays(weekStart, i),
    );
    final days = dates.map(range.day).toList(growable: false);
    final maximum = days.fold<int>(
      0,
      (value, day) => math.max(value, day?.countedCount ?? 0),
    );
    final total = days.fold<int>(
      0,
      (sum, day) => sum + (day?.countedCount ?? 0),
    );
    return Column(
      key: const ValueKey('progress-week-chart'),
      children: [
        Semantics(
          label: '$total Reels and Shorts this week',
          excludeSemantics: true,
          child: Column(
            children: [
              Text(total.toString(), style: AppTypography.metric),
              Text(
                'Reels and Shorts this week',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        SizedBox(
          height: _scaledHeight(context, 230),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < dates.length; i++)
                Expanded(
                  child: _WeekBar(
                    date: dates[i],
                    day: days[i],
                    maximum: maximum,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.date,
    required this.day,
    required this.maximum,
  });
  final DateTime date;
  final ProgressDay? day;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final count = day?.countedCount ?? 0;
    final hasRecord = day != null;
    final hasBar = count > 0;
    final fraction = maximum == 0 ? 0.0 : count / maximum;
    final weekday = MaterialLocalizations.of(context)
        .narrowWeekdays[date.weekday % 7];
    final label = MaterialLocalizations.of(context).formatMediumDate(date);
    return Semantics(
      label: hasRecord
          ? '$label, $count Reels and Shorts'
          : '$label, no count record',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            SizedBox(
              height: _scaledHeight(context, 22),
              child: Center(
                child: hasRecord
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          count.toString(),
                          key: ValueKey(
                            'progress-week-count-${_dateKey(date)}',
                          ),
                          style: AppTypography.cardTitle,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: hasBar
                    ? FractionallySizedBox(
                        heightFactor: fraction,
                        child: Container(
                          key: ValueKey('progress-week-bar-${_dateKey(date)}'),
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 4),
                          decoration: BoxDecoration(
                            color: colors.onSurface.withValues(
                              alpha: 0.55 + fraction * 0.45,
                            ),
                            borderRadius: BorderRadius.circular(AppRadii.card),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              '$weekday ${date.day}',
              textAlign: TextAlign.center,
              softWrap: true,
              style: AppTypography.chartLabel.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProgressState extends StatelessWidget {
  const _EmptyProgressState({required this.weekView});
  final bool weekView;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('progress-empty-state'),
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          children: [
            const SizedBox(
              width: 132,
              height: 126,
              child: RookMascot(state: RookState.ready),
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              'No counts recorded this ${weekView ? 'week' : 'day'}',
              textAlign: TextAlign.center,
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Saved counts will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressMessage extends StatelessWidget {
  const _ProgressMessage({
    required this.title,
    required this.message,
    this.action,
  });
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.x1),
          Text(message, style: AppTypography.body),
          ?action,
        ],
      ),
    ),
  );
}

double _scaledHeight(BuildContext context, double height) {
  final base = AppTypography.supporting.fontSize ?? AppTypeScale.xSmall;
  final lineHeight = AppTypography.supporting.height ?? 1;
  final scaled = MediaQuery.textScalerOf(context).scale(base);
  final extra = (scaled - base) * lineHeight;
  return height + (extra > 0 ? extra * 4 : 0);
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _hourLabel(int hour) =>
    '${hour % 12 == 0 ? 12 : hour % 12}${hour < 12 ? 'am' : 'pm'}';

String _hourWindowLabel(int hour) =>
    '${hour % 12 == 0 ? 12 : hour % 12}:00–'
    '${hour % 12 == 0 ? 12 : hour % 12}:59${hour < 12 ? 'am' : 'pm'}';

String _exactTimeLabel(DateTime time) =>
    '${time.hour % 12 == 0 ? 12 : time.hour % 12}:'
    '${time.minute.toString().padLeft(2, '0')}:'
    '${time.second.toString().padLeft(2, '0')}'
    '${time.hour < 12 ? 'am' : 'pm'}';
