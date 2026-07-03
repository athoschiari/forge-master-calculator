import '../models/enums.dart';
import '../models/stats.dart';
import 'parser.dart';

/// Everything recognisable in an OCR'd in-game item popup screenshot. Fields
/// are null/empty when not found in the text — callers merge only the
/// non-null/non-empty fields onto an existing item, matching this app's
/// "0/empty = unset" [NumberField] convention rather than clobbering fields
/// OCR couldn't read.
class ParsedItemScreenshot {
  final int? level;
  final double? mainDamage;
  final double? mainHealth;
  final List<Substat> substats; // up to two, in reading order
  final String? rarityRawLabel; // raw bracket text, e.g. "Legendary", "Quantum"
  final List<String> unmatchedLines; // diagnostic only

  const ParsedItemScreenshot({
    this.level,
    this.mainDamage,
    this.mainHealth,
    this.substats = const [],
    this.rarityRawLabel,
    this.unmatchedLines = const [],
  });

  bool get isEmpty =>
      level == null &&
      mainDamage == null &&
      mainHealth == null &&
      substats.isEmpty &&
      rarityRawLabel == null;
}

/// Parses OCR text recognised from an in-game item popup (see
/// [ParsedItemScreenshot]) into structured stats. Pure Dart — no
/// Flutter/plugin dependency — so it's directly unit-testable against golden
/// OCR text without a device or emulator.
class ItemScreenshotParser {
  const ItemScreenshotParser._();

  static final _rarityBracket = RegExp(r'^\[([^\]]+)\]');
  static final _levelLine = RegExp(r'lv\.?\s*(\d+)', caseSensitive: false);
  static final _mainStatLine = RegExp(
    r'^([0-9]+(?:\.[0-9]+)?\s*[kKmMbB]?)\s*(damage|dmg|health|hp)\s*$',
    caseSensitive: false,
  );
  static final _substatLine = RegExp(r'^[+-]\s*([0-9]+(?:\.[0-9]+)?)\s*%?\s*(.+)$');
  static final _leadingAmount = RegExp(r'^([0-9]+(?:\.[0-9]+)?)\s*([kKmMbB])?');
  static const _noiseLines = {'equipped', 'locked'};

  static ParsedItemScreenshot parse(String rawText) {
    int? level;
    double? mainDamage;
    double? mainHealth;
    final substats = <Substat>[];
    String? rarityRaw;
    final unmatched = <String>[];

    for (final rawLine in rawText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (_noiseLines.contains(line.toLowerCase())) continue;

      if (rarityRaw == null) {
        final m = _rarityBracket.firstMatch(line);
        if (m != null) {
          rarityRaw = m.group(1)!.trim();
          continue;
        }
      }

      if (level == null) {
        final m = _levelLine.firstMatch(line);
        if (m != null) {
          level = int.tryParse(m.group(1)!);
          continue;
        }
      }

      if (line.startsWith('+') || line.startsWith('-')) {
        final m = _substatLine.firstMatch(line);
        final value =
            m == null ? null : double.tryParse(m.group(1)!.replaceAll(',', '.'));
        final type = m == null ? null : _matchSubstatLabel(m.group(2)!);
        if (value != null && type != null && substats.length < 2) {
          substats.add(Substat(type: type, value: value));
        } else {
          unmatched.add(line);
        }
        continue;
      }

      final m = _mainStatLine.firstMatch(line);
      final amount = m == null ? null : _extractAmount(m.group(1)!);
      if (m != null && amount != null) {
        if (m.group(2)!.toLowerCase().startsWith('h')) {
          mainHealth = amount;
        } else {
          mainDamage = amount;
        }
        continue;
      }

      unmatched.add(line);
    }

    return ParsedItemScreenshot(
      level: level,
      mainDamage: mainDamage,
      mainHealth: mainHealth,
      substats: substats,
      rarityRawLabel: rarityRaw,
      unmatchedLines: unmatched,
    );
  }

  /// Isolates a leading "number[k/m/b]" substring (e.g. "264k" out of
  /// "264k Damage") and reuses [Parser.parseAmount] for the actual
  /// conversion, since that function requires the whole trimmed string to
  /// already be just the number and suffix.
  static double? _extractAmount(String token) {
    final m = _leadingAmount.firstMatch(token.trim());
    if (m == null) return null;
    return Parser.parseAmount('${m.group(1)}${m.group(2) ?? ''}');
  }

  /// Exact match first (mirrors [SubstatType.fromLabel]); falls back to a
  /// normalised comparison (lowercase, punctuation stripped, "dmg"->"damage")
  /// so wording differences between the game's own text ("Ranged Damage")
  /// and this app's label ("Ranged Dmg") still match. Iterates
  /// [SubstatType.values] generically rather than hardcoding any member.
  static SubstatType? _matchSubstatLabel(String raw) {
    final exact = SubstatType.fromLabel(raw);
    if (exact != null) return exact;
    final needle = _normalize(raw);
    if (needle.isEmpty) return null;
    for (final t in SubstatType.values) {
      if (_normalize(t.label) == needle) return t;
    }
    return null;
  }

  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w == 'dmg' ? 'damage' : w)
      .join(' ');
}

/// Matches [raw] against whichever enum values are passed in, by exact label
/// first, then loose substring containment. Generic over the enum type `T`
/// so it works for [Rarity] (pets/mounts), `GearRarity` (gear), or any future
/// rarity enum without hardcoding specific members.
T? matchByLabel<T>(Iterable<T> values, String Function(T) labelOf, String raw) {
  final needle = raw.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final v in values) {
    if (labelOf(v).toLowerCase() == needle) return v;
  }
  for (final v in values) {
    final l = labelOf(v).toLowerCase();
    if (l.isNotEmpty && (needle.contains(l) || l.contains(needle))) return v;
  }
  return null;
}
