import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/optimizer.dart';
import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/build_summary_banner.dart';

/// The optimizer. Evaluates every pet + mount combination over the current gear
/// and presents the best loadout for each of the three objectives:
///   1. Lifesteal/sec  2. DPS  3. Balanced (50/50 of the two)
/// The player can switch objective and equip any recommended combination.
class OptimizerScreen extends StatefulWidget {
  const OptimizerScreen({super.key});

  @override
  State<OptimizerScreen> createState() => _OptimizerScreenState();
}

class _OptimizerScreenState extends State<OptimizerScreen> {
  OptimizationMode _mode = OptimizationMode.balanced;

  Color _accent(OptimizationMode mode) {
    switch (mode) {
      case OptimizationMode.dps:
        return MetricColors.dps;
      case OptimizationMode.lifestealPerSecond:
        return MetricColors.lifesteal;
      case OptimizationMode.balanced:
        return MetricColors.balanced;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final output = state.runOptimizer();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Optimizer', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Best pet + mount loadout over your current gear. Choose what to '
          'optimise for.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        BuildSummaryBanner(
          result: state.currentBuild,
          pets: state.equippedPets,
          mount: state.equippedMount,
          proposed: output.isEmpty ? null : output.best[_mode]!.build,
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 8),
        Text(
          _mode.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (output.isEmpty)
          _EmptyState(state: state)
        else ...[
          _BestCard(
            candidate: output.best[_mode]!,
            mode: _mode,
            accent: _accent(_mode),
            onEquip: () {
              final best = output.best[_mode]!;
              state.setEquippedPets(best.pets.map((p) => p.id).toList());
              state.setEquippedMount(best.mount?.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Equipped the recommended loadout.')),
              );
            },
          ),
          const SizedBox(height: 20),
          Text('All combinations', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${output.candidates.length} evaluated, ranked by ${_mode.shortLabel}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ..._rankedRows(output, theme),
        ],
      ],
    );
  }

  List<Widget> _rankedRows(OptimizerOutput output, ThemeData theme) {
    final ranked = output.ranked(_mode).take(12).toList();
    return [
      for (var i = 0; i < ranked.length; i++)
        _RankRow(
          rank: i + 1,
          candidate: ranked[i],
          mode: _mode,
          accent: _accent(_mode),
        ),
    ];
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.pets, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Add some pets and mounts first',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The optimizer tries every combination of your pets and mounts. '
              'Add the ones you own on the Pets and Mounts tabs.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestCard extends StatelessWidget {
  const _BestCard({
    required this.candidate,
    required this.mode,
    required this.accent,
    required this.onEquip,
  });

  final BuildCandidate candidate;
  final OptimizationMode mode;
  final Color accent;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final build = candidate.build;
    final pets = candidate.pets.isEmpty
        ? 'No pets'
        : candidate.pets.map(describePet).join('   |   ');
    final mount = candidate.mount == null
        ? 'No mount'
        : describePiece(
            substats: candidate.mount!.substats,
            damage: candidate.mount!.mainDamage,
            health: candidate.mount!.mainHealth,
            rarity: candidate.mount!.rarity);

    return Card(
      color: accent.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: accent),
                const SizedBox(width: 8),
                Text(mode.label, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _Metric(
                  label: 'DPS',
                  value: formatCompact(build.dps),
                  highlight: mode == OptimizationMode.dps,
                  accent: MetricColors.dps,
                ),
                _Metric(
                  label: 'Lifesteal/sec',
                  value: formatCompact(build.lifestealPerSecond),
                  highlight: mode == OptimizationMode.lifestealPerSecond,
                  accent: MetricColors.lifesteal,
                ),
                _Metric(
                  label: 'Heal/sec',
                  value: formatCompact(build.healPerSecond),
                  highlight: false,
                  accent: MetricColors.lifesteal,
                ),
                _Metric(
                  label: 'Shown Dmg',
                  value: formatSheetCompact(build.shownDamage),
                  highlight: false,
                  accent: MetricColors.damage,
                ),
                _Metric(
                  label: 'Calculated Dmg',
                  value: formatCompact(build.totalDamage),
                  highlight: false,
                  accent: MetricColors.damage,
                ),
                _Metric(
                  label: 'Shown HP',
                  value: formatSheetCompact(build.shownHealth),
                  highlight: false,
                  accent: MetricColors.health,
                ),
                _Metric(
                  label: 'Calculated HP',
                  value: formatCompact(build.totalHealth),
                  highlight: false,
                  accent: MetricColors.health,
                ),
              ],
            ),
            const Divider(height: 28),
            _LoadoutLine(icon: Icons.pets, label: 'Pets', value: pets),
            const SizedBox(height: 6),
            _LoadoutLine(icon: Icons.two_wheeler, label: 'Mount', value: mount),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onEquip,
                icon: const Icon(Icons.check),
                label: const Text('Equip this combination'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.highlight,
    required this.accent,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: highlight ? accent : theme.colorScheme.onSurface,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LoadoutLine extends StatelessWidget {
  const _LoadoutLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(width: 52, child: Text(label, style: theme.textTheme.labelMedium)),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.candidate,
    required this.mode,
    required this.accent,
  });

  final int rank;
  final BuildCandidate candidate;
  final OptimizationMode mode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = mode == OptimizationMode.lifestealPerSecond
        ? formatCompact(candidate.lifestealPerSecond)
        : mode == OptimizationMode.dps
            ? formatCompact(candidate.dps)
            : '${(candidate.balancedScore * 100).toStringAsFixed(0)}%';
    final pets = candidate.pets.isEmpty
        ? 'No pets'
        : candidate.pets.map(describePet).join('   |   ');
    final mount = candidate.mount == null
        ? 'no mount'
        : describePiece(
            substats: candidate.mount!.substats,
            damage: candidate.mount!.mainDamage,
            health: candidate.mount!.mainHealth,
            rarity: candidate.mount!.rarity);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$rank', style: theme.textTheme.labelLarge),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$pets  -  $mount', style: theme.textTheme.bodyMedium),
                Text(
                  'DPS ${formatCompact(candidate.dps)}  -  '
                  'LS/s ${formatCompact(candidate.lifestealPerSecond)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            primary,
            style: theme.textTheme.titleSmall?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}
