import 'dart:math' as math;

import '../models/build.dart';
import '../models/enums.dart';
import '../models/stats.dart';

/// Every game formula, transcribed from the master spreadsheet
/// (sheets: Profile 1, Profile Comparison, Regenlifestealdps). This is the only
/// place formulas live; the calculator and optimizer call into it so nothing is
/// duplicated. To recalibrate against a spreadsheet change, edit here.
class Formulas {
  const Formulas._();

  /// Baseline crit multiplier in percentage points. A crit deals
  /// (120 + critDamage)% of a normal hit. From the DPS/lifesteal formulas.
  static const double kBaseCritPercent = 120;

  /// Attack-speed stat -> seconds between attacks. Higher attack speed means a
  /// shorter interval. Transcribed from Regenlifestealdps!C5.
  static double attackInterval(double attackSpeed) {
    if (attackSpeed > 400) return 0.5;
    if (attackSpeed > 275) return 0.6;
    if (attackSpeed > 200) return 0.7;
    if (attackSpeed > 150) return 0.8;
    if (attackSpeed > 114) return 0.9;
    if (attackSpeed > 87.5) return 1.0;
    if (attackSpeed > 66.7) return 1.1;
    if (attackSpeed > 50) return 1.2;
    if (attackSpeed > 36.4) return 1.3;
    if (attackSpeed > 25) return 1.4;
    if (attackSpeed > 15.4) return 1.5;
    if (attackSpeed > 7.1) return 1.6;
    return 1.7;
  }

  /// Shown damage: flat gear damage + flat base damage + global damage%.
  /// (Profile Comparison!D2)
  static double shownDamage(double flatDamage, BuildConfig config) {
    return flatDamage +
        config.baseDamage +
        flatDamage * (config.globalDamagePct / 100);
  }

  /// Total damage: shown damage boosted by the Damage substat and, depending on
  /// weapon type, the Melee or Ranged damage substat. (Profile Comparison!D4)
  static double totalDamage(Stats aggregate, BuildConfig config) {
    final shown = shownDamage(aggregate.flatDamage, config);
    final damagePct = aggregate.sub(SubstatType.damage);
    final typePct = config.weaponType == WeaponType.melee
        ? aggregate.sub(SubstatType.meleeDmg)
        : aggregate.sub(SubstatType.rangedDmg);
    return shown + shown * (damagePct / 100) + shown * (typePct / 100);
  }

  /// Shown health: flat health + flat base health + global health%.
  /// (Profile Comparison!D3)
  static double shownHealth(Stats aggregate, BuildConfig config) {
    return aggregate.flatHealth +
        config.baseHealth +
        aggregate.flatHealth * (config.globalHealthPct / 100);
  }

  /// Total health with the Health substat applied. (Profile Comparison!D5)
  static double totalHealth(Stats aggregate, BuildConfig config) {
    final shown = shownHealth(aggregate, config);
    return shown + shown * (aggregate.sub(SubstatType.health) / 100);
  }

  /// Damage per second. (Regenlifestealdps!G25)
  ///
  /// base = (totalDamage / interval) x (1 + doubleChance%)
  /// dps  = base x [(1 - crit) + crit x (baseCrit + critDamage)%]
  ///
  /// doubleChance is clamped to 100 (can't proc more than one extra hit per
  /// attack), same as critChance.
  static double dps(Stats aggregate, BuildConfig config) {
    final td = totalDamage(aggregate, config);
    final interval = attackInterval(aggregate.sub(SubstatType.attackSpeed));
    final doubleChance =
        math.min(100.0, aggregate.sub(SubstatType.doubleChance));
    final critFraction =
        math.min(100.0, aggregate.sub(SubstatType.critChance)) / 100;
    final critMultiplier =
        (kBaseCritPercent + aggregate.sub(SubstatType.critDamage)) / 100;

    final base = (td / interval) * (1 + doubleChance / 100);
    return base * ((1 - critFraction) + critFraction * critMultiplier);
  }

  /// Effective attacks per second including double-hit chance.
  /// (Denominator of Regenlifestealdps!G24)
  static double attacksPerSecond(Stats aggregate) {
    final interval = attackInterval(aggregate.sub(SubstatType.attackSpeed));
    final doubleChance =
        math.min(100.0, aggregate.sub(SubstatType.doubleChance));
    return (1 + doubleChance / 100) / interval;
  }

  /// Health recovered per second from lifesteal, weighted by crit rate; a crit
  /// heals off the larger crit hit. Rounded to a whole number like the sheet.
  /// (Regenlifestealdps!G24)
  static double lifestealPerSecond(Stats aggregate, BuildConfig config) {
    final td = totalDamage(aggregate, config);
    final lifesteal = aggregate.sub(SubstatType.lifesteal) / 100;
    if (lifesteal <= 0) return 0;

    final critFraction =
        math.min(100.0, aggregate.sub(SubstatType.critChance)) / 100;
    final critMultiplier =
        (kBaseCritPercent + aggregate.sub(SubstatType.critDamage)) / 100;

    final healPerNormalHit = td * lifesteal;
    final healPerCritHit = td * critMultiplier * lifesteal;
    final healPerHit = healPerNormalHit * (1 - critFraction) +
        healPerCritHit * critFraction;

    return (attacksPerSecond(aggregate) * healPerHit).roundToDouble();
  }

  /// Passive regen per second: total health x regen%. (Regenlifestealdps!D15)
  static double regenPerSecond(Stats aggregate, BuildConfig config) {
    return totalHealth(aggregate, config) *
        (aggregate.sub(SubstatType.regen) / 100);
  }

  static BuildResult derive(Stats aggregate, BuildConfig config) {
    return BuildResult(
      aggregate: aggregate,
      shownDamage: shownDamage(aggregate.flatDamage, config),
      totalDamage: totalDamage(aggregate, config),
      shownHealth: shownHealth(aggregate, config),
      totalHealth: totalHealth(aggregate, config),
      attackInterval: attackInterval(aggregate.sub(SubstatType.attackSpeed)),
      attacksPerSecond: attacksPerSecond(aggregate),
      dps: dps(aggregate, config),
      lifestealPerSecond: lifestealPerSecond(aggregate, config),
      regenPerSecond: regenPerSecond(aggregate, config),
    );
  }
}
