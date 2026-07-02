import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/pet.dart';
import '../models/stats.dart';
import '../state/app_state.dart';
import '../widgets/number_field.dart';
import '../widgets/pet_card.dart';
import '../widgets/substat_editor.dart';

enum _PetSort { damage, health }

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
    final columns = MediaQuery.of(context).size.width > 900 ? 2 : 1;

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
              DropdownButton<_PetSort>(
                value: _sort,
                onChanged: (v) => setState(() => _sort = v ?? _PetSort.damage),
                items: const [
                  DropdownMenuItem(value: _PetSort.damage, child: Text('Damage')),
                  DropdownMenuItem(value: _PetSort.health, child: Text('Health')),
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
              childAspectRatio: 1.9,
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
          onChanged: (r) => setState(() {
            row.rarity = r ?? row.rarity;
            row.applyPreset();
          }),
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
        width: 120,
        child: DropdownButtonFormField<PetType>(
          initialValue: row.type,
          isExpanded: true,
          items: [
            for (final t in PetType.values)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) => setState(() {
            row.type = t ?? row.type;
            row.applyPreset();
          }),
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
