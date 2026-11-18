enum ProgressCoverage { unknown, partial, verified }

class ProgressCountTime {
  const ProgressCountTime({
    required this.appId,
    required this.wallClockMillis,
    required this.offsetSeconds,
  });

  final String appId;
  final int wallClockMillis;
  final int offsetSeconds;

  DateTime get recordedLocalTime => DateTime.fromMillisecondsSinceEpoch(
    wallClockMillis + offsetSeconds * 1000,
    isUtc: true,
  );

  factory ProgressCountTime.fromMap(Map<String, Object?> map) =>
      ProgressCountTime(
        appId: map['appId'] as String? ?? '',
        wallClockMillis: _progressInt(map['wallClockMillis']),
        offsetSeconds: _progressInt(map['offsetSeconds']),
      );
}

class ProgressAppTotal {
  const ProgressAppTotal({
    required this.appId,
    required this.confirmedCount,
    required this.estimatedCount,
    required this.correctionDelta,
    required this.adjustedConfirmedCount,
    required this.correctionCount,
    required this.pendingUndoCorrectionId,
  });

  final String appId;
  final int confirmedCount;
  final int estimatedCount;
  final int correctionDelta;
  final int adjustedConfirmedCount;
  final int correctionCount;
  final String? pendingUndoCorrectionId;

  /// Counts every event stored for this app and local date.
  int get countedCount => confirmedCount + estimatedCount;

  factory ProgressAppTotal.fromMap(Map<String, Object?> map) =>
      ProgressAppTotal(
        appId: map['appId'] as String? ?? '',
        confirmedCount: _progressInt(map['confirmedCount']),
        estimatedCount: _progressInt(map['estimatedCount']),
        correctionDelta: _progressInt(map['correctionDelta']),
        adjustedConfirmedCount: _progressInt(map['adjustedConfirmedCount']),
        correctionCount: _progressInt(map['correctionCount']),
        pendingUndoCorrectionId: map['pendingUndoCorrectionId'] as String?,
      );
}

class ProgressDay {
  const ProgressDay({
    required this.localDate,
    required this.timeZoneId,
    required this.offsetSeconds,
    required this.coverage,
    required this.coverageReason,
    required this.lastDetectionAtMillis,
    required this.apps,
    this.hourlyCounts = const [],
    this.countedTimes = const [],
    this.hasHourlyBreakdown = false,
    this.isPersonalBest = false,
    this.observedFeedDurationMillis,
  });

  final DateTime localDate;
  final String? timeZoneId;
  final int? offsetSeconds;
  final ProgressCoverage coverage;
  final String? coverageReason;
  final int lastDetectionAtMillis;
  final List<ProgressAppTotal> apps;
  final List<int> hourlyCounts;
  final List<ProgressCountTime> countedTimes;
  final bool hasHourlyBreakdown;
  final bool isPersonalBest;
  final int? observedFeedDurationMillis;

  int get adjustedConfirmedCount =>
      apps.fold(0, (total, app) => total + app.adjustedConfirmedCount);

  int get estimatedCount =>
      apps.fold(0, (total, app) => total + app.estimatedCount);

  int get countedCount =>
      apps.fold(0, (total, app) => total + app.countedCount);

  int get correctionCount =>
      apps.fold(0, (total, app) => total + app.correctionCount);

  ProgressAppTotal? app(String appId) {
    for (final total in apps) {
      if (total.appId == appId) return total;
    }
    return null;
  }

  factory ProgressDay.fromMap(Map<String, Object?> map) {
    final rows = map['apps'] is List ? map['apps'] as List : const [];
    final observedDuration = map['observedFeedDurationMillis'];
    return ProgressDay(
      localDate:
          DateTime.tryParse(map['localDate'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      timeZoneId: map['timeZoneId'] as String?,
      offsetSeconds: map['offsetSeconds'] is num
          ? (map['offsetSeconds'] as num).toInt()
          : null,
      coverage: switch (map['coverage']) {
        'partial' => ProgressCoverage.partial,
        'verified' => ProgressCoverage.verified,
        _ => ProgressCoverage.unknown,
      },
      coverageReason: map['coverageReason'] as String?,
      lastDetectionAtMillis: _progressInt(map['lastDetectionAtMillis']),
      observedFeedDurationMillis:
          observedDuration is num && observedDuration >= 0
          ? observedDuration.toInt()
          : null,
      isPersonalBest: map['isPersonalBest'] as bool? ?? false,
      hourlyCounts: map['hourlyCounts'] is List
          ? (map['hourlyCounts'] as List)
                .whereType<num>()
                .map((count) => count.toInt())
                .toList(growable: false)
          : const [],
      countedTimes: map['countedTimes'] is List
          ? [
              for (final row in map['countedTimes'] as List)
                if (row is Map)
                  ProgressCountTime.fromMap(
                    row.map((key, value) => MapEntry(key.toString(), value)),
                  ),
            ]
          : const [],
      hasHourlyBreakdown: map['hasHourlyBreakdown'] as bool? ?? false,
      apps: [
        for (final row in rows)
          if (row is Map)
            ProgressAppTotal.fromMap(
              row.map((key, value) => MapEntry(key.toString(), value)),
            ),
      ],
    );
  }
}

class ProgressRange {
  const ProgressRange({required this.checkedAtMillis, required this.days});

  final int checkedAtMillis;
  final List<ProgressDay> days;

  ProgressDay? day(DateTime date) {
    for (final entry in days) {
      if (_sameDate(entry.localDate, date)) return entry;
    }
    return null;
  }

  factory ProgressRange.fromMap(Map<String, Object?> map) {
    final version = _progressInt(map['schemaVersion']);
    if (version != 1) {
      throw FormatException('Unsupported progress schema version: $version');
    }
    final rows = map['days'] is List ? map['days'] as List : const [];
    return ProgressRange(
      checkedAtMillis: _progressInt(map['checkedAtMillis']),
      days: [
        for (final row in rows)
          if (row is Map)
            ProgressDay.fromMap(
              row.map((key, value) => MapEntry(key.toString(), value)),
            ),
      ],
    );
  }
}

class ProgressCorrection {
  const ProgressCorrection({
    required this.id,
    required this.localDate,
    required this.appId,
    required this.delta,
    required this.reason,
    required this.createdAtMillis,
    required this.reversesCorrectionId,
  });

  final String id;
  final DateTime localDate;
  final String appId;
  final int delta;
  final String? reason;
  final int createdAtMillis;
  final String? reversesCorrectionId;

  factory ProgressCorrection.fromMap(Map<String, Object?> map) =>
      ProgressCorrection(
        id: map['id'] as String? ?? '',
        localDate:
            DateTime.tryParse(map['localDate'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        appId: map['appId'] as String? ?? '',
        delta: _progressInt(map['delta']),
        reason: map['reason'] as String?,
        createdAtMillis: _progressInt(map['createdAtMillis']),
        reversesCorrectionId: map['reversesCorrectionId'] as String?,
      );
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

int _progressInt(Object? value) => value is num ? value.toInt() : 0;
