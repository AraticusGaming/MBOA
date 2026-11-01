extends MboaTestBase
## Slice 3 (GDD "Farm habitats and pasture", "Bonding", "Taking care of
## monsters"): capacities (pasture 6, habitat 12, barn 20 + 4 upgrades to
## 100), placement, moves, the 25% barn and 100% star thresholds, feeding
## (favorite > preferred > other, streak, daily cap), party of 2 from the
## barn, the daily bond tick, the pass-out drop when non-zero, Angie's gift
## and the save round-trip.

const PlayerStateScript := preload("res://scripts/core/player_state.gd")

var _cleanup: Array = []
var _rng := RandomNumberGenerator.new()


func _run_tests() -> void:
	_rng.seed = 11
	_test_data()
	_test_capacity_and_placement()
	_test_moves_and_thresholds()
	_test_party()
	_test_feeding()
	_test_daily_tick()
	_test_pass_out_drop()
	_test_angie_gift()
	_test_save_round_trip()
	for n in _cleanup:
		if is_instance_valid(n):
			n.free()


func _state() -> Node:
	var ps: Node = PlayerStateScript.new()
	root.add_child(ps)
	_cleanup.append(ps)
	ps.care_config = ps.care_config.duplicate()
	ps.care_config.angie_gift_enabled = false
	return ps


func _mon(species: StringName = &"cinderkin", biome: int = SpeciesData.Biome.WOODLAND) -> Monster:
	var m := MonsterFactory.create(SpeciesCatalog.get_default().get_species(species), "D", _rng)
	m.origin_biome = biome
	return m


## A state whose farm has the Woodland habitat (as after the Assessment).
func _farm() -> Node:
	var ps := _state()
	ps.farm_biome = SpeciesData.Biome.WOODLAND
	ps.build_habitat(SpeciesData.Biome.WOODLAND)
	return ps


func _test_data() -> void:
	var ps := _state()
	check_eq(ps.pasture_data.capacity, 6, "GDD: pasture 6 spots")
	check_eq(ps.barn_data.capacity, 20, "GDD: barn starts with 20 stalls")
	check_eq(ps.barn_data.max_upgrades, 4, "GDD: barn upgradable four times")
	check_eq(ps.barn_data.get_capacity(4), 100, "GDD: barn max 100")
	check(ps.barn_data.needs_daily_care and not ps.pasture_data.needs_daily_care,
		"GDD: barn needs daily food/water, pasture doesn't")
	var hab = HabitatData.for_biome(SpeciesData.Biome.WOODLAND)
	check_eq(hab.capacity, 12, "GDD: habitat 12")
	var cfg: CareConfig = ps.care_config
	check(cfg.feed_bond_favorite > cfg.feed_bond_preferred and cfg.feed_bond_preferred > cfg.feed_bond_other,
		"favorite > preferred type > other (placeholder numbers)")
	var treat = load("res://resources/items/angie_treat.tres")
	check(treat.always_favorite and treat.is_feedable(), "Angie's treat always counts as favorite")


func _test_capacity_and_placement() -> void:
	var ps := _farm()
	var hab_id := StringName(ps.get_habitat(SpeciesData.Biome.WOODLAND).id)
	check_eq(ps.get_capacity(hab_id), 12, "built habitat has 12 spots")
	check_eq(ps.get_capacity(&"marsh_habitat"), 0, "unbuilt habitat has none")
	var placed := []
	for i in 12:
		var m := _mon()
		ps.add_wild_monster(m)
		placed.append(m.home)
	check(placed.all(func(h): return h == hab_id), "Woodland monsters fill the Woodland habitat (12)")
	var m13 := _mon()
	check(ps.add_wild_monster(m13) and m13.home == &"pasture", "13th goes to the pasture")
	var rock := _mon(&"rockback", SpeciesData.Biome.MARSH)
	check(ps.add_wild_monster(rock) and rock.home == &"pasture", "no Marsh habitat -> pasture")
	for i in 4:
		ps.add_wild_monster(_mon(&"rockback", SpeciesData.Biome.MARSH))
	check_eq(ps.get_residents(&"pasture").size(), 6, "pasture full at 6")
	var extra := _mon(&"rockback", SpeciesData.Biome.MARSH)
	check(not ps.add_wild_monster(extra) and not ps.monsters.has(extra), "no room anywhere: refused")
	check_eq(ps.get_free_spots(hab_id), 0, "habitat full")
	# Barn: 20 stalls, upgrades +20 up to 100.
	var ps2 := _state()
	check_eq(ps2.get_capacity(&"barn"), 20, "barn 20")
	var ups := 0
	while ps2.upgrade_barn():
		ups += 1
	check(ups == 4 and ps2.get_capacity(&"barn") == 100, "four upgrades -> 100 stalls")


