import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../state/app_state.dart';
import '../theme/nocturne.dart';
import '../util/dates.dart';
import '../widgets/nocturne_widgets.dart';

/// Challenge window and daily goals. Logged data is kept when these change;
/// rings, streaks and the heatmap are simply re-derived.
Future<void> showSettingsDialog(BuildContext context) async {
  final app = AppScope.of(context);
  var s = app.settings;

  await showNocDialog<void>(
    context,
    title: 'Challenge-Einstellungen',
    body: StatefulBuilder(
      builder: (context, setState) {
        Future<void> pickDate(DateTime current, ValueChanged<DateTime> apply) async {
          final d = await showDatePicker(
            context: context,
            initialDate: current,
            firstDate: DateTime(current.year - 2),
            lastDate: DateTime(current.year + 3),
          );
          if (d != null) setState(() => apply(d));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(
              'Start',
              NocButton(
                variant: NocButtonVariant.secondary,
                label: shortDate(s.start),
                icon: Ph.calendarBlank,
                onPressed: () => pickDate(s.start, (d) {
                  s = s.copyWith(start: d, end: d.isAfter(s.end) ? d : null);
                }),
              ),
            ),
            _row(
              'Ende',
              NocButton(
                variant: NocButtonVariant.secondary,
                label: shortDate(s.end),
                icon: Ph.calendarBlank,
                onPressed: () => pickDate(s.end, (d) {
                  s = s.copyWith(end: d, start: d.isBefore(s.start) ? d : null);
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('${daysBetween(s.start, s.end) + 1} Tage', style: NocText.small),
            ),
            _row(
              'Dips pro Tag',
              _Stepper(
                value: '${s.dipsGoal}',
                onMinus: s.dipsGoal > 5
                    ? () => setState(() => s = s.copyWith(dipsGoal: s.dipsGoal - 5))
                    : null,
                onPlus: () => setState(() => s = s.copyWith(dipsGoal: s.dipsGoal + 5)),
              ),
            ),
            _row(
              'Klimmzüge pro Tag',
              _Stepper(
                value: '${s.pullGoal}',
                onMinus: s.pullGoal > 5
                    ? () => setState(() => s = s.copyWith(pullGoal: s.pullGoal - 5))
                    : null,
                onPlus: () => setState(() => s = s.copyWith(pullGoal: s.pullGoal + 5)),
              ),
            ),
            _row(
              'Schlaf pro Nacht',
              _Stepper(
                value: hoursLabel(s.sleepGoalMinutes),
                onMinus: s.sleepGoalMinutes > 240
                    ? () => setState(() => s = s.copyWith(sleepGoalMinutes: s.sleepGoalMinutes - 15))
                    : null,
                onPlus: s.sleepGoalMinutes < 720
                    ? () => setState(() => s = s.copyWith(sleepGoalMinutes: s.sleepGoalMinutes + 15))
                    : null,
              ),
            ),
          ],
        );
      },
    ),
    actions: [
      Builder(
        builder: (c) => NocButton(
          variant: NocButtonVariant.secondary,
          label: 'Abbrechen',
          onPressed: () => Navigator.pop(c),
        ),
      ),
      Builder(
        builder: (c) => NocButton(
          label: 'Speichern',
          onPressed: () {
            app.updateSettings(s);
            Navigator.pop(c);
          },
        ),
      ),
    ],
  );
}

Widget _row(String label, Widget control) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: Noc.neutral300)),
      ),
      control,
    ],
  ),
);

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onMinus, required this.onPlus});

  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      NocButton(variant: NocButtonVariant.secondary, icon: Ph.minus, iconSize: 16, onPressed: onMinus),
      SizedBox(
        width: 64,
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      NocButton(variant: NocButtonVariant.secondary, icon: Ph.plus, iconSize: 16, onPressed: onPlus),
    ],
  );
}
