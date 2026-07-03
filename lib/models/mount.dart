import 'enums.dart';
import 'stats.dart';

/// An owned mount. Same inventory behaviour and shape as [Pet]: flat Damage,
/// flat Health and up to two substats, with rarity and level as metadata. Like
/// everything else in game it has no name; its substats identify it.
class Mount {
  final String id;
  final Rarity rarity;
  final int level;
  final double mainDamage;
  final double mainHealth;
  final List<Substat> substats; // up to two

  const Mount({
    required this.id,
    this.rarity = Rarity.common,
    this.level = 1,
    this.mainDamage = 0,
    this.mainHealth = 0,
    this.substats = const [],
  });

  Stats toStats() => Stats.fromParts(
        flatDamage: mainDamage,
        flatHealth: mainHealth,
        substats: substats,
      );

  Mount copyWith({
    String? id,
    Rarity? rarity,
    int? level,
    double? mainDamage,
    double? mainHealth,
    List<Substat>? substats,
  }) {
    return Mount(
      id: id ?? this.id,
      rarity: rarity ?? this.rarity,
      level: level ?? this.level,
      mainDamage: mainDamage ?? this.mainDamage,
      mainHealth: mainHealth ?? this.mainHealth,
      substats: substats ?? this.substats,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rarity': rarity.name,
        'level': level,
        'mainDamage': mainDamage,
        'mainHealth': mainHealth,
        'substats': substats.map((s) => s.toJson()).toList(),
      };

  factory Mount.fromJson(Map<String, dynamic> json) => Mount(
        id: json['id'] as String,
        rarity: Rarity.fromJson(json['rarity'] as String?),
        level: (json['level'] as num?)?.toInt() ?? 1,
        mainDamage: (json['mainDamage'] as num?)?.toDouble() ?? 0,
        mainHealth: (json['mainHealth'] as num?)?.toDouble() ?? 0,
        substats: ((json['substats'] as List?) ?? const [])
            .map((e) => Substat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
