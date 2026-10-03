import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/icons.dart';
import '../theme/nocturne.dart';
import '../util/dates.dart';
import '../widgets/goal_card.dart';
import '../widgets/nocturne_widgets.dart';
import 'log_set_screen.dart';
import 'sleep_screen.dart';

/// Opens one day of the challenge to review or backfill it.
Future<void> openDay(BuildContext context, DateTime day) =>
    Navigator.of(context)
        .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => DayScreen(initial: day)));

/// A single day: its three goals, with actions to add sets or the night.
/// The arrows step through days up to today.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.initial});

  final DateTime initial;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late DateTime _day = dateOnly(widget.initial);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    final log = app.log(_day);
    final n = daysBetween(s.start, _day) + 1;
    final inWindow = n >= 1 && n <= app.totalDays;
    final canForward = _day.isBefore(app.today);
    final met = app.goalsMet(_day);
    final sleep = log.sleepMinutes;

    return Scaffold(
      backgroundColor: Noc.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Noc.screenGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  children: [
                    NocButton(
                      variant: NocButtonVariant.ghost,
                      icon: Ph.x,
                      tooltip: 'Schließen',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    NocButton(
                      variant: NocButtonVariant.ghost,
                      icon: Ph.caretLeft,
                      iconSize: 18,
                      tooltip: 'Vorheriger Tag',
                      onPressed: () => setState(() => _day = addDays(_day, -1)),
                    ),
                    NocButton(
                      variant: NocButtonVariant.ghost,
                      icon: Ph.caretRight,
                      iconSize: 18,
                      tooltip: 'Nächster Tag',
                      onPressed: canForward ? () => setState(() => _day = addDays(_day, 1)) : null,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: ScreenHeader(
                  kicker: inWindow ? 'Tag $n von ${app.totalDays}' : 'Außerhalb der Challenge',
                  title: _day == app.today ? 'Heute' : dayLabel(_day),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: NocTag(
                    met == 3 ? 'Alle 3 Ziele' : '$met von 3 Zielen',
                    variant: met == 3 ? NocTagVariant.accent : NocTagVariant.neutral,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: Column(
                  children: [
                    for (final e in Exercise.values) ...[
                      GoalCard(
                        progress: log.total(e) / s.goalFor(e),
                        label: e.label,
                        value: '${log.total(e)}',
                        unit: ' / ${s.goalFor(e)}',
                        detail: log.sets(e).isEmpty ? 'Keine Sätze' : 'Sätze: ${log.sets(e).join(' · ')}',
                        onTap: () => openLogSet(context, exercise: e, day: _day),
                        trailing: NocButton(
                          label: 'Satz',
                          icon: Ph.plus,
                          tooltip: '${e.label}-Satz für ${dayLabel(_day)} eintragen',
                          onPressed: () => openLogSet(context, exercise: e, day: _day),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    GoalCard(
                      progress: (sleep ?? 0) / s.sleepGoalMinutes,
                      label: 'Schlaf',
                      value: sleep == null ? '–' : hm(sleep),
                      unit: ' / ${hoursLabel(s.sleepGoalMinutes)}',
                      detail: log.hasSleep ? '${clock(log.bedMinutes!)} – ${clock(log.wakeMinutes!)}' : null,
                      onTap: () => showSleepEntryDialog(context, day: _day),
                      trailing: NocButton(
                        label: log.hasSleep ? 'Ändern' : 'Eintragen',
                        icon: log.hasSleep ? Ph.pencilSimple : Ph.moon,
                        onPressed: () => showSleepEntryDialog(context, day: _day),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
