import 'enums.dart';

/// A single rolled substat: a type and its in-game value (percentage for most
/// types, a raw stat number for Attack speed).
class Substat {
  final SubstatType type;
  final double value;

  const Substat({required this.type, required this.value});

  Substat copyWith({SubstatType? type, double? value}) =>
      Substat(type: type ?? this.type, value: value ?? this.value);

  Map<String, dynamic> toJson() => {'type': type.name, 'value': value};

  factory Substat.fromJson(Map<String, dynamic> json) => Substat(
        type: SubstatType.values.byName(json['type'] as String),
        value: (json['value'] as num).toDouble(),
      );
}

/// Immutable aggregate of everything one or more equipped pieces contribute:
/// flat Damage, flat Health, and the summed substat values keyed by type.
///
/// Every calculation manipulates [Stats] objects. Combining sources is a single
/// [operator +]; the engine never re-implements the aggregation anywhere else.
class Stats {
  final double flatDamage;
  final double flatHealth;
  final Map<SubstatType, double> subs;

  const Stats({
    this.flatDamage = 0,
    this.flatHealth = 0,
    this.subs = const {},
  });

  static const Stats zero = Stats();

  /// Value of a substat bucket, or 0 if not present.
  double sub(SubstatType type) => subs[type] ?? 0;

  /// Merges two aggregates: flat stats add, substat buckets add per type.
  Stats operator +(Stats other) {
    final merged = <SubstatType, double>{...subs};
    other.subs.forEach((type, value) {
      merged[type] = (merged[type] ?? 0) + value;
    });
    return Stats(
      flatDamage: flatDamage + other.flatDamage,
      flatHealth: flatHealth + other.flatHealth,
      subs: merged,
    );
  }

  /// Builds an aggregate from raw main stats and a list of substats. Shared by
  /// gear, pets and mounts, which all have the same shape.
  factory Stats.fromParts({
    double flatDamage = 0,
    double flatHealth = 0,
    List<Substat> substats = const [],
  }) {
    final map = <SubstatType, double>{};
    for (final s in substats) {
      map[s.type] = (map[s.type] ?? 0) + s.value;
    }
    return Stats(flatDamage: flatDamage, flatHealth: flatHealth, subs: map);
  }

  Map<String, dynamic> toJson() => {
        'flatDamage': flatDamage,
        'flatHealth': flatHealth,
        'subs': {for (final e in subs.entries) e.key.name: e.value},
      };

  factory Stats.fromJson(Map<String, dynamic> json) {
    final rawSubs = (json['subs'] as Map?) ?? const {};
    final map = <SubstatType, double>{};
    rawSubs.forEach((key, value) {
      final type = SubstatType.values
          .where((t) => t.name == key)
          .cast<SubstatType?>()
          .firstWhere((t) => true, orElse: () => null);
      if (type != null) map[type] = (value as num).toDouble();
    });
    return Stats(
      flatDamage: (json['flatDamage'] as num?)?.toDouble() ?? 0,
      flatHealth: (json['flatHealth'] as num?)?.toDouble() ?? 0,
      subs: map,
    );
  }
}
