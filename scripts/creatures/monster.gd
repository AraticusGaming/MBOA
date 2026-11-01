class_name Monster
extends RefCounted
## One monster instance (GDD "Monster data"): species, family (from the
## species), gender, rank D-S, stats HP/STR/DEF/INT/SPD, per-stat letters,
## bond 0-100%, favorite food, parentage, skills. Rank is not stored: GDD,
## the overall rank is the average of the stat letters, rounded down.

enum Gender { MALE, FEMALE }

const STAT_KEYS: PackedStringArray = ["hp", "str", "def", "int", "spd"]
const STAT_LABELS: PackedStringArray = ["HP", "STR", "DEF", "INT", "SPD"]
const DEFAULT_BANDS_PATH := "res://resources/stats/stat_letters_1_20.tres"
const CONFIG_PATH := "res://resources/monsters/monster_config.tres"

## Unique id (saves, party, parentage).
var uid: String = ""
var species_id: StringName = &""
var nickname: String = ""
var gender: int = Gender.FEMALE
## Base stats by STAT_KEYS key.
var stats: Dictionary = {"hp": 1, "str": 1, "def": 1, "int": 1, "spd": 1}
## Bond bar 0-100 (%).
var bond: float = 0.0
var favorite_food_id: StringName = &""
## Parentage only (GDD): up to two {uid, species_id} records, [] = wild.
var parents: Array = []
## Skill ids (GDD: skills; none defined yet).
var skills: Array = []
## Named variant (e.g. &"blue_flame" for an S-rank Cinderkin).
var variant: StringName = &""
## Biome it was caught in (SpeciesData.Biome, -1 = bred/unknown).
var origin_biome: int = -1
## Where it lives: &"party", &"habitat", &"pasture", &"barn" (Slice 3).
var home: StringName = &""

var _species: SpeciesData


func get_species() -> SpeciesData:
	if _species == null or _species.id != species_id:
		_species = SpeciesCatalog.get_default().get_species(species_id)
	return _species


func get_family() -> int:
	var s := get_species()
	return s.family if s else -1


func get_bands() -> StatLetterBands:
	var s := get_species()
	if s and s.stat_bands:
		return s.stat_bands
	return load(DEFAULT_BANDS_PATH) as StatLetterBands


func get_stat(key: String) -> int:
	return int(stats.get(key, 0))


## GDD: each stat has its own letter.
func get_stat_letter(key: String) -> String:
	return get_bands().get_letter(get_stat(key))


func get_stat_letters() -> Array:
	var out: Array = []
	for k in STAT_KEYS:
		out.append(get_stat_letter(k))
	return out


## GDD: overall rank = average of the stat letters, rounded down.
func get_rank() -> String:
	return StatLetterBands.overall_rank(get_stat_letters())


func get_display_name() -> String:
	if nickname != "":
		return nickname
	var s := get_species()
	if s == null:
		return String(species_id)
	return s.get_variant_name(variant)


func get_gender_name() -> String:
	return "Male" if gender == Gender.MALE else "Female"


func add_bond(delta: float) -> void:
	bond = clampf(bond + delta, 0.0, _config().bond_max)


## GDD: at 25% bond it can go to the barn.
func can_go_to_barn() -> bool:
	return bond >= _config().barn_bond


## GDD: at 100% it has the breeding star.
func has_star() -> bool:
	return bond >= _config().star_bond


func is_wild_caught() -> bool:
	return parents.is_empty()


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"species": String(species_id),
		"nickname": nickname,
		"gender": gender,
		"stats": stats.duplicate(),
		"bond": bond,
		"favorite_food": String(favorite_food_id),
		"parents": parents.duplicate(true),
		"skills": skills.duplicate(),
		"variant": String(variant),
		"origin_biome": origin_biome,
		"home": String(home),
	}


static func from_dict(d: Dictionary) -> Monster:
	var m := Monster.new()
	m.uid = String(d.get("uid", ""))
	m.species_id = StringName(String(d.get("species", "")))
	m.nickname = String(d.get("nickname", ""))
	m.gender = int(d.get("gender", Gender.FEMALE))
	var st: Dictionary = d.get("stats", {})
	for k in STAT_KEYS:
		m.stats[k] = int(st.get(k, 1))
	m.bond = float(d.get("bond", 0.0))
	m.favorite_food_id = StringName(String(d.get("favorite_food", "")))
	m.parents = (d.get("parents", []) as Array).duplicate(true)
	m.skills = (d.get("skills", []) as Array).duplicate()
	m.variant = StringName(String(d.get("variant", "")))
	m.origin_biome = int(d.get("origin_biome", -1))
	m.home = StringName(String(d.get("home", "")))
	return m


static func _config() -> MonsterConfig:
	var c := load(CONFIG_PATH) as MonsterConfig
	return c if c else MonsterConfig.new()
