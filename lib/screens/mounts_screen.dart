import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/item_screenshot_parser.dart';
import '../models/enums.dart';
import '../models/mount.dart';
import '../models/stats.dart';
import '../services/screenshot_import_flow.dart';
import '../state/app_state.dart';
import '../utils/platform_support.dart';
import '../widgets/mount_card.dart';
import '../widgets/number_field.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/substat_editor.dart';

enum _MountSort {
  damage,
  health;

  String get label => this == _MountSort.damage ? 'Damage' : 'Health';
}

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
    final width = MediaQuery.of(context).size.width;
    final columns = width > 1300 ? 3 : (width > 900 ? 2 : 1);

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
              SearchableDropdown<_MountSort>(
                value: _sort,
                width: 160,
                entries: [
                  for (final s in _MountSort.values)
                    DropdownMenuEntry(value: s, label: s.label),
                ],
                onChanged: (v) => setState(() => _sort = v),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _batchInsert(context, state),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Batch insert'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _massUpdate(context, state),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Mass update'),
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
              childAspectRatio: 2.6,
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
                    onImportScreenshot: isMobilePlatform
                        ? () => _importFromScreenshot(context, state, mount)
                        : null,
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

  Future<void> _massUpdate(BuildContext context, AppState state) async {
    final result = await showDialog<List<Mount>>(
      context: context,
      builder: (_) => _MountMassUpdateDialog(mounts: state.mounts),
    );
    if (result == null || result.isEmpty) return;
    state.updateMounts(result);
  }

  Future<void> _importFromScreenshot(
    BuildContext context,
    AppState state,
    Mount mount,
  ) async {
    final parsed = await ScreenshotImportFlow.run(context);
    if (parsed == null || !context.mounted) return;
    final result = await showDialog<Mount>(
      context: context,
      builder: (_) => _MountEditorDialog(mount: _mergeParsed(mount, parsed)),
    );
    if (result != null) state.updateMount(result);
  }

  /// Merges OCR-parsed fields onto an existing mount: only fields OCR
  /// actually recognised overwrite the existing values, matching this app's
  /// "0/empty = unset" convention rather than clobbering fields OCR missed.
  Mount _mergeParsed(Mount base, ParsedItemScreenshot p) => base.copyWith(
        level: p.level ?? base.level,
        mainDamage: p.mainDamage ?? base.mainDamage,
        mainHealth: p.mainHealth ?? base.mainHealth,
        substats: p.substats.isNotEmpty ? p.substats : base.substats,
        rarity: p.rarityRawLabel == null
            ? null
            : matchByLabel(Rarity.values, (r) => r.label, p.rarityRawLabel!),
      );
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
                    child: SearchableDropdown<Rarity>(
                      value: _draft.rarity,
                      label: const Text('Rarity'),
                      entries: [
                        for (final r in Rarity.values)
                          DropdownMenuEntry(value: r, label: r.label),
                      ],
                      onChanged: (r) =>
                          setState(() => _draft = _draft.copyWith(rarity: r)),
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

/// Filter-then-apply dialog: pick criteria (rarity, level, main damage, main
/// health — each skipped when left at its "any" value), then push a new Main
/// Damage and/or Main Health value to every mount that matches all set
/// criteria at once.
class _MountMassUpdateDialog extends StatefulWidget {
  const _MountMassUpdateDialog({required this.mounts});
  final List<Mount> mounts;

  @override
  State<_MountMassUpdateDialog> createState() =>
      _MountMassUpdateDialogState();
}

class _MountMassUpdateDialogState extends State<_MountMassUpdateDialog> {
  Rarity? _rarity;
  int _level = 0;
  double _mainDamage = 0;
  double _mainHealth = 0;

  double _newDamage = 0;
  double _newHealth = 0;

  List<Mount> _matches() => widget.mounts.where((m) {
        if (_rarity != null && m.rarity != _rarity) return false;
        if (_level > 0 && m.level != _level) return false;
        if (_mainDamage > 0 && m.mainDamage != _mainDamage) return false;
        if (_mainHealth > 0 && m.mainHealth != _mainHealth) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final matches = _matches();
    final canApply = matches.isNotEmpty && (_newDamage > 0 || _newHealth > 0);

    return AlertDialog(
      title: const Text('Mass update mounts'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SearchableDropdown<Rarity?>(
                      value: _rarity,
                      label: const Text('Rarity'),
                      entries: [
                        const DropdownMenuEntry(value: null, label: 'Any'),
                        for (final r in Rarity.values)
                          DropdownMenuEntry(value: r, label: r.label),
                      ],
                      onChanged: (r) => setState(() => _rarity = r),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberField(
                      label: 'Level (any if empty)',
                      value: _level.toDouble(),
                      allowShorthand: false,
                      onChanged: (v) => setState(
                          () => _level = v.round().clamp(0, 999).toInt()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NumberField(
                      label: 'Main Damage (any if empty)',
                      value: _mainDamage,
                      onChanged: (v) => setState(() => _mainDamage = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberField(
                      label: 'Main Health (any if empty)',
                      value: _mainHealth,
                      onChanged: (v) => setState(() => _mainHealth = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                  '${matches.length} mount${matches.length == 1 ? '' : 's'} match',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 16),
              Text('New values', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: NumberField(
                      label: 'Main Damage (leave empty to skip)',
                      value: _newDamage,
                      onChanged: (v) => setState(() => _newDamage = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberField(
                      label: 'Main Health (leave empty to skip)',
                      value: _newHealth,
                      onChanged: (v) => setState(() => _newHealth = v),
                    ),
                  ),
                ],
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
          onPressed: canApply
              ? () => Navigator.pop(
                    context,
                    [
                      for (final m in matches)
                        m.copyWith(
                          mainDamage: _newDamage > 0 ? _newDamage : null,
                          mainHealth: _newHealth > 0 ? _newHealth : null,
                        ),
                    ],
                  )
              : null,
          child: Text(
              'Apply to ${matches.length} mount${matches.length == 1 ? '' : 's'}'),
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
  final _vController = ScrollController();
  final _hController = ScrollController();

  void _addRow() => setState(() => _rows.add(_MountBatchRow()));

  void _removeRow(int index) => setState(() => _rows.removeAt(index));

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width - 48).clamp(0, 1200).toDouble();
    return Dialog(
      child: SizedBox(
        width: dialogWidth,
        height: size.height - 96,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Batch insert mounts', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: Scrollbar(
                  controller: _vController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _vController,
                    child: Scrollbar(
                      controller: _hController,
                      thumbVisibility: true,
                      notificationPredicate: (n) => n.depth == 0,
                      child: SingleChildScrollView(
                        controller: _hController,
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
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Add row'),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      [for (final r in _rows) r.toMount()],
                    ),
                    child: Text('Insert ${_rows.length}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(int i) {
    final row = _rows[i];
    return DataRow(key: ValueKey(row), cells: [
      DataCell(SearchableDropdown<Rarity>(
        value: row.rarity,
        width: 130,
        entries: [
          for (final r in Rarity.values)
            DropdownMenuEntry(value: r, label: r.label),
        ],
        onChanged: (r) => setState(() => row.rarity = r),
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
      DataCell(SearchableDropdown<SubstatType?>(
        value: row.sub1Type,
        width: 140,
        entries: [
          const DropdownMenuEntry(value: null, label: 'None'),
          for (final t in SubstatType.values)
            DropdownMenuEntry(value: t, label: t.label),
        ],
        onChanged: (t) => setState(() => row.sub1Type = t),
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
      DataCell(SearchableDropdown<SubstatType?>(
        value: row.sub2Type,
        width: 140,
        entries: [
          const DropdownMenuEntry(value: null, label: 'None'),
          for (final t in SubstatType.values)
            DropdownMenuEntry(value: t, label: t.label),
        ],
        onChanged: (t) => setState(() => row.sub2Type = t),
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
