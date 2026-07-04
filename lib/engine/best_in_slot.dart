import '../models/build.dart';
import '../models/enums.dart';
import '../models/gear.dart';
import '../models/mount.dart';
import '../models/pet.dart';
import '../models/stats.dart';
import 'calculator.dart';
import 'formulas.dart';

/// Highest value a single substat roll can reach, keyed by type - the same
/// pool for gear, pets and mounts alike (there's no separate max-roll table
/// per item kind in-game). [BestInSlot] uses this to value every substat slot
/// it optimises, whichever item it belongs to.
class SubstatCaps {
  const SubstatCaps._();

  static const Map<SubstatType, double> maxRoll = {
    SubstatType.critChance: 12,
    SubstatType.critDamage: 80,
    SubstatType.blockChance: 5,
    SubstatType.regen: 4,
    SubstatType.lifesteal: 20,
    SubstatType.doubleChance: 20,
    SubstatType.damage: 15,
    SubstatType.meleeDmg: 50,
    SubstatType.rangedDmg: 15,
    SubstatType.attackSpeed: 40,
    SubstatType.skillDamage: 30,
    SubstatType.skillCooldown: 7,
    SubstatType.health: 15,
  };
}

/// Result of [BestInSlot.solve]. [totalSlots] is how many substat slots (across
/// gear and, if included, pets/mount) fed the search (0 means nothing
/// included has any substat rolled, so [build] is just the unmodified fixed
/// aggregate) - callers use it to tell "nothing to optimise" apart from a
/// genuine best-in-slot [build].
class BestInSlotResult {
  final BuildResult build;
  final int totalSlots;

  const BestInSlotResult({required this.build, required this.totalSlots});
}

/// Answers "if every substat slot rolled ideally, what's my ceiling for a
/// chosen objective (DPS, Lifesteal/sec, or both combined)?" Every equipped
/// item's main stats (Damage/Health) are always held fixed at their current
/// contribution; the caller passes an empty pet list / null mount to exclude
/// them from the calculation entirely. Whichever items *are* included - gear
/// always, pets/mount when the caller includes them - have their substats
/// re-optimised together as one pool, each contributing only as many slots as
/// it already has rolled (an item with one substat is searched with one slot,
/// not two; an empty item contributes none). A single item's two slots are
/// never assigned the same type, matching the game's no-duplicate-substat-
/// per-item rule.
class BestInSlot {
  const BestInSlot._();

  /// Substat types that can move the needle for [mode], per the formulas in
  /// `formulas.dart`: [Formulas.dps] reads crit chance/damage, double chance,
  /// damage%, the melee-or-ranged% matching [WeaponType], and attack speed;
  /// [Formulas.lifestealPerSecond] reads all of those plus lifesteal% itself.
  /// Block chance, regen, health, skill damage/cooldown and the *other*
  /// melee/ranged type never appear in either formula, so a slot spent there
  /// can never beat spending it on one of these - excluded entirely rather
  /// than wasting search branches on a type that can only tie.
  static List<SubstatType> _relevantTypes(
    WeaponType weaponType,
    OptimizationMode mode,
  ) {
    final dpsTypes = [
      SubstatType.critChance,
      SubstatType.critDamage,
      SubstatType.doubleChance,
      SubstatType.damage,
      weaponType == WeaponType.melee
          ? SubstatType.meleeDmg
          : SubstatType.rangedDmg,
      SubstatType.attackSpeed,
    ];
    if (mode == OptimizationMode.dps) return dpsTypes;
    return [...dpsTypes, SubstatType.lifesteal];
  }

  static BestInSlotResult solve({
    required Map<GearSlot, GearPiece?> gear,
    required List<Pet> pets,
    required Mount? mount,
    required BuildConfig config,
    required OptimizationMode mode,
  }) {
    var fixed = Stats.zero;
    final capacities = <int>[];

    // One item (gear piece, pet or mount) contributes its main stats always,
    // and as many substat slots as it already has rolled (0/1/2) to the
    // shared pool the search below fills.
    void addItem(double mainDamage, double mainHealth, List<Substat> substats) {
      fixed = fixed +
          Stats.fromParts(flatDamage: mainDamage, flatHealth: mainHealth);
      final slots = substats.length.clamp(0, 2);
      if (slots > 0) capacities.add(slots);
    }

    for (final piece in gear.values) {
      if (piece != null) {
        addItem(piece.mainDamage, piece.mainHealth, piece.substats);
      }
    }
    for (final pet in pets) {
      addItem(pet.mainDamage, pet.mainHealth, pet.substats);
    }
    if (mount != null) {
      addItem(mount.mainDamage, mount.mainHealth, mount.substats);
    }

    final itemCount = capacities.length;
    final totalSlots = capacities.fold(0, (sum, c) => sum + c);

    if (totalSlots == 0) {
      return BestInSlotResult(
        build: Calculator.fromAggregate(fixed, config),
        totalSlots: 0,
      );
    }

    final types = _relevantTypes(config.weaponType, mode);
    final maxPerSlot = [for (final t in types) SubstatCaps.maxRoll[t] ?? 0];

    var bestScore = -1.0;
    var bestCounts = List<int>.filled(types.length, 0);
    final counts = List<int>.filled(types.length, 0);

    // Every composition of totalSlots across `types`, capped at itemCount
    // per type (one item can carry a given type at most once, whether it has
    // one or two slots) so the result stays realisable per-item.
    void search(int index, int remaining) {
      final last = index == types.length - 1;
      final cap = remaining < itemCount ? remaining : itemCount;
      if (last) {
        if (remaining <= itemCount) {
          counts[index] = remaining;
          final score = _score(fixed, config, mode, types, maxPerSlot, counts);
          if (score > bestScore) {
            bestScore = score;
            bestCounts = List.of(counts);
          }
        }
        return;
      }
      for (var n = 0; n <= cap; n++) {
        counts[index] = n;
        search(index + 1, remaining - n);
      }
      counts[index] = 0;
    }

    search(0, totalSlots);

    final subs = <SubstatType, double>{};
    for (var i = 0; i < types.length; i++) {
      if (bestCounts[i] > 0) subs[types[i]] = bestCounts[i] * maxPerSlot[i];
    }
    final build = Calculator.fromAggregate(fixed + Stats(subs: subs), config);

    return BestInSlotResult(build: build, totalSlots: totalSlots);
  }

  /// Same objective definition as [BuildResult.objectiveValue]: balanced is
  /// the raw DPS + Lifesteal/sec sum (this search evaluates one aggregate at
  /// a time, not a discrete candidate set, so there's nothing to normalise
  /// against - unlike [Optimizer], which blends normalised 0..1 scores).
  static double _score(
    Stats fixed,
    BuildConfig config,
    OptimizationMode mode,
    List<SubstatType> types,
    List<double> maxPerSlot,
    List<int> counts,
  ) {
    final subs = <SubstatType, double>{};
    for (var i = 0; i < types.length; i++) {
      if (counts[i] > 0) subs[types[i]] = counts[i] * maxPerSlot[i];
    }
    final aggregate = fixed + Stats(subs: subs);
    switch (mode) {
      case OptimizationMode.dps:
        return Formulas.dps(aggregate, config);
      case OptimizationMode.lifestealPerSecond:
        return Formulas.lifestealPerSecond(aggregate, config);
      case OptimizationMode.balanced:
        return Formulas.dps(aggregate, config) +
            Formulas.lifestealPerSecond(aggregate, config);
    }
  }
}
