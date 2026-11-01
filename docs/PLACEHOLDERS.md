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
