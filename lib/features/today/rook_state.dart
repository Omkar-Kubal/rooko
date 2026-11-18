enum RookState {
  ready,
  strained,
  injured,
  queasy,
  vomiting,
  recovering,
  victorious,
  sleeping;

  static RookState fromCount(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    return switch (count) {
      < 50 => ready,
      < 100 => strained,
      < 150 => injured,
      < 200 => queasy,
      _ => vomiting,
    };
  }

  static RookState forToday({
    required int count,
    required bool monitoringAvailable,
    bool recovering = false,
  }) {
    if (!monitoringAvailable) return sleeping;
    if (recovering) return RookState.recovering;
    return fromCount(count);
  }

  String get label => switch (this) {
    ready => 'Ready',
    strained => 'Strained',
    injured => 'Injured',
    queasy => 'Queasy',
    vomiting => 'Vomiting',
    recovering => 'Recovering',
    victorious => 'Victorious',
    sleeping => 'Sleeping',
  };

  String get svgAsset => switch (this) {
    ready => 'assets/rook/rook-ready.svg',
    strained => 'assets/rook/rook-strained.svg',
    injured => 'assets/rook/rook-injured.svg',
    queasy => 'assets/rook/rook-about-to-vomit.svg',
    vomiting => 'assets/rook/rook-vomiting.svg',
    recovering => 'assets/rook/rook-recovering.svg',
    victorious => 'assets/rook/rook-victorious.svg',
    sleeping => 'assets/rook/rook-sleeping.svg',
  };

  String get floatingCounterAsset => switch (this) {
    ready => 'assets/rook/rook-ready-transparent.png',
    strained => 'assets/rook/rook-strained-transparent.png',
    injured => 'assets/rook/rook-injured-transparent.png',
    queasy => 'assets/rook/rook-about-to-vomit-transparent.png',
    vomiting => 'assets/rook/rook-vomiting-transparent.png',
    recovering || victorious || sleeping => throw StateError(
      '$label is not a floating-counter count pose.',
    ),
  };

  String get riveAsset => switch (this) {
    ready || strained || injured || queasy => 'assets/rook/rook.riv',
    vomiting => 'assets/rook/rook-vomiting.riv',
    recovering => 'assets/rook/rook-recovering.riv',
    victorious => 'assets/rook/rook-victorious.riv',
    sleeping => 'assets/rook/rook-sleeping.riv',
  };

  bool get usesSharedStateMachine => switch (this) {
    ready || strained || injured || queasy => true,
    _ => false,
  };

  bool get isStrainedInput => this == strained;
  bool get isInjuredInput => this == injured;
  bool get isQueasyInput => this == queasy;
}

class RookRecoveryWindow {
  const RookRecoveryWindow._(this.untilMillis);

  static const durationMillis = 600;
  static const maximumSignalAgeMillis = 2000;

  final int untilMillis;

  static RookRecoveryWindow? fromSignal({
    required int signalAtMillis,
    required int observedAtMillis,
  }) {
    final age = observedAtMillis - signalAtMillis;
    if (signalAtMillis <= 0 || age < 0 || age > maximumSignalAgeMillis) {
      return null;
    }
    return RookRecoveryWindow._(observedAtMillis + durationMillis);
  }

  bool isActiveAt(int nowMillis) => nowMillis < untilMillis;
}
