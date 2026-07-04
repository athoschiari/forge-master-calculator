# Forge Master Optimizer

A Flutter app that replaces the "Forge master master calculator" spreadsheet,
originally created by **Thermo**. [`docs/base spreadsheet.xlsx`](docs/base%20spreadsheet.xlsx)
is not that original file, but a modified version with the core calculation
logic that this app is built on, kept here for reference.

It tracks your current gear, your pet and mount inventory, computes your build,
and finds the best pet + mount loadout for three objectives:

1. **Lifesteal / sec** — health recovered per second from lifesteal
2. **DPS** — damage per second
3. **Balanced** — a 50/50 blend of the two, normalised so neither dominates

The Gear tab also has a **best-in-slot substat** calculator: holding your
pets, mount and gear main stats fixed, it works out the highest Lifesteal/sec
you could reach if every gear piece's existing substat slots rolled the ideal
type at its maximum value.

Material 3, dark by default. Local JSON persistence (no server, no login).
Works on Flutter Web, desktop and Android from a single codebase.

**Live demo:** https://athoschiari.github.io/forge-master-calculator/
(built and deployed automatically from `main` via GitHub Actions, see
`.github/workflows/deploy.yml`).

## Setup

You need the Flutter SDK (stable channel, **3.27 or newer**). Then, from this
folder:

```bash
# 1. Generate the platform scaffolding (android/web/windows/... folders).
#    This does NOT overwrite lib/ or pubspec.yaml.
flutter create .

# 2. Fetch dependencies.
flutter pub get

# 3. Check it analyses clean.
flutter analyze

# 4. Run it.
flutter run -d chrome      # web
# or: flutter run -d windows / macos / linux / <device>
```

## How the numbers work

Every formula is transcribed directly from the spreadsheet and lives in one
place: `lib/engine/formulas.dart`. They were verified to reproduce the
spreadsheet's Profile 1 outputs exactly:

| Metric        | This app / sheet |
| ------------- | ---------------- |
| Total Damage  | 1,631,547.94     |
| Total Health  | 5,836,745.2      |
| Attack interval | 1.1s           |
| DPS           | 2,179,599.725    |
| Lifesteal/sec | 1,316,260        |

Key points from the sheet:

- **Main stats** (Damage, Health) are flat and summed across every piece; enter
  them with k/m/b shorthand (e.g. `1.05m`).
- **Substats** are percentages summed by name (Attack speed is a raw value).
- **Attack speed** maps through a step function to an attack interval.
- **Lifesteal** heals off damage dealt, weighted by double-hit and crit rate.
- **Forge level** is metadata for upgrade cost, not a stat multiplier — you enter
  already-forged values, exactly like the sheet.

To recalibrate after a game patch, edit `lib/engine/formulas.dart` only.

### Best-in-slot gear substats

The Gear tab's best-in-slot card (`lib/engine/best_in_slot.dart`) answers
"what's my Lifesteal/sec ceiling if my gear substats were ideal?" It keeps
pets, mount and every gear piece's main stats fixed, and searches every way
to fill each gear piece's *existing* substat slots (a piece with one rolled
substat only gets one slot, an unrolled piece gets none) with the type/max
combination that maximises Lifesteal/sec, never repeating a type on the same
piece. The per-substat maximum gear roll:

| Substat        | Max roll |
| -------------- | -------- |
| Crit chance    | 12%      |
| Crit damage    | 80%      |
| Block chance   | 5%       |
| Health regen   | 4%       |
| Lifesteal      | 20%      |
| Double chance  | 20%      |
| Damage         | 15%      |
| Melee damage   | 50%      |
| Ranged damage  | 15%      |
| Attack speed   | 40       |
| Skill damage   | 30%      |
| Skill cooldown | 7%       |
| Health         | 15%      |

## Project layout

```
lib/
  models/     enums, Stats aggregate, gear/pet/mount, build config + result
  engine/     formulas, calculator (single entry point), optimizer, parser
  repository/ local JSON storage
  state/      AppState (single source of truth, ChangeNotifier)
  widgets/    reusable cards, number field, substat editor
  screens/    dashboard, gear, pets, mounts, optimizer, planner, settings, compare
  theme/      Material 3 theme
  main.dart   app entry + responsive navigation shell
```

## Importing from the spreadsheet

Go to **Settings -> Import from spreadsheet -> Choose .xlsx file**, pick your
`Forge master master calculator` workbook, then choose Profile 1, 2 or 3.

The importer reads that profile's eight gear pieces, three pets, mount and the
profile-level Skills block (base Damage/Health, Damage%/Health%, weapon type),
applies the k/m/b multipliers exactly like the sheet, and rebuilds everything
through the same engine. It was verified to reproduce the sheet's Profile 1
numbers to the decimal. Importing overwrites your current gear and config and
adds the profile's pets and mount to your inventory (equipping them).

## Gear slots

The app uses all eight gear slots from the spreadsheet: Helmet, Armor, Gloves,
Necklace, Ring, Weapon, Boots, Belt. Plus a mount and three pet slots. The
engine sums across every contributor, so the calculation matches the sheet.

## Original credits

<img width="683" height="740" alt="image" src="https://github.com/user-attachments/assets/5e85730b-cba8-4a26-82f1-11a7780c6c11" />
