/// Gear slots the player can equip. There is no gear inventory: each slot holds
/// one current piece which is overwritten when a new item is obtained.
enum GearSlot {
  helmet,
  armor,
  gloves,
  necklace,
  ring,
  weapon,
  boots,
  belt;

  String get label {
    switch (this) {
      case GearSlot.helmet:
        return 'Helmet';
      case GearSlot.armor:
        return 'Armor';
      case GearSlot.gloves:
        return 'Gloves';
      case GearSlot.necklace:
        return 'Necklace';
      case GearSlot.ring:
        return 'Ring';
      case GearSlot.weapon:
        return 'Weapon';
      case GearSlot.boots:
        return 'Boots';
      case GearSlot.belt:
        return 'Belt';
    }
  }
}

/// Attack type of the build. Determines whether Melee Dmg or Ranged Dmg
/// substats are applied to total damage (see [Formulas.totalDamage]).
enum WeaponType {
  melee,
  ranged;

  String get label => this == WeaponType.melee ? 'Melee' : 'Ranged';
}

/// Every substat the game rolls. Values are stored as the raw number shown in
/// game (a percentage for most, a flat stat value for Attack speed). The engine
/// sums substats by type across all equipped pieces, exactly like the sheet.
enum SubstatType {
  critChance,
  critDamage,
  blockChance,
  regen,
  lifesteal,
  doubleChance,
  meleeDmg,
  rangedDmg,
  damage,
  attackSpeed,
  health,
  skillDamage,
  skillCooldown;

  /// Human label. These match the spreadsheet bucket names so pasted profiles
  /// parse cleanly.
  String get label {
    switch (this) {
      case SubstatType.critChance:
        return 'Crit chance';
      case SubstatType.critDamage:
        return 'Crit damage';
      case SubstatType.blockChance:
        return 'Block chance';
      case SubstatType.regen:
        return 'Regen';
      case SubstatType.lifesteal:
        return 'Lifesteal';
      case SubstatType.doubleChance:
        return 'Double chance';
      case SubstatType.meleeDmg:
        return 'Melee Dmg';
      case SubstatType.rangedDmg:
        return 'Ranged Dmg';
      case SubstatType.damage:
        return 'Damage';
      case SubstatType.attackSpeed:
        return 'Attack speed';
      case SubstatType.health:
        return 'Health';
      case SubstatType.skillDamage:
        return 'Skill damage';
      case SubstatType.skillCooldown:
        return 'Skill cooldown';
    }
  }

  /// Attack speed is a raw stat value; every other substat is a percentage.
  bool get isPercent => this != SubstatType.attackSpeed;

  static SubstatType? fromLabel(String raw) {
    final needle = raw.trim().toLowerCase();
    for (final t in SubstatType.values) {
      if (t.label.toLowerCase() == needle) return t;
    }
    return null;
  }
}

/// The three optimization objectives the optimizer ranks combinations against.
enum OptimizationMode {
  dps,
  lifestealPerSecond,
  balanced;

  String get label {
    switch (this) {
      case OptimizationMode.dps:
        return 'Best DPS';
      case OptimizationMode.lifestealPerSecond:
        return 'Best Lifesteal/sec';
      case OptimizationMode.balanced:
        return 'Best Balanced';
    }
  }

  String get shortLabel {
    switch (this) {
      case OptimizationMode.dps:
        return 'DPS';
      case OptimizationMode.lifestealPerSecond:
        return 'Lifesteal/sec';
      case OptimizationMode.balanced:
        return 'Balanced';
    }
  }

  String get description {
    switch (this) {
      case OptimizationMode.dps:
        return 'Maximises damage per second.';
      case OptimizationMode.lifestealPerSecond:
        return 'Maximises health recovered per second (lifesteal healing).';
      case OptimizationMode.balanced:
        return 'Balances DPS and lifesteal/sec 50/50, normalised across every '
            'combination so neither metric dominates by raw scale.';
    }
  }
}

/// Optional rarity metadata for pets and mounts. Used for sorting and search;
/// it does not affect calculations.
enum Rarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  mythic;

  String get label {
    switch (this) {
      case Rarity.common:
        return 'Common';
      case Rarity.uncommon:
        return 'Uncommon';
      case Rarity.rare:
        return 'Rare';
      case Rarity.epic:
        return 'Epic';
      case Rarity.legendary:
        return 'Legendary';
      case Rarity.mythic:
        return 'Mythic';
    }
  }
}

/// A pet's role. Metadata only (it does not affect calculations); used for
/// organising and identifying pets, which have no names.
enum PetType {
  attack,
  balanced,
  health;

  String get label {
    switch (this) {
      case PetType.attack:
        return 'Attack';
      case PetType.balanced:
        return 'Balanced';
      case PetType.health:
        return 'Health';
    }
  }
}
