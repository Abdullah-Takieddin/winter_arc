import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../util/dates.dart';

/// How a day shows in the Verlauf heatmap.
enum HeatLevel { all, some, none, future }

class HeatCell {
  const HeatCell(this.date, this.level, {required this.isToday});
  final DateTime date;
  final HeatLevel level;
  final bool isToday;
}

class Night {
  const Night(this.date, this.minutes);
  final DateTime date;
  final int? minutes;
}

class Streak {
  const Streak(this.length, this.start, this.end);
  static const zero = Streak(0, null, null);
  final int length;
  final DateTime? start;
  final DateTime? end;
}

/// Single source of truth for the UI. Stores raw logs and derives every
/// number on the screens (rings, streaks, heatmap, totals) from them.
class AppState extends ChangeNotifier {
  AppState(this._repo, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _settings = _repo.loadSettings() ?? ChallengeSettings.defaults(today);
    _logs = _repo.loadLogs();
  }

  final Repository _repo;
  final DateTime Function() _clock;
  late ChallengeSettings _settings;
  late Map<String, DayLog> _logs;

  ChallengeSettings get settings => _settings;
  DateTime get today => dateOnly(_clock());

  /// Lets the UI re-read [today] after the app resumes on a new day.
  void refresh() => notifyListeners();

  DayLog log(DateTime day) => _logs[dateKey(day)] ?? DayLog();
  DayLog get todayLog => log(today);

  // — challenge progress —

  int get totalDays => daysBetween(_settings.start, _settings.end) + 1;

  /// 1-based day of the challenge; < 1 before the start, > [totalDays] after.
  int get dayNumber => daysBetween(_settings.start, today) + 1;

  double get progress => (dayNumber / totalDays).clamp(0.0, 1.0);

  bool _inChallenge(DateTime d) => !d.isBefore(_settings.start) && !d.isAfter(_settings.end);

  // — goals —

  bool exerciseMet(DateTime d, Exercise e) => log(d).total(e) >= _settings.goalFor(e);

  bool sleepMet(DateTime d) => (log(d).sleepMinutes ?? 0) >= _settings.sleepGoalMinutes;

  int goalsMet(DateTime d) =>
      [exerciseMet(d, Exercise.dips), exerciseMet(d, Exercise.pull), sleepMet(d)].where((m) => m).length;

  bool allMet(DateTime d) => goalsMet(d) == 3;

  // — streaks: consecutive challenge days with all three goals —

  /// Today still counts as "in progress": the streak runs through yesterday
  /// until today is complete, so it doesn't read 0 every morning.
  Streak get currentStreak {
    var end = allMet(today) ? today : addDays(today, -1);
    if (end.isAfter(_settings.end)) end = _settings.end;
    var d = end;
    var n = 0;
    while (_inChallenge(d) && allMet(d)) {
      n++;
      d = addDays(d, -1);
    }
    return n == 0 ? Streak.zero : Streak(n, addDays(d, 1), end);
  }

  Streak get longestStreak {
    var best = Streak.zero;
    var runStart = _settings.start;
    var run = 0;
    final last = today.isAfter(_settings.end) ? _settings.end : today;
    for (var d = _settings.start; !d.isAfter(last); d = addDays(d, 1)) {
      if (allMet(d)) {
        if (run == 0) runStart = d;
        run++;
        if (run > best.length) best = Streak(run, runStart, d);
      } else {
        run = 0;
      }
    }
    return best;
  }

  /// Whether [longestStreak] is the streak that is still running.
  bool get longestIsCurrent {
    final l = longestStreak, c = currentStreak;
    return l.length > 0 && l.length == c.length && l.end == c.end;
  }

  // — Verlauf —

  List<HeatCell> get heat => [
    for (var i = 0; i < totalDays; i++)
      () {
        final d = addDays(_settings.start, i);
        final level = d.isAfter(today)
            ? HeatLevel.future
            : switch (goalsMet(d)) {
                3 => HeatLevel.all,
                0 => HeatLevel.none,
                _ => HeatLevel.some,
              };
        return HeatCell(d, level, isToday: d == today);
      }(),
  ];

