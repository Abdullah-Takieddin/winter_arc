import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../state/app_state.dart';
import '../theme/nocturne.dart';
import '../util/dates.dart';
import '../widgets/nocturne_widgets.dart';

/// 1c · Schlaf — last seven nights against the goal, last night's times and
/// the bedtime reminder.
class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    final last = app.todayLog;
    final avg = app.averageSleep;

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: ScreenHeader(
                  kicker: 'Schlaf · letzte 7 Nächte',
                  title: avg == null ? 'Ø – h' : 'Ø ${hm(avg)} h',
                  aside: 'Ziel ${hoursLabel(s.sleepGoalMinutes)}',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                child: _SleepChart(nights: app.lastNights, goalMinutes: s.sleepGoalMinutes, today: app.today),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeCard(icon: Ph.moon, label: 'Im Bett', minutes: last.bedMinutes),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TimeCard(icon: Ph.sunHorizon, label: 'Aufgestanden', minutes: last.wakeMinutes),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: NocCard(
                  padding: 14,
                  onTap: () => _pickReminderTime(context, app),
                  child: Row(
                    children: [
                      const Icon(Ph.alarm, size: 22, color: Noc.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Schlafenszeit-Erinnerung', style: TextStyle(fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              s.reminderOn
                                  ? 'Heute um ${clock(s.reminderMinutes)}'
                                  : 'Aus · ${clock(s.reminderMinutes)}',
                              style: const TextStyle(fontSize: 12, color: Noc.neutral400),
                            ),
                          ],
                        ),
                      ),
                      NocTag(
                        s.reminderOn ? 'An' : 'Aus',
                        variant: s.reminderOn ? NocTagVariant.accent : NocTagVariant.neutral,
                        onTap: () => app.updateSettings(s.copyWith(reminderOn: !s.reminderOn)),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: NocButton(
                  label: last.hasSleep ? 'Nacht bearbeiten' : 'Nacht eintragen',
                  icon: last.hasSleep ? Ph.pencilSimple : Ph.plus,
                  block: true,
                  height: 52,
                  fontSize: 15,
                  onPressed: () => showSleepEntryDialog(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickReminderTime(BuildContext context, AppState app) async {
    final m = app.settings.reminderMinutes;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
      helpText: 'Schlafenszeit-Erinnerung',
    );
    if (t != null) {
      await app.updateSettings(
        app.settings.copyWith(reminderMinutes: t.hour * 60 + t.minute, reminderOn: true),
      );
    }
  }
}

class _SleepChart extends StatelessWidget {
  const _SleepChart({required this.nights, required this.goalMinutes, required this.today});

  final List<Night> nights;
  final int goalMinutes;
  final DateTime today;

  static const _height = 200.0;

  /// The mockup scales bars to a 10 h ceiling.
  static double _px(int minutes) => (minutes / 600 * _height).clamp(0, _height);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < nights.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: _bar(nights[i])),
                ],
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _px(goalMinutes),
              child: const FadingRule(color: Noc.accent600),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          for (var i = 0; i < nights.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: Text(weekdayShort(nights[i].date), textAlign: TextAlign.center, style: NocText.small),
            ),
          ],
        ],
      ),
    ],
  );

  Widget _bar(Night n) {
    final m = n.minutes;
    if (m == null) {
      // No entry: a faint stub so the gap reads as "missing", not "zero".
      return Container(
        height: 4,
        decoration: BoxDecoration(color: Noc.neutral800, borderRadius: BorderRadius.circular(2)),
      );
    }
    final color = n.date == today
        ? Noc.accent
        : m >= goalMinutes
        ? Noc.accent600
        : Noc.neutral700;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _px(m)),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, h, _) => Container(
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.icon, required this.label, required this.minutes});

  final IconData icon;
  final String label;
  final int? minutes;

  @override
  Widget build(BuildContext context) => NocCard(
    padding: 14,
    onTap: () => showSleepEntryDialog(context),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Noc.neutral300),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Noc.neutral300)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          minutes == null ? '–' : clock(minutes!),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

/// Logs (or edits) the night that ended on [day] (default: last night).
Future<void> showSleepEntryDialog(BuildContext context, {DateTime? day}) async {
  final app = AppScope.of(context);
  final d = day ?? app.today;
  final log = app.log(d);
  var bed = log.bedMinutes ?? 23 * 60;
  var wake = log.wakeMinutes ?? 7 * 60;

  await showNocDialog<void>(
    context,
    title: d == app.today ? 'Letzte Nacht' : 'Nacht zum ${dayLabel(d)}',
    body: StatefulBuilder(
      builder: (context, setState) {
        Future<void> pick(int current, ValueChanged<int> apply, String help) async {
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
            helpText: help,
          );
          if (t != null) setState(() => apply(t.hour * 60 + t.minute));
        }

        final slept = (wake - bed + 1440) % 1440;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _timeRow(Ph.moon, 'Im Bett', bed, () => pick(bed, (v) => bed = v, 'Im Bett')),
            const SizedBox(height: 8),
            _timeRow(Ph.sunHorizon, 'Aufgestanden', wake, () => pick(wake, (v) => wake = v, 'Aufgestanden')),
            const SizedBox(height: 12),
            Text(
              'Geschlafen: ${hm(slept)} h · Ziel ${hoursLabel(app.settings.sleepGoalMinutes)}',
              style: NocText.label,
            ),
          ],
        );
      },
    ),
    actions: [
      if (log.hasSleep)
        Builder(
          builder: (c) => NocButton(
            variant: NocButtonVariant.ghost,
            label: 'Löschen',
            onPressed: () {
              app.clearSleep(day: d);
              Navigator.pop(c);
            },
          ),
        ),
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
            app.setSleep(bed, wake, day: d);
            Navigator.pop(c);
          },
        ),
      ),
    ],
  );
}

Widget _timeRow(IconData icon, String label, int minutes, VoidCallback onTap) => Material(
  color: Noc.bg,
  borderRadius: BorderRadius.circular(Noc.radiusMd),
  child: InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(Noc.radiusMd),
    splashFactory: NoSplash.splashFactory,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Noc.divider),
        borderRadius: BorderRadius.circular(Noc.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Noc.neutral300),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: Noc.neutral300)),
          ),
          Text(clock(minutes), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  ),
);
