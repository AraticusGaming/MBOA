class_name PenData
extends Resource
## A monster home that is not a biome habitat: the pasture and the barn
## (GDD "Farm habitats and pasture"). One .tres per pen in resources/buildings/.
## Biome habitats use HabitatData (capacity 12, GDD).

@export var id: StringName = &""
@export var display_name: String = ""
## Spots at level 0 (GDD: pasture 6, barn 20 stalls).
@export_range(1, 200) var capacity: int = 6
## Spots added per upgrade (GDD barn: 20 -> 100 over four upgrades = +20).
@export_range(0, 100) var upgrade_step: int = 0
## GDD barn: four upgrades.
@export_range(0, 10) var max_upgrades: int = 0
## Cost of each upgrade (Coins). GDD: OPEN; [] = free (PLACEHOLDER).
@export var upgrade_costs: PackedInt32Array = PackedInt32Array()
## GDD: barn monsters need food and water every day; pasture monsters don't.
@export var needs_daily_care: bool = false
## GDD: only bonded monsters (MonsterConfig.barn_bond) may move in.
@export var requires_bond: bool = false
## Placeholder pen color (no pen/barn art yet).
@export var color: Color = Color(0.6, 0.5, 0.35)


func get_capacity(upgrades: int = 0) -> int:
	return capacity + upgrade_step * clampi(upgrades, 0, max_upgrades)


func get_upgrade_cost(level: int) -> int:
	return upgrade_costs[level] if level >= 0 and level < upgrade_costs.size() else 0