func _test_moves_and_thresholds() -> void:
	var ps := _farm()
	var hab_id := StringName(ps.get_habitat(SpeciesData.Biome.WOODLAND).id)
	var m := _mon()
	ps.add_wild_monster(m)
	m.bond = 24.9
	check(not m.can_go_to_barn() and not ps.move_to_barn(m), "24.9% bond: not bonded enough for the barn")
	check(ps.get_move_block(m, &"barn").begins_with("Needs 25%"), "reason names the 25% threshold")
	m.bond = 25.0
	check(m.can_go_to_barn() and ps.move_to_barn(m) and m.home == &"barn", "25%: moves to the barn")
	check(not m.has_star(), "no star below 100%")
	m.add_bond(80.0)
	check(m.bond == 100.0 and m.has_star(), "100% (clamped): star")
	m.bond = 99.9
	check(not m.has_star(), "99.9%: no star")
	check(ps.move_monster(m, &"pasture") and m.home == &"pasture", "barn -> pasture")
	check(ps.move_monster(m, hab_id), "pasture -> its biome's habitat")
	var rock := _mon(&"rockback", SpeciesData.Biome.MARSH)
	ps.add_wild_monster(rock)
	check_eq(ps.get_move_block(rock, hab_id), "Wrong biome", "habitat only takes its biome")
	check_eq(ps.get_move_block(m, hab_id), "Already there", "no-op move refused")
	# Barn full: 20 bonded monsters.
	var ps2 := _state()
	for i in 20:
		var b := _mon()
		b.bond = 30.0
		ps2.monsters.append(b)
		b.home = &"barn"
	var late := _mon(&"rockback", SpeciesData.Biome.MARSH)
	late.bond = 30.0
	ps2.add_wild_monster(late)
	check(not ps2.move_to_barn(late) and ps2.get_move_block(late, &"barn") == "Barn is full", "barn full at 20")
	ps2.upgrade_barn()
	check(ps2.move_to_barn(late), "after an upgrade there is room")


func _test_party() -> void:
	var ps := _farm()
	var a := _mon()
	var b := _mon()
	var c := _mon()
	var wild := _mon()
	for m in [a, b, c, wild]:
		ps.add_wild_monster(m)
	for m in [a, b, c]:
		m.bond = 25.0
		ps.move_to_barn(m)
	check(not ps.add_to_party(wild), "party only from the barn")
	check(ps.add_to_party(a) and ps.add_to_party(b), "two barn monsters join")
	check(not ps.add_to_party(c) and ps.party.size() == 2, "GDD: party limit 2")
	check(not ps.add_to_party(a), "no duplicates")
	check(a.home == &"barn" and ps.get_residents(&"barn").size() == 3, "party members keep their stall")
	check(ps.remove_from_party(a) and ps.add_to_party(c), "swap a member")
	ps.move_monster(c, &"pasture")
	check(not ps.party.has(c), "leaving the barn leaves the party")


