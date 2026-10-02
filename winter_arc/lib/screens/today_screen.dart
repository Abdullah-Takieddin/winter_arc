import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/nocturne.dart';
import '../util/dates.dart';
import '../widgets/nocturne_widgets.dart';
import 'log_set_screen.dart';
import 'sleep_screen.dart';

/// 1a · Heute — challenge day, progress and the three daily goals.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  /// Quick-add amounts on the cards, as in the mockup.
  static const quickAdd = {Exercise.dips: 15, Exercise.pull: 8};

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    final day = app.dayNumber;
    final total = app.totalDays;
    final (title, aside) = day < 1
        ? ('Tag 0', 'Start am ${shortDate(s.start)}')
        : day > total
        ? ('Tag $total', 'geschafft')
        : ('Tag $day', 'von $total');
    final streak = app.currentStreak.length;
    final sleep = app.todayLog;

    return ListView(
      padding: const EdgeInsets.only(top: 28, bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(kicker: longDate(app.today), title: title, aside: aside),
              const SizedBox(height: 10),
              _DayProgress(progress: app.progress),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(app.progress * 100).round()} % geschafft', style: NocText.small),
                  Row(
                    children: [
                      Icon(PhFill.flame, size: 11, color: Noc.accent300),
                      const SizedBox(width: 4),
                      Text(
                        'Serie $streak ${streak == 1 ? 'Tag' : 'Tage'}',
                        style: NocText.small.copyWith(color: Noc.accent300),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: Column(
            children: [
              for (final e in Exercise.values) ...[_ExerciseCard(exercise: e), const SizedBox(height: 10)],
              _GoalCard(
                progress: (sleep.sleepMinutes ?? 0) / s.sleepGoalMinutes,
                label: 'Schlaf letzte Nacht',
                value: sleep.sleepMinutes == null ? '–' : hm(sleep.sleepMinutes!),
                unit: ' / ${hoursLabel(s.sleepGoalMinutes)}',
                onTap: () => showSleepEntryDialog(context),
                trailing: sleep.hasSleep
                    ? NocTag(clock(sleep.bedMinutes!), icon: Ph.moon)
                    : NocButton(
                        label: 'Eintragen',
                        icon: Ph.moon,
                        onPressed: () => showSleepEntryDialog(context),
                      ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Text(_note(app), style: NocText.body),
        ),
      ],
    );
  }

  static String _note(AppState app) {
    final left = {
      for (final e in Exercise.values) e: (app.settings.goalFor(e) - app.todayLog.total(e)).clamp(0, 1 << 30),
    };
    final open = [
      for (final e in Exercise.values)
        if (left[e]! > 0) '${left[e]} ${e.label}',
    ];
    if (open.isEmpty) return 'Training für heute erledigt. Jetzt zählt nur noch der Schlaf.';
    return 'Noch ${open.join(' und ')} bis zum Tagesziel.';
  }
}

class _DayProgress extends StatelessWidget {
  const _DayProgress({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: Container(
      height: 3,
      color: Noc.neutral800,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress,
        child: Container(
          decoration: const BoxDecoration(
            color: Noc.accent,
            boxShadow: [BoxShadow(color: Noc.accent, blurRadius: 12)],
          ),
        ),
      ),
    ),
  );
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final done = app.todayLog.total(exercise);
    final goal = app.settings.goalFor(exercise);
    final add = TodayScreen.quickAdd[exercise]!;
    return _GoalCard(
      progress: done / goal,
      label: exercise.label,
      value: '$done',
      unit: ' / $goal',
      onTap: () => openLogSet(context, exercise),
      trailing: NocButton(
        label: '$add',
        icon: Ph.plus,
        tooltip: '$add ${exercise.label} als Satz eintragen',
        onPressed: () => app.addSet(exercise, add),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.progress,
    required this.label,
    required this.value,
    required this.unit,
    required this.trailing,
    this.onTap,
  });

  final double progress;
  final String label;
  final String value;
  final String unit;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => NocCard(
    onTap: onTap,
    child: Row(
      children: [
        ProgressRing(value: progress),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: NocText.label),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  text: value,
                  style: NocText.value,
                  children: [TextSpan(text: unit, style: NocText.valueUnit)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        trailing,
      ],
    ),
  );
}
