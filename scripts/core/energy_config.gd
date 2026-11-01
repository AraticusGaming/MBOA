class_name EnergyConfig
extends Resource
## Health and stamina tuning (GDD "Energy": two bars, both start at 100%).
## Stamina drops with each tool use (per-tool cost lives in ToolData); at 0 the
## player is slowed and can't use tools; eating, sleeping and resting in a hot
## spring refill it. Values marked PLACEHOLDER are not in the GDD.

## Bars are percentages in the GDD; 100 = full bar.
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
## Movement speed multiplier at 0 stamina ("slowed"). PLACEHOLDER: the GDD
## does not say how much slower.
@export_range(0.05, 1.0, 0.05) var exhausted_speed_multiplier: float = 0.5
## Stamina restored per in-game hour resting in a hot spring. PLACEHOLDER
## (hot springs are not placed in the world yet).
@export_range(0.0, 100.0, 1.0) var hot_spring_stamina_per_game_hour: float = 50.0
