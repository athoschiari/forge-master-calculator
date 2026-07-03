import 'package:flutter/material.dart';

import '../models/gear.dart';
import '../theme/app_theme.dart';
import '../utils/formatting.dart';
import 'substat_chips.dart';

/// Card summarising the piece in one gear slot, with an edit action.
class GearCard extends StatelessWidget {
  const GearCard({super.key, required this.piece, required this.onEdit});

  final GearPiece piece;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = piece.mainDamage > 0 ||
        piece.mainHealth > 0 ||
        piece.substats.isNotEmpty;
    return Card(
      color: AppTheme.rarityTint(theme.colorScheme, piece.rarity.color),
      child: InkWell(
        onTap: onEdit,
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
                          piece.slot.label,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          piece.rarity.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (piece.forgeLevel > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        '+${piece.forgeLevel}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  const Icon(Icons.edit, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              if (hasContent) ...[
                Row(
                  children: [
                    _Main(label: 'DMG', value: piece.mainDamage),
                    const SizedBox(width: 20),
                    _Main(label: 'HP', value: piece.mainHealth),
                  ],
                ),
                const SizedBox(height: 10),
                SubstatChips(substats: piece.substats),
              ] else
                Text(
                  'Empty - tap to set up',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
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
