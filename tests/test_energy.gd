extends MboaTestBase
## Health / stamina tests (GDD Energy): both bars start full, tool uses cost
## stamina, 0 stamina blocks tools and slows the player, refills.

const PlayerStateScript := preload("res://scripts/core/player_state.gd")
const CROP_PATH := "res://resources/crops/placeholder_crop.tres"


func _make_state() -> Node:
	var ps: Node = PlayerStateScript.new()
	ps.energy_config = ps.energy_config.duplicate()
	root.add_child(ps)
	return ps


func _run_tests() -> void:
	_test_config()
	_test_state()
	_test_player_tool_gating()


func _test_config() -> void:
	var cfg := load("res://resources/energy_config.tres") as EnergyConfig
	check(cfg != null, "energy_config.tres loads")
	check(cfg.max_health == 100.0 and cfg.max_stamina == 100.0, "bars are percentages (100%)")
	check(cfg.exhausted_speed_multiplier > 0.0 and cfg.exhausted_speed_multiplier < 1.0,
		"placeholder exhausted slow multiplier")


func _test_state() -> void:
	var ps := _make_state()
	check(ps.health == 100.0 and ps.stamina == 100.0, "GDD: both bars start at 100%")
	var changes: Array = []
	ps.stamina_changed.connect(func(v, _m): changes.append(v))
	check(ps.spend_stamina(30.0), "spend stamina")
	check_eq(ps.stamina, 70.0, "stamina 70")
	check(ps.spend_stamina(100.0) and ps.stamina == 0.0, "last use empties the bar (clamped)")
	check(ps.is_exhausted() and not ps.can_use_tools(), "exhausted at 0: no tools")
	check(not ps.spend_stamina(1.0), "can't spend at 0")
	check_eq(ps.get_speed_multiplier(), ps.energy_config.exhausted_speed_multiplier, "slowed at 0")
	ps.eat(25.0)
	check_eq(ps.stamina, 25.0, "eating refills stamina")
	ps.rest_in_hot_spring(30.0)
	check_eq(ps.stamina, 25.0 + ps.energy_config.hot_spring_stamina_per_game_hour * 0.5,
		"hot spring refills per game hour")
	ps.refill_stamina()
	check_eq(ps.stamina, 100.0, "refill to full")
	check_eq(ps.get_speed_multiplier(), 1.0, "normal speed with stamina")
	check(changes.size() >= 4, "stamina_changed emitted")
	ps.damage(40.0)
	check_eq(ps.health, 60.0, "damage hook")
	ps.heal(100.0)
	check_eq(ps.health, 100.0, "heal clamps at max")
	var data := JSON.parse_string(JSON.stringify(ps.to_dict())) as Dictionary
	ps.spend_stamina(50.0)
	var ps2 := _make_state()
	data.stamina = 42.0
	ps2.from_dict(data)
	check(ps2.stamina == 42.0 and ps2.health == 100.0, "health/stamina save roundtrip")
	ps.free()
	ps2.free()


func _test_player_tool_gating() -> void:
	var clock := make_clock()
	var ps := _make_state()
	var grid := FarmGrid.new()
	grid.crops = [load(CROP_PATH) as CropData]
	grid.clock = clock
	root.add_child(grid)
	grid._ready()
	var p := Player.new()
	p.clock = clock
	p.player_state = ps
	p.farm_grid = grid
	root.add_child(p)
	p._ready()
	check(p.select_tool_by_id(&"sickle"), "default hotbar loaded")
	var cost: float = p.current_tool.stamina_cost
	p.act_on_cell(Vector2i(0, 0))
	check_eq(ps.stamina, 100.0 - cost, "a tool use with no effect still costs stamina")
	p.select_tool_by_id(&"pulaski")
	check(p.act_on_cell(Vector2i(0, 0)), "Pulaski tills")
	check_eq(ps.stamina, 100.0 - cost * 2.0, "tilling costs stamina")
	p.select_tool_by_id(&"seeds")
	check(p.act_on_cell(Vector2i(0, 0)), "plant")
	check_eq(ps.stamina, 100.0 - cost * 2.0, "planting seeds is not a tool use")
	ps.spend_stamina(1000.0)
	p.select_tool_by_id(&"pulaski")
	check(not p.act_on_cell(Vector2i(1, 0)), "no tools at 0 stamina")
	check_eq(grid.get_plot(Vector2i(1, 0)).state, FarmPlot.State.EMPTY, "cell untouched")
	var normal := p.move_speed
	check_eq(p.get_current_speed(), normal * ps.energy_config.exhausted_speed_multiplier,
		"slowed at 0 stamina")
	clock.advance_minutes(18.0 * 60.0)
	check_eq(p.get_current_speed(),
		normal * p.tired_speed_multiplier * ps.energy_config.exhausted_speed_multiplier,
		"tired and exhausted multipliers stack (placeholder rule)")
	# Harvest is free even when exhausted (GDD: walk up and click).
	var plot := grid.get_plot(Vector2i(0, 0))
	plot.growth_days = (load(CROP_PATH) as CropData).get_days_to_mature()
	check(p.act_on_cell(Vector2i(0, 0)), "harvest works at 0 stamina")
	p.free()
	grid.free()
	ps.free()
	clock.free()
