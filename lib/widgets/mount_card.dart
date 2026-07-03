import 'package:flutter/material.dart';

import '../models/mount.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import 'substat_chips.dart';

/// Card for a mount in the inventory. A single mount can be equipped at a time.
class MountCard extends StatelessWidget {
  const MountCard({
    super.key,
    required this.mount,
    required this.equipped,
    required this.onToggleEquip,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Mount mount;
  final bool equipped;
  final VoidCallback onToggleEquip;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppTheme.rarityTint(theme.colorScheme, mount.rarity.color),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mount.rarity.label,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Level ${mount.level}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        onEdit();
                      case 'duplicate':
                        onDuplicate();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Main(label: 'DMG', value: mount.mainDamage),
                const SizedBox(width: 20),
                _Main(label: 'HP', value: mount.mainHealth),
              ],
            ),
            const SizedBox(height: 10),
            SubstatChips(substats: mount.substats),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                selected: equipped,
                onSelected: (_) => onToggleEquip(),
                avatar: Icon(
                  equipped ? Icons.check_circle : Icons.add_circle_outline,
                  size: 18,
                ),
                label: Text(equipped ? 'Equipped' : 'Equip'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Main extends StatelessWidget {
  const _Main({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          formatCompact(value),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
