# MBOA Roadmap

Source of truth: `docs/GDD.md` (GDD dated Oct 26, 2026). Where this file and the GDD disagree, the GDD wins.
Reviewed against the full GDD by Ledan. Open and conflicting items are tracked in `docs/OPEN_QUESTIONS.md`.

Owners: Cody = systems/GDScript, ART = pixel art, Ledan = integration, structure, GDD consistency.
Order follows the GDD's "Suggested build order" (steps 1-6), with breeding, village, and reputation after it.

## Milestone 1: Clock, farm, sleep, pass-out (build order step 1). Merged to main.
- [x] Continuous clock autoload with midnight tired state and 2:00 AM pass-out (Cody)
- [x] Player, farm grid (till, plant, water, grow, harvest), bed, HUD, day/night tint (Cody)
- [x] Farm tileset, player sheet (4-frame idle and walk), 4-stage crop, wired in (ART, Cody)
- [x] 200 headless tests (`tests/run_all.sh`)

### Milestone 1.5: Align with the GDD (do next, small)
- [x] Pass-out per GDD: lose a percentage of carried money and a fixed bonding drop for monsters with the player; wakes in bed. Rework `PassOutConfig`: keep `gold_penalty_fraction` (value open), add `party_bond_drop` (inactive until monsters exist), drop the invented `wake_hour_delay` and `energy_penalty_fraction`, or keep them at 0 and mark them non-GDD. (Cody)
- [x] Remove or rename the "climate" per-season hook. In the GDD, climate means managing the egg or pregnancy environment (Milestone 7), not weather or seasons. Whether seasons change anything beyond crops is an open question. (Cody)
- [x] Energy: two bars, health and stamina, both 100%. Stamina drops per tool use; at 0 the player is slowed and cannot use tools. Refill by eating, sleeping, or a hot spring. Health outside battle is an open question, so stub it. (Cody)
- [x] Tools per GDD: Pulaski (axe and hoe in one), sickle, pickaxe, watering can; 1 tile at base level. Tree clearing: four stages (seed, seedling, sapling, grown); seeds and seedlings dug out; sapling 3 Pulaski hits; grown tree 10 swings (6 to fell, 4 for the stump). (Cody)
- [x] Crop data: four growth stages, season tag, growth days as data in `resources/` (values open). (Cody)
- [x] Save and load across days and seasons from the start (GDD technical requirement). (Cody)
- [ ] Display: GDD wants 1920x1080 with a 4K option. The current 640x360 viewport scales by exactly 3x and 6x, so it fits. Keep integer scaling; add UI scale and zoom options later. (Ledan to confirm; no display settings were changed in 1.5)
- [ ] Art: placed fence and path tiles, bed sprite, Stardew-like HUD frame, more ground variation, more contrast for watered soil. (ART)

## Milestone 2: Food, shop, and the Assessment (build order step 2)
- [ ] Seasonal crops, shop (seeds), selling crops, Coins (Cody)
- [ ] Monster data resource: species, family (7), gender, rank D-S, stats HP/STR/DEF/INT/SPD, per-stat letter, bond 0-100%, favorite food, parentage, skills (Cody)
- [ ] Character creation: name, farm name, gender, body, skin tone, hair, outfit colors (Cody, ART)
- [ ] Opening: Association letter, arrival, Angie (Cody)
- [ ] Assessment: pick a Biome room (Meadowlands, Woodland, Marsh, Lake and Coast), 5 traps, random creature movement, rank display, rank odds D 79% / C 20% / B 1%, keep one or use all 5 traps (Cody)
- [ ] Biome room art, first creatures, trap and bait sprites, Angie portrait (ART)
- [ ] Farm start state from the first monster's biome, Angie's walkthrough, 20 favorite-food items, 45 favorite seeds (Cody)

## Milestone 3: Habitats, pasture, barn, bonding (build order step 3)
- [ ] Pasture (6 spots), habitats (12 monsters each, built with biome ingredients and Rowan), barn (20 stalls, 4 upgrades to 100) (Cody)
- [ ] Bond bar: 25% moves to barn, 100% earns the breeding star; feeding, daily food and water in the barn, party of up to 2 (Cody)
- [ ] Kitchen and kibble; per-monster random tastes (Cody)
- [ ] Day 2 with Tom: 5 basic traps, trap recipe, first portal (Cody)
- [ ] Habitat, barn, pasture art, creature sprites (ART)

## Milestone 4: Battles, 1 to 2 creatures (build order step 4)
- [ ] Turn-based battle, direct or auto control (INT picks auto skills), wild recruit chance after defeat, defeat and Vet revive (Cody)
- [ ] Battle UI, creature battle sprites, 64x64 portraits (ART)
- Needs design first: moves, type matchups, damage formula, turn rules.

## Milestone 5: Seasonal tournament (build order step 5)
- [ ] Optional seasonal tournament; wins give a chance to raise farm rank and size and build a new habitat (Cody)
- Needs design first: bracket format, plus habitat gating (see open questions).

## Milestone 6: World map and taming (build order step 6)
- [ ] World map, screen-to-screen travel on the same clock, portals and unlocks (Cody)
- [ ] Taming by food, battle, and trap (three trap tiers, bait, biome sets) (Cody)

## Milestone 7+: After the GDD build order
- [ ] Breeding: Nursery, Pedigree and modifier, family crossing grid (7x7), modifiers Plant and Elemental, stat inheritance, parentage, recipes, eggs and pregnancy with climate, recovery timers
- [ ] Village: Shop, Tavern board, Arena, Job board, Monster Hunter Association, appraisal and egg evaluation
- [ ] Villagers: 20 named, friendship hearts, gifts, heart events, dating (needs the full villager table)
- [ ] Economy, releasing, seasonal festival, reputation (six categories, guarded A and S areas)
- [ ] Options: UI scale, zoom, colorblind mode, 4K; mobile controls and builds

## Conventions
- Data in `resources/` as `.tres`; logic in `scripts/`; undecided numbers live in config resources, never hard-coded.
- Pixel-perfect rendering: nearest filtering, integer scaling.
- Feature branches; Ledan reviews, runs `tests/run_all.sh`, and merges to `main`.
