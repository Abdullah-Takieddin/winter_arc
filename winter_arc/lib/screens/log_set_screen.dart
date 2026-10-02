import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/icons.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';

/// Opens 1b as a full-screen modal, the way the mockup's close button implies.
Future<void> openLogSet(BuildContext context, [Exercise exercise = Exercise.dips]) =>
    Navigator.of(context)
        .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => LogSetScreen(initial: exercise)));

/// 1b · Satz eintragen — pick the exercise, dial in reps, save the set.
class LogSetScreen extends StatefulWidget {
  const LogSetScreen({super.key, this.initial = Exercise.dips});

  final Exercise initial;

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
  int? _reps;

  /// Starts from the last set of the day, else the mockup's default.
  int _startReps(AppState app) {
    final sets = app.todayLog.sets(_mode);
    return sets.isNotEmpty ? sets.last : LogSetScreen.defaultReps[_mode]!;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final reps = _reps ??= _startReps(app);
    final sets = app.todayLog.sets(_mode);
    final done = app.todayLog.total(_mode);
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
                            Text('Heute: $done / $goal · noch $left', style: NocText.label),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sätze heute', style: NocText.small),
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
                                        onTap: () => _confirmRemove(app, i),
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
                                app.addSet(_mode, reps);
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

  Future<void> _confirmRemove(AppState app, int index) async {
    final reps = app.todayLog.sets(_mode)[index];
    final ok = await showNocDialog<bool>(
      context,
      title: 'Satz löschen?',
      body: Text('Satz ${index + 1} mit $reps ${_mode.label} wird aus dem heutigen Tag entfernt.'),
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
    if (ok == true) await app.removeSet(_mode, index);
  }
}
