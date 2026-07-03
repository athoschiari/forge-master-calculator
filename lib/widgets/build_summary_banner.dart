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
/// opens a detail dialog without cluttering the banner itself - just the
/// substat breakdown normally, or a current -> proposed comparison (every
/// row color-coded green/red for higher/lower) when the caller passes
/// [proposed] - the screen's suggested alternative build (the Optimizer's
/// best candidate for the selected mode, the Planner's top-ranked move).
class BuildSummaryBanner extends StatelessWidget {
  const BuildSummaryBanner({
    super.key,
    required this.result,
    required this.pets,
    required this.mount,
    this.proposed,
  });

  final BuildResult result;
  final List<Pet> pets;
  final Mount? mount;
  final BuildResult? proposed;

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
    final theme = Theme.of(context);
    final p = proposed;

    // Higher is green, lower is red - a plain magnitude comparison, not a
    // per-stat "is higher actually better" judgement (e.g. skill cooldown).
    Color deltaColor(double current, double next) {
      if (next > current) return MetricColors.lifesteal;
      if (next < current) return theme.colorScheme.error;
      return theme.colorScheme.onSurfaceVariant;
    }

    Widget row(String label, double current, double? next,
        String Function(double) fmt) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(fmt(current),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (next != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
              ),
              Text(
                fmt(next),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: deltaColor(current, next),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final substatTypes = [
      for (final type in substatDisplayOrder)
        if (result.aggregate.sub(type) != 0 ||
            (p?.aggregate.sub(type) ?? 0) != 0)
          type,
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(p == null ? 'Substats' : 'Current -> Proposed'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p != null) ...[
                  row('Shown Dmg', result.shownDamage, p.shownDamage,
                      formatSheetCompact),
                  row('Shown HP', result.shownHealth, p.shownHealth,
                      formatSheetCompact),
                  row('Calculated Dmg', result.totalDamage, p.totalDamage,
                      formatCompact),
                  row('Calculated HP', result.totalHealth, p.totalHealth,
                      formatCompact),
                  row('DPS', result.dps, p.dps, formatCompact),
                  row('Lifesteal/sec', result.lifestealPerSecond,
                      p.lifestealPerSecond, formatCompact),
                  row('Heal/sec', result.healPerSecond, p.healPerSecond,
                      formatCompact),
                  const Divider(height: 20),
                ],
                if (substatTypes.isEmpty)
                  const Text('No substats equipped.')
                else
                  for (final type in substatTypes)
                    row(
                      type.label,
                      result.aggregate.sub(type),
                      p?.aggregate.sub(type),
                      (v) => formatStatValue(type, v),
                    ),
              ],
            ),
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
