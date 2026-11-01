extends MboaTestBase
## Monster data (GDD "Monster data"): species catalog, the Cinderkin test
## creature (docs/creatures/cinderkin.md), rank-consistent stat rolls,
## serialization, bond thresholds, roster/party in PlayerState and saves.

const PlayerStateScript := preload("res://scripts/core/player_state.gd")

var _cleanup: Array = []


func _run_tests() -> void:
	_test_species()
	_test_cinderkin()
	_test_factory_bands()
	_test_monster_data()
	_test_player_state()
	for n in _cleanup:
		n.free()


func _test_species() -> void:
	var cat := SpeciesCatalog.get_default()
	check(cat.species.size() >= 5, "species catalog loads")
	check_eq(SpeciesData.FAMILY_NAMES.size(), 7, "GDD: seven families")
	check_eq(SpeciesData.BIOME_NAMES, PackedStringArray(["Meadowlands", "Woodland", "Marsh", "Lake and Coast"]),
		"GDD: four starter biomes")
	var items := ItemCatalog.get_default()
	var seen := {}
	for s in cat.species:
		check(not seen.has(s.id) and s.display_name != "", "species %s unique and named" % s.id)
		seen[s.id] = true
		check(s.stat_bands != null and s.stat_bands.is_valid(), "%s has valid stat bands" % s.id)
		check(items.has_item(s.favorite_food_id), "%s favorite food is an item" % s.id)
		check_eq(s.favorite_crops.size(), 4, "%s: a favorite crop slot per season" % s.id)
		check(not s.biomes.is_empty(), "%s lives in a biome" % s.id)
	var rock := cat.get_species(&"rockback")
	check(rock != null and rock.family == SpeciesData.Family.AQUATIC and rock.modifier == &"earth"
		and rock.favorite_food_id == &"snouter_roe", "GDD Rockback: Aquatic + Earth, favorite Snouter Roe")
	check_eq(cat.get_species(&"crow").get_family_name(), "Bird", "Crow is a Bird")
	check(cat.get_wild_in_biome(SpeciesData.Biome.WOODLAND).size() >= 2, "several Woodland species")
	check_eq(SpeciesData.biome_from_id("woodland"), SpeciesData.Biome.WOODLAND, "biome id lookup")


func _test_cinderkin() -> void:
	var c := SpeciesCatalog.get_default().get_species(&"cinderkin")
	check(c != null, "Cinderkin species exists")
	check_eq(c.family, SpeciesData.Family.CRITTER, "Cinderkin: Critter family")
	check_eq(c.modifier, &"fire", "Cinderkin: Fire modifier")
	check(c.lives_in(SpeciesData.Biome.WOODLAND), "Cinderkin: Woodland")
	check_eq(c.favorite_food_id, &"wet_waxweed", "Cinderkin: favorite food Wet Waxweed")
	check(c.wild_catchable, "Cinderkin: catchable in the wild")
	check_eq(c.get_variant_for_rank("S"), &"blue_flame", "S rank = blue-flame old variant")
	check_eq(c.get_variant_for_rank("B"), &"", "no variant below S")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s_rank := MonsterFactory.create(c, "S", rng)
	check(s_rank.variant == &"blue_flame" and s_rank.get_display_name() == "Blue-flame Cinderkin",
		"S-rank Cinderkin is the blue-flame variant")
	var d_rank := MonsterFactory.create(c, "D", rng)
	check(d_rank.variant == &"" and d_rank.get_display_name() == "Cinderkin", "D-rank: plain Cinderkin")


func _test_factory_bands() -> void:
	var bands := load("res://resources/stats/stat_letters_1_20.tres") as StatLetterBands
	var species := SpeciesCatalog.get_default().get_species(&"cinderkin")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for rank in ["D", "C", "B", "A", "S"]:
		var ok := true
		var in_band := true
		for i in 300:
			var m := MonsterFactory.create(species, rank, rng)
			if m.get_rank() != rank:
				ok = false
			for k in Monster.STAT_KEYS:
				if not bands.is_valid_value(m.get_stat(k)):
					in_band = false
		check(ok, "300 rolls at rank %s all compute overall rank %s" % [rank, rank])
		check(in_band, "rank %s stats stay inside 1-20" % rank)
	# Letters vary (+/-1) but always average to the target.
	var varied := false
	for i in 50:
		var letters := MonsterFactory.roll_letters("C", rng, 1)
		if letters.has("D") or letters.has("B"):
			varied = true
		if StatLetterBands.overall_rank(letters) != "C":
			check(false, "letters average to C")
	check(varied, "stat letters vary around the rank")
	var s_letters := MonsterFactory.roll_letters("S", rng, 1)
	check_eq(s_letters, ["S", "S", "S", "S", "S"], "overall S needs all S letters (spread 1)")
	# Seeded: same seed -> same monster.
	var a := RandomNumberGenerator.new()
	a.seed = 99
	var b := RandomNumberGenerator.new()
	b.seed = 99
	check_eq(MonsterFactory.create(species, "B", a).to_dict(), MonsterFactory.create(species, "B", b).to_dict(),
		"seeded creation is deterministic")
	# Genders: both appear.
	var genders := {}
	for i in 40:
		genders[MonsterFactory.create(species, "D", rng).gender] = true
	check(genders.size() == 2, "random gender: both appear")