func _test_feeding() -> void:
	var ps := _farm()
	var m := _mon()
	ps.add_wild_monster(m)
	ps.inventory.clear()
	ps.add_item(&"wet_waxweed", 5)
	ps.add_item(&"turnip", 5)
	ps.add_item(&"snouter_roe", 5)
	ps.add_item(&"angie_treat", 2)
	ps.add_item(&"turnip_seeds", 2)
	var cfg: CareConfig = ps.care_config
	cfg.bond_feeds_per_day = 99
	check_eq(m.favorite_food_id, &"wet_waxweed", "Cinderkin's favorite: Wet Waxweed")
	var r: Dictionary = ps.feed_monster(m, &"wet_waxweed")
	check(r.ok and is_equal_approx(r.bond, cfg.feed_bond_favorite), "favorite food: +%s" % cfg.feed_bond_favorite)
	check_eq(ps.inventory.count(&"wet_waxweed"), 4, "food used up")
	r = ps.feed_monster(m, &"turnip")
	check(is_equal_approx(r.bond, cfg.feed_bond_preferred), "preferred type (plant): +%s" % cfg.feed_bond_preferred)
	r = ps.feed_monster(m, &"snouter_roe")
	check(is_equal_approx(r.bond, cfg.feed_bond_other), "other food: +%s" % cfg.feed_bond_other)
	r = ps.feed_monster(m, &"angie_treat")
	check(is_equal_approx(r.bond, cfg.feed_bond_favorite), "Angie's treat counts as favorite")
	check(not ps.feed_monster(m, &"turnip_seeds").ok, "seeds aren't food")
	check(not ps.feed_monster(m, &"pumpkin").ok, "can't feed what you don't have")
	check(m.fed_today and m.fed_favorite_today, "fed flags set")
	# Streak: consecutive favorite days add a bonus.
	ps.apply_daily_care()
	check_eq(m.favorite_streak, 1, "streak 1 after a favorite day")
	r = ps.feed_monster(m, &"wet_waxweed")
	check(is_equal_approx(r.bond, cfg.feed_bond_favorite + cfg.favorite_streak_bonus), "streak bonus")
	m.favorite_streak = 50
	check(is_equal_approx(ps.get_feed_bond(m, load("res://resources/items/wet_waxweed.tres")),
		cfg.feed_bond_favorite + cfg.favorite_streak_bonus * cfg.favorite_streak_cap), "streak bonus capped")
	ps.apply_daily_care()
	ps.apply_daily_care()
	check_eq(m.favorite_streak, 0, "a day without it resets the streak")
	# Daily cap.
	cfg.bond_feeds_per_day = 2
	ps.add_item(&"turnip", 5)
	var gains := []
	for i in 3:
		gains.append(ps.feed_monster(m, &"turnip").bond)
	check(gains[0] > 0.0 and gains[1] > 0.0 and gains[2] == 0.0, "only %d bond feeds a day" % 2)
	m.bond = 99.0
	m.bond_feeds_today = 0
	r = ps.feed_monster(m, &"wet_waxweed")
	check(m.bond == 100.0 and is_equal_approx(r.bond, 1.0), "bond clamps at 100%")


func _test_daily_tick() -> void:
	var ps := _farm()
	var cfg: CareConfig = ps.care_config
	var barn_ok := _mon()
	var barn_hungry := _mon()
	var pasture := _mon()
	var member := _mon()
	for m in [barn_ok, barn_hungry, pasture, member]:
		ps.add_wild_monster(m)
		m.bond = 50.0
	for m in [barn_ok, barn_hungry, member]:
		ps.move_to_barn(m)
	ps.add_to_party(member)
	ps.add_item(&"turnip", 3)
	ps.feed_monster(barn_ok, &"turnip")
	var fed_bond := barn_ok.bond
	check_eq(ps.get_barn_needs(), {"hungry": 1, "thirsty": 2}, "barn needs (party member exempt)")
	check_eq(ps.water_barn(), 3, "water troughs fill the barn")
	var clock := make_clock()
	_cleanup.append(clock)
	ps.bind_clock(clock)
	clock.sleep()
	check_eq(barn_ok.bond, fed_bond, "fed + watered barn monster keeps its bond")
	check_eq(barn_hungry.bond, 50.0 - cfg.barn_neglect_bond_drop, "unfed barn monster loses bond (day rollover)")
	check_eq(pasture.bond, 50.0, "pasture monsters don't need feeding")
	check_eq(member.bond, 50.0 + cfg.party_bond_per_day, "party member gains passive bond")
	check(not barn_ok.fed_today and not barn_ok.watered_today and barn_ok.bond_feeds_today == 0, "flags reset")
	ps.bind_clock(null)


