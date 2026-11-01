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
	ps.eat()
	check_eq(ps.stamina, ps.energy_config.eat_stamina_refill, "eating without a food value: fallback refill")
	check_eq(ps.energy_config.eat_stamina_refill, 25.0, "placeholder fallback eat refill 25")
	var rate: float = ps.energy_config.hot_spring_stamina_per_second
	check(rate > 0.0, "hot spring: steady rate (placeholder)")
	for i in 4:
		ps.soak_in_hot_spring(0.5)
	check(is_equal_approx(ps.stamina, 25.0 + rate * 2.0), "hot spring: 2 s of soaking = 2 x rate")
	ps.soak_in_hot_spring(1000.0)
	check_eq(ps.stamina, 100.0, "hot spring refill caps at max")
	check(is_equal_approx(ps.pass_out_config.reputation_penalty, 0.02),
		"pass-out reputation penalty 0.02 (placeholder, inactive)")
	ps.refill_stamina(0.0)
	ps.spend_stamina(1000.0)
	ps.eat(10.0)
	check_eq(ps.stamina, 10.0, "eat amount override")
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
	grid.crops = [load(CROP_PATH) as CropData, load("res://resources/crops/turnip.tres") as CropData]
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
	p.set_tool(p.tools.size())  # first item slot: starting turnip seeds (placeholder kit)
	check(p.get_current_item() != null and p.get_current_item().is_seed(), "seed item selected")
	var seeds_before: int = ps.inventory.count(&"turnip_seeds")
	check(p.act_on_cell(Vector2i(0, 0)), "plant")
	check_eq(ps.inventory.count(&"turnip_seeds"), seeds_before - 1, "planting uses one seed")
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
		normal * minf(p.tired_speed_multiplier, ps.energy_config.exhausted_speed_multiplier),
		"tired + exhausted: the worse multiplier, not the product (ruling)")
	check_eq(p.get_current_speed(), normal * 0.5, "tired + exhausted = 50%")
	ps.refill_stamina()
	check_eq(p.get_current_speed(), normal * p.tired_speed_multiplier, "tired only = 75%")
	ps.spend_stamina(1000.0)
	# Harvest is free even when exhausted (GDD: walk up and click).
	var plot := grid.get_plot(Vector2i(0, 0))
	plot.growth_days = (load("res://resources/crops/turnip.tres") as CropData).get_days_to_mature()
	check(p.act_on_cell(Vector2i(0, 0)), "harvest works at 0 stamina")
	check_eq(ps.inventory.count(&"turnip"), 1, "harvest puts the crop in the inventory")
	p.free()
	grid.free()
	ps.free()
	clock.free()
