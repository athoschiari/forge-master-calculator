import '../models/build.dart';
import '../models/enums.dart';
import '../models/gear.dart';
import '../models/mount.dart';
import '../models/pet.dart';
import 'calculator.dart';

/// A single evaluated pet+mount combination over the current (fixed) gear.
class BuildCandidate {
  final List<Pet> pets;
  final Mount? mount;
  final BuildResult build;

  /// 0..1 normalised score for the balanced objective, filled after the whole
  /// set is known (a combination scores well only relative to what is possible).
  double balancedScore;

  BuildCandidate({
    required this.pets,
    required this.mount,
    required this.build,
    this.balancedScore = 0,
  });

  double get dps => build.dps;
  double get lifestealPerSecond => build.lifestealPerSecond;
  double get healPerSecond => build.healPerSecond;

  double score(OptimizationMode mode) {
    switch (mode) {
      case OptimizationMode.dps:
        return dps;
      case OptimizationMode.lifestealPerSecond:
        return lifestealPerSecond;
      case OptimizationMode.healPerSecond:
        return healPerSecond;
      case OptimizationMode.balanced:
        return balancedScore;
    }
  }
}

/// Result of an optimizer run: every evaluated candidate plus the best one per
/// objective.
class OptimizerOutput {
  final List<BuildCandidate> candidates;
  final Map<OptimizationMode, BuildCandidate> best;

  const OptimizerOutput({required this.candidates, required this.best});

  static const OptimizerOutput empty =
      OptimizerOutput(candidates: [], best: {});

  bool get isEmpty => candidates.isEmpty;

  /// All candidates ranked high-to-low for the given objective.
  List<BuildCandidate> ranked(OptimizationMode mode) {
    final list = [...candidates];
    list.sort((a, b) => b.score(mode).compareTo(a.score(mode)));
    return list;
  }
}

/// Evaluates every possible pet + mount combination over the current gear and
/// ranks them for each of the four objectives: DPS, lifesteal/sec, heal/sec
/// (lifesteal + regen combined), and a 50/50 balanced blend of DPS and
/// lifesteal/sec (normalised so neither dominates by scale).
class Optimizer {
  const Optimizer._();

  static OptimizerOutput run({
    required Map<GearSlot, GearPiece?> gear,
    required List<Pet> pets,
    required List<Mount> mounts,
    required BuildConfig config,
    required int petSlots,
  }) {
    final petGroups = _combinations(pets, petSlots.clamp(0, pets.length).toInt());
    final petOptions = petGroups.isEmpty ? <List<Pet>>[<Pet>[]] : petGroups;
    final mountOptions = mounts.isEmpty ? <Mount?>[null] : <Mount?>[...mounts];

    final candidates = <BuildCandidate>[];
    for (final petCombo in petOptions) {
      for (final mount in mountOptions) {
        final build = Calculator.calculateBuild(
          gear: gear,
          pets: petCombo,
          mount: mount,
          config: config,
        );
        candidates.add(
          BuildCandidate(pets: petCombo, mount: mount, build: build),
        );
      }
    }

    if (candidates.isEmpty) return OptimizerOutput.empty;

    // Normalise DPS and lifesteal/sec to 0..1 across the whole set, then blend.
    var maxDps = 0.0;
    var maxLifesteal = 0.0;
    for (final c in candidates) {
      if (c.dps > maxDps) maxDps = c.dps;
      if (c.lifestealPerSecond > maxLifesteal) {
        maxLifesteal = c.lifestealPerSecond;
      }
    }
    for (final c in candidates) {
      final normDps = maxDps > 0 ? c.dps / maxDps : 0.0;
      final normLifesteal =
          maxLifesteal > 0 ? c.lifestealPerSecond / maxLifesteal : 0.0;
      c.balancedScore = 0.5 * normDps + 0.5 * normLifesteal;
    }

    BuildCandidate bestFor(OptimizationMode mode) {
      var best = candidates.first;
      for (final c in candidates) {
        if (c.score(mode) > best.score(mode)) best = c;
      }
      return best;
    }

    return OptimizerOutput(
      candidates: candidates,
      best: {
        for (final mode in OptimizationMode.values) mode: bestFor(mode),
      },
    );
  }

  /// All ways to choose [k] items from [items], order-insensitive. Choosing 0
  /// yields a single empty selection; k >= length yields the full list.
  static List<List<T>> _combinations<T>(List<T> items, int k) {
    if (k <= 0) return [<T>[]];
    if (k >= items.length) return [List<T>.from(items)];

    final result = <List<T>>[];
    final indices = List<int>.generate(k, (i) => i);
    while (true) {
      result.add([for (final i in indices) items[i]]);
      var pivot = k - 1;
      while (pivot >= 0 && indices[pivot] == items.length - k + pivot) {
        pivot--;
      }
      if (pivot < 0) break;
      indices[pivot]++;
      for (var j = pivot + 1; j < k; j++) {
        indices[j] = indices[j - 1] + 1;
      }
    }
    return result;
  }
}
