class_name MonsterFactory
extends RefCounted
## Creates monsters from a species and a target overall rank.
##
## Stat roll (not GDD, placeholder method): each stat letter is the target
## rank +/- MonsterConfig.letter_spread (clamped D..S); letter sets whose
## average (rounded down, GDD rule) isn't the target are re-rolled. Each stat
## value is then rolled uniformly inside its letter's band
## (stat_letters_1_20: D 1-4, C 5-9, B 10-14, A 15-17, S 18-20). So the
## monster's computed rank always equals the requested rank.

const MAX_TRIES := 200


## A new wild monster of `species` with overall rank `rank` ("D".."S").
static func create(species: SpeciesData, rank: String, rng: RandomNumberGenerator,
		config: MonsterConfig = null) -> Monster:
	var cfg := config if config else Monster._config()
	var m := Monster.new()
	m.species_id = species.id
	m.uid = make_uid(rng)
	m.gender = Monster.Gender.FEMALE if rng.randf() < cfg.female_chance else Monster.Gender.MALE
	m.favorite_food_id = species.favorite_food_id
	var bands: StatLetterBands = species.stat_bands if species.stat_bands \
		else load(Monster.DEFAULT_BANDS_PATH) as StatLetterBands
	m.stats = roll_stats(bands, rank, rng, cfg.letter_spread)
	m.variant = species.get_variant_for_rank(rank)
	m.bond = 0.0
	return m


## Stat values (by Monster.STAT_KEYS) whose letters average to `rank`.
static func roll_stats(bands: StatLetterBands, rank: String, rng: RandomNumberGenerator,
		spread: int = 1) -> Dictionary:
	var letters := roll_letters(rank, rng, spread)
	var out := {}
	for i in Monster.STAT_KEYS.size():
		var band := bands.get_band(letters[i])
		out[Monster.STAT_KEYS[i]] = rng.randi_range(band.x, band.y)
	return out


## Five stat letters whose overall rank (average, rounded down) is `rank`.
static func roll_letters(rank: String, rng: RandomNumberGenerator, spread: int = 1) -> Array:
	var target := StatLetterBands.letter_index(rank)
	if target < 0:
		target = 0
	var n := Monster.STAT_KEYS.size()
	for attempt in MAX_TRIES:
		var letters: Array = []
		for i in n:
			var idx := clampi(target + rng.randi_range(-spread, spread), 0, StatLetterBands.LETTERS.size() - 1)
			letters.append(StatLetterBands.LETTERS[idx])
		if StatLetterBands.overall_rank(letters) == StatLetterBands.LETTERS[target]:
			return letters
	var flat: Array = []
	for i in n:
		flat.append(StatLetterBands.LETTERS[target])
	return flat


static func make_uid(rng: RandomNumberGenerator) -> String:
	return "m%08x%08x" % [rng.randi(), rng.randi()]
