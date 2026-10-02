import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/nocturne.dart';
import '../util/dates.dart';
import '../widgets/nocturne_widgets.dart';
import 'settings_dialog.dart';

/// 1d · Verlauf — the whole challenge as a heatmap, totals and best values.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    final best = app.bestSleep;

    return ListView(
      padding: const EdgeInsets.only(top: 28, bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ScreenHeader(
            kicker: 'Winter Arc ${s.start.year}',
            title: 'Verlauf',
            trailing: NocButton(
              variant: NocButtonVariant.ghost,
              icon: Ph.gear,
              iconSize: 20,
              tooltip: 'Challenge-Einstellungen',
              onPressed: () => showSettingsDialog(context),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Heatmap(cells: app.heat),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(shortDate(s.start), style: NocText.small),
                  Text(shortDate(s.end), style: NocText.small),
                ],
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _Legend(Noc.accent, 'Alle 3 Ziele'),
                  _Legend(Noc.accent700, '1–2 Ziele'),
                  _Legend(Noc.neutral800, 'Keins'),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          child: _TotalsTable(
            rows: [
              for (final e in Exercise.values)
                (e.label, grouped(app.total(e)), app.bestSet(e) == 0 ? '–' : '${app.bestSet(e)} am Stück'),
              (
                'Schlaf ≥ ${hoursLabel(s.sleepGoalMinutes)}',
                '${app.nightsMetGoal} ${app.nightsMetGoal == 1 ? 'Nacht' : 'Nächte'}',
                best == null ? '–' : '${hm(best)} h',
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _StreakCard(streak: app.longestStreak, running: app.longestIsCurrent),
        ),
      ],
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.cells});
  final List<HeatCell> cells;

  static const _columns = 13;
  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final size = (c.maxWidth - _gap * (_columns - 1)) / _columns;
      return Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final cell in cells)
            Tooltip(
              message:
                  '${shortDate(cell.date)}${switch (cell.level) {
                    HeatLevel.all => ' · alle 3 Ziele',
                    HeatLevel.some => ' · 1–2 Ziele',
                    HeatLevel.none => ' · keins',
                    HeatLevel.future => '',
                  }}',
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: switch (cell.level) {
                    HeatLevel.all => Noc.accent,
                    HeatLevel.some => Noc.accent700,
                    HeatLevel.none => Noc.neutral800,
                    HeatLevel.future => Noc.neutral900,
                  },
                  borderRadius: BorderRadius.circular(3),
                  border: cell.isToday ? Border.all(color: Noc.accent) : null,
                  boxShadow: cell.level == HeatLevel.all && !cell.isToday
                      ? const [BoxShadow(color: Noc.accent700, blurRadius: 6)]
                      : null,
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 5),
      Text(label, style: NocText.small.copyWith(color: Noc.neutral300)),
    ],
  );
}

/// `.table` — uppercase muted header, rows separated by fading rules.
class _TotalsTable extends StatelessWidget {
  const _TotalsTable({required this.rows});
  final List<(String, String, String)> rows;

  static final _head = TextStyle(fontSize: 11, letterSpacing: 11 * .08, color: Noc.textMix(.6));
  static const _cell = TextStyle(fontSize: 14);

  Widget _row((String, String, String) r, TextStyle style, Color rule) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(Noc.space2),
        child: Row(
          children: [
            Expanded(flex: 4, child: Text(r.$1, style: style)),
            Expanded(
              flex: 3,
              child: Text(r.$2, style: style, textAlign: TextAlign.right),
            ),
            Expanded(
              flex: 4,
              child: Text(r.$3, style: style, textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
      FadingRule(color: rule),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _row(('GESAMT', 'ERREICHT', 'BESTWERT'), _head, Noc.divider),
      for (final r in rows) _row(r, _cell, Noc.textMix(.08)),
    ],
  );
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.running});
  final Streak streak;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final (title, sub) = streak.length == 0
        ? ('Noch keine Serie', 'Schaff alle 3 Ziele an einem Tag, um eine zu starten.')
        : (
            'Längste Serie: ${streak.length} ${streak.length == 1 ? 'Tag' : 'Tage'}',
            running
                ? 'Läuft seit ${dayMonth(streak.start!)}'
                : '${shortDate(streak.start!)} – ${shortDate(streak.end!)}',
          );
    return NocCard(
      padding: 14,
      child: Row(
        children: [
          const Icon(PhFill.flame, size: 22, color: Noc.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12, color: Noc.neutral400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
