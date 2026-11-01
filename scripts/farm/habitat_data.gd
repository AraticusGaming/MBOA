class_name HabitatData
extends Resource
## A biome habitat on the farm (GDD "Farm habitats and pasture"): each biome
## can have a small section on the farm; wild-caught monsters from that biome
## live there until bonded; it holds up to 12 monsters. DECISIONS.md: the farm
## starts with the first monster's biome habitat already built. Slice 2 only
## stores habitats as data/state; placement and art come in Slice 3.
## One .tres per biome: resources/habitats/<biome id>.tres.

const DIR := "res://resources/habitats/%s.tres"

@export var id: StringName = &""
@export var display_name: String = ""
@export var biome: SpeciesData.Biome = SpeciesData.Biome.WOODLAND
## GDD: up to 12 monsters at a time.
@export_range(1, 100) var capacity: int = 12
## Build ingredients (item id -> amount). GDD: not decided yet; empty.
@export var build_materials: Dictionary = {}


## Returns the HabitatData for `biome` (or null). Typed as Resource on purpose:
## a self-typed static return here leaks the script at exit (same quirk as
## ItemData in player.gd).
static func for_biome(biome: int) -> Resource:
	var bid := SpeciesData.BIOME_IDS[biome] if biome >= 0 and biome < SpeciesData.BIOME_IDS.size() else ""
	var path := DIR % bid
	return load(path) if bid != "" and ResourceLoader.exists(path) else null
