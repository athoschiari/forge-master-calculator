import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/mount.dart';
import '../models/stats.dart';
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
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _batchInsert(context, state),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Batch insert'),
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

  Future<void> _batchInsert(BuildContext context, AppState state) async {
    final result = await showDialog<List<Mount>>(
      context: context,
      builder: (_) => const _MountBatchInsertDialog(),
    );
    if (result == null || result.isEmpty) return;
    state.addMounts(result);
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

/// One row of the batch insert table: everything needed to build a [Mount].
class _MountBatchRow {
  Rarity rarity = Rarity.common;
  int level = 1;
  double mainDamage = 0;
  double mainHealth = 0;
  SubstatType? sub1Type;
  double sub1Value = 0;
  SubstatType? sub2Type;
  double sub2Value = 0;

  Mount toMount() => Mount(
        id: '',
        rarity: rarity,
        level: level,
        mainDamage: mainDamage,
        mainHealth: mainHealth,
        substats: [
          if (sub1Type != null) Substat(type: sub1Type!, value: sub1Value),
          if (sub2Type != null) Substat(type: sub2Type!, value: sub2Value),
        ],
      );
}

/// Table-based batch insert: one row per mount, one column per option. Used
/// instead of a file import so pasted/typed rows can be reviewed before adding
/// them all to the inventory at once.
class _MountBatchInsertDialog extends StatefulWidget {
  const _MountBatchInsertDialog();

  @override
  State<_MountBatchInsertDialog> createState() =>
      _MountBatchInsertDialogState();
}

class _MountBatchInsertDialogState extends State<_MountBatchInsertDialog> {
  final List<_MountBatchRow> _rows = [_MountBatchRow()];

  void _addRow() => setState(() => _rows.add(_MountBatchRow()));

  void _removeRow(int index) => setState(() => _rows.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Batch insert mounts'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12,
                  columns: const [
                    DataColumn(label: Text('Rarity')),
                    DataColumn(label: Text('Level')),
                    DataColumn(label: Text('Main Damage')),
                    DataColumn(label: Text('Main Health')),
                    DataColumn(label: Text('Substat 1')),
                    DataColumn(label: Text('Value')),
                    DataColumn(label: Text('Substat 2')),
                    DataColumn(label: Text('Value')),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (var i = 0; i < _rows.length; i++) _buildRow(i),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Add row'),
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
            [for (final r in _rows) r.toMount()],
          ),
          child: Text('Insert ${_rows.length}'),
        ),
      ],
    );
  }

  DataRow _buildRow(int i) {
    final row = _rows[i];
    return DataRow(cells: [
      DataCell(SizedBox(
        width: 120,
        child: DropdownButtonFormField<Rarity>(
          initialValue: row.rarity,
          isExpanded: true,
          items: [
            for (final r in Rarity.values)
              DropdownMenuItem(value: r, child: Text(r.label)),
          ],
          onChanged: (r) => setState(() => row.rarity = r ?? row.rarity),
        ),
      )),
      DataCell(SizedBox(
        width: 70,
        child: NumberField(
          label: '',
          value: row.level.toDouble(),
          allowShorthand: false,
          onChanged: (v) => row.level = v.round().clamp(1, 999).toInt(),
        ),
      )),
      DataCell(SizedBox(
        width: 100,
        child: NumberField(
          label: '',
          value: row.mainDamage,
          onChanged: (v) => row.mainDamage = v,
        ),
      )),
      DataCell(SizedBox(
        width: 100,
        child: NumberField(
          label: '',
          value: row.mainHealth,
          onChanged: (v) => row.mainHealth = v,
        ),
      )),
      DataCell(SizedBox(
        width: 130,
        child: DropdownButtonFormField<SubstatType?>(
          initialValue: row.sub1Type,
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final t in SubstatType.values)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) => setState(() => row.sub1Type = t),
        ),
      )),
      DataCell(SizedBox(
        width: 80,
        child: NumberField(
          label: '',
          value: row.sub1Value,
          allowShorthand: false,
          suffix: row.sub1Type?.isPercent ?? false ? '%' : null,
          onChanged: (v) => row.sub1Value = v,
        ),
      )),
      DataCell(SizedBox(
        width: 130,
        child: DropdownButtonFormField<SubstatType?>(
          initialValue: row.sub2Type,
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final t in SubstatType.values)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) => setState(() => row.sub2Type = t),
        ),
      )),
      DataCell(SizedBox(
        width: 80,
        child: NumberField(
          label: '',
          value: row.sub2Value,
          allowShorthand: false,
          suffix: row.sub2Type?.isPercent ?? false ? '%' : null,
          onChanged: (v) => row.sub2Value = v,
        ),
      )),
      DataCell(IconButton(
        icon: const Icon(Icons.close),
        onPressed: _rows.length > 1 ? () => _removeRow(i) : null,
      )),
    ]);
  }
}
