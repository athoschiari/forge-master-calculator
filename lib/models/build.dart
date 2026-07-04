import 'enums.dart';
import 'stats.dart';

/// Profile-level configuration that sits outside individual pieces. Mirrors the
/// spreadsheet "Skills" block plus the melee/ranged choice: flat base Damage and
/// Health, and global Damage%/Health% multipliers applied before substats.
class BuildConfig {
  final double baseDamage; // flat, added to summed gear damage
  final double baseHealth; // flat, added to summed gear health
  final double globalDamagePct; // percentage points, e.g. 10 == +10%
  final double globalHealthPct;
  final WeaponType weaponType;

  const BuildConfig({
    this.baseDamage = 0,
    this.baseHealth = 0,
    this.globalDamagePct = 0,
    this.globalHealthPct = 0,
    this.weaponType = WeaponType.ranged,
  });

  BuildConfig copyWith({
    double? baseDamage,
    double? baseHealth,
    double? globalDamagePct,
    double? globalHealthPct,
    WeaponType? weaponType,
  }) {
    return BuildConfig(
      baseDamage: baseDamage ?? this.baseDamage,
      baseHealth: baseHealth ?? this.baseHealth,
      globalDamagePct: globalDamagePct ?? this.globalDamagePct,
      globalHealthPct: globalHealthPct ?? this.globalHealthPct,
      weaponType: weaponType ?? this.weaponType,
    );
  }

  Map<String, dynamic> toJson() => {
        'baseDamage': baseDamage,
        'baseHealth': baseHealth,
        'globalDamagePct': globalDamagePct,
        'globalHealthPct': globalHealthPct,
        'weaponType': weaponType.name,
      };

  factory BuildConfig.fromJson(Map<String, dynamic> json) => BuildConfig(
        baseDamage: (json['baseDamage'] as num?)?.toDouble() ?? 0,
        baseHealth: (json['baseHealth'] as num?)?.toDouble() ?? 0,
        globalDamagePct: (json['globalDamagePct'] as num?)?.toDouble() ?? 0,
        globalHealthPct: (json['globalHealthPct'] as num?)?.toDouble() ?? 0,
        weaponType:
            WeaponType.values.byName(json['weaponType'] as String? ?? 'ranged'),
      );
}

/// The fully computed build. Produced only by [Calculator.calculateBuild] so
/// there is a single source of truth for every number the UI shows.
class BuildResult {
  /// Aggregated raw stats (flat + summed substats) the result was derived from.
  final Stats aggregate;

  final double shownDamage;
  final double totalDamage;
  final double shownHealth;
  final double totalHealth;

  /// Seconds between attacks, from the attack-speed step function.
  final double attackInterval;

  /// Effective attacks per second, including double-hit chance.
  final double attacksPerSecond;

  final double dps;
  final double lifestealPerSecond;
  final double regenPerSecond;

  const BuildResult({
    required this.aggregate,
    required this.shownDamage,
    required this.totalDamage,
    required this.shownHealth,
    required this.totalHealth,
    required this.attackInterval,
    required this.attacksPerSecond,
    required this.dps,
    required this.lifestealPerSecond,
    required this.regenPerSecond,
  });

  /// Flat gear+pet+mount Damage before base/global bonuses (sheet "Build Damage").
  double get buildDamage => aggregate.flatDamage;

  /// Flat gear+pet+mount Health before base/global bonuses (sheet "Build Health").
  double get buildHealth => aggregate.flatHealth;

  /// Total health recovered per second from lifesteal and regen combined.
  double get healPerSecond => lifestealPerSecond + regenPerSecond;

  static const BuildResult empty = BuildResult(
    aggregate: Stats.zero,
    shownDamage: 0,
    totalDamage: 0,
    shownHealth: 0,
    totalHealth: 0,
    attackInterval: 0,
    attacksPerSecond: 0,
    dps: 0,
    lifestealPerSecond: 0,
    regenPerSecond: 0,
  );

  /// The value optimised for a given objective. Balanced is handled by the
  /// optimizer because it needs the whole candidate set to normalise.
  double objectiveValue(OptimizationMode mode) {
    switch (mode) {
      case OptimizationMode.dps:
        return dps;
      case OptimizationMode.lifestealPerSecond:
        return lifestealPerSecond;
      case OptimizationMode.healPerSecond:
        return healPerSecond;
      case OptimizationMode.balanced:
        return dps + lifestealPerSecond;
    }
  }
}
