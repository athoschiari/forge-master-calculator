# `1vcian/fm` reference notes

Research notes on the third-party "ForgeMaster" companion web app, for a
future session that wants to add pet/mount inventory + an equip optimizer +
a best-in-slot substat solver to it (the three things this app has that it
doesn't). This is factual documentation of their repo as it stood when
researched (2026-07-04) — not a plan, not a list of steps to take.

- Upstream: https://github.com/1vcian/fm
- Fork already created under this user's account: https://github.com/athoschiari/fm
  (empty fork, no commits added yet — `origin` = the fork, `upstream` =
  `1vcian/fm`). Not cloned locally as of this note; re-clone with
  `gh repo clone athoschiari/fm` to resume.
- DeepWiki (auto-generated, often incomplete/paraphrased — prefer reading the
  actual source over trusting this): https://deepwiki.com/1vcian/fm

## What it is

A full companion web app for the mobile game "Forge Master" — not just a
build calculator. Covers equipment/forge mechanics, a tech tree, pets/mounts,
skills, PvP battle simulation, missions/dungeons, and an in-app wiki backed
by real scraped game data. Reverse-engineered by the community; not
officially affiliated with the game.

## Stack

React 18 + TypeScript, built with Vite, styled with Tailwind CSS. State via
React Context (no Redux/Zustand). Key deps: `react-router-dom` (HashRouter),
`framer-motion` (animation), `lz-string` (compresses profiles into shareable
URLs), `@dnd-kit/*` (drag-and-drop, used by the tech tree planner),
`react-toastify`. Requires **Node.js 18+** to build/run
(`npm install`, `npm run dev`, `npm run build`, `npm run lint`). Deployed to
GitHub Pages via GitHub Actions.

## Persistence

Entirely client-side: profiles persist to `localStorage`; sharing a profile
works by LZ-string-compressing it into a URL (no accounts, no backend).
Supports multiple locally-stored profiles with versioned schema migration
(`ProfileProvider` merges saved data with current defaults on load). No
login/cloud sync of any kind.

## Source layout (`src/`)

```
App.tsx            route table (HashRouter, see below)
main.tsx           entry point
pages/             one file per route (29 routes, see below)
components/
  Battle/          PvE/solo mission battle UI
  Layout/          AppShell (nav chrome)
  Profile/         equipment/pet/mount/skill editor panels
  Pvp/             Enemy Builder + Battle Visualizer
  UI/              shared/generic components
  Wiki/            wiki/encyclopedia page components
context/
  GameDataContext.tsx   loads/exposes bundled game-data JSON (useGameData hook)
  ProfileContext.tsx    the active profile(s): equipment, pets, mounts, skills,
                        tech tree progress, misc settings; persistence + import/export
  TreeModeContext.tsx   tech tree UI mode state
  ComparisonContext.tsx current-vs-candidate comparison state
hooks/             15 hooks — the real business logic layer:
  useGameData, useProfileStats, useCalculatedStats, useGlobalStats,
  useSetBonuses, useSkinSets, usePersistentState,
  useForgeCalculator, useEggsCalculator, useEggSummonCalculator,
  useMountsCalculator, useSkillsCalculator,
  useTreeOptimizer, useTreePlanner, useProfileOptimizer (tech-tree upgrade
  priority, NOT a pet/mount equip optimizer — no equivalent of this app's
  Optimizer screen exists anywhere in the codebase),
  useBattleSimulation
lib/               formatVersion.ts, utils.ts (misc helpers)
types/
  Profile.ts       the UserProfile shape (equipment, pets, mounts, skills,
                    tech tree, misc) — items/pets/mounts are stored as
                    references (id + level + rarity) into the bundled game-data
                    libraries below, NOT arbitrary free-typed stat numbers like
                    this app's models. A straight JSON translation from this
                    app's export format is not possible for that reason.
utils/             calculation engine + misc:
  statEngine.ts        steady-state stat/DPS/lifesteal calculation (see formulas below)
  itemCalculations.ts, ascensionUtils.ts, techUtils.ts, guildWarUtils.ts,
  statsCalculator.ts, statNames.ts, format.ts, constants.ts,
  itemAssets.ts, skinSprites.ts (sprite lookup, not raw image loading)
  BattleEngine.ts, BattleSimulator.ts, BattleHelper.ts   PvE/solo mission sim
  PvpBattleEngine.ts   tick-based PvP fight simulator (up to 10,000 iterations
                        for win/loss probability via `simulatePvpBattleMulti`)
```

## Routes (from `App.tsx`, all under `AppShell`)

`/` (Profile, index), `progress-prediction`, `home`, `configs`, `mounts`,
`skills`, `eggs`, `dungeons`, `forge-calculator`, `items`, `pets`,
`tech-tree`, `arena`, `guild-war`, `verify`, `unlocks`, `offline`, `colors`,
`emblems`, `faq`, `pvp-arena`, `calculators/forge`, `calculators/mounts`,
`calculators/skills`, `calculators/tree`, `calculators/substats`,
`solo-mission`, `wiki/forge`, `wiki/base-drops`, `wiki/shop`,
`wiki/progress-pass`, `wiki/secondary-stats`, `wiki/missions`, `skins`,
`gallery`. (`*` falls back to `home`.)

## Bundled game data (`public/`)

- `parsed_configs/<dated snapshot>/*.json` — real game config data (item
  stats, pet/mount libraries, tech tree, arena, guild war, missions, economy,
  etc.), scraped from the game's own files. Multiple dated snapshots exist
  historically; **only the latest snapshot matters** going forward (was
  `2026_07_03_12_39` as of this research, ~3.2MB). ~55MB total across all
  historical snapshots combined — don't carry old ones forward.
- `Texture2D/<dated snapshot>/` — sprite/icon image assets (590 files,
  ~31MB in the latest snapshot alone).
- `icons/` — small, ~16KB, misc UI icons.
- Loaded via `useGameData` (`GameDataContext`); wiki pages and calculators
  read from this rather than any hardcoded data.

## Key formulas already transcribed from `statEngine.ts`

(For cross-checking against this app's `lib/engine/formulas.dart` — see the
earlier conversation/PR history for the full comparison. Restated here since
it's the one piece of their actual source already extracted line-by-line.)

- Damage: `FinalDamage = (BaseFlat + WeaponWithMelee + OtherItems + Pet + SkillPassive + Mount) × (EquipMultiplier + SkinFactor + SetFactor) × (1 + SpecificDamageMulti)` — melee weapons get a flat **1.6x** multiplier baked into `WeaponWithMelee` before percentage bonuses (this app has no equivalent constant).
- Crit: `CriticalDamage = 1 + 0.2 + secondaryStats` (120% base, matches this app's `kBaseCritPercent`). `HitDamageCrit = FinalDamage × CriticalDamage`.
- Double hit: `WeightedAPS = (1 + DoubleDamageChance) / ((1 - DoubleDamageChance) × NormalCycle + DoubleDamageChance × DoubleCycle)` — the double-hit's own cycle (`DoubleCycle`) is shorter than a normal cycle (double-hit delay ≈ `windup × 0.25`), unlike this app's simpler `(1 + doubleChance%) / interval`.
- Attack interval: `SteppedCycle = max(0.4, floor(baseWindup/speedMult × 10)/10 + floor(baseRecovery/speedMult × 10)/10 + 0.2)` — derived per-weapon from windup/recovery frames, not a single fixed lookup table like this app's `Formulas.attackInterval`.
- Lifesteal: `LifestealDPS = RealWeaponDPS × LifeSteal`.
- Block (defensive only, doesn't touch damage/lifesteal output): `RealTotalHPS = (Regen + LifestealDPS + SkillHPS) × (1 / (1 - BlockChance))`.
- Power score: `Power = ((FinalDamage - 10) × 8 + (FinalHealth - 80)) × 3`.
- Skill DPS: `SkillDPS = (BaseSkillDamage × SkillMultiplier × CommonMultiplier × HitCount) / FinalCooldown`, with `FinalCd = max(0.1, Cooldown × (1 - CooldownReduction))`.

## Confirmed absent (the actual gap to fill)

No pet/mount equip optimizer (search over owned pets/mounts for best
DPS/Lifesteal/Balanced loadout) and no best-in-slot gear-substat solver exist
anywhere in `hooks/`, `utils/`, or `pages/` — confirmed by reading
`useProfileOptimizer.ts` (it's a **tech-tree** upgrade-priority optimizer,
unrelated) and the full hook/util file listing above. This app
(`forge_master_optimizer`, `lib/engine/optimizer.dart` +
`lib/engine/best_in_slot.dart`) is the only place that logic currently
exists.

## Practical note for resuming

Node.js was not installed on this machine as of this session; it was
installed via `winget install OpenJS.NodeJS.LTS` mid-session (may or may not
still be present depending on what else happened after). Verify with
`node --version` before assuming it's available.
