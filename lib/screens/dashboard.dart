import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/stats.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import '../widgets/stat_card.dart';

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aggregated stats', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                for (final type in substatDisplayOrder)
                  _StatRow(
                    type: type,
                    value: build.aggregate.sub(type),
                    breakdown: _breakdown(state, type),
                  ),
              ],
            ),
          ),
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
                          health: state.equippedMount!.mainHealth,
                          rarity: state.equippedMount!.rarity),
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

  /// Every equipped source (gear slots, pets, mount) that rolls [type],
  /// with just its contribution to that one stat - not its whole kit.
  List<_Contribution> _breakdown(AppState state, SubstatType type) {
    final list = <_Contribution>[];

    double contributionOf(List<Substat> substats) => substats
        .where((s) => s.type == type)
        .fold(0.0, (sum, s) => sum + s.value);

    for (final slot in GearSlot.values) {
      final piece = state.gearFor(slot);
      final v = contributionOf(piece.substats);
      if (v != 0) list.add(_Contribution(label: slot.label, value: v));
    }

    for (final pet in state.equippedPets) {
      final v = contributionOf(pet.substats);
      if (v != 0) {
        list.add(_Contribution(label: '${pet.type.label} pet', value: v));
      }
    }

    final mount = state.equippedMount;
    if (mount != null) {
      final v = contributionOf(mount.substats);
      if (v != 0) list.add(_Contribution(label: 'Mount', value: v));
    }

    return list;
  }
}

/// One source's contribution to a single substat total, e.g. Helmet -> +10%.
class _Contribution {
  const _Contribution({required this.label, required this.value});
  final String label;
  final double value;
}

/// A stat total that expands (tap to toggle) into which equipped pieces
/// contribute to it and by how much.
class _StatRow extends StatefulWidget {
  const _StatRow({
    required this.type,
    required this.value,
    required this.breakdown,
  });

  final SubstatType type;
  final double value;
  final List<_Contribution> breakdown;

  @override
  State<_StatRow> createState() => _StatRowState();
}

class _StatRowState extends State<_StatRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBreakdown = widget.breakdown.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasBreakdown
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: hasBreakdown
                      ? Icon(
                          _expanded ? Icons.expand_more : Icons.chevron_right,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    widget.type.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  formatStatValue(widget.type, widget.value),
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in widget.breakdown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(c.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                        ),
                        Text(
                          formatStatValue(widget.type, c.value),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
