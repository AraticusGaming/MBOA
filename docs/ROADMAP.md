# MBOA Roadmap (follows the GDD's suggested build order)

Owners: Cody = systems/GDScript, ART = pixel art, Ledan = integration, structure, GDD consistency.

## Milestone 1: Core loop skeleton
- [x] Continuous clock (time of day, days, seasons) as an autoload (Cody)
- [x] Player movement and a basic farm scene (Cody)
- [x] Farm tiles: till, plant, water, grow (Cody)
- [x] Sleeping and pass-out, day rollover (Cody)
- [ ] Placeholder tileset and player sprite (ART)
- Open question: pass-out penalty, climate. Both are configurable placeholders for now
  (`resources/pass_out_config.tres`, all penalties 0; `resources/climate_config.tres`, unused hook).

## Milestone 2: Food and Assessment
- [ ] Growing and harvesting food crops (Cody)
- [ ] Assessment trapping mechanic (design first, then Cody)
- [ ] Crop, food, and trap sprites (ART)

## Milestone 3: Habitat, barn, bonding
- [ ] Habitats and barn (Cody)
- [ ] Creature care and bonding (Cody)
- [ ] Creature sprites and habitat art (ART)

## Milestone 4: Battles (1-2 creatures)
- [ ] Minimal battle system (Cody)
- [ ] Battle UI and portraits at 64x64 (ART)

## Milestone 5+: Breeding, seasons content, optional tournaments
- [ ] Breeding, taming variety, tournaments (to be broken down after Milestone 4)

## Conventions
- Data in `resources/` as `.tres`; logic in `scripts/`; no art generated into `scripts/`.
- Pixel-perfect rendering: nearest filtering, integer scaling (already set in project.godot).
- Commit to feature branches; Ledan merges to `main`.
