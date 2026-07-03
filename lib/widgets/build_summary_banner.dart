import 'package:flutter/material.dart';

import '../models/build.dart';
import '../models/mount.dart';
import '../models/pet.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';

/// "Current build at a glance" banner shown atop the Planner and Optimizer
/// screens, so both stay anchored to what's actually equipped right now
/// while they suggest changes to it: shown/calculated Damage and Health,
/// per-second output, and the currently equipped pets/mount. The (i) icon
/// opens the full substat breakdown without cluttering the banner itself.
class BuildSummaryBanner extends StatelessWidget {
  const BuildSummaryBanner({
    super.key,
    required this.result,
    required this.pets,
    required this.mount,
  });

  final BuildResult result;
  final List<Pet> pets;
  final Mount? mount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Current build', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Substat breakdown',
                  icon: const Icon(Icons.info_outline, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showSubstats(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _Stat(
                  label: 'Shown Dmg',
                  value: formatSheetCompact(result.shownDamage),
                  accent: MetricColors.damage,
                ),
                _Stat(
                  label: 'Shown HP',
                  value: formatSheetCompact(result.shownHealth),
                  accent: MetricColors.health,
                ),
                _Stat(
                  label: 'Calculated Dmg',
                  value: formatCompact(result.totalDamage),
                  accent: MetricColors.damage,
                ),
                _Stat(
                  label: 'Calculated HP',
                  value: formatCompact(result.totalHealth),
                  accent: MetricColors.health,
                ),
                _Stat(
                  label: 'DPS',
                  value: formatCompact(result.dps),
                  accent: MetricColors.dps,
                ),
                _Stat(
                  label: 'Lifesteal/sec',
                  value: formatCompact(result.lifestealPerSecond),
                  accent: MetricColors.lifesteal,
                ),
                _Stat(
                  label: 'Heal/sec',
                  value: formatCompact(result.healPerSecond),
                  accent: MetricColors.lifesteal,
                ),
              ],
            ),
            const Divider(height: 24),
            _LoadoutLine(
              icon: Icons.pets,
              label: 'Pets',
              value: pets.isEmpty
                  ? 'None equipped'
                  : pets.map(describePet).join('   |   '),
            ),
            const SizedBox(height: 6),
            _LoadoutLine(
              icon: Icons.two_wheeler,
              label: 'Mount',
              value: mount == null
                  ? 'None equipped'
                  : describePiece(
                      substats: mount!.substats,
                      damage: mount!.mainDamage,
                      health: mount!.mainHealth),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubstats(BuildContext context) {
    final entries = [
      for (final type in substatDisplayOrder)
        if (result.aggregate.sub(type) != 0) type,
    ];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Substats'),
        content: SizedBox(
          width: 320,
          child: entries.isEmpty
              ? const Text('No substats equipped.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final type in entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(type.label)),
                            Text(
                              formatStatValue(
                                  type, result.aggregate.sub(type)),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
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
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: accent, fontWeight: FontWeight.bold),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(width: 52, child: Text(label, style: theme.textTheme.labelMedium)),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
