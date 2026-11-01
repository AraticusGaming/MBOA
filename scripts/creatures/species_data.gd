class_name SpeciesData
extends Resource
## One monster species (GDD "Monster data", "Breeding families and the
## crossing grid"). One .tres per species in resources/monsters/species/.
## Fields the GDD fixes: family (one of the seven), modifier (Plant /
## Elemental such as Fire or Earth; a modifier result stays in its family),
## favorite food, a favorite crop per season. Biome assignments, stat ranges
## and colors are placeholders unless a species doc says otherwise
## (docs/creatures/*.md, docs/PLACEHOLDERS.md).

## GDD: the seven families. Plant and Elemental are modifiers, not families.
enum Family { BIRD, REPTILE, INSECT, ARACHNID, AQUATIC, BEAST, CRITTER }
## GDD: the four starter biomes (Assessment rooms / starting farm biome).
enum Biome { MEADOWLANDS, WOODLAND, MARSH, LAKE_AND_COAST }

const FAMILY_NAMES: PackedStringArray = ["Bird", "Reptile", "Insect", "Arachnid", "Aquatic", "Beast", "Critter"]
const BIOME_NAMES: PackedStringArray = ["Meadowlands", "Woodland", "Marsh", "Lake and Coast"]
const BIOME_IDS: PackedStringArray = ["meadowlands", "woodland", "marsh", "lake_and_coast"]

@export var id: StringName = &""
@export var display_name: String = ""
@export var family: Family = Family.CRITTER
## Breeding modifier this species is the result of (&"" = base species), e.g.
## &"fire" (Cinderkin), &"earth" (Rockback).
@export var modifier: StringName = &""
## Biomes where it lives in the wild (Biome values).
@export var biomes: PackedInt32Array = PackedInt32Array()
## Can be caught in the wild (Assessment, traps), not only bred.
@export var wild_catchable: bool = true
## Item id of its favorite food (GDD: e.g. Rockback -> Snouter Roe).
@export var favorite_food_id: StringName = &""
## GDD: a favorite crop for each season. Crop ids in GameClock.Season order
## (spring, summer, fall, winter); "" = none. PLACEHOLDER values.
@export var favorite_crops: PackedStringArray = PackedStringArray(["", "", "", ""])
## Letter bands for its stats (the GDD allows a range per stat, e.g. 1-20 or
## 1-25; only 1-20 is decided, so all five stats share these bands).
@export var stat_bands: StatLetterBands
## Named variants by overall rank letter, e.g. {"S": &"blue_flame"}.
@export var rank_variants: Dictionary = {}
## Display names of variants, e.g. {&"blue_flame": "Blue-flame Cinderkin"}.
@export var variant_names: Dictionary = {}
## Placeholder body color (no creature sprites yet).
## Animations idle_/walk_<down|left|right|up> (built from the ART sheet by
## tools/godot/build_art_resources.gd). null = colored placeholder.
@export var sprite_frames: SpriteFrames
## 64x64 portrait (ART assets/portraits/). null = none.
@export var portrait: Texture2D
@export var color: Color = Color(0.7, 0.7, 0.7)


func get_family_name() -> String:
	return FAMILY_NAMES[family] if family >= 0 and family < FAMILY_NAMES.size() else ""


func lives_in(biome: int) -> bool:
	return biomes.has(biome)


func get_favorite_crop(season: int) -> StringName:
	return StringName(favorite_crops[season]) if season >= 0 and season < favorite_crops.size() else &""


## Variant id for an overall rank letter (&"" = none).
func get_variant_for_rank(rank: String) -> StringName:
	return StringName(rank_variants.get(rank, rank_variants.get(StringName(rank), &"")))


func get_variant_name(variant: StringName) -> String:
	if variant == &"":
		return display_name
	return String(variant_names.get(variant, variant_names.get(String(variant), display_name)))


static func biome_name(biome: int) -> String:
	return BIOME_NAMES[biome] if biome >= 0 and biome < BIOME_NAMES.size() else ""


## Biome value for a string id like "woodland" (-1 if unknown).
static func biome_from_id(biome_id: String) -> int:
	return BIOME_IDS.find(biome_id)
