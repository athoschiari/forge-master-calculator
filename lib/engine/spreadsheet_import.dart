import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/build.dart';
import '../models/enums.dart';
import '../models/gear.dart';
import '../models/mount.dart';
import '../models/pet.dart';
import '../models/stats.dart';

/// The result of parsing one profile out of the master spreadsheet: the eight
/// gear pieces, the three pets, the mount and the profile-level config. Ids are
/// left blank here; [AppState.applyImport] assigns them.
class ImportedProfile {
  final Map<GearSlot, GearPiece> gear;
  final List<Pet> pets;
  final Mount? mount;
  final BuildConfig config;

  const ImportedProfile({
    required this.gear,
    required this.pets,
    required this.mount,
    required this.config,
  });
}

class SpreadsheetImportException implements Exception {
  SpreadsheetImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads the "Forge master master calculator" workbook and turns one of its
/// three profiles into an [ImportedProfile].
///
/// Only literal input cells are read (the value + k/m/b unit columns and the
/// substat name/value pairs); the k/m/b multiplier is applied here exactly as
/// the sheet does, so the importer never depends on the workbook's formula
/// results. Cell addresses were mapped from the Profile sheet layout.
class SpreadsheetImporter {
  const SpreadsheetImporter._();

  static const List<int> availableProfiles = [1, 2, 3];

  static ImportedProfile parse(Uint8List bytes, int profile) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw SpreadsheetImportException(
        'That file could not be read as an .xlsx workbook.',
      );
    }

    final sheet = excel.tables['Profile $profile'];
    if (sheet == null) {
      throw SpreadsheetImportException(
        'Sheet "Profile $profile" was not found. Is this the master '
        'calculator spreadsheet?',
      );
    }
    final comparison = excel.tables['Profile Comparison'];

    // Gear: [dmgValue, dmgUnit, hpValue, hpUnit, sub1Name, sub1Value,
    //        sub2Name, sub2Value]
    final gear = <GearSlot, GearPiece>{
      GearSlot.helmet: _gear(sheet, GearSlot.helmet,
          ['B2', 'C2', 'B3', 'C3', 'A4', 'B4', 'A5', 'B5']),
      GearSlot.armor: _gear(sheet, GearSlot.armor,
          ['G2', 'H2', 'G3', 'H3', 'F4', 'G4', 'F5', 'G5']),
      GearSlot.gloves: _gear(sheet, GearSlot.gloves,
          ['L2', 'M2', 'L3', 'M3', 'K4', 'L4', 'K5', 'L5']),
      GearSlot.necklace: _gear(sheet, GearSlot.necklace,
          ['Q2', 'R2', 'Q3', 'R3', 'P4', 'Q4', 'P5', 'Q5']),
      GearSlot.ring: _gear(sheet, GearSlot.ring,
          ['V2', 'W2', 'V3', 'W3', 'U4', 'V4', 'U5', 'V5']),
      GearSlot.weapon: _gear(sheet, GearSlot.weapon,
          ['B8', 'C8', 'B9', 'C9', 'A10', 'B10', 'A11', 'B11']),
      GearSlot.boots: _gear(sheet, GearSlot.boots,
          ['G8', 'H8', 'G9', 'H9', 'F10', 'G10', 'F11', 'G11']),
      GearSlot.belt: _gear(sheet, GearSlot.belt,
          ['L8', 'M8', 'L9', 'M9', 'K10', 'L10', 'K11', 'L11']),
    };

    final mountPiece = _piece(
        sheet, ['S8', 'T8', 'S9', 'T9', 'R10', 'S10', 'R11', 'S11']);
    final mount = Mount(
      id: '',
      mainDamage: mountPiece.damage,
      mainHealth: mountPiece.health,
      substats: mountPiece.subs,
    );

