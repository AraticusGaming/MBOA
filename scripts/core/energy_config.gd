class_name EnergyConfig
extends Resource
## Health and stamina tuning (GDD "Energy": two bars, both start at 100%).
## Stamina drops with each tool use (per-tool cost lives in ToolData); at 0 the
## player is slowed and can't use tools; eating, sleeping and resting in a hot
## spring refill it. Values marked PLACEHOLDER are not in the GDD.

## Bars are percentages in the GDD; 100 = full bar.
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
## Movement speed multiplier at 0 stamina ("slowed"). Not GDD, placeholder
## (Ledan ruling: 50%). It does NOT stack with the tired multiplier: the
## player moves at the worse (minimum) of the two (see docs/PLACEHOLDERS.md).
@export_range(0.05, 1.0, 0.05) var exhausted_speed_multiplier: float = 0.5
## Fallback stamina refill for food with no value of its own. DECISIONS.md:
## eating refills depending on the food eaten; each food sets
## ItemData.stamina_refill (values are placeholders until food values come).
@export_range(0.0, 100.0, 1.0) var eat_stamina_refill: float = 25.0
## DECISIONS.md: the hot spring refills at a steady rate. Stamina per real
## second while soaking. The rate is a placeholder; hot springs are not
## placed in the world yet.
@export_range(0.0, 100.0, 0.5) var hot_spring_stamina_per_second: float = 5.0
