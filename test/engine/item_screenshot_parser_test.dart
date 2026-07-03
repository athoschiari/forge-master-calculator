import 'package:flutter_test/flutter_test.dart';
import 'package:forge_master_optimizer/engine/item_screenshot_parser.dart';
import 'package:forge_master_optimizer/models/enums.dart';

void main() {
  test('Legendary Kitsune (pet)', () {
    final p = ItemScreenshotParser.parse(
      '[Legendary] Kitsune\nEquipped\nLv. 6\n264k Damage\n706k Health\n'
      '+6.46% Double Chance\n+8.98% Attack Speed',
    );
    expect(p.level, 6);
    expect(p.mainDamage, 264000);
    expect(p.mainHealth, 706000);
    expect(p.substats.map((s) => s.type),
        [SubstatType.doubleChance, SubstatType.attackSpeed]);
    expect(p.substats[0].value, closeTo(6.46, 1e-9));
    expect(p.substats[1].value, closeTo(8.98, 1e-9));
    expect(p.rarityRawLabel, 'Legendary');
    // Resolved by label, never a hardcoded enum member, so this survives any
    // further Rarity enum rewrite.
    expect(
      matchByLabel(Rarity.values, (r) => r.label, p.rarityRawLabel!)?.label,
      'Legendary',
    );
  });

  test('Quantum Helm (gear) - "Ranged Damage" fuzzy-matches "Ranged Dmg" label',
      () {
    final p = ItemScreenshotParser.parse(
      '[Quantum] Quantum Helm\nLv. 46\n1.08m Health\n'
      '+19.5% Double Chance\n+13.2% Ranged Damage',
    );
    expect(p.level, 46);
    expect(p.mainHealth, closeTo(1080000, 1e-6));
    expect(p.mainDamage, isNull);
    expect(p.substats.map((s) => s.type),
        [SubstatType.doubleChance, SubstatType.rangedDmg]);
    expect(p.rarityRawLabel, 'Quantum');
  });

  test('Ethereal Socks (gear)', () {
    final p = ItemScreenshotParser.parse(
      '[Multiverse] Ethereal Socks\nLv. 106\n512k Health\n+34% Attack Speed',
    );
    expect(p.level, 106);
    expect(p.mainHealth, 512000);
    expect(p.substats.single.type, SubstatType.attackSpeed);
    expect(p.substats.single.value, 34);
    expect(p.rarityRawLabel, 'Multiverse');
  });

  test('Lily Leaf (mount, locked)', () {
    final p = ItemScreenshotParser.parse(
      '[Common] Lily Leaf\nLocked\nLv. 76\n498 Damage\n3.98k Health\n'
      '+19.8% Lifesteal',
    );
    expect(p.level, 76);
    expect(p.mainDamage, 498);
    expect(p.mainHealth, closeTo(3980, 1e-6));
    expect(p.substats.single.type, SubstatType.lifesteal);
    expect(p.rarityRawLabel, 'Common');
  });

  test('empty/noise-only text does not crash', () {
    final p = ItemScreenshotParser.parse('Equipped\nLocked\n');
    expect(p.isEmpty, isTrue);
    expect(p.level, isNull);
    expect(p.mainDamage, isNull);
    expect(p.mainHealth, isNull);
    expect(p.substats, isEmpty);
  });

  test('matchByLabel is generic and works for GearRarity too', () {
    expect(
      matchByLabel(GearRarity.values, (r) => r.label, 'multiverse')?.label,
      'Multiverse',
    );
    expect(
      matchByLabel(GearRarity.values, (r) => r.label, 'nonsense'),
      isNull,
    );
  });
}
