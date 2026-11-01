# Monster Breeders of Ahymn (MBOA)

A cozy 2D farming and creature-taming game for PC and mobile, built in Godot 4.
Stardew-style farming, clock, and seasons combined with Dragon Warrior Monsters-style
taming and breeding, plus optional tournaments.

## Pillars
1. Farming is integral.
2. Time is the resource.
3. Every creature is tamed in its own unique way.
4. Tournaments are optional.

## Art spec
16-bit pixel art, cozy Stardew-like style. 16x16 tiles, 16x32 characters, 64x64 portraits.

## Structure
- `scenes/`: Godot scenes (`world/`, `farm/`, `ui/`, `creatures/`)
- `scripts/`: GDScript (`core/`, `farm/`, `creatures/`, `ui/`)
- `assets/`: sprites, tilesets, portraits, audio, fonts
- `resources/`: custom `.tres` data (items, crops, creature definitions)
- `docs/`: roadmap and design notes. The GDD is the source of truth for design.

## Getting started
Open `project.godot` with Godot 4.3 or newer (developed and tested on 4.7.2 stable)
and press Play; the main scene is `scenes/main/main.tscn`.

## Status (Milestone 1: core loop skeleton)
- [x] Continuous clock autoload `Clock` (`scripts/core/game_clock.gd`): time of day, days,
      seasons/years, phases, darkness, pause reasons, save/load
- [x] Midnight makes the player tired (slower movement); 2:00 AM forces a pass-out
- [x] Player movement and a basic farm scene (12x8 grid of 16x16 plots)
- [x] Farm plots: till, plant, water, grow (watered days), harvest (signal only)
- [x] Sleeping (bed) and pass-out with day rollover and fade-to-black
- [ ] Placeholder tileset and player sprite (ART): colored rectangles for now
- Open questions (configurable placeholders, no penalty by default):
  pass-out penalty (`resources/pass_out_config.tres`) and climate (`resources/climate_config.tres`)

All numbers (clock speed, wake hour, phase boundaries, days per season, crop days, tired
slowdown...) are **placeholders** until the GDD values are applied. Tune them in the `.tres`
files in `resources/` or the exported vars in the scenes, not in code.

## Controls
| Action | Keys |
| --- | --- |
| Move | WASD / arrow keys |
| Use tool on faced cell / harvest / sleep at bed | E or Space |
| Select tool: Hoe / Seeds / Watering can | 1 / 2 / 3 (or the HUD buttons) |
| Act on an adjacent cell (mouse / touch) | Left click / tap |
| Cancel (reserved) | Esc |
| Debug: clock speed x1 / x10 / x60 | F1 / F2 / F3 |
| Debug: sleep now | F4 |

## Core systems
- `Clock` autoload (`scripts/core/game_clock.gd`, tunables in `resources/clock_config.tres`).
  The game day runs from `wake_hour` (06:00) to 02:00 next morning; times after midnight
  are still the same game day. Signals: `minute_changed`, `hour_changed`, `phase_changed`,
  `day_started(day)`, `season_changed(season, year)`, `midnight_reached`, `pass_out_reached`,
  `sleep_started(pass_out)`, `day_ended(day, pass_out)`, `paused_changed`.
  Menus pause it with `Clock.pause(&"menu")` / `Clock.resume(&"menu")`.
- `PlayerState` autoload (`scripts/core/player_state.gd`): applies the pass-out penalty
  (`resources/pass_out_config.tres`) and exposes `last_sleep_was_pass_out`.
- Farm: `scripts/farm/farm_grid.gd` (rules + placeholder drawing), `farm_plot.gd` (data),
  crops are `CropData` resources in `resources/crops/`.
- UI: `scenes/ui/hud.tscn`; night tint is `DayNightTint` (CanvasModulate) in the main scene.

## Tests
Headless tests live in `tests/` (each extends `SceneTree`):
```
tests/run_all.sh /path/to/godot          # imports, then runs every tests/test_*.gd
godot --headless --path . --script res://tests/test_clock.gd   # single suite
```
Suites: `test_clock`, `test_farm`, `test_sleep`, `test_boot` (loads the main scene).
`run_all.sh` fails on a non-zero exit or any `SCRIPT ERROR` in the output.
