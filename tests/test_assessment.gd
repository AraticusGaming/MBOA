extends MboaTestBase
## Assessment (GDD "Assessment" + "Monster Trapping"; Slice 2): rank odds
## D79/C20/B1, band-consistent creatures, 5 traps, catch/fail, choose, the
## first monster setting the farm biome + habitat, saves, and the farm door
## to the room and back.

const PlayerStateScript := preload("res://scripts/core/player_state.gd")
const WOODLAND := "res://resources/assessment/woodland.tres"

var _cleanup: Array = []


func _run_tests() -> void:
	_test_config()
	_test_rank_distribution()
	_test_spawn_bands()
	_test_traps()
	_test_refill_and_choose()
	_test_complete_assessment()
	await _test_room_flow()
	for n in _cleanup:
		if is_instance_valid(n):
			n.free()


func _cfg() -> AssessmentConfig:
	return (load(WOODLAND) as AssessmentConfig).duplicate()


func _test_config() -> void:
	var cfg := _cfg()
	check_eq(cfg.trap_count, 5, "GDD: Angie gives 5 traps")
	var w := cfg.rank_weights
	check(w.size() == 3 and int(w.D) == 79 and int(w.C) == 20 and int(w.B) == 1, "GDD: rank odds D79/C20/B1")
	check_eq(cfg.biome, SpeciesData.Biome.WOODLAND, "Slice 2: Woodland room")
	check(not cfg.first_monster_joins_party, "GDD: wild-caught monster lives in its habitat")
	for b in 4:
		var h = HabitatData.for_biome(b)
		check(h != null and h.biome == b and h.capacity == 12, "habitat data for %s (12 per GDD)" % SpeciesData.biome_name(b))


func _test_rank_distribution() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var n := 20000
	var counts := {"D": 0, "C": 0, "B": 0}
	for i in n:
		var r := AssessmentSession.roll_rank(_cfg().rank_weights if i == 0 else {"D": 79, "C": 20, "B": 1}, rng)
		counts[r] = counts.get(r, 0) + 1
	check_eq(counts.size(), 3, "only D/C/B ranks rolled")
	var d := float(counts.D) / n
	var c := float(counts.C) / n
	var b := float(counts.B) / n
	check(absf(d - 0.79) < 0.015, "D ~79%% (got %.3f)" % d)
	check(absf(c - 0.20) < 0.015, "C ~20%% (got %.3f)" % c)
	check(absf(b - 0.01) < 0.005, "B ~1%% (got %.3f)" % b)
	check_eq(AssessmentSession.roll_rank({}, rng), "D", "empty weights fall back to D")
	check_eq(AssessmentSession.roll_rank({"A": 1}, rng), "A", "weights are data-driven")


func _test_spawn_bands() -> void:
	var cfg := _cfg()
	cfg.creature_count = 0
	var s := AssessmentSession.new(cfg, 7)
	s.start()
	var woodland := SpeciesCatalog.get_default().get_wild_in_biome(SpeciesData.Biome.WOODLAND)
	var ok_rank := true
	var ok_band := true
	var ok_biome := true
	var ok_pos := true
	var ranks := {}
	for i in 400:
		var ci := s.spawn_creature()
		var c: Dictionary = s.creatures[ci]
		var m: Monster = c.monster
		var rank := m.get_rank()
		ranks[rank] = true
		if not rank in ["D", "C", "B"]:
			ok_rank = false
		var bands := m.get_species().stat_bands
		for stat in m.stats:
			if not bands.is_valid_value(m.stats[stat]):
				ok_band = false
		if not woodland.has(m.get_species()) or m.origin_biome != SpeciesData.Biome.WOODLAND:
			ok_biome = false
		if not cfg.room_rect.has_point(c.pos):
			ok_pos = false
	check(ok_rank, "spawned ranks are D/C/B only")
	check(ok_band, "spawned stats are inside the species' bands")
	check(ok_biome, "spawns are wild Woodland species, origin Woodland")
	check(ok_pos, "spawns inside the room")
	check(ranks.has("D") and ranks.has("C"), "D and C both appear in 400 spawns")
	var cinder := SpeciesCatalog.get_default().get_species(&"cinderkin")
	check(woodland.has(cinder), "Cinderkin is catchable in the Woodland room")


## Runs the session until trap `ti` resolves. Returns its final state.
func _run_until_resolved(s: AssessmentSession, ti: int, seconds: float = 30.0) -> int:
	var t := 0.0
	while t < seconds:
		s.update(0.1)
		t += 0.1
		var st: int = s.traps[ti].state
		if st == AssessmentSession.TrapState.CAUGHT or st == AssessmentSession.TrapState.FAILED:
			return st
	return s.traps[ti].state