func _test_pass_out_drop() -> void:
	var ps := _farm()
	var a := _mon()
	var b := _mon()
	var home := _mon()
	for m in [a, b, home]:
		ps.add_wild_monster(m)
		m.bond = 40.0
	ps.move_to_barn(a)
	ps.move_to_barn(b)
	ps.add_to_party(a)
	ps.add_to_party(b)
	check_eq(ps.pass_out_config.party_bond_drop, 0.0, "pass-out bond drop stays 0 (open)")
	ps.apply_sleep(true)
	check(a.bond == 40.0 and b.bond == 40.0, "0 drop: inactive")
	ps.pass_out_config = ps.pass_out_config.duplicate()
	ps.pass_out_config.party_bond_drop = 7.5
	var pen: Dictionary = ps.apply_sleep(true)
	check(a.bond == 32.5 and b.bond == 32.5, "non-zero drop hits both party members")
	check_eq(home.bond, 40.0, "monsters at home are untouched")
	check_eq(pen.party_bond_drop, 7.5, "penalty reported")
	ps.apply_sleep(false)
	check_eq(a.bond, 32.5, "sleeping normally: no drop")


func _test_angie_gift() -> void:
	var ps: Node = PlayerStateScript.new()
	root.add_child(ps)
	_cleanup.append(ps)
	ps.inventory.clear()
	var m := _mon()
	ps.complete_assessment(m)
	check_eq(ps.inventory.count(&"angie_treat"), 20, "GDD: Angie gives 20 always-favorite foods")
	check_eq(ps.inventory.count(&"waxweed_starter"), 45, "GDD: and 45 seeds of the favorite crop")
	check(m.home == StringName(ps.get_habitat(SpeciesData.Biome.WOODLAND).id), "first monster in its habitat")
	ps.complete_assessment(_mon())
	check_eq(ps.inventory.count(&"angie_treat"), 20, "gift only once")


func _test_save_round_trip() -> void:
	var ps := _farm()
	var a := _mon()
	var b := _mon()
	var p := _mon(&"rockback", SpeciesData.Biome.MARSH)
	for m in [a, b, p]:
		ps.add_wild_monster(m)
	a.bond = 60.0
	ps.move_to_barn(a)
	ps.add_to_party(a)
	ps.upgrade_barn()
	ps.add_item(&"wet_waxweed", 2)
	ps.feed_monster(b, &"wet_waxweed")
	b.favorite_streak = 3
	a.watered_today = true
	var data: Dictionary = JSON.parse_string(JSON.stringify(ps.to_dict()))
	var ps2 := _state()
	ps2.from_dict(data)
	var a2: Monster = ps2.get_monster(a.uid)
	var b2: Monster = ps2.get_monster(b.uid)
	check(a2.home == &"barn" and ps2.party.size() == 1 and ps2.party[0] == a2, "barn + party saved")
	check_eq(a2.bond, 60.0, "bond saved")
	check(b2.home == b.home and b2.bond == b.bond and b2.fed_today and b2.fed_favorite_today
		and b2.bond_feeds_today == 1 and b2.favorite_streak == 3, "care flags + streak saved")
	check(a2.watered_today, "watered flag saved")
	check_eq(ps2.get_monster(p.uid).home, &"pasture", "pasture saved")
	check_eq(ps2.get_capacity(&"barn"), 40, "barn upgrades saved")
	var old := _state()
	old.from_dict({"monsters": [{"uid": "x", "species": "cinderkin", "home": "party"}], "party": ["x"]})
	check(old.get_monster("x").home == &"barn" and old.barn_upgrades == 0, "M2 saves: party home -> barn")
