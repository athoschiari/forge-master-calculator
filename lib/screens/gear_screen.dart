import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/item_screenshot_parser.dart';
import '../models/enums.dart';
import '../models/gear.dart';
import '../models/stats.dart';
import '../services/screenshot_import_flow.dart';
import '../state/app_state.dart';
import '../utils/platform_support.dart';
import '../widgets/gear_card.dart';
import '../widgets/number_field.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/substat_editor.dart';
import 'comparison_screen.dart';

/// Shows the four current gear pieces. Tapping a card edits that slot; a piece
/// is overwritten in place (there is no gear inventory). A compare action opens
/// the candidate comparison for a slot.
class GearScreen extends StatelessWidget {
  const GearScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final columns = width > 1300 ? 3 : (width > 900 ? 2 : 1);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Current Gear', style: theme.textTheme.headlineSmall),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => _pickSlotToCompare(context, state),
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Compare candidate'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final slot in GearSlot.values)
              GearCard(
                piece: state.gearFor(slot),
                onEdit: () => _editPiece(context, state, slot),
                onImportScreenshot: isMobilePlatform
                    ? () => _importFromScreenshot(context, state, slot)
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  void _pickSlotToCompare(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Compare a candidate for which slot?')),
            for (final slot in GearSlot.values)
              ListTile(
                leading: const Icon(Icons.shield),
                title: Text(slot.label),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ComparisonScreen(slot: slot),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPiece(
    BuildContext context,
    AppState state,
    GearSlot slot,
  ) async {
    final result = await showDialog<GearPiece>(
      context: context,
      builder: (_) => _GearEditorDialog(piece: state.gearFor(slot)),
    );
    if (result != null) state.setGear(slot, result);
  }

  Future<void> _importFromScreenshot(
    BuildContext context,
    AppState state,
    GearSlot slot,
  ) async {
    final parsed = await ScreenshotImportFlow.run(context);
    if (parsed == null || !context.mounted) return;
    final seeded = _mergeParsed(state.gearFor(slot), parsed);
    final result = await showDialog<GearPiece>(
      context: context,
      builder: (_) => _GearEditorDialog(piece: seeded),
    );
    if (result != null) state.setGear(slot, result);
  }

  /// Merges OCR-parsed fields onto an existing gear piece: only fields OCR
  /// actually recognised overwrite the existing values, matching this app's
  /// "0/empty = unset" convention rather than clobbering fields OCR missed.
  GearPiece _mergeParsed(GearPiece base, ParsedItemScreenshot p) =>
      base.copyWith(
        mainDamage: p.mainDamage ?? base.mainDamage,
        mainHealth: p.mainHealth ?? base.mainHealth,
        substats: p.substats.isNotEmpty ? p.substats : base.substats,
        rarity: p.rarityRawLabel == null
            ? null
            : matchByLabel(GearRarity.values, (r) => r.label, p.rarityRawLabel!),
      );
}

class _GearEditorDialog extends StatefulWidget {
  const _GearEditorDialog({required this.piece});
  final GearPiece piece;

  @override
  State<_GearEditorDialog> createState() => _GearEditorDialogState();
}

class _GearEditorDialogState extends State<_GearEditorDialog> {
  late GearPiece _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.piece;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${_draft.slot.label}'),
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
                    child: NumberField(
                      label: 'Main Damage',
                      value: _draft.mainDamage,
                      onChanged: (v) =>
                          setState(() => _draft = _draft.copyWith(mainDamage: v)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberField(
                      label: 'Main Health',
                      value: _draft.mainHealth,
                      onChanged: (v) =>
                          setState(() => _draft = _draft.copyWith(mainHealth: v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SearchableDropdown<GearRarity>(
                      value: _draft.rarity,
                      label: const Text('Rarity'),
                      entries: [
                        for (final r in GearRarity.values)
                          DropdownMenuEntry(value: r, label: r.label),
                      ],
                      onChanged: (r) =>
                          setState(() => _draft = _draft.copyWith(rarity: r)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberField(
                      label: 'Forge level',
                      value: _draft.forgeLevel.toDouble(),
                      allowShorthand: false,
                      onChanged: (v) => setState(() => _draft = _draft.copyWith(
                          forgeLevel: v.round().clamp(0, 100).toInt())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Substats (up to 2)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
              substats: _clean(_draft.substats),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  List<Substat> _clean(List<Substat> subs) =>
      subs.where((s) => s.value != 0).toList();
}
