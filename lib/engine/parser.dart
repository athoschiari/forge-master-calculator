import '../models/enums.dart';
import '../models/stats.dart';

/// Parses the in-game shorthand the spreadsheet uses. Numbers are entered as a
/// value plus a k/m/b suffix ("1.05m" -> 1050000); stat lines are entered as
/// "Name: value" and mapped to substats by their spreadsheet label.
class Parser {
  const Parser._();

  /// Parses an amount such as "121k", "1.05 m", "2.5B" or "58100" into its raw
  /// numeric value. Returns null when the text has no usable number.
  static double? parseAmount(String raw) {
    final text = raw.trim().toLowerCase().replaceAll(',', '');
    if (text.isEmpty) return null;

    final match = RegExp(r'^([0-9]*\.?[0-9]+)\s*([kmb])?$').firstMatch(text);
    if (match == null) return null;

    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;

    switch (match.group(2)) {
      case 'k':
        return value * 1000;
      case 'm':
        return value * 1000000;
      case 'b':
        return value * 1000000000;
      default:
        return value;
    }
  }

  /// Parses a single "Name: value" substat line into a [Substat], or null if the
  /// name is not a recognised substat or the value is missing.
  static Substat? parseSubstatLine(String line) {
    final parts = line.split(RegExp(r'[:\t]'));
    if (parts.length < 2) return null;

    final type = SubstatType.fromLabel(parts[0]);
    if (type == null) return null;

    final value = double.tryParse(
      parts.sublist(1).join(':').trim().replaceAll('%', '').replaceAll(',', '.'),
    );
    if (value == null) return null;

    return Substat(type: type, value: value);
  }

  /// Parses a block of pasted "Name: value" lines into a list of substats,
  /// skipping any line that is not a recognised substat.
  static List<Substat> parseSubstatBlock(String text) {
    final result = <Substat>[];
    for (final line in text.split('\n')) {
      final substat = parseSubstatLine(line);
      if (substat != null) result.add(substat);
    }
    return result;
  }
}
