import 'package:flutter/material.dart';

import '../models/stats.dart';
import '../utils/formatting.dart';

/// A wrapped row of small chips describing a list of substats. Shared by the
/// gear, pet and mount cards so substats render identically everywhere.
class SubstatChips extends StatelessWidget {
  const SubstatChips({super.key, required this.substats});

  final List<Substat> substats;

  @override
  Widget build(BuildContext context) {
    if (substats.isEmpty) {
      return Text(
        'No substats',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in substats)
          Chip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            label: Text(
              '${s.type.label} '
              '${s.type.isPercent ? formatPercentPoints(s.value) : s.value.toStringAsFixed(1)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}
