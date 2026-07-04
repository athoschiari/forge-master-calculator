import '../models/enums.dart';
import '../models/pet.dart';
import '../models/stats.dart';

/// Substats in the same order the spreadsheet lists them on Profile
/// Comparison. Shared by every screen that renders a full substat breakdown
/// (the dashboard's aggregated-stats card, the build summary banner's info
/// modal) so the ordering stays consistent app-wide.
const List<SubstatType> substatDisplayOrder = [
  SubstatType.critChance,
  SubstatType.critDamage,
  SubstatType.blockChance,
  SubstatType.regen,
  SubstatType.lifesteal,
  SubstatType.doubleChance,
  SubstatType.damage,
  SubstatType.meleeDmg,
  SubstatType.rangedDmg,
  SubstatType.attackSpeed,
  SubstatType.health,
  SubstatType.skillDamage,
  SubstatType.skillCooldown,
];

/// Formats a raw number the way the spreadsheet displays it: compact with a
/// k/m/b suffix. e.g. 1631547.94 -> "1.63M", 121000 -> "121K".
String formatCompact(double value) {
  final sign = value < 0 ? '-' : '';
  final n = value.abs();

  String withSuffix(double scaled, String suffix) {
    if (scaled >= 100) return '$sign${scaled.toStringAsFixed(0)}$suffix';
    if (scaled >= 10) return '$sign${scaled.toStringAsFixed(1)}$suffix';
    return '$sign${scaled.toStringAsFixed(2)}$suffix';
  }

  if (n >= 1e9) return withSuffix(n / 1e9, 'B');
  if (n >= 1e6) return withSuffix(n / 1e6, 'M');
  if (n >= 1e3) return withSuffix(n / 1e3, 'K');
  if (n == n.roundToDouble()) return '$sign${n.toStringAsFixed(0)}';
  return '$sign${n.toStringAsFixed(1)}';
}

/// Formats a value already expressed in percentage points, keeping full
/// precision (no rounding) e.g. 5.99 -> "5.99%", 46.95 -> "46.95%".
String formatPercentPoints(double points) => '${_trimDecimals(points)}%';

/// Formats a signed delta with a leading + or - and compact magnitude.
String formatDelta(double value) {
  if (value == 0) return '0';
  final prefix = value > 0 ? '+' : '-';
  return '$prefix${formatCompact(value.abs())}';
}

/// Formats an attack interval in seconds, e.g. 1.1 -> "1.10s".
String formatSeconds(double seconds) => '${seconds.toStringAsFixed(2)}s';

/// Formats a number with thousands separators, like the spreadsheet, e.g.
/// 1639668 -> "1,639,668". Pass [decimals] to keep a fixed number of decimals
/// (2190447.51 -> "2,190,447.51").
String formatThousands(double value, {int decimals = 0}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts[0];

  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  final grouped = parts.length > 1 ? '$buffer.${parts[1]}' : buffer.toString();
  return negative ? '-$grouped' : grouped;
}

/// Compact k/m/b string using the exact rounding the spreadsheet applies to its
/// "Shown" values (Profile Comparison!E2): for each magnitude tier the scaled
/// number shows 0 decimals when >= 100, 1 decimal when >= 10, otherwise 2;
/// values under 1000 are shown as a whole number with no suffix.
String formatSheetCompact(double value) {
  String tier(double scaled, String suffix) {
    if (scaled >= 100) return '${scaled.toStringAsFixed(0)}$suffix';
    if (scaled >= 10) return '${scaled.toStringAsFixed(1)}$suffix';
    return '${scaled.toStringAsFixed(2)}$suffix';
  }

  if (value >= 1e9) return tier(value / 1e9, 'B');
  if (value >= 1e6) return tier(value / 1e6, 'M');
  if (value >= 1e3) return tier(value / 1e3, 'K');
  return value.toStringAsFixed(0);
}

/// Formats a raw substat value at full precision, percent or flat depending
/// on how the type is rolled in game (see [SubstatType.isPercent]).
String formatStatValue(SubstatType type, double value) =>
    type.isPercent ? formatPercentPoints(value) : _trimDecimals(value);

/// One substat rendered as text, e.g. "Lifesteal 18.2%" or "Attack speed 34".
String formatSubstat(Substat substat) =>
    '${substat.type.label} ${formatStatValue(substat.type, substat.value)}';

/// A comma-joined description of a list of substats, used to identify pets and
/// mounts (which have no names in game). Falls back to the main stats when a
/// piece has no substats. Leads with the rarity (when given) since that's the
/// fastest way to tell two similarly-rolled pieces apart at a glance -
/// notably in optimizer/planner suggestions, which otherwise read as a wall
/// of near-identical substat lists.
String describePiece({
  required List<Substat> substats,
  required double damage,
  required double health,
  Rarity? rarity,
}) {
  final prefix = rarity == null ? '' : '${rarity.label} - ';
  if (substats.isNotEmpty) {
    return '$prefix${substats.map(formatSubstat).join(', ')}';
  }
  return '${prefix}DMG ${formatCompact(damage)} / HP ${formatCompact(health)}';
}

/// A pet's description including its rarity and type: "Legendary Attack -
/// Lifesteal 18.2%, ...".
String describePet(Pet pet) {
  return '${pet.rarity.label} ${pet.type.label} - '
      '${describePiece(substats: pet.substats, damage: pet.mainDamage, health: pet.mainHealth)}';
}

/// Renders a value at full precision, trimming only trailing zeros (never
/// rounding away significant digits). 4 decimals comfortably covers every
/// substat value the game or a spreadsheet import can produce.
String _trimDecimals(double value) {
  var text = value.toStringAsFixed(4);
  if (text.contains('.')) {
    text = text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return text;
}
