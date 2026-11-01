# MBOA Placeholders (not GDD)

Everything listed here is **not GDD, placeholder**. These are working values and rules so the game runs; the user
confirms or replaces them. Exact GDD values and `docs/DECISIONS.md` rulings are not listed here. Each item names
where the value lives so it can be changed without code edits where possible.

Rulings from Ledan (Stardew-style), awaiting the user's confirmation, are marked **(Ledan)**.

## Energy and movement
| Item | Value | Where |
|------|-------|-------|
| Stamina cost per tool use **(Ledan)** | 2 | `resources/tools/*.tres` `stamina_cost` |
| Movement at 0 stamina **(Ledan)** | 50% | `resources/energy_config.tres` `exhausted_speed_multiplier` |
| Tired and exhausted slowdowns don't stack; use the worse (minimum) multiplier **(Ledan)** | min(0.75, 0.5) | `scripts/farm/player.gd` `get_current_speed()` |
| Tired (midnight) movement | 75% | `scenes/world/player.tscn` / `player.gd` `tired_speed_multiplier` |
| Eating: flat stamina refill **(Ledan)** | 25 | `resources/energy_config.tres` `eat_stamina_refill` |
| Hot spring: flat stamina refill per rest **(Ledan)** | 50 | `resources/energy_config.tres` `hot_spring_stamina_refill` |
| Health outside battle **(Ledan)** | stub (no effect) | `PlayerState.damage()/heal()` |
| Pass-out bond drop **(Ledan)** | 0 (inactive) | `resources/pass_out_config.tres` `party_bond_drop` |
| Pass-out 10% loss is money only, not items **(Ledan)** | coins only | `PlayerState.apply_sleep()` |

## Farm clearing and trees
| Item | Value | Where |
|------|-------|-------|
| Sickle clears grass and weeds **(Ledan)** | 1 hit each | `resources/obstacles/grass.tres`, `weed.tres` |
| Pickaxe breaks rocks **(Ledan)** | 2 hits, drops 1 stone | `resources/obstacles/rock.tres` |
| Pulaski can't till a cell with an obstacle; only the obstacle's own tool works | rule | `FarmGrid.use_tool()` / `hit_obstacle()` |
| Starting grass/weed/rock layout | 9 cells | `scenes/farm/farm.tscn` `starting_obstacles` |
| Trees drop wood **(Ledan)** | sapling 1, felled 8, stump 2; dug-out seed/seedling 0 | `resources/trees/placeholder_tree.tres` |
| Tree growth times **(Ledan: data placeholders)** | 7 days per stage (seed, seedling, sapling) | `placeholder_tree.tres` `stage_days` |
| Digging out a seed/seedling | 1 Pulaski hit | `placeholder_tree.tres` `dig_out_hits` |
| Stone item | dropped by rocks | `resources/obstacles/rock.tres` `drop_item_id` |

## Crops
| Item | Value | Where |
|------|-------|-------|
| Crop list **(Ledan)** | Turnip (spring), Carrot (spring+fall), Tomato (summer), Pumpkin (fall), Placeholder Crop (all seasons, test/dev crop); no winter crop (Stardew) | `resources/crops/*.tres` |
| Days per growth stage **(Ledan)** | Turnip 1/1/2, Carrot 1/2/1, Tomato 2/2/2, Pumpkin 2/3/3, Placeholder 1/1/1 | `stage_days` |
| Crop sprites | all share `crop_basic.png`, tinted per crop | `sprite_tint` |
| Out-of-season crops die at the season change **(Ledan, Stardew rule)** | on; the plot goes back to tilled soil (no dead-crop object) | `FarmGrid.kill_out_of_season_crops` |
