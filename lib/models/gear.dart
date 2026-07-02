import 'enums.dart';
import 'stats.dart';

/// One equipped gear piece. There is no gear collection: the piece in a slot is
/// overwritten when a new one is obtained. The slot is the piece's identity;
/// the game has no item names. Forge level is metadata used by the planner for
/// upgrade cost; it does not scale stats (entered values are already forged).
class GearPiece {
  final GearSlot slot;
  final double mainDamage;
  final double mainHealth;
  final int forgeLevel;
  final List<Substat> substats; // up to two

  const GearPiece({
    required this.slot,
    this.mainDamage = 0,
    this.mainHealth = 0,
    this.forgeLevel = 0,
    this.substats = const [],
  });

  factory GearPiece.empty(GearSlot slot) => GearPiece(slot: slot);

  Stats toStats() => Stats.fromParts(
        flatDamage: mainDamage,
        flatHealth: mainHealth,
        substats: substats,
      );

  GearPiece copyWith({
    GearSlot? slot,
    double? mainDamage,
    double? mainHealth,
    int? forgeLevel,
    List<Substat>? substats,
  }) {
    return GearPiece(
      slot: slot ?? this.slot,
      mainDamage: mainDamage ?? this.mainDamage,
      mainHealth: mainHealth ?? this.mainHealth,
      forgeLevel: forgeLevel ?? this.forgeLevel,
      substats: substats ?? this.substats,
    );
  }

  Map<String, dynamic> toJson() => {
        'slot': slot.name,
        'mainDamage': mainDamage,
        'mainHealth': mainHealth,
        'forgeLevel': forgeLevel,
        'substats': substats.map((s) => s.toJson()).toList(),
      };

  factory GearPiece.fromJson(Map<String, dynamic> json) => GearPiece(
        slot: GearSlot.values.byName(json['slot'] as String),
        mainDamage: (json['mainDamage'] as num?)?.toDouble() ?? 0,
        mainHealth: (json['mainHealth'] as num?)?.toDouble() ?? 0,
        forgeLevel: (json['forgeLevel'] as num?)?.toInt() ?? 0,
        substats: ((json['substats'] as List?) ?? const [])
            .map((e) => Substat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
