import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/pet.dart';
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
