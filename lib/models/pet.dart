import 'enums.dart';
import 'stats.dart';

/// An owned pet, stored in an inventory (add / edit / delete / duplicate). Pets
/// have no names in game: a pet is identified by its type, substats, rarity and
/// level. Same stat shape as gear: flat Damage, flat Health and up to two
/// substats. Type/rarity/level are metadata and do not affect calculations.
class Pet {
  final String id;
  final PetType type;
  final Rarity rarity;
  final int level;
  final double mainDamage;
  final double mainHealth;
  final List<Substat> substats; // up to two

  const Pet({
    required this.id,
    this.type = PetType.balanced,
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

  Pet copyWith({
    String? id,
    PetType? type,
    Rarity? rarity,
    int? level,
    double? mainDamage,
    double? mainHealth,
    List<Substat>? substats,
  }) {
    return Pet(
      id: id ?? this.id,
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      level: level ?? this.level,
      mainDamage: mainDamage ?? this.mainDamage,
      mainHealth: mainHealth ?? this.mainHealth,
      substats: substats ?? this.substats,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'rarity': rarity.name,
        'level': level,
        'mainDamage': mainDamage,
        'mainHealth': mainHealth,
        'substats': substats.map((s) => s.toJson()).toList(),
      };

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        type: PetType.values.byName(json['type'] as String? ?? 'balanced'),
        rarity: Rarity.fromJson(json['rarity'] as String?),
        level: (json['level'] as num?)?.toInt() ?? 1,
        mainDamage: (json['mainDamage'] as num?)?.toDouble() ?? 0,
        mainHealth: (json['mainHealth'] as num?)?.toDouble() ?? 0,
        substats: ((json['substats'] as List?) ?? const [])
            .map((e) => Substat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
