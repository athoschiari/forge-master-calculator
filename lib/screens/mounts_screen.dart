import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/mount.dart';
import '../state/app_state.dart';
import '../widgets/mount_card.dart';
import '../widgets/number_field.dart';
import '../widgets/substat_editor.dart';

enum _MountSort { damage, health }

/// Mount inventory: search, sort, add, edit, duplicate, delete and equip. Only
/// one mount is equipped at a time.
class MountsScreen extends StatefulWidget {
  const MountsScreen({super.key});

  @override
  State<MountsScreen> createState() => _MountsScreenState();
}

class _MountsScreenState extends State<MountsScreen> {
  String _query = '';
  _MountSort _sort = _MountSort.damage;

  List<Mount> _visible(List<Mount> mounts) {
    final q = _query.toLowerCase();
    final filtered = mounts.where((m) {
      if (q.isEmpty) return true;
      return m.rarity.label.toLowerCase().contains(q) ||
          m.substats.any((s) => s.type.label.toLowerCase().contains(q));
    }).toList();
    switch (_sort) {
      case _MountSort.damage:
        filtered.sort((a, b) => b.mainDamage.compareTo(a.mainDamage));
      case _MountSort.health:
        filtered.sort((a, b) => b.mainHealth.compareTo(a.mainHealth));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final mounts = _visible(state.mounts);
    final columns = MediaQuery.of(context).size.width > 900 ? 2 : 1;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, state, null),
        icon: const Icon(Icons.add),
        label: const Text('Add mount'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Mounts', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search substats or rarity',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<_MountSort>(
                value: _sort,
                onChanged: (v) => setState(() => _sort = v ?? _MountSort.damage),
                items: const [
                  DropdownMenuItem(value: _MountSort.damage, child: Text('Damage')),
                  DropdownMenuItem(value: _MountSort.health, child: Text('Health')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (mounts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  state.mounts.isEmpty
                      ? 'No mounts yet. Add mounts you own so the optimizer can pick from them.'
                      : 'No mounts match your search.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.9,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final mount in mounts)
                  MountCard(
                    mount: mount,
                    equipped: state.isMountEquipped(mount.id),
                    onToggleEquip: () => state.equipMount(mount.id),
                    onEdit: () => _edit(context, state, mount),
                    onDuplicate: () => state.duplicateMount(mount),
                    onDelete: () => state.deleteMount(mount.id),
                  ),
              ],
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, AppState state, Mount? mount) async {
    final result = await showDialog<Mount>(
      context: context,
      builder: (_) => _MountEditorDialog(mount: mount),
    );
    if (result == null) return;
    if (mount == null) {
      state.addMount(result);
    } else {
      state.updateMount(result);
    }
  }
}

class _MountEditorDialog extends StatefulWidget {
  const _MountEditorDialog({required this.mount});
  final Mount? mount;

  @override
  State<_MountEditorDialog> createState() => _MountEditorDialogState();
}

class _MountEditorDialogState extends State<_MountEditorDialog> {
  late Mount _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.mount ??
        Mount(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mount == null ? 'Add mount' : 'Edit mount'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Rarity>(
                      initialValue: _draft.rarity,
                      decoration: const InputDecoration(labelText: 'Rarity'),
                      items: [
                        for (final r in Rarity.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (r) => setState(
                          () => _draft = _draft.copyWith(rarity: r ?? _draft.rarity)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberField(
                      label: 'Level',
                      value: _draft.level.toDouble(),
                      allowShorthand: false,
                      onChanged: (v) =>
                          _draft = _draft.copyWith(level: v.round().clamp(1, 999).toInt()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NumberField(
                      label: 'Main Damage',
                      value: _draft.mainDamage,
                      onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(mainDamage: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberField(
                      label: 'Main Health',
                      value: _draft.mainHealth,
                      onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(mainHealth: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Substats (up to 2)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SubstatEditor(
                substats: _draft.substats,
                onChanged: (list) =>
                    setState(() => _draft = _draft.copyWith(substats: list)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _draft.copyWith(
              substats: _draft.substats.where((s) => s.value != 0).toList(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
