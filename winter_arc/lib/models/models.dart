enum Exercise {
  dips('Dips'),
  pull('Klimmzüge');

  const Exercise(this.label);
  final String label;
}

/// The challenge window and daily goals. Defaults are the assumptions from
/// the design: 1 Oct – 31 Dec, 100 Dips, 50 Klimmzüge, 8 h Schlaf.
class ChallengeSettings {
  const ChallengeSettings({
    required this.start,
    required this.end,
    this.dipsGoal = 100,
    this.pullGoal = 50,
    this.sleepGoalMinutes = 8 * 60,
    this.reminderOn = true,
    this.reminderMinutes = 22 * 60 + 15,
  });

  factory ChallengeSettings.defaults(DateTime today) =>
      ChallengeSettings(start: DateTime(today.year, 10, 1), end: DateTime(today.year, 12, 31));

  final DateTime start;
  final DateTime end;
  final int dipsGoal;
  final int pullGoal;
  final int sleepGoalMinutes;
  final bool reminderOn;
  final int reminderMinutes;

  int goalFor(Exercise e) => e == Exercise.dips ? dipsGoal : pullGoal;

  ChallengeSettings copyWith({
    DateTime? start,
    DateTime? end,
    int? dipsGoal,
    int? pullGoal,
    int? sleepGoalMinutes,
    bool? reminderOn,
    int? reminderMinutes,
  }) => ChallengeSettings(
    start: start ?? this.start,
    end: end ?? this.end,
    dipsGoal: dipsGoal ?? this.dipsGoal,
    pullGoal: pullGoal ?? this.pullGoal,
    sleepGoalMinutes: sleepGoalMinutes ?? this.sleepGoalMinutes,
    reminderOn: reminderOn ?? this.reminderOn,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
  );

  Map<String, Object> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'dipsGoal': dipsGoal,
    'pullGoal': pullGoal,
    'sleepGoalMinutes': sleepGoalMinutes,
    'reminderOn': reminderOn,
    'reminderMinutes': reminderMinutes,
  };

  factory ChallengeSettings.fromJson(Map<String, dynamic> j) => ChallengeSettings(
    start: DateTime.parse(j['start'] as String),
    end: DateTime.parse(j['end'] as String),
    dipsGoal: j['dipsGoal'] as int,
    pullGoal: j['pullGoal'] as int,
    sleepGoalMinutes: j['sleepGoalMinutes'] as int,
    reminderOn: j['reminderOn'] as bool,
    reminderMinutes: j['reminderMinutes'] as int,
  );
}

/// Everything logged for one calendar day. The sleep belongs to the night
/// that ended on this day (you wake up on it), so "Schlaf letzte Nacht" on
/// the Heute screen is today's entry.
class DayLog {
  DayLog({List<int>? dips, List<int>? pull, this.bedMinutes, this.wakeMinutes})
    : dips = dips ?? [],
      pull = pull ?? [];

  final List<int> dips;
  final List<int> pull;

  /// Minutes since midnight. Bedtime is usually the evening before.
  int? bedMinutes;
  int? wakeMinutes;

  List<int> sets(Exercise e) => e == Exercise.dips ? dips : pull;
  int total(Exercise e) => sets(e).fold(0, (a, b) => a + b);

  bool get hasSleep => bedMinutes != null && wakeMinutes != null;

  /// Slept minutes, wrapping past midnight (23:04 → 06:12 is 7:08).
  int? get sleepMinutes => hasSleep ? (wakeMinutes! - bedMinutes! + 1440) % 1440 : null;

  bool get isEmpty => dips.isEmpty && pull.isEmpty && !hasSleep;

  Map<String, Object?> toJson() => {'dips': dips, 'pull': pull, 'bed': bedMinutes, 'wake': wakeMinutes};

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
    dips: (j['dips'] as List).cast<int>().toList(),
    pull: (j['pull'] as List).cast<int>().toList(),
    bedMinutes: j['bed'] as int?,
    wakeMinutes: j['wake'] as int?,
  );
}
