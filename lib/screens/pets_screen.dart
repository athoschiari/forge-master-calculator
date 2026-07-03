import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/item_screenshot_parser.dart';
import '../models/enums.dart';
import '../models/pet.dart';
import '../models/stats.dart';
import '../services/screenshot_import_flow.dart';
import '../state/app_state.dart';
import '../utils/platform_support.dart';
import '../widgets/number_field.dart';
import '../widgets/pet_card.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/substat_editor.dart';

enum _PetSort {
  damage,
  health;

  String get label => this == _PetSort.damage ? 'Damage' : 'Health';
}

/// Pet inventory: search, sort, add, edit, duplicate, delete and equip.
class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  String _query = '';
  _PetSort _sort = _PetSort.damage;

  List<Pet> _visible(List<Pet> pets) {
    final q = _query.toLowerCase();
    final filtered = pets.where((p) {
      if (q.isEmpty) return true;
      return p.type.label.toLowerCase().contains(q) ||
          p.rarity.label.toLowerCase().contains(q) ||
          p.substats.any((s) => s.type.label.toLowerCase().contains(q));
    }).toList();
    switch (_sort) {
      case _PetSort.damage:
        filtered.sort((a, b) => b.mainDamage.compareTo(a.mainDamage));
      case _PetSort.health:
        filtered.sort((a, b) => b.mainHealth.compareTo(a.mainHealth));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final pets = _visible(state.pets);
    final width = MediaQuery.of(context).size.width;
    final columns = width > 1300 ? 3 : (width > 900 ? 2 : 1);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, state, null),
        icon: const Icon(Icons.add),
        label: const Text('Add pet'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Pets', style: theme.textTheme.headlineSmall),
              const Spacer(),
              Text('${state.equippedPets.length}/${state.petSlots} equipped',
                  style: theme.textTheme.labelLarge),
            ],
          ),
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
              SearchableDropdown<_PetSort>(
                value: _sort,
                width: 160,
                entries: [
                  for (final s in _PetSort.values)
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
          if (pets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  state.pets.isEmpty
                      ? 'No pets yet. Add pets you own so the optimizer can pick from them.'
                      : 'No pets match your search.',
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
                for (final pet in pets)
                  PetCard(
                    pet: pet,
                    equipped: state.isPetEquipped(pet.id),
                    onToggleEquip: () => state.togglePetEquipped(pet.id),
                    onEdit: () => _edit(context, state, pet),
                    onDuplicate: () => state.duplicatePet(pet),
                    onDelete: () => state.deletePet(pet.id),
                    onImportScreenshot: isMobilePlatform
                        ? () => _importFromScreenshot(context, state, pet)
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
    final result = await showDialog<List<Pet>>(
      context: context,
      builder: (_) => const _PetBatchInsertDialog(),
    );
    if (result == null || result.isEmpty) return;
    state.addPets(result);
  }

  Future<void> _edit(BuildContext context, AppState state, Pet? pet) async {
    final result = await showDialog<Pet>(
      context: context,
      builder: (_) => _PetEditorDialog(pet: pet),
    );
    if (result == null) return;
    if (pet == null) {
      state.addPet(result);
    } else {
      state.updatePet(result);
    }
  }

  Future<void> _massUpdate(BuildContext context, AppState state) async {
    final result = await showDialog<List<Pet>>(
      context: context,
      builder: (_) => _PetMassUpdateDialog(pets: state.pets),
    );
    if (result == null || result.isEmpty) return;
    state.updatePets(result);
  }

  Future<void> _importFromScreenshot(
    BuildContext context,
    AppState state,
    Pet pet,
  ) async {
    final parsed = await ScreenshotImportFlow.run(context);
    if (parsed == null || !context.mounted) return;
    final result = await showDialog<Pet>(
      context: context,
      builder: (_) => _PetEditorDialog(pet: _mergeParsed(pet, parsed)),
    );
    if (result != null) state.updatePet(result);
  }

  /// Merges OCR-parsed fields onto an existing pet: only fields OCR actually
  /// recognised overwrite the existing values, matching this app's
  /// "0/empty = unset" convention rather than clobbering fields OCR missed.
  Pet _mergeParsed(Pet base, ParsedItemScreenshot p) => base.copyWith(
        level: p.level ?? base.level,
        mainDamage: p.mainDamage ?? base.mainDamage,
        mainHealth: p.mainHealth ?? base.mainHealth,
        substats: p.substats.isNotEmpty ? p.substats : base.substats,
        rarity: p.rarityRawLabel == null
            ? null
            : matchByLabel(Rarity.values, (r) => r.label, p.rarityRawLabel!),
      );
}

class _PetEditorDialog extends StatefulWidget {
  const _PetEditorDialog({required this.pet});
  final Pet? pet;

  @override
  State<_PetEditorDialog> createState() => _PetEditorDialogState();
}

class _PetEditorDialogState extends State<_PetEditorDialog> {
  late Pet _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.pet ??
        Pet(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.pet == null ? 'Add pet' : 'Edit pet'),
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Type', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 6),
              SegmentedButton<PetType>(
                segments: const [
                  ButtonSegment(value: PetType.attack, label: Text('Attack')),
                  ButtonSegment(value: PetType.balanced, label: Text('Balanced')),
                  ButtonSegment(value: PetType.health, label: Text('Health')),
                ],
                selected: {_draft.type},
                onSelectionChanged: (s) =>
                    setState(() => _draft = _draft.copyWith(type: s.first)),
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

/// Filter-then-apply dialog: pick criteria (rarity, type, level, main damage,
/// main health — each skipped when left at its "any" value), then push a new
/// Main Damage and/or Main Health value to every pet that matches all set
/// criteria at once.
class _PetMassUpdateDialog extends StatefulWidget {
  const _PetMassUpdateDialog({required this.pets});
  final List<Pet> pets;

  @override
  State<_PetMassUpdateDialog> createState() => _PetMassUpdateDialogState();
}

class _PetMassUpdateDialogState extends State<_PetMassUpdateDialog> {
  Rarity? _rarity;
  PetType? _type;
  int _level = 0;
  double _mainDamage = 0;
  double _mainHealth = 0;

  double _newDamage = 0;
  double _newHealth = 0;

  List<Pet> _matches() => widget.pets.where((p) {
        if (_rarity != null && p.rarity != _rarity) return false;
        if (_type != null && p.type != _type) return false;
        if (_level > 0 && p.level != _level) return false;
        if (_mainDamage > 0 && p.mainDamage != _mainDamage) return false;
        if (_mainHealth > 0 && p.mainHealth != _mainHealth) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final matches = _matches();
    final canApply = matches.isNotEmpty && (_newDamage > 0 || _newHealth > 0);

    return AlertDialog(
      title: const Text('Mass update pets'),
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
                    child: SearchableDropdown<PetType?>(
                      value: _type,
                      label: const Text('Type'),
                      entries: [
                        const DropdownMenuEntry(value: null, label: 'Any'),
                        for (final t in PetType.values)
                          DropdownMenuEntry(value: t, label: t.label),
                      ],
                      onChanged: (t) => setState(() => _type = t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              NumberField(
                label: 'Level (any if empty)',
                value: _level.toDouble(),
                allowShorthand: false,
                onChanged: (v) =>
                    setState(() => _level = v.round().clamp(0, 999).toInt()),
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
              Text('${matches.length} pet${matches.length == 1 ? '' : 's'} match',
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
                      for (final p in matches)
                        p.copyWith(
                          mainDamage: _newDamage > 0 ? _newDamage : null,
                          mainHealth: _newHealth > 0 ? _newHealth : null,
                        ),
                    ],
                  )
              : null,
          child: Text('Apply to ${matches.length} pet${matches.length == 1 ? '' : 's'}'),
        ),
      ],
    );
  }
}

/// One row of the batch insert table: everything needed to build a [Pet].
class _PetBatchRow {
  Rarity rarity = Rarity.common;
  int level = 1;
  PetType type = PetType.balanced;
  double mainDamage = 0;
  double mainHealth = 0;
  SubstatType? sub1Type;
  double sub1Value = 0;
  SubstatType? sub2Type;
  double sub2Value = 0;

  /// Fills in the known base stats for combinations the game always rolls the
  /// same way, so the user only has to pick rarity + type.
  void applyPreset() {
    if (rarity == Rarity.legendary && type == PetType.attack) {
      mainDamage = 234000;
      mainHealth = 624000;
    } else if (rarity == Rarity.legendary && type == PetType.health) {
      mainDamage = 156000;
      mainHealth = 1240000;
    }
  }

  Pet toPet() => Pet(
        id: '',
        type: type,
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

/// Table-based batch insert: one row per pet, one column per option. Used
/// instead of a file import so pasted/typed rows can be reviewed before adding
/// them all to the inventory at once.
class _PetBatchInsertDialog extends StatefulWidget {
  const _PetBatchInsertDialog();

  @override
  State<_PetBatchInsertDialog> createState() => _PetBatchInsertDialogState();
}

class _PetBatchInsertDialogState extends State<_PetBatchInsertDialog> {
  final List<_PetBatchRow> _rows = [_PetBatchRow()];
  final _vController = ScrollController();
  final _hController = ScrollController();

  void _addRow() => setState(() => _rows.add(_PetBatchRow()));

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
              Text('Batch insert pets', style: Theme.of(context).textTheme.titleLarge),
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
                            DataColumn(label: Text('Type')),
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
                      [for (final r in _rows) r.toPet()],
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
        onChanged: (r) => setState(() {
          row.rarity = r;
          row.applyPreset();
        }),
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
      DataCell(SearchableDropdown<PetType>(
        value: row.type,
        width: 130,
        entries: [
          for (final t in PetType.values)
            DropdownMenuEntry(value: t, label: t.label),
        ],
        onChanged: (t) => setState(() {
          row.type = t;
          row.applyPreset();
        }),
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
