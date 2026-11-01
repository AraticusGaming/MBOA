# MBOA Roadmap

Source of truth: `docs/GDD.md` (GDD dated Oct 26, 2026). Where this file and the GDD disagree, the GDD wins.
Reviewed against the full GDD by Ledan. Open items are in `docs/OPEN_QUESTIONS.md`; user rulings that supplement the GDD are in `docs/DECISIONS.md`; villager table in `docs/VILLAGERS.md`.

Owners: Cody = systems/GDScript, ART = pixel art, Ledan = integration, structure, GDD consistency.
Order follows the GDD's "Suggested build order" (steps 1-6), with breeding, village, and reputation after it.

## Milestone 1: Clock, farm, sleep, pass-out (build order step 1). Merged to main.
- [x] Continuous clock autoload with midnight tired state and 2:00 AM pass-out (Cody)
- [x] Player, farm grid (till, plant, water, grow, harvest), bed, HUD, day/night tint (Cody)
- [x] Farm tileset, player sheet (4-frame idle and walk), 4-stage crop, wired in (ART, Cody)
- [x] 200 headless tests (`tests/run_all.sh`)

### Milestone 1.5: Align with the GDD (do next, small)
- [x] Clock config per ruling: wake 6:00 AM, 30 days per season, 60 real seconds per game hour. (Cody)
- [x] Pass-out per ruling: lose 10% of carried money (`gold_penalty_fraction = 0.1`, no cap) plus a fixed bonding drop for monsters with the player (value open, inactive until monsters exist); wakes in bed. Drop the invented `wake_hour_delay` and `energy_penalty_fraction`. (Cody)
- [x] Stat letters for 1-20 stats per ruling (D 1-4, C 5-9, B 10-14, A 15-17, S 18-20) as `resources/stats/stat_letters_1_20.tres` with a lookup, for the future monster resource. (Cody)
- [x] Remove or rename the "climate" per-season hook. In the GDD, climate means managing the egg or pregnancy environment (Milestone 7), not weather or seasons. Whether seasons change anything beyond crops is an open question. (Cody)
- [x] Energy: two bars, health and stamina, both 100%. Stamina drops per tool use; at 0 the player is slowed and cannot use tools. Refill by eating, sleeping, or a hot spring. Health outside battle is an open question, so stub it. (Cody)
- [x] Tools per GDD: Pulaski (axe and hoe in one), sickle, pickaxe, watering can; 1 tile at base level. Tree clearing: four stages (seed, seedling, sapling, grown); seeds and seedlings dug out; sapling 3 Pulaski hits; grown tree 10 swings (6 to fell, 4 for the stump). (Cody)
- [x] Crop data: four growth stages, season tag, growth days as data in `resources/` (values open). (Cody)
- [x] Save and load across days and seasons from the start (GDD technical requirement). (Cody)
- [ ] Display: GDD wants 1920x1080 with a 4K option. The current 640x360 viewport scales by exactly 3x and 6x, so it fits. Keep integer scaling; add UI scale and zoom options later. (Ledan to confirm; no display settings were changed in 1.5)
- [ ] Art: placed fence and path tiles, bed sprite, Stardew-like HUD frame, more ground variation, more contrast for watered soil. (ART)

## Direction: creature-loop vertical slice (user confirmed 2026-11-01)
The GDD's suggested order is a suggestion, not a rule. With limited weekly resources, the next work proves the unique hook:
Assessment, bond, breed, first baby. Battles, tournaments, village, reputation, world map, and mobile come after the slice.
Test creature: the Cinderkin (`docs/creatures/cinderkin.md`). Slice simplifications: all breeding produces eggs, fixed hatch time, no climate or recovery timers.

## Slice 1: Food, shop, monster data, Cinderkin (Cody items done in M2, branch feature/m2-food-assessment)
- [x] Coins, shop (seeds), selling crops (Cody)
- [x] Monster data resource per the GDD (species, family, gender, rank, stats HP/STR/DEF/INT/SPD with per-stat letters, bond, favorite food, parentage) (Cody)
- [x] Cinderkin species data (Critter, Woodland, favorite food Wet Waxweed) and the Wet Waxweed crop, which must be planted near trees (Cody)
- [ ] Cinderkin sprites, portrait, Waxweed icon (ART, branch art/cinderkin)

## Slice 2: Assessment and the first monster (Cody items done in M2; the opening and character creation are skipped, a placeholder farm portal starts the Assessment; habitat is a data/state stub until Slice 3)
- [x] One biome room (Woodland), 5 traps, random creature movement, rank odds D 79 / C 20 / B 1, keep one or use all 5 (Cody)
- [x] First monster sets the farm's starting biome and its habitat is pre-built (Cody)
- [ ] A few more Woodland creatures and room art (ART)

## Slice 3: Pasture, barn, bonding
- [ ] Pasture (6), the starting habitat (12), barn (20 stalls), Bond bar (25% barn, 100% star), feeding, daily food and water, party of 2 (Cody)
- [ ] Pasture, habitat, barn art (ART)

## Slice 4: Nursery and the first baby
- [ ] Nursery, opposite-gender pair with stars, Pedigree and modifier, stat inheritance (S+5, A+4, B+2, C+1, D+0), parentage, egg with fixed hatch time, baby with random gender (Cody)
- [ ] Small family crossing grid (2 families, a few species, diagonal gives Pedigree species) (Cody, user for content)
- [ ] Egg, baby, and nursery art (ART)

## After the slice (order to be revisited)
- [ ] Battles (1 to 2 creatures, turn-based), tournaments (story-gating), world map, portals, taming by food, battle, and trap
- [ ] Opening and character creation, village, villagers (`docs/VILLAGERS.md`), reputation, economy, climate and recovery timers, options, mobile

## Conventions
- Data in `resources/` as `.tres`; logic in `scripts/`; undecided numbers live in config resources, never hard-coded.
- Pixel-perfect rendering: nearest filtering, integer scaling.
- Feature branches; Ledan reviews, runs `tests/run_all.sh`, and merges to `main`.
