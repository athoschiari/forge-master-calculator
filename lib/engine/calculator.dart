import '../models/build.dart';
import '../models/enums.dart';
import '../models/gear.dart';
import '../models/mount.dart';
import '../models/pet.dart';
import '../models/stats.dart';
import 'formulas.dart';

/// The single calculation entry point for the whole app. Nothing else computes
/// a build. Flow: gear -> base stats -> pet bonuses -> mount bonuses -> attack
/// speed -> crit -> damage -> final build.
class Calculator {
  const Calculator._();

  /// Aggregates every equipped contributor into one [Stats] object.
  static Stats aggregate({
    required Map<GearSlot, GearPiece?> gear,
    required List<Pet> pets,
    Mount? mount,
  }) {
    var total = Stats.zero;
    for (final piece in gear.values) {
      if (piece != null) total = total + piece.toStats();
    }
    for (final pet in pets) {
      total = total + pet.toStats();
    }
    if (mount != null) total = total + mount.toStats();
    return total;
  }

  /// Computes the full build from equipped gear, pets and mount.
  static BuildResult calculateBuild({
    required Map<GearSlot, GearPiece?> gear,
    required List<Pet> pets,
    required Mount? mount,
    required BuildConfig config,
  }) {
    final agg = aggregate(gear: gear, pets: pets, mount: mount);
    return Formulas.derive(agg, config);
  }

  /// Convenience overload when the aggregate is already known.
  static BuildResult fromAggregate(Stats aggregate, BuildConfig config) =>
      Formulas.derive(aggregate, config);
}
