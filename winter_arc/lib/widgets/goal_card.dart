import 'package:flutter/material.dart';

import '../theme/nocturne.dart';
import 'nocturne_widgets.dart';

/// The ring card from 1a: progress ring, label, `value / goal` and an action.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.progress,
    required this.label,
    required this.value,
    required this.unit,
    required this.trailing,
    this.detail,
    this.onTap,
  });

  final double progress;
  final String label;
  final String value;
  final String unit;
  final Widget trailing;

  /// An optional small line under the value, e.g. the sets of the day.
  final String? detail;
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
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(detail!, style: NocText.small, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        trailing,
      ],
    ),
  );
}