func _test_traps() -> void:
	var cfg := _cfg()
	cfg.catch_chance = 1.0
	cfg.refill_when_empty = false
	var s := AssessmentSession.new(cfg, 11)
	s.start()
	check_eq(s.creatures.size(), cfg.creature_count, "room starts with creatures")
	check_eq(s.traps_left, 5, "5 traps at start")
	check(not s.can_place_trap(Vector2(0, 0)), "can't trap outside the room")
	var target: Dictionary = s.creatures[0]
	var ti := s.place_trap(target.pos)
	check_eq(ti, 0, "trap placed")
	check_eq(s.traps_left, 4, "a trap is used")
	check(not s.can_place_trap(target.pos + Vector2(2, 0)), "traps need spacing")
	var caught := []
	s.trap_caught.connect(func(_i, m): caught.append(m))
	check_eq(_run_until_resolved(s, ti), AssessmentSession.TrapState.CAUGHT, "lured creature is caught (catch 100%)")
	check_eq(s.captures.size(), 1, "capture recorded")
	check(caught.size() == 1 and caught[0] == s.captures[0], "trap_caught signal carries the monster")
	check(s.can_choose(), "can end after one capture")
	s.release(0)
	check(s.captures.is_empty() and not s.can_choose(), "release lets it go")
	# Failure: knocked over, bait gone, creature spooked.
	var cfg2 := _cfg()
	cfg2.catch_chance = 0.0
	cfg2.refill_when_empty = false
	var s2 := AssessmentSession.new(cfg2, 12)
	s2.start()
	var ti2 := s2.place_trap(s2.creatures[0].pos)
	check_eq(_run_until_resolved(s2, ti2), AssessmentSession.TrapState.FAILED, "failed trap is knocked over")
	check(s2.captures.is_empty(), "nothing captured on a fail")
	check_eq(s2.traps_left, 4, "failed trap is spent (placeholder)")
	# Seeded sessions are deterministic.
	var a := AssessmentSession.new(_cfg(), 99)
	var b := AssessmentSession.new(_cfg(), 99)
	a.start()
	b.start()
	var same := true
	for i in a.creatures.size():
		if a.creatures[i].pos != b.creatures[i].pos or a.creatures[i].monster.stats != b.creatures[i].monster.stats:
			same = false
	check(same, "same seed, same room")


func _test_refill_and_choose() -> void:
	var cfg := _cfg()
	cfg.catch_chance = 0.0
	var s := AssessmentSession.new(cfg, 5)
	s.start()
	var refilled := [0]
	s.traps_refilled.connect(func(): refilled[0] += 1)
	for i in 5:
		s.place_trap(s.creatures[i].pos)
	check_eq(s.traps_left, 0, "all 5 traps set")
	for i in 400:
		s.update(0.1)
		if refilled[0] > 0:
			break
	check_eq(refilled[0], 1, "no captures after all traps: Angie refills (placeholder)")
	check_eq(s.traps_left, 5, "traps refilled")
	# Choose ends the Assessment.
	var cfg2 := _cfg()
	cfg2.catch_chance = 1.0
	var s2 := AssessmentSession.new(cfg2, 6)
	s2.start()
	var t0 := s2.place_trap(s2.creatures[0].pos)
	var t1 := s2.place_trap(s2.creatures[1].pos)
	_run_until_resolved(s2, t0)
	_run_until_resolved(s2, t1)
	check_eq(s2.captures.size(), 2, "two captures")
	check(s2.choose(5) == null, "invalid choice rejected")
	var done := []
	s2.finished.connect(func(m): done.append(m))
	var m := s2.choose(1)
	check(m != null and s2.chosen == m and s2.is_finished, "choose ends the Assessment")
	check(done.size() == 1 and done[0] == m, "finished signal")
	check_eq(s2.place_trap(Vector2(300, 200)), -1, "no traps after finishing")
	check(s2.choose(0) == null, "can't choose twice")


func _make_state() -> Node:
	var ps: Node = PlayerStateScript.new()
	root.add_child(ps)
	_cleanup.append(ps)
	return ps


