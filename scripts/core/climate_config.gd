class_name ClimateConfig
extends Resource
## PLACEHOLDER HOOK - climate is an OPEN DESIGN QUESTION.
##
## Nothing reads this yet. It exists so climate/weather data has an agreed home
## once the design owner decides how it works (weather odds per season,
## temperature, effects on crops/creatures...).
## TODO(design): define climate rules, then consume this from Clock/FarmGrid.

## Keyed by season name ("SPRING", "SUMMER", "FALL", "WINTER"); each value is a
## free-form Dictionary of climate parameters. Intentionally empty for now.
@export var season_climate: Dictionary = {
	"SPRING": {},
	"SUMMER": {},
	"FALL": {},
	"WINTER": {},
}


func get_for_season(season_name: String) -> Dictionary:
	return season_climate.get(season_name, {})
