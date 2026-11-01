class_name SpeciesCatalog
extends Resource
## All species definitions (resources/monsters/species_catalog.tres).

const DEFAULT_PATH := "res://resources/monsters/species_catalog.tres"

@export var species: Array[SpeciesData] = []


static func get_default() -> SpeciesCatalog:
	var cat := load(DEFAULT_PATH) as SpeciesCatalog
	return cat if cat else SpeciesCatalog.new()


func get_species(id: StringName) -> SpeciesData:
	for s in species:
		if s and s.id == id:
			return s
	return null


## Wild-catchable species living in `biome` (SpeciesData.Biome).
func get_wild_in_biome(biome: int) -> Array[SpeciesData]:
	var out: Array[SpeciesData] = []
	for s in species:
		if s and s.wild_catchable and s.lives_in(biome):
			out.append(s)
	return out
