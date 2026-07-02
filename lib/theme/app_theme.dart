import 'package:flutter/material.dart';

/// Material 3 theme. Dark by default to feel like a build tool (Path of Building
/// / a raid optimizer) rather than a spreadsheet.
class AppTheme {
  const AppTheme._();

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
