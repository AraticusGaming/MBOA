# MBOA Placeholders (not GDD)

Everything listed here is **not GDD, placeholder**. These are working values and rules so the game runs; the user
confirms or replaces them. Exact GDD values and `docs/DECISIONS.md` rulings are not listed here. Each item names
where the value lives so it can be changed without code edits where possible.

Rulings from Ledan (Stardew-style), awaiting the user's confirmation, are marked **(Ledan)**. Rules the user has confirmed in
`docs/DECISIONS.md` are marked "confirmed"; only their numbers are placeholders here.

## Energy and movement
| Item | Value | Where |
|------|-------|-------|
| Stamina cost per tool use (confirmed ~2) | 2 | `resources/tools/*.tres` `stamina_cost` |
| Movement at 0 stamina (confirmed) | 50% | `resources/energy_config.tres` `exhausted_speed_multiplier` |
| Tired and exhausted slowdowns don't stack; use the worse (minimum) multiplier (confirmed) | min(0.75, 0.5) | `scripts/farm/player.gd` `get_current_speed()` |
| Tired (midnight) movement | 75% | `scenes/world/player.tscn` / `player.gd` `tired_speed_multiplier` |
| Eating refills by food (rule confirmed); per-food values | Turnip 15, Carrot 20, Tomato 25, Pumpkin 40, Placeholder Crop 10 | `resources/items/*.tres` `stamina_refill` |
| Fallback refill for food without a value | 25 | `resources/energy_config.tres` `eat_stamina_refill` |
| Hot spring refills at a steady rate (rule confirmed); rate | 5 stamina per real second | `energy_config.tres` `hot_spring_stamina_per_second`, `PlayerState.soak_in_hot_spring(delta)` |
| Health outside battle (on hold, off the critical path) | stub (no effect) | `PlayerState.damage()/heal()` |
| Pass-out bond drop | 0 (inactive) | `resources/pass_out_config.tres` `party_bond_drop` |
| Pass-out reputation hit (DECISIONS: ~1-3%) | 0.02, inactive until reputation exists | `pass_out_config.tres` `reputation_penalty` |

## Farm clearing and trees
| Item | Value | Where |
|------|-------|-------|
| Sickle clears grass and weeds (rule confirmed; hits are placeholders) | 1 hit each | `resources/obstacles/grass.tres`, `weed.tres` |
| Pickaxe breaks rocks (rule confirmed; hits/drop placeholders) | 2 hits, drops 1 stone | `resources/obstacles/rock.tres` |
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
| Wet Waxweed (Cinderkin food; farmable near trees: user ruling) | spring/summer/fall, 2/2/2 days | `resources/crops/wet_waxweed.tres` |
| "Near trees" for Wet Waxweed | a sapling, grown tree or stump within 1 cell (8 neighbours); checked at planting only, felling the tree later doesn't kill it | `CropData.requires_adjacent_tree`, `tree_search_radius`, `min_tree_stage`; `FarmGrid.meets_placement()` |
| Wet Waxweed "must be transported wet" (lore) | not modelled; the item is always wet | - |
| Out-of-season crops die at the season change (rule confirmed) | on; the plot goes back to tilled soil (no dead-crop object) | `FarmGrid.kill_out_of_season_crops` |

## Coins, items and inventory
GDD: currency is Coins; the shop sells "seeds and other goods"; every item has a buy and a sell value. The numbers
and the inventory rules below are placeholders.

| Item | Value | Where |
|------|-------|-------|
| Starting Coins (new game) | 500 | `resources/economy_config.tres` `starting_coins` |
| Starting items (new game) | 10 Turnip Seeds | `economy_config.tres` `starting_items` |
| Inventory size | 24 slots | `economy_config.tres` `inventory_slots` |
| Max stack | 99 per slot (all items) | `resources/items/*.tres` `max_stack` |
| Hotbar | tools in keys 1-4, then the first 5 inventory slots in keys 5-9 | `economy_config.tres` `hotbar_item_slots`, `Player.hotbar_item_slots` |
| Items that don't fit (full inventory) | lost (no ground drops yet); harvest is refused when there's no space | `PlayerState.add_item()`, `Player._harvest()` |
| Seeds are inventory items (the old "Seeds" tool is gone); planting uses one seed | rule | `Player.act_on_cell()` |
| Harvested crops are edible (flat stamina refill, see Energy) | all crops | `resources/items/<crop>.tres` `edible` |
| One crop per harvest | 1 | `resources/crops/*.tres` `harvest_amount` |
| Item colors (no item art yet) | colored swatches | `resources/items/*.tres` `color` |

### Prices (Coins)
| Item | Buy | Sell |
|------|-----|------|
| Turnip Seeds | 20 | 10 |
| Carrot Seeds | 30 | 15 |
| Tomato Seeds | 50 | 25 |
| Pumpkin Seeds | 100 | 50 |
| Turnip | - | 35 |
| Carrot | - | 45 |
| Tomato | - | 60 |
| Pumpkin | - | 140 |
| Placeholder Crop | - | 10 |
| Waxweed Starter (plants Wet Waxweed) | 40 | 20 |
| Wet Waxweed | - | 50 (not eaten by the player) |
| Wood | - | 2 |
| Stone | - | 2 |

## Shop
| Item | Value | Where |
|------|-------|-------|
| Seed shop location | a counter with a placeholder shopkeeper on the farm (top right); no town yet | `scenes/world/shop_counter.tscn`, `scenes/farm/farm.tscn` |
| Shopkeeper identity | unnamed placeholder (the GDD/VILLAGERS don't assign the seed shop yet) | `ShopCounter._draw()` |
| Stock | the four seeds plus Waxweed Starter; only seeds that grow in the current season (Stardew-style) | `resources/shop/seed_shop.tres` `stock`, `seasonal_seeds` |
| Selling | instant sale at the shop window (no shipping bin / overnight payout yet) | `ShopData.buys_from_player`, `Shop.sell_slot()` |
| Time pauses while the shop window is open | Stardew rule | `ShopUI` (`Clock.pause(&"shop")`) |
| Shop hours / closed days | none (always open) | - |