  Iterable<DayLog> get _challengeLogs =>
      _logs.entries.where((e) => _inChallenge(parseDateKey(e.key))).map((e) => e.value);

  int total(Exercise e) => _challengeLogs.fold(0, (a, l) => a + l.total(e));

  int bestSet(Exercise e) => _challengeLogs.fold(0, (a, l) => l.sets(e).fold(a, math.max));

  int get nightsMetGoal => _logs.keys.map(parseDateKey).where((d) => _inChallenge(d) && sleepMet(d)).length;

  int? get bestSleep => _challengeLogs
      .map((l) => l.sleepMinutes)
      .whereType<int>()
      .fold<int?>(null, (a, m) => a == null ? m : math.max(a, m));

  // — Schlaf —

  /// The seven nights ending this morning, oldest first.
  List<Night> get lastNights => [
    for (var i = 6; i >= 0; i--)
      () {
        final d = addDays(today, -i);
        return Night(d, log(d).sleepMinutes);
      }(),
  ];

  int? get averageSleep {
    final logged = lastNights.map((n) => n.minutes).whereType<int>().toList();
    if (logged.isEmpty) return null;
    return (logged.reduce((a, b) => a + b) / logged.length).round();
  }

  // — mutations —

  DayLog _editable(DateTime day) => _logs.putIfAbsent(dateKey(day), DayLog.new);

  /// The day an edit targets: [day] (time stripped) or today. Future days
  /// can't be logged.
  DateTime _target(DateTime? day) {
    final d = day == null ? today : dateOnly(day);
    if (d.isAfter(today)) throw ArgumentError.value(day, 'day', 'lies in the future');
    return d;
  }

  Future<void> addSet(Exercise e, int reps, {DateTime? day}) async {
    if (reps <= 0) return;
    final d = _target(day);
    _editable(d).sets(e).add(reps);
    await _saveLogs(d);
  }

  Future<void> removeSet(Exercise e, int index, {DateTime? day}) async {
    final d = _target(day);
    final sets = _editable(d).sets(e);
    if (index < 0 || index >= sets.length) return;
    sets.removeAt(index);
    await _saveLogs(d);
  }

  Future<void> setSleep(int bedMinutes, int wakeMinutes, {DateTime? day}) async {
    final d = _target(day);
    _editable(d)
      ..bedMinutes = bedMinutes
      ..wakeMinutes = wakeMinutes;
    await _saveLogs(d);
  }

  Future<void> clearSleep({DateTime? day}) async {
    final d = _target(day);
    _editable(d)
      ..bedMinutes = null
      ..wakeMinutes = null;
    await _saveLogs(d);
  }

  Future<void> updateSettings(ChallengeSettings s) async {
    final old = _settings;
    _settings = s;
    notifyListeners();
    await _repo.saveSettings(s);
    // Goals and the window change every day's "Ziele erreicht" and "Tag N";
    // the reminder doesn't touch any logged day.
    final affectsDays =
        old.start != s.start ||
        old.end != s.end ||
        old.dipsGoal != s.dipsGoal ||
        old.pullGoal != s.pullGoal ||
        old.sleepGoalMinutes != s.sleepGoalMinutes;
    if (affectsDays) _emitDays(loggedDays);
  }

  Future<void> _saveLogs(DateTime day) async {
    notifyListeners();
    await _repo.saveLogs(_logs);
    _emitDays([day]);
  }

  // — change feed for observers such as the Notion sync —

  final _dayListeners = <void Function(Iterable<DateTime> days)>[];

  /// Calls [listener] with the days whose data changed, after each save.
  void addDayListener(void Function(Iterable<DateTime> days) listener) => _dayListeners.add(listener);

  void _emitDays(Iterable<DateTime> days) {
    for (final l in _dayListeners) {
      l(days);
    }
  }

  /// Every day with at least one entry.
  List<DateTime> get loggedDays => [
    for (final e in _logs.entries)
      if (!e.value.isEmpty) parseDateKey(e.key),
  ];
}

/// Makes [AppState] reachable from any widget and rebuilds dependents when
/// it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