func _test_monster_data() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var m := MonsterFactory.create(SpeciesCatalog.get_default().get_species(&"crow"), "C", rng)
	check(m.uid != "" and m.species_id == &"crow", "monster has uid and species")
	check_eq(m.get_family(), SpeciesData.Family.BIRD, "family from species")
	check_eq(m.favorite_food_id, m.get_species().favorite_food_id, "favorite food from species")
	check_eq(m.get_stat_letters().size(), 5, "five stat letters")
	check(m.is_wild_caught() and m.parents.is_empty(), "wild: no parentage")
	check_eq(m.bond, 0.0, "new monster bond 0%")
	m.add_bond(24.0)
	check(not m.can_go_to_barn(), "24%: not ready for the barn")
	m.add_bond(1.0)
	check(m.can_go_to_barn() and not m.has_star(), "GDD: 25% -> barn")
	m.add_bond(500.0)
	check(m.bond == 100.0 and m.has_star(), "GDD: 100% -> star (clamped)")
	m.add_bond(-500.0)
	check_eq(m.bond, 0.0, "bond clamps at 0")
	m.parents = [{"uid": "p1", "species_id": "crow"}, {"uid": "p2", "species_id": "robin"}]
	m.skills = ["peck"]
	m.bond = 42.5
	m.origin_biome = SpeciesData.Biome.WOODLAND
	var json: Dictionary = JSON.parse_string(JSON.stringify(m.to_dict()))
	var back := Monster.from_dict(json)
	check_eq(JSON.stringify(back.to_dict()), JSON.stringify(m.to_dict()), "monster JSON round-trip")
	check_eq(back.get_rank(), m.get_rank(), "rank survives (computed from stats)")
	check_eq(back.parents[1].species_id, "robin", "parentage survives")


func _test_player_state() -> void:
	var ps: Node = PlayerStateScript.new()
	root.add_child(ps)
	_cleanup.append(ps)
	check_eq(ps.get_party_max(), 2, "GDD: party of up to two")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cat := SpeciesCatalog.get_default()
	var m1 := MonsterFactory.create(cat.get_species(&"cinderkin"), "D", rng)
	var m2 := MonsterFactory.create(cat.get_species(&"crow"), "C", rng)
	var m3 := MonsterFactory.create(cat.get_species(&"blue_jay"), "B", rng)
	check(ps.add_monster(m1) and ps.add_monster(m2), "two join the party")
	check(not ps.add_monster(m3), "third doesn't fit the party")
	check(ps.monsters.size() == 3 and ps.party.size() == 2, "roster 3, party 2")
	check_eq(ps.get_monster(m3.uid), m3, "lookup by uid")
	var data: Dictionary = JSON.parse_string(JSON.stringify(ps.to_dict()))
	var ps2: Node = PlayerStateScript.new()
	root.add_child(ps2)
	_cleanup.append(ps2)
	ps2.from_dict(data)
	check_eq(ps2.monsters.size(), 3, "roster saved/loaded")
	check(ps2.party.size() == 2 and ps2.party[0].uid == m1.uid and ps2.party[1].uid == m2.uid,
		"party saved/loaded by uid")
	check_eq(ps2.party[0].get_stat_letters(), m1.get_stat_letters(), "loaded stats match")
	# Pass-out bond drop: 0 by default, applies to real monsters if set.
	m1.bond = 50.0
	ps.apply_sleep(true)
	check_eq(m1.bond, 50.0, "default bond drop 0: no change")
	ps.pass_out_config = ps.pass_out_config.duplicate()
	ps.pass_out_config.party_bond_drop = 5.0
	ps.apply_sleep(true)
	check(m1.bond == 45.0 and m3.bond == 0.0, "non-zero drop hits party monsters only")
