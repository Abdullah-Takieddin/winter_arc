import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winter_arc/data/repository.dart';
import 'package:winter_arc/models/models.dart';
import 'package:winter_arc/state/app_state.dart';
import 'package:winter_arc/util/dates.dart';

/// An [AppState] whose clock the test moves, so mutations (which always
/// target "today") can fill any day.
class Harness {
  Harness._(this.prefs, this.now);

  final SharedPreferences prefs;
  DateTime now;
  late final AppState state = AppState(Repository(prefs), clock: () => now);

  static Future<Harness> create(DateTime now) async {
    SharedPreferences.setMockInitialValues({});
    return Harness._(await SharedPreferences.getInstance(), now);
  }

  Future<void> on(DateTime day, Future<void> Function(AppState s) body) async {
    final keep = now;
    now = day.add(const Duration(hours: 20));
    await body(state);
    now = keep;
  }

  /// Meets all three default goals (100 / 50 / 8 h) on [day].
  Future<void> complete(DateTime day) => on(day, (s) async {
    await s.addSet(Exercise.dips, 100);
    await s.addSet(Exercise.pull, 50);
    await s.setSleep(22 * 60 + 30, 6 * 60 + 45);
  });
}

void main() {
  final today = DateTime(2026, 11, 3, 7, 12);

  group('challenge day', () {
    test('3 Nov is day 34 of 92 (37 %)', () async {
      final h = await Harness.create(today);
      expect(h.state.totalDays, 92);
      expect(h.state.dayNumber, 34);
      expect((h.state.progress * 100).round(), 37);
    });

    test('progress clamps outside the window', () async {
      final h = await Harness.create(DateTime(2026, 9, 20));
      expect(h.state.dayNumber, lessThan(1));
      expect(h.state.progress, 0);
      h.now = DateTime(2027, 1, 5);
      expect(h.state.progress, 1);
    });
  });

  test('sleep wraps past midnight: 23:04 → 06:12 is 7:08', () async {
    final h = await Harness.create(today);
    await h.state.setSleep(23 * 60 + 4, 6 * 60 + 12);
    expect(hm(h.state.todayLog.sleepMinutes!), '7:08');
    expect(h.state.sleepMet(h.state.today), isFalse);
  });

  group('streaks', () {
    test('a run ending today is current and longest', () async {
      final h = await Harness.create(today);
      for (var d = DateTime(2026, 10, 23); !d.isAfter(DateTime(2026, 11, 3)); d = addDays(d, 1)) {
        await h.complete(d);
      }
      expect(h.state.currentStreak.length, 12);
      expect(h.state.longestStreak.start, DateTime(2026, 10, 23));
      expect(h.state.longestIsCurrent, isTrue);
    });

    test('an unfinished today does not break the streak', () async {
      final h = await Harness.create(today);
      await h.complete(DateTime(2026, 11, 1));
      await h.complete(DateTime(2026, 11, 2));
      await h.state.addSet(Exercise.dips, 20);
      expect(h.state.currentStreak.length, 2);
    });

    test('a missed day ends the run; longest remembers the older one', () async {
      final h = await Harness.create(today);
      for (final d in [1, 2, 3, 4]) {
        await h.complete(DateTime(2026, 10, d));
      }
      await h.complete(DateTime(2026, 11, 2));
      expect(h.state.currentStreak.length, 1);
      expect(h.state.longestStreak.length, 4);
      expect(h.state.longestStreak.end, DateTime(2026, 10, 4));
      expect(h.state.longestIsCurrent, isFalse);
    });

    test('days before the start never count', () async {
      final h = await Harness.create(DateTime(2026, 10, 2, 8));
      await h.complete(DateTime(2026, 9, 30));
      await h.complete(DateTime(2026, 10, 1));
      expect(h.state.currentStreak.length, 1);
    });
  });

  test('heatmap levels', () async {
    final h = await Harness.create(today);
    await h.complete(DateTime(2026, 10, 1));
    await h.on(DateTime(2026, 10, 2), (s) => s.addSet(Exercise.dips, 100));
    final heat = h.state.heat;
    expect(heat, hasLength(92));
    expect(heat[0].level, HeatLevel.all);
    expect(heat[1].level, HeatLevel.some);
    expect(heat[2].level, HeatLevel.none);
    expect(heat[33].isToday, isTrue);
    expect(heat[34].level, HeatLevel.future);
  });

  test('totals, best set and best night', () async {
    final h = await Harness.create(today);
    await h.on(DateTime(2026, 10, 5), (s) async {
      await s.addSet(Exercise.dips, 32);
      await s.addSet(Exercise.dips, 20);
      await s.setSleep(22 * 60, 7 * 60 + 2);
    });
    await h.on(DateTime(2026, 9, 1), (s) => s.addSet(Exercise.dips, 99)); // outside the window
    await h.state.addSet(Exercise.pull, 14);
    expect(h.state.total(Exercise.dips), 52);
    expect(h.state.bestSet(Exercise.dips), 32);
    expect(h.state.total(Exercise.pull), 14);
    expect(h.state.nightsMetGoal, 1);
    expect(hm(h.state.bestSleep!), '9:02');
  });

  test('removing a set and changing goals', () async {
    final h = await Harness.create(today);
    await h.state.addSet(Exercise.dips, 20);
    await h.state.addSet(Exercise.dips, 25);
    await h.state.removeSet(Exercise.dips, 0);
    expect(h.state.todayLog.dips, [25]);
    await h.state.updateSettings(h.state.settings.copyWith(dipsGoal: 25));
    expect(h.state.exerciseMet(h.state.today, Exercise.dips), isTrue);
  });

  test('data survives a restart', () async {
    final h = await Harness.create(today);
    await h.state.addSet(Exercise.pull, 8);
    await h.state.setSleep(23 * 60, 7 * 60);
    await h.state.updateSettings(h.state.settings.copyWith(pullGoal: 40));

    final reloaded = AppState(Repository(h.prefs), clock: () => today);
    expect(reloaded.todayLog.pull, [8]);
    expect(reloaded.todayLog.sleepMinutes, 480);
    expect(reloaded.settings.pullGoal, 40);
  });

  test('German formatting', () {
    expect(grouped(3120), '3.120');
    expect(grouped(1486), '1.486');
    expect(grouped(999), '999');
    expect(longDate(DateTime(2026, 11, 2)), 'Montag, 2. November');
    expect(shortDate(DateTime(2026, 12, 31)), '31. Dez.');
    expect(hoursLabel(480), '8 h');
    expect(hoursLabel(450), '7:30 h');
  });
}
