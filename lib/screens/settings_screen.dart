import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/spreadsheet_import.dart';
import '../models/enums.dart';
import '../state/app_state.dart';
import '../widgets/number_field.dart';

/// Edits the profile-level config (the spreadsheet "Skills" block) and the
/// number of equipped pet slots the optimizer fills.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final config = state.config;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.file_upload, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Import from spreadsheet',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Load a profile straight from the master calculator .xlsx. '
                  'This overwrites your current gear and config, and adds the '
                  "profile's pets and mount to your inventory.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _importFlow(context, state),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose .xlsx file'),
                  ),
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
                Row(
                  children: [
                    Icon(Icons.sync_alt, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Backup / transfer', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Export everything (gear, pets, mounts, config) to a .json '
                  'file, then import it on another device to carry your data '
                  'over.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _exportFlow(context, state),
                      icon: const Icon(Icons.download),
                      label: const Text('Export to .json'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _importAllFlow(context, state),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import .json'),
                    ),
                  ],
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
                Text('Skills / global bonuses', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Flat base Damage and Health and the global Damage%/Health% '
                  'from your skills, applied to every build.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: NumberField(
                        label: 'Base Damage',
                        value: config.baseDamage,
                        onChanged: (v) =>
                            state.setConfig(config.copyWith(baseDamage: v)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NumberField(
                        label: 'Base Health',
                        value: config.baseHealth,
                        onChanged: (v) =>
                            state.setConfig(config.copyWith(baseHealth: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: NumberField(
                        label: 'Damage %',
                        value: config.globalDamagePct,
                        allowShorthand: false,
                        suffix: '%',
                        onChanged: (v) =>
                            state.setConfig(config.copyWith(globalDamagePct: v)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NumberField(
                        label: 'Health %',
                        value: config.globalHealthPct,
                        allowShorthand: false,
                        suffix: '%',
                        onChanged: (v) =>
                            state.setConfig(config.copyWith(globalHealthPct: v)),
                      ),
                    ),
                  ],
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
                Text('Weapon type', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Chooses whether Melee Dmg or Ranged Dmg substats apply.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<WeaponType>(
                  segments: const [
                    ButtonSegment(value: WeaponType.melee, label: Text('Melee')),
                    ButtonSegment(value: WeaponType.ranged, label: Text('Ranged')),
                  ],
                  selected: {config.weaponType},
                  onSelectionChanged: (s) =>
                      state.setConfig(config.copyWith(weaponType: s.first)),
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
                Text('Equipped pet slots', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'How many pets you can equip at once. The optimizer fills '
                  'this many slots. The spreadsheet uses 3.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('$_min', style: theme.textTheme.labelMedium),
                    Expanded(
                      child: Slider(
                        value: state.petSlots.toDouble(),
                        min: _min.toDouble(),
                        max: _max.toDouble(),
                        divisions: _max - _min,
                        label: '${state.petSlots}',
                        onChanged: (v) => state.setPetSlots(v.round()),
                      ),
                    ),
                    Text('$_max', style: theme.textTheme.labelMedium),
                    const SizedBox(width: 8),
                    Text('${state.petSlots} slots',
                        style: theme.textTheme.titleSmall),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const int _min = 1;
  static const int _max = 6;

  Future<void> _importFlow(BuildContext context, AppState state) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (picked == null) return; // cancelled

    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      if (context.mounted) _snack(context, 'Could not read that file.');
      return;
    }
    if (!context.mounted) return;

    final profile = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Which profile?'),
        content: const Text('Pick the profile to import from the workbook.'),
        actions: [
          for (final n in SpreadsheetImporter.availableProfiles)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, n),
              child: Text('Profile $n'),
            ),
        ],
      ),
    );
    if (profile == null || !context.mounted) return;

    try {
      final imported = SpreadsheetImporter.parse(bytes, profile);
      state.applyImport(imported);
      if (context.mounted) _snack(context, 'Imported Profile $profile.');
    } on SpreadsheetImportException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (e) {
      if (context.mounted) _snack(context, 'Import failed: $e');
    }
  }

  Future<void> _exportFlow(BuildContext context, AppState state) async {
    final json = const JsonEncoder.withIndent('  ').convert(state.exportAll());
    final bytes = Uint8List.fromList(utf8.encode(json));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup',
      fileName: 'forge-master-backup.json',
      bytes: bytes,
    );
    if (!context.mounted) return;
    _snack(context, path == null ? 'Export cancelled.' : 'Exported backup.');
  }

  Future<void> _importAllFlow(BuildContext context, AppState state) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null) return; // cancelled

    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      if (context.mounted) _snack(context, 'Could not read that file.');
      return;
    }
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Replace everything?'),
        content: const Text(
          'Importing a backup replaces all your current gear, pets, mounts, '
          'config and equipped loadout with what is in that file. This '
          'cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      state.importAll(json);
      if (context.mounted) _snack(context, 'Backup restored.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Import failed: $e');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