    final pets = <Pet>[
      _pet(sheet, ['B14', 'C14', 'B15', 'C15', 'A16', 'B16', 'A17', 'B17']),
      _pet(sheet, ['G14', 'H14', 'G15', 'H15', 'F16', 'G16', 'F17', 'G17']),
      _pet(sheet, ['L14', 'M14', 'L15', 'M15', 'K16', 'L16', 'K17', 'L17']),
    ];

    final weaponType = (_text(sheet, 'C10') ?? '').toLowerCase().contains('melee')
        ? WeaponType.melee
        : WeaponType.ranged;

    // Profile-level "Skills" block lives on the Profile Comparison sheet.
    final config = BuildConfig(
      baseDamage: (_num(comparison, 'B20') ?? 0) * _unit(_text(comparison, 'C20')),
      baseHealth: (_num(comparison, 'B21') ?? 0) * _unit(_text(comparison, 'C21')),
      globalDamagePct: _num(comparison, 'B23') ?? 0,
      globalHealthPct: _num(comparison, 'B24') ?? 0,
      weaponType: weaponType,
    );

    return ImportedProfile(
      gear: gear,
      pets: pets,
      mount: mount,
      config: config,
    );
  }

  static GearPiece _gear(Sheet sheet, GearSlot slot, List<String> a) {
    final p = _piece(sheet, a);
    return GearPiece(
      slot: slot,
      mainDamage: p.damage,
      mainHealth: p.health,
      substats: p.subs,
    );
  }

  static Pet _pet(Sheet sheet, List<String> a) {
    final p = _piece(sheet, a);
    return Pet(
      id: '',
      mainDamage: p.damage,
      mainHealth: p.health,
      substats: p.subs,
    );
  }

  static ({double damage, double health, List<Substat> subs}) _piece(
    Sheet sheet,
    List<String> a,
  ) {
    final damage = (_num(sheet, a[0]) ?? 0) * _unit(_text(sheet, a[1]));
    final health = (_num(sheet, a[2]) ?? 0) * _unit(_text(sheet, a[3]));
    final subs = <Substat>[];
    _addSub(subs, _text(sheet, a[4]), _num(sheet, a[5]));
    _addSub(subs, _text(sheet, a[6]), _num(sheet, a[7]));
    return (damage: damage, health: health, subs: subs);
  }

  static void _addSub(List<Substat> subs, String? name, double? value) {
    if (name == null || value == null || value == 0) return;
    final type = SubstatType.fromLabel(name);
    if (type != null) subs.add(Substat(type: type, value: value));
  }

  /// k/m/b -> multiplier, matching the sheet's Pick column. Blank/unknown -> 1.
  static double _unit(String? unit) {
    switch ((unit ?? '').trim().toLowerCase()) {
      case 'k':
        return 1000;
      case 'm':
        return 1000000;
      case 'b':
        return 1000000000;
      default:
        return 1;
    }
  }

  static CellValue? _raw(Sheet? sheet, String address) =>
      sheet?.cell(CellIndex.indexByString(address)).value;

  static double? _num(Sheet? sheet, String address) {
    final value = _raw(sheet, address);
    if (value is IntCellValue) return value.value.toDouble();
    if (value is DoubleCellValue) return value.value;
    if (value is TextCellValue) {
      return double.tryParse(_textOf(value).replaceAll(',', '.'));
    }
    return null;
  }

  static String? _text(Sheet? sheet, String address) {
    final value = _raw(sheet, address);
    if (value == null) return null;
    if (value is TextCellValue) return _textOf(value);
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    return value.toString();
  }

  /// Extracts plain text from a TextCellValue across excel package versions,
  /// where `.value` may be a String or a rich-text object.
  static String _textOf(TextCellValue value) {
    final dynamic inner = (value as dynamic).value;
    if (inner is String) return inner.trim();
    try {
      final dynamic text = (inner as dynamic).text;
      if (text is String) return text.trim();
    } catch (_) {
      // Fall through to toString below.
    }
    return inner.toString().trim();
  }
}
