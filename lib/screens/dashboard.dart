import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/stat_card.dart';

/// Substats in the same order the spreadsheet lists them on Profile Comparison.
const List<SubstatType> _statOrder = [
  SubstatType.critChance,
  SubstatType.critDamage,
  SubstatType.blockChance,
  SubstatType.regen,
  SubstatType.lifesteal,
  SubstatType.doubleChance,
  SubstatType.damage,
  SubstatType.meleeDmg,
  SubstatType.rangedDmg,
  SubstatType.attackSpeed,
  SubstatType.health,
  SubstatType.skillDamage,
  SubstatType.skillCooldown,
];

/// Full build readout: the same detail as the spreadsheet's Profile Comparison
/// and Regenlifestealdps sheets — Build/Shown/Total damage and health, the
/// per-second output and recovery, and every aggregated stat.
class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.onNavigate});

  /// Called with a destination index to jump to another tab.
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final build = state.currentBuild;
    final theme = Theme.of(context);
    final wide = MediaQuery.of(context).size.width > 720;

    final damageCard = _SectionCard(
      title: 'Damage',
      trailing: state.config.weaponType.label,
      rows: [
        _Row('Build Damage', formatThousands(build.buildDamage)),
        _Row('Shown Damage',
            '${formatThousands(build.shownDamage)} (${formatSheetCompact(build.shownDamage)})'),
        _Row('Total Damage', formatThousands(build.totalDamage),
            accent: MetricColors.damage, emphasise: true),
      ],
    );

    final healthCard = _SectionCard(
      title: 'Health',
      rows: [
        _Row('Build Health', formatThousands(build.buildHealth)),
        _Row('Shown Health',
            '${formatThousands(build.shownHealth)} (${formatSheetCompact(build.shownHealth)})'),
        _Row('Total Health', formatThousands(build.totalHealth),
            accent: MetricColors.health, emphasise: true),
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dashboard', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${state.config.weaponType.label} build - '
          '${state.equippedPets.length}/${state.petSlots} pets, '
          '${state.equippedMount == null ? 'no mount' : 'mount equipped'}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: wide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.7,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            StatCard(
              label: 'Dmg / sec',
              value: formatCompact(build.dps),
              accent: MetricColors.dps,
              icon: Icons.bolt,
              sub: '${formatSeconds(build.attackInterval)} / attack',
            ),
            StatCard(
              label: 'Lifesteal HP / sec',
              value: formatCompact(build.lifestealPerSecond),
              accent: MetricColors.lifesteal,
              icon: Icons.favorite,
            ),
            StatCard(
              label: 'Heal / sec',
              value: formatCompact(build.healPerSecond),
              accent: MetricColors.lifesteal,
              icon: Icons.healing,
              sub: 'Lifesteal + regen',
            ),
            StatCard(
              label: 'Total Health',
              value: formatCompact(build.totalHealth),
              accent: MetricColors.health,
              icon: Icons.shield,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: damageCard),
              const SizedBox(width: 12),
              Expanded(child: healthCard),
            ],
          )
        else ...[
          damageCard,
          const SizedBox(height: 12),
          healthCard,
        ],
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Per second',
          rows: [
            _Row('Dmg / sec', formatThousands(build.dps, decimals: 2),
                accent: MetricColors.dps),
            _Row('Lifesteal HP / sec',
                formatThousands(build.lifestealPerSecond, decimals: 2),
                accent: MetricColors.lifesteal),
            _Row('Regen / sec', formatThousands(build.regenPerSecond, decimals: 2)),
            _Row('Heal / sec', formatThousands(build.healPerSecond, decimals: 2),
                accent: MetricColors.lifesteal, emphasise: true),
            _Row('Attacks / sec', build.attacksPerSecond.toStringAsFixed(2)),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Aggregated stats',
          rows: [
            for (final type in _statOrder)
              _Row(type.label,
                  formatStatValue(type, build.aggregate.sub(type))),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Loadout', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _LoadoutRow(
                  icon: Icons.pets,
                  label: 'Pets',
                  value: state.equippedPets.isEmpty
                      ? 'None equipped'
                      : state.equippedPets
                          .map(describePet)
                          .join('   |   '),
                ),
                const Divider(height: 24),
                _LoadoutRow(
                  icon: Icons.two_wheeler,
                  label: 'Mount',
                  value: state.equippedMount == null
                      ? 'None equipped'
                      : describePiece(
                          substats: state.equippedMount!.substats,
                          damage: state.equippedMount!.mainDamage,
                          health: state.equippedMount!.mainHealth),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => onNavigate(4),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Optimize'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => onNavigate(1),
              icon: const Icon(Icons.shield_moon),
              label: const Text('Edit gear'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => onNavigate(6),
              icon: const Icon(Icons.file_upload),
              label: const Text('Import spreadsheet'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => onNavigate(5),
              icon: const Icon(Icons.trending_up),
              label: const Text('Planner'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A label/value pair rendered as one line inside a [_SectionCard].
class _Row {
  const _Row(this.label, this.value, {this.accent, this.emphasise = false});
  final String label;
  final String value;
  final Color? accent;
  final bool emphasise;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows, this.trailing});

  final String title;
  final List<_Row> rows;
  final String? trailing;

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
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: (row.emphasise
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.bodyLarge)
                          ?.copyWith(
                        color: row.accent,
                        fontWeight:
                            row.emphasise ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadoutRow extends StatelessWidget {
  const _LoadoutRow({
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
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 64,
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
