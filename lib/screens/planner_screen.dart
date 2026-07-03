import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/calculator.dart';
import '../models/build.dart';
import '../models/enums.dart';
import '../models/mount.dart';
import '../models/pet.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/build_summary_banner.dart';

/// A single suggested change and its projected effect on the chosen metric.
class _Move {
  _Move({required this.label, required this.delta, required this.result});
  final String label;
  final double delta;
  final BuildResult result;
}

/// "What if" planner: shows which single change (equip a different mount, or
/// swap in a pet you own) would most improve the metric you care about, versus
/// your current loadout.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  OptimizationMode _metric = OptimizationMode.dps;

  double _value(BuildResult r) {
    switch (_metric) {
      case OptimizationMode.dps:
        return r.dps;
      case OptimizationMode.lifestealPerSecond:
        return r.lifestealPerSecond;
      case OptimizationMode.balanced:
        return r.dps + r.lifestealPerSecond;
    }
  }

  List<_Move> _moves(AppState state, BuildResult current) {
    final moves = <_Move>[];
    final baseline = _value(current);
    final equippedPets = state.equippedPets;
    final equippedIds = equippedPets.map((p) => p.id).toSet();

    BuildResult buildWith(List<Pet> pets, Mount? mount) =>
        Calculator.calculateBuild(
          gear: state.gear,
          pets: pets,
          mount: mount,
          config: state.config,
        );

    // Mount swaps.
    for (final mount in state.mounts) {
      if (state.isMountEquipped(mount.id)) continue;
      final result = buildWith(equippedPets, mount);
      moves.add(_Move(
        label: 'Equip mount: '
            '${describePiece(substats: mount.substats, damage: mount.mainDamage, health: mount.mainHealth)}',
        delta: _value(result) - baseline,
        result: result,
      ));
    }

    // Pet swaps: try each owned-but-unequipped pet in the best equipped slot.
    for (final pet in state.pets) {
      if (equippedIds.contains(pet.id)) continue;
      BuildResult? bestResult;
      var bestLabel = '';
      if (equippedPets.length < state.petSlots) {
        bestResult = buildWith([...equippedPets, pet], state.equippedMount);
        bestLabel = 'Add pet: ${describePet(pet)}';
      }
      for (final slotPet in equippedPets) {
        final swapped = [
          for (final p in equippedPets) if (p.id == slotPet.id) pet else p,
        ];
        final result = buildWith(swapped, state.equippedMount);
        if (bestResult == null || _value(result) > _value(bestResult)) {
          bestResult = result;
          bestLabel = 'Swap in ${describePet(pet)} for ${describePet(slotPet)}';
        }
      }
      if (bestResult != null) {
        moves.add(_Move(
          label: bestLabel,
          delta: _value(bestResult) - baseline,
          result: bestResult,
        ));
      }
    }

    moves.sort((a, b) => b.delta.compareTo(a.delta));
    return moves;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final current = state.currentBuild;
    final moves = _moves(state, current);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Planner', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Projected gains from a single change to your current loadout.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        BuildSummaryBanner(
          result: current,
          pets: state.equippedPets,
          mount: state.equippedMount,
        ),
        const SizedBox(height: 16),
        SegmentedButton<OptimizationMode>(
          segments: const [
            ButtonSegment(
                value: OptimizationMode.dps, label: Text('DPS')),
            ButtonSegment(
                value: OptimizationMode.lifestealPerSecond,
                label: Text('Lifesteal/sec')),
            ButtonSegment(
                value: OptimizationMode.balanced, label: Text('Both')),
          ],
          selected: {_metric},
          onSelectionChanged: (s) => setState(() => _metric = s.first),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            title: const Text('Current'),
            subtitle: Text(
              'DPS ${formatCompact(current.dps)}  -  '
              'Lifesteal/sec ${formatCompact(current.lifestealPerSecond)}',
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (moves.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: Text(
                'Add more pets or mounts to see projected upgrades.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final move in moves.take(15))
            _MoveTile(move: move, positive: move.delta > 0),
      ],
    );
  }
}

class _MoveTile extends StatelessWidget {
  const _MoveTile({required this.move, required this.positive});
  final _Move move;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = move.delta == 0
        ? theme.colorScheme.onSurfaceVariant
        : (positive ? MetricColors.lifesteal : theme.colorScheme.error);
    return Card(
      child: ListTile(
        leading: Icon(
          positive ? Icons.trending_up : Icons.trending_down,
          color: color,
        ),
        title: Text(move.label),
        subtitle: Text(
          'DPS ${formatCompact(move.result.dps)}  -  '
          'Lifesteal/sec ${formatCompact(move.result.lifestealPerSecond)}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          formatDelta(move.delta),
          style: theme.textTheme.titleSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}
