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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < substats.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == substats.length - 1 ? 0 : 6),
            child: Chip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text(
                formatSubstat(substats[i]),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}