func _test_complete_assessment() -> void:
	var ps := _make_state()
	check_eq(ps.farm_biome, -1, "no farm biome before the Assessment")
	var cinder := SpeciesCatalog.get_default().get_species(&"cinderkin")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var m := MonsterFactory.create(cinder, "C", rng)
	m.origin_biome = SpeciesData.Biome.WOODLAND
	var got := []
	ps.assessment_completed.connect(func(x): got.append(x))
	ps.complete_assessment(m)
	check_eq(ps.farm_biome, SpeciesData.Biome.WOODLAND, "first monster sets the farm's starting biome")
	var hab: Dictionary = ps.get_habitat(SpeciesData.Biome.WOODLAND)
	check(not hab.is_empty() and hab.built, "that biome's habitat is pre-built")
	check(ps.get_habitat(SpeciesData.Biome.MARSH).is_empty(), "other habitats not built")
	check(ps.monsters.has(m) and not ps.party.has(m), "monster added to the roster, not the party")
	check_eq(m.home, StringName(hab.id), "monster lives in its habitat")
	check(ps.assessment_done and got.size() == 1, "assessment marked done + signal")
	# A second monster from another biome doesn't change the farm biome.
	var rock := MonsterFactory.create(SpeciesCatalog.get_default().get_species(&"rockback"), "D", rng)
	rock.origin_biome = SpeciesData.Biome.MARSH
	ps.complete_assessment(rock, true)
	check_eq(ps.farm_biome, SpeciesData.Biome.WOODLAND, "farm biome set only once")
	check(ps.party.has(rock), "join_party option")
	# Save round-trip.
	var data: Dictionary = ps.to_dict()
	var ps2 := _make_state()
	ps2.from_dict(JSON.parse_string(JSON.stringify(data)))
	check_eq(ps2.farm_biome, SpeciesData.Biome.WOODLAND, "farm biome saved")
	check(not ps2.get_habitat(SpeciesData.Biome.WOODLAND).is_empty(), "habitat saved")
	check(ps2.assessment_done, "assessment_done saved")
	check_eq(ps2.monsters.size(), 2, "monsters saved")
	var fresh := _make_state()
	fresh.from_dict({})
	check(fresh.farm_biome == -1 and fresh.habitats.is_empty() and not fresh.assessment_done, "old saves default sensibly")


func _test_room_flow() -> void:
	var ps := _make_state()
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var farm := main.get_node("Farm") as Node2D
	var player := main.get_node("Farm/Player") as Player
	var door := main.get_node_or_null("Farm/AssessmentDoor") as AssessmentDoor
	check(door != null, "assessment door on the farm")
	door.player_state = ps
	check(door.is_available(), "door open before the first monster")
	var grid := player.farm_grid
	var home_pos := player.global_position
	check(door.use(player), "door opens the room")
	var room := main.get_node_or_null("AssessmentRoom") as AssessmentRoom
	check(room != null, "room added under Main")
	check(player.get_parent() == room, "player moved into the room")
	check(player.farm_grid == null, "no farm grid in the room")
	check(not farm.visible and farm.process_mode == Node.PROCESS_MODE_DISABLED, "farm hidden and paused")
	check(root.get_node("Clock").is_paused(), "clock paused in the room (placeholder)")
	await process_frame
	# Interact places a trap in front of the player.
	player.global_position = Vector2(320, 200)
	player.facing = Vector2i.DOWN
	check(player.interact(), "interact sets a trap")
	check_eq(room.session.traps_left, 4, "trap used via interact")
	# Exit without choosing.
	room.leave()
	await process_frame
	check(player.get_parent() == farm and player.farm_grid == grid, "back on the farm")
	check_eq(player.global_position, home_pos, "player back at the door")
	check(farm.visible and farm.process_mode == Node.PROCESS_MODE_INHERIT, "farm restored")
	check(not root.get_node("Clock").is_paused(), "clock resumed")
	check(not ps.assessment_done, "leaving without a monster doesn't finish")
	# Enter again, catch, keep.
	door.use(player)
	room = main.get_node_or_null("AssessmentRoom") as AssessmentRoom
	if room == null:
		room = main.get_children().filter(func(n): return n is AssessmentRoom).back()
	room.config = room.config.duplicate()
	room.config.catch_chance = 1.0
	room.session.config = room.config
	var ti := room.place_trap(room.session.creatures[0].pos)
	_run_until_resolved(room.session, ti)
	check_eq(room.session.captures.size(), 1, "caught in the room")
	var exited := []
	room.exited.connect(func(m): exited.append(m))
	var kept: Monster = room.keep(0)
	await process_frame
	check(kept != null and exited.size() == 1 and exited[0] == kept, "keep returns to the farm")
	check(ps.assessment_done and ps.monsters.has(kept), "kept monster is the first monster")
	check_eq(ps.farm_biome, SpeciesData.Biome.WOODLAND, "farm biome is Woodland")
	check(player.get_parent() == farm, "player on the farm after keeping")
	check(not door.is_available(), "door closed after the first monster")
	check(not door.use(player), "door can't be reused")
	main.free()
	await process_frame
