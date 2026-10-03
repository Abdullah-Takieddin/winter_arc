import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/icons.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/nocturne.dart';
import '../util/dates.dart';
import '../widgets/nocturne_widgets.dart';

/// Opens 1b as a full-screen modal, the way the mockup's close button implies.
/// [day] logs for an earlier day instead of today.
Future<void> openLogSet(BuildContext context, {Exercise exercise = Exercise.dips, DateTime? day}) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LogSetScreen(initial: exercise, day: day),
      ),
    );

/// 1b · Satz eintragen — pick the exercise, dial in reps, save the set.
class LogSetScreen extends StatefulWidget {
  const LogSetScreen({super.key, this.initial = Exercise.dips, this.day});

  final Exercise initial;

  /// The day sets go to; null means today.
  final DateTime? day;

  static const quickReps = {
    Exercise.dips: [10, 15, 20, 25],
    Exercise.pull: [5, 8, 10, 12],
  };
  static const defaultReps = {Exercise.dips: 12, Exercise.pull: 8};

  @override
  State<LogSetScreen> createState() => _LogSetScreenState();
}

class _LogSetScreenState extends State<LogSetScreen> {
  late Exercise _mode = widget.initial;
  late DateTime? _day = widget.day;
  int? _reps;

  /// Starts from the last set of the day, else the mockup's default.
  int _startReps(DayLog log) {
    final sets = log.sets(_mode);
    return sets.isNotEmpty ? sets.last : LogSetScreen.defaultReps[_mode]!;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final day = _day ?? app.today;
    final isToday = day == app.today;
    final log = app.log(day);
    final reps = _reps ??= _startReps(log);
    final sets = log.sets(_mode);
    final done = log.total(_mode);
    final goal = app.settings.goalFor(_mode);
    final left = (goal - done).clamp(0, goal);

    return Scaffold(
      backgroundColor: Noc.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: Noc.screenGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          NocButton(
                            variant: NocButtonVariant.ghost,
                            icon: Ph.x,
                            tooltip: 'Schließen',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          NocSegmented<Exercise>(
                            options: {for (final e in Exercise.values) e: e.label},
                            selected: _mode,
                            onChanged: (e) => setState(() {
                              _mode = e;
                              _reps = null;
                            }),
                          ),
                          const SizedBox(width: 36),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NocTag(
                              isToday ? 'Heute' : dayLabel(day),
                              icon: Ph.calendarBlank,
                              variant: isToday ? NocTagVariant.outline : NocTagVariant.accent,
                              onTap: () => _pickDay(app, day),
                            ),
                            const SizedBox(height: 14),
                            Text('SATZ ${sets.length + 1} · WIEDERHOLUNGEN', style: NocText.kicker),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _stepButton(
                                  Ph.minus,
                                  'Weniger',
                                  reps > 0 ? () => setState(() => _reps = reps - 1) : null,
                                ),
                                const SizedBox(width: 20),
                                // Three-digit counts shrink to fit narrow phones.
                                Flexible(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(minWidth: 150),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$reps',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 112,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 112 * -.04,
                                          height: 1,
                                          shadows: [Shadow(color: Noc.accent700, blurRadius: 40)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                _stepButton(Ph.plus, 'Mehr', () => setState(() => _reps = reps + 1)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final n in LogSetScreen.quickReps[_mode]!)
                                  NocButton(
                                    variant: NocButtonVariant.ghost,
                                    label: '$n',
                                    onPressed: () => setState(() => _reps = n),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 26),
                            Text(
                              '${isToday ? 'Heute' : 'Am ${shortDate(day)}'}: $done / $goal · noch $left',
                              style: NocText.label,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isToday ? 'Sätze heute' : 'Sätze am ${shortDate(day)}', style: NocText.small),
                          const SizedBox(height: 8),
                          sets.isEmpty
                              ? Text('Noch keine', style: NocText.small.copyWith(color: Noc.neutral600))
                              : Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (var i = 0; i < sets.length; i++)
                                      NocTag(
                                        '${sets[i]} Wdh.',
                                        variant: NocTagVariant.neutral,
                                        onTap: () => _confirmRemove(app, day, i),
                                      ),
                                  ],
                                ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: NocButton(
                        label: 'Satz speichern',
                        block: true,
                        height: 52,
                        fontSize: 15,
                        onPressed: reps > 0
                            ? () {
                                HapticFeedback.lightImpact();
                                app.addSet(_mode, reps, day: day);
                              }
                            : null,
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

  Widget _stepButton(IconData icon, String tooltip, VoidCallback? onPressed) => NocButton(
    variant: NocButtonVariant.secondary,
    icon: icon,
    iconSize: 20,
    iconOnlySize: 52,
    tooltip: tooltip,
    onPressed: onPressed,
  );

  /// Switches to an earlier day (back to the challenge start, at most a year).
  Future<void> _pickDay(AppState app, DateTime current) async {
    final yearAgo = addDays(app.today, -365);
    final first = app.settings.start.isBefore(yearAgo) ? yearAgo : app.settings.start;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(first) ? first : current,
      firstDate: first.isAfter(app.today) ? app.today : first,
      lastDate: app.today,
      helpText: 'Für welchen Tag?',
    );
    if (picked != null) {
      setState(() {
        _day = picked;
        _reps = null;
      });
    }
  }

  Future<void> _confirmRemove(AppState app, DateTime day, int index) async {
    final reps = app.log(day).sets(_mode)[index];
    final where = day == app.today ? 'aus dem heutigen Tag' : 'vom ${shortDate(day)}';
    final ok = await showNocDialog<bool>(
      context,
      title: 'Satz löschen?',
      body: Text('Satz ${index + 1} mit $reps ${_mode.label} wird $where entfernt.'),
      actions: [
        Builder(
          builder: (c) => NocButton(
            variant: NocButtonVariant.secondary,
            label: 'Abbrechen',
            onPressed: () => Navigator.pop(c, false),
          ),
        ),
        Builder(
          builder: (c) => NocButton(label: 'Löschen', onPressed: () => Navigator.pop(c, true)),
        ),
      ],
    );
    if (ok == true) await app.removeSet(_mode, index, day: day);
  }
}
