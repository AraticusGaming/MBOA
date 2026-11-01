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

## Status
Milestone 1 (core loop skeleton):
- [x] Continuous clock autoload `Clock` (`scripts/core/game_clock.gd`): time of day, days,
      seasons/years, phases, darkness, pause reasons, save/load
- [x] Midnight makes the player tired (slower movement); 2:00 AM forces a pass-out
- [x] Player movement and a basic farm scene (12x8 grid of 16x16 plots)
- [x] Farm plots: till, plant, water, grow (watered days), harvest (signal only)
- [x] Sleeping (bed) and pass-out with day rollover and fade-to-black
- [x] Placeholder tileset and player sprite (ART) integrated: farm tiles, animated player,
      crop stage sprites (the bed and HUD are still placeholder shapes)

Milestone 1.5 (align with the GDD):
- [x] Clock per ruling (`docs/DECISIONS.md`): wake 6:00 AM, 30 days per season, 60 real
      seconds per in-game hour (`resources/clock_config.tres`)
- [x] Pass-out: lose 10% of carried Coins (ruling, no cap) plus a fixed bond drop for the
      party (still open: 0, inactive until monsters exist); wake up in bed
- [x] Stat letter bands for 1-20 stats (ruling: D 1-4, C 5-9, B 10-14, A 15-17, S 18-20):
      `StatLetterBands` + `resources/stats/stat_letters_1_20.tres`, GDD overall-rank helper
- [x] Removed the per-season "climate" hook (GDD climate = egg/pregnancy environment, M7)
- [x] Health and stamina bars (100%); tool uses cost stamina; at 0 stamina no tools and
      slower movement; refill by sleeping, `eat()` and `rest_in_hot_spring()` (flat placeholder refills)
- [x] GDD tools as data (`resources/tools/`): Pulaski, sickle, pickaxe, watering can (1 tile),
      plus the seed bag; trees with four stages and GDD hit counts (`resources/trees/`)
- [x] Crop data: four growth stages, per-stage days and a season tag (`resources/crops/`)
- [x] `SaveManager`: versioned saves of clock, player and farm (incl. trees), autosave
      each morning, tested across days and seasons
- [ ] Display options (Ledan to confirm; 640x360 with integer scaling unchanged)

User rulings in `docs/DECISIONS.md` override the GDD. All numbers that neither fixes (phase
boundaries, crop and tree stage days, stamina costs, slowdowns, penalties...) are
**placeholders**. Tune them in the `.tres` files in `resources/` or the exported vars in the
scenes, not in code. GDD-fixed values (four crop stages, tree hits 3 / 6 + 4, bars at 100%,
1-tile basic tools) are used as written.

## Controls
| Action | Keys |
| --- | --- |
| Move | WASD / arrow keys |
| Use tool on faced cell / harvest / sleep at bed | E or Space |
| Select Pulaski / Sickle / Pickaxe / Watering can / Seeds | 1 / 2 / 3 / 4 / 5 (or the HUD buttons) |
| Act on an adjacent cell (mouse / touch) | Left click / tap |
| Cancel (reserved) | Esc |
| Debug: clock speed x1 / x10 / x60 | F1 / F2 / F3 |
| Debug: sleep now | F4 |
| Debug: save / load (`user://save_slot_0.json`) | F5 / F9 |

## Core systems
- `Clock` autoload (`scripts/core/game_clock.gd`, tunables in `resources/clock_config.tres`).
  The game day runs from `wake_hour` (06:00) to 02:00 next morning; times after midnight
  are still the same game day. Signals: `minute_changed`, `hour_changed`, `phase_changed`,
  `day_started(day)`, `season_changed(season, year)`, `midnight_reached`, `pass_out_reached`,
  `sleep_started(pass_out)`, `day_ended(day, pass_out)`, `paused_changed`.
  Menus pause it with `Clock.pause(&"menu")` / `Clock.resume(&"menu")`.
- `PlayerState` autoload (`scripts/core/player_state.gd`): coins, health, stamina
  (`resources/energy_config.tres`) and the party; on `day_ended` it refills stamina and,
  after a pass-out, applies the penalty (`resources/pass_out_config.tres`). Exposes
  `spend_stamina`, `refill_stamina`, `eat`, `rest_in_hot_spring`, `damage`, `heal`.
- `SaveManager` autoload (`scripts/core/save_manager.gd`): `{version, clock, player_state,
  farm}` JSON in `user://` (trees are saved on their farm plot). `save_game()` /
  `load_game()`; autosaves at the start of each day; `migrate()` handles old versions.
- Farm: `scripts/farm/farm_grid.gd` (rules + rendering), `farm_plot.gd` / `farm_tree.gd`
  (data). Data resources: crops `CropData` (`resources/crops/`), tools `ToolData`
  (`resources/tools/`), trees `TreeData` (`resources/trees/`). The farm's starting trees
  are `FarmGrid.starting_trees` in `scenes/farm/farm.tscn`.
- The bed (`scripts/farm/bed.gd`) moves the player to its wake spot on every `day_started`.
- Creatures (data only so far): `StatLetterBands` (`scripts/creatures/stat_letter_bands.gd`)
  maps a stat value to its letter; one resource per stat range in `resources/stats/`.
- UI: `scenes/ui/hud.tscn`; night tint is `DayNightTint` (CanvasModulate) in the main scene.

## Tests
Headless tests live in `tests/` (each extends `SceneTree`):
```
tests/run_all.sh /path/to/godot          # imports, then runs every tests/test_*.gd
godot --headless --path . --script res://tests/test_clock.gd   # single suite
```
Suites: `test_clock`, `test_farm` (plots, tools, trees), `test_sleep` (pass-out, bed),
`test_energy` (health/stamina), `test_save` (SaveManager), `test_stats` (stat letters), `test_art`, `test_boot` (loads the
main scene).

## Art integration
See `assets/ART_NOTES.md` for sheet layouts. Godot-side resources:
- `resources/farm_tileset.tres` (from `assets/tilesets/farm_tiles.png`) and
  `resources/player_frames.tres` (from `assets/sprites/player_base.png`) are generated by
  `godot --headless --path . --script res://tools/godot/build_art_resources.gd`; rerun it
  if a sheet layout changes. Commit the `.png.import` files (Godot import settings).
- `resources/farm_tile_mapping.tres`: plot state -> soil tile (empty = dirt, tilled,
  watered). `FarmGrid` renders soil on a child TileMapLayer and draws crops on top.
- Crops: each `CropData` (`resources/crops/*.tres`) names its `sprite_sheet`, `frame_size`
  and `stage_frames` (one sheet frame per growth stage, 4 stages; `stage_days` sets how many
  watered days each stage lasts).
- Trees: no art yet; placeholder rectangles per stage.
- Player: `AnimatedSprite2D` with `idle_`/`walk_` + `down/left/right/up`, offset (0, -16) so
  the feet sit on the node origin.
- Preview render (needs a display, e.g. Xvfb):
  `xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/godot/render_preview.gd -- out.png 10`

`run_all.sh` fails on a non-zero exit or any `SCRIPT ERROR` in the output.
