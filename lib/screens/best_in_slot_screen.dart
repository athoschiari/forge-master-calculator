import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/app_state.dart';
import '../widgets/build_summary_banner.dart';

/// Answers "what's my ceiling for a chosen objective if my gear substats were
/// ideal?" Every gear piece's main stats stay exactly as equipped; pets and
/// mount can be toggled in or out of the calculation. The search itself
/// lives in `engine/best_in_slot.dart` - this screen just presents it.
class BestInSlotScreen extends StatefulWidget {
  const BestInSlotScreen({super.key});

  @override
  State<BestInSlotScreen> createState() => _BestInSlotScreenState();
}

class _BestInSlotScreenState extends State<BestInSlotScreen> {
  OptimizationMode _mode = OptimizationMode.balanced;
  bool _includePets = true;
  bool _includeMount = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final result = state.bestInSlot(
      mode: _mode,
      includePets: _includePets,
      includeMount: _includeMount,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Best in Slot', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          "Highest ${_mode.shortLabel} achievable if every gear piece's "
          'existing substat slots rolled the ideal type at its maximum '
          'value. Main stats stay as they are now.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Objective', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                SegmentedButton<OptimizationMode>(
                  segments: const [
                    ButtonSegment(
                      value: OptimizationMode.lifestealPerSecond,
                      label: Text('Lifesteal/sec'),
                      icon: Icon(Icons.favorite),
                    ),
                    ButtonSegment(
                      value: OptimizationMode.dps,
                      label: Text('DPS'),
                      icon: Icon(Icons.bolt),
                    ),
                    ButtonSegment(
                      value: OptimizationMode.balanced,
                      label: Text('Balanced'),
                      icon: Icon(Icons.balance),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
                const SizedBox(height: 4),
                Text(
                  _mode.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include equipped pets'),
                  subtitle:
                      const Text("Count your pets' stats toward the result"),
                  value: _includePets,
                  onChanged: (v) => setState(() => _includePets = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include equipped mount'),
                  subtitle:
                      const Text("Count your mount's stats toward the result"),
                  value: _includeMount,
                  onChanged: (v) => setState(() => _includeMount = v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BuildSummaryBanner(
          result: state.currentBuild,
          pets: state.equippedPets,
          mount: state.equippedMount,
          proposed: result.totalSlots == 0 ? null : result.build,
          inlineComparison: true,
        ),
        if (result.totalSlots == 0) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "None of your gear has any substats rolled yet, so there's "
                'nothing to optimise.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
