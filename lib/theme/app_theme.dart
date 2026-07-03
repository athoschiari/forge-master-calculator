import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Material 3 theme. Dark by default to feel like a build tool (Path of Building
/// / a raid optimizer) rather than a spreadsheet.
class AppTheme {
  const AppTheme._();

  /// Blends a rarity colour into the theme's card surface at low opacity, so
  /// rarity reads as a subtle colour cue rather than a solid vivid background.
  static Color rarityTint(
    ColorScheme scheme,
    Color rarityColor, {
    double opacity = 0.16,
  }) {
    return Color.alphaBlend(
      rarityColor.withValues(alpha: opacity),
      scheme.surfaceContainerHigh,
    );
  }

  static const Color _seed = Color(0xFFFF6D3A); // forge ember orange

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    return _build(scheme);
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return _build(scheme);
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Colours used across the app for the two headline metrics so DPS and
/// lifesteal read consistently everywhere.
class MetricColors {
  const MetricColors._();

  static const Color dps = Color(0xFFFF6D3A);
  static const Color lifesteal = Color(0xFF4CD07D);
  static const Color balanced = Color(0xFF5B9DFF);
  static const Color health = Color(0xFF4CD07D);
  static const Color damage = Color(0xFFFF6D3A);
}

/// Rarity -> colour, used to tint pet/mount cards. Declared as an extension
/// (not a member of the enum) so `lib/models/enums.dart` stays framework
/// agnostic; call sites read as `rarity.color`, just like `.label`.
extension RarityColor on Rarity {
  Color get color {
    switch (this) {
      case Rarity.common:
        return const Color(0xFFB0B4BB); // light gray
      case Rarity.rare:
        return const Color(0xFF4A90E2); // blue
      case Rarity.epic:
        return const Color(0xFF2ECC71); // green
      case Rarity.legendary:
        return const Color(0xFFFFC107); // yellow/gold
      case Rarity.ultimate:
        return const Color(0xFFFF6B4A); // red/coral
      case Rarity.mythic:
        return const Color(0xFFCE3DD1); // purple/magenta
    }
  }
}

/// Gear rarity -> colour, used to tint gear cards. The first six tiers reuse
/// the same hues as [RarityColor] (same conceptual power band); the four
/// gear-exclusive tiers beyond mythic continue the escalation with hues that
/// don't collide with the first six.
extension GearRarityColor on GearRarity {
  Color get color {
    switch (this) {
      case GearRarity.primitive:
        return const Color(0xFFB0B4BB); // light gray
      case GearRarity.medieval:
        return const Color(0xFF4A90E2); // blue
      case GearRarity.earlyModern:
        return const Color(0xFF2ECC71); // green
      case GearRarity.modern:
        return const Color(0xFFFFC107); // yellow/gold
      case GearRarity.space:
        return const Color(0xFFFF6B4A); // red/coral
      case GearRarity.interstellar:
        return const Color(0xFFCE3DD1); // purple/magenta
      case GearRarity.multiverse:
        return const Color(0xFF1FC8C0); // teal/cyan
      case GearRarity.quantum:
        return const Color(0xFF5B3DE0); // dark indigo
      case GearRarity.underworld:
        return const Color(0xFF7A2E2E); // dark maroon
      case GearRarity.divine:
        return const Color(0xFFFFA726); // orange/gold
    }
  }
}
