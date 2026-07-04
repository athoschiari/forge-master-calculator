import 'package:flutter/material.dart';

import '../models/build.dart';
import '../models/mount.dart';
import '../models/pet.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';

/// "Current build at a glance" banner shown atop the Planner, Optimizer and
/// Best in Slot screens, so each stays anchored to what's actually equipped
/// right now while it suggests changes to it: shown/calculated Damage and
/// Health, per-second output, and the currently equipped pets/mount. When the
/// caller passes [proposed] - the screen's suggested alternative build (the
/// Optimizer's best candidate for the selected mode, the Planner's top-ranked
/// move, the Best in Slot screen's ceiling for the chosen objective) - a
/// current -> proposed comparison becomes available, every row color-coded
/// green/red for higher/lower. By default that comparison sits behind an (i)
/// icon so it doesn't clutter the banner; pass [inlineComparison] true (Best
/// in Slot: the comparison *is* the screen's main content, not a detail worth
/// hiding) to render it directly in the card instead, with no (i) icon.
class BuildSummaryBanner extends StatelessWidget {
  const BuildSummaryBanner({
    super.key,
    required this.result,
    required this.pets,
    required this.mount,
    this.proposed,
    this.inlineComparison = false,
  });

  final BuildResult result;
  final List<Pet> pets;
  final Mount? mount;
  final BuildResult? proposed;
  final bool inlineComparison;

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
                if (!inlineComparison)
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
                _Stat(
                  label: 'Shown Dmg',
                  value: formatSheetCompact(result.shownDamage),
                  accent: MetricColors.damage,
                ),
                _Stat(
                  label: 'Calculated Dmg',
                  value: formatCompact(result.totalDamage),
                  accent: MetricColors.damage,
                ),
                _Stat(
                  label: 'Shown HP',
                  value: formatSheetCompact(result.shownHealth),
                  accent: MetricColors.health,
                ),
                _Stat(
                  label: 'Calculated HP',
                  value: formatCompact(result.totalHealth),
                  accent: MetricColors.health,
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
                      health: mount!.mainHealth,
                      rarity: mount!.rarity),
            ),
            if (inlineComparison) ...[
              const Divider(height: 24),
              Text(
                proposed == null ? 'Substats' : 'Current -> Proposed',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              ..._comparisonRows(context),
            ],
          ],
        ),
      ),
    );
  }

  // Higher is green, lower is red - a plain magnitude comparison, not a
  // per-stat "is higher actually better" judgement (e.g. skill cooldown).
  Color _deltaColor(BuildContext context, double current, double next) {
    final theme = Theme.of(context);
    if (next > current) return MetricColors.lifesteal;
    if (next < current) return theme.colorScheme.error;
    return theme.colorScheme.onSurfaceVariant;
  }

  Widget _row(BuildContext context, String label, double current,
      double? next, String Function(double) fmt) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(fmt(current), style: const TextStyle(fontWeight: FontWeight.w600)),
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
                color: _deltaColor(context, current, next),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shown/calculated/per-second summary rows plus every non-zero substat,
  /// each current -> proposed (or just current, with no [proposed] set) -
  /// shared by the (i) dialog and [inlineComparison] so the two stay in sync.
  List<Widget> _comparisonRows(BuildContext context) {
    final p = proposed;
    final substatTypes = [
      for (final type in substatDisplayOrder)
        if (result.aggregate.sub(type) != 0 ||
            (p?.aggregate.sub(type) ?? 0) != 0)
          type,
    ];

    return [
      if (p != null) ...[
        _row(context, 'DPS', result.dps, p.dps, formatCompact),
        _row(context, 'Lifesteal/sec', result.lifestealPerSecond,
            p.lifestealPerSecond, formatCompact),
        _row(context, 'Heal/sec', result.healPerSecond, p.healPerSecond,
            formatCompact),
        _row(context, 'Shown Dmg', result.shownDamage, p.shownDamage,
            formatSheetCompact),
        _row(context, 'Calculated Dmg', result.totalDamage, p.totalDamage,
            formatCompact),
        _row(context, 'Shown HP', result.shownHealth, p.shownHealth,
            formatSheetCompact),
        _row(context, 'Calculated HP', result.totalHealth, p.totalHealth,
            formatCompact),
        const Divider(height: 20),
      ],
      if (substatTypes.isEmpty)
        const Text('No substats equipped.')
      else
        for (final type in substatTypes)
          _row(
            context,
            type.label,
            result.aggregate.sub(type),
            p?.aggregate.sub(type),
            (v) => formatStatValue(type, v),
          ),
    ];
  }

  void _showSubstats(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(proposed == null ? 'Substats' : 'Current -> Proposed'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _comparisonRows(context),
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
