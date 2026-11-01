extends MboaTestBase
## Sleep / pass-out tests: PassOutConfig penalties, PlayerState handler,
## timed transition, tired slowdown, and the bed in the main scene.

const PlayerStateScript := preload("res://scripts/core/player_state.gd")


func _make_state(clock: GameClock) -> Node:
	var ps: Node = PlayerStateScript.new()
	ps.pass_out_config = ps.pass_out_config.duplicate()
	root.add_child(ps)
	ps.bind_clock(clock)
	return ps


func _run_tests() -> void:
	_test_defaults_are_neutral()
	_test_pass_out_penalties()
	_test_voluntary_sleep_restores()
	await _test_timed_transition()
	_test_tired_slowdown()
	await _test_bed_in_scene()


func _test_defaults_are_neutral() -> void:
	var cfg := load("res://resources/pass_out_config.tres") as PassOutConfig
	check(cfg != null, "pass_out_config.tres loads")
	check(cfg.gold_penalty_fraction == 0.0 and cfg.party_bond_drop == 0.0,
		"GDD pass-out penalty values are open: default 0")
	check(not ("wake_hour_delay" in cfg) and not ("energy_penalty_fraction" in cfg),
		"invented wake delay / energy penalty removed")
	var clock := make_clock()
	var ps := _make_state(clock)
	ps.coins = 100
	clock.advance_minutes(20.0 * 60.0)  # 6:00 + 20h = 02:00 -> pass out
	check_eq(clock.day, 2, "passed out -> day 2")
	check(ps.last_sleep_was_pass_out, "PlayerState.last_sleep_was_pass_out = true")
	check(clock.last_sleep_was_pass_out, "Clock.last_sleep_was_pass_out = true")
	check_eq(ps.coins, 100, "no Coins lost with default config")
	check_eq(clock.get_time_string(true), "06:00", "wake at wake_hour after pass-out")
	ps.free()
	clock.free()


class FakeMonster:
	var bond := 50.0
	func add_bond(delta: float) -> void:
		bond = clampf(bond + delta, 0.0, 100.0)


func _test_pass_out_penalties() -> void:
	var clock := make_clock()
	var ps := _make_state(clock)
	ps.pass_out_config.gold_penalty_fraction = 0.1
	ps.pass_out_config.party_bond_drop = 5.0
	ps.coins = 205
	var m1 := FakeMonster.new()
	var m2 := FakeMonster.new()
	ps.party = [m1, m2]
	var resolved: Array = []
	ps.sleep_resolved.connect(func(p, pen): resolved.append([p, pen]))
	clock.advance_minutes(100000.0)
	check_eq(clock.day, 2, "pass-out rollover")
	check_eq(clock.get_time_string(true), "06:00", "no invented wake delay")
	check_eq(ps.coins, 185, "10% of carried Coins lost (floor of 20.5)")
	check(m1.bond == 45.0 and m2.bond == 45.0, "fixed bond drop applied to party")
	check(resolved.size() == 1 and resolved[0][0] == true, "sleep_resolved(pass_out=true) once")
	check_eq(resolved[0][1], {"coins_lost": 20, "party_bond_drop": 5.0}, "penalty report")
	check_eq(ps.pass_out_count, 1, "pass_out_count")
	ps.free()
	clock.free()


func _test_voluntary_sleep_restores() -> void:
	var clock := make_clock()
	var ps := _make_state(clock)
	ps.pass_out_config.gold_penalty_fraction = 0.5
	ps.pass_out_config.party_bond_drop = 10.0
	var m := FakeMonster.new()
	ps.party = [m]
	ps.coins = 100
	ps.last_sleep_was_pass_out = true
	clock.advance_minutes(19.0 * 60.0)  # 01:00, tired
	check(clock.is_tired, "tired at 01:00")
	clock.sleep()
	check(not ps.last_sleep_was_pass_out, "voluntary sleep clears last_sleep_was_pass_out")
	check(ps.coins == 100 and m.bond == 50.0, "no penalty for sleeping in bed")
	check_eq(clock.get_time_string(true), "06:00", "wake at 06:00")
	check(not clock.is_tired, "not tired after sleeping")
	ps.free()
	clock.free()


func _test_timed_transition() -> void:
	await process_frame  # root is only inside the tree once the loop runs
	var clock := make_clock()
	clock.config.sleep_transition_seconds = 0.1
	var ended := [false]
	clock.day_ended.connect(func(_d, _p): ended[0] = true)
	clock.sleep()
	check(clock.is_sleeping and clock.day == 1 and not ended[0], "rollover waits for transition")
	clock.advance_minutes(60.0)
	check_eq(clock.get_time_string(true), "06:00", "time frozen while sleeping")
	clock.sleep()  # ignored while already sleeping
	await create_timer(0.25).timeout
	check(not clock.is_sleeping and clock.day == 2, "rolled over after transition")
	clock.free()


func _test_tired_slowdown() -> void:
	var clock := make_clock()
	var p := Player.new()
	p.clock = clock
	var normal := p.get_current_speed()
	clock.advance_minutes(18.0 * 60.0)
	check_eq(p.get_current_speed(), normal * p.tired_speed_multiplier, "tired slows movement")
	check_eq(p.tired_speed_multiplier, 0.75, "placeholder tired multiplier 0.75")
	p.free()
	clock.free()


func _test_bed_in_scene() -> void:
	var clock := root.get_node_or_null("Clock") as GameClock
	var ps := root.get_node_or_null("PlayerState")
	check(clock != null and ps != null, "Clock and PlayerState autoloads present")
	if clock == null or ps == null:
		return
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var player := main.get_node("Farm/Player") as Player
	var bed := main.get_node_or_null("Farm/Bed") as Bed
	check(bed != null, "bed exists in farm scene")
	if bed == null:
		return
	player.global_position = bed.global_position
	for i in 4:
		await physics_frame
	check(player.is_near_bed(), "standing on bed registers it")
	var day := clock.day
	check(player.interact(), "interact at bed starts sleep")
	check(clock.is_sleeping, "clock sleeping")
	var fade := main.get_node("HUD").get_node("%Fade") as ColorRect
	check(fade.visible, "HUD fade-to-black shown")
	await create_timer(clock.config.sleep_transition_seconds + 0.2).timeout
	check_eq(clock.day, day + 1, "bed sleep rolled the day")
	check(not ps.last_sleep_was_pass_out, "bed sleep is not a pass-out")
	check(clock.get_pause_reasons().has(&"sleep_fade"), "clock paused during fade-in")
	await create_timer(1.5).timeout
	check(not fade.visible and not clock.is_paused(), "fade finished and clock resumed")
	check(player.global_position.is_equal_approx(bed.get_wake_position()), "player wakes at the bed")
	# Pass out far from the bed: still wakes in bed (GDD).
	player.global_position = Vector2(500, 300)
	clock.advance_minutes(100000.0)
	await create_timer(clock.config.sleep_transition_seconds + 0.2).timeout
	check(ps.last_sleep_was_pass_out, "passed out")
	check(player.global_position.is_equal_approx(bed.get_wake_position()), "wakes in bed after pass-out")
	await create_timer(1.5).timeout
	main.queue_free()
	await process_frame
