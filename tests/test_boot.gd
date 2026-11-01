extends MboaTestBase
## Boot check: loads the main scene headless, runs some frames, and exercises
## the player/HUD wiring. Fails on missing nodes; run_all.sh also fails on any
## SCRIPT ERROR printed while running.

const MAIN_SCENE := "res://scenes/main/main.tscn"


func _run_tests() -> void:
	check_eq(ProjectSettings.get_setting("application/run/main_scene"), MAIN_SCENE,
		"main_scene is set")
	var clock := root.get_node_or_null("Clock") as GameClock
	check(clock != null, "Clock autoload present")
	for action in ["move_up", "move_down", "move_left", "move_right", "interact",
			"tool_1", "tool_2", "tool_3", "tool_4", "tool_5", "cancel",
			"debug_time_x1", "debug_time_x10", "debug_time_x60", "debug_sleep", "debug_save", "debug_load"]:
		check(InputMap.has_action(action), "input action '%s'" % action)
	var packed := load(MAIN_SCENE) as PackedScene
	check(packed != null, "main scene loads")
	if packed == null:
		return
	var main := packed.instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var player := main.get_node_or_null("Farm/Player") as Player
	var grid := main.get_node_or_null("Farm/FarmGrid") as FarmGrid
	var hud := main.get_node_or_null("HUD") as Hud
	check(player != null and grid != null and hud != null, "player, farm grid and HUD exist")
	check(main.get_node_or_null("DayNightTint") is CanvasModulate, "night tint CanvasModulate exists")
	if player == null or grid == null or hud == null or clock == null:
		return
	check(player.farm_grid == grid, "player wired to farm grid")
	check(not grid.crops.is_empty(), "farm grid has crops")
	var t0 := clock.time_minutes
	for i in 5:
		await process_frame
	check(clock.time_minutes > t0, "clock advances while the scene runs")
	check(hud.get_node("%TimeLabel").text == clock.get_time_string(), "HUD shows clock time")
	# Drive a tool use through the player on its faced cell.
	player.global_position = grid.cell_to_world_center(Vector2i(3, 0)) + Vector2(0, 7)
	player.facing = Vector2i.DOWN
	await physics_frame
	check_eq(player.get_target_cell(), Vector2i(3, 1), "player targets faced cell")
	check_eq(player.tools.size(), 5, "hotbar: Pulaski, sickle, pickaxe, watering can, seeds")
	check(player.select_tool_by_id(&"pulaski") or player.current_tool.id == &"pulaski", "select Pulaski")
	check(player.interact(), "player tills faced cell")
	check_eq(grid.get_plot(Vector2i(3, 1)).state, FarmPlot.State.TILLED, "faced cell tilled")
	check(player.tap_at(grid.cell_to_world_center(Vector2i(4, 1))), "tap on adjacent cell acts")
	check(not player.tap_at(grid.cell_to_world_center(Vector2i(9, 7))), "tap out of reach ignored")
	await process_frame
	check(hud.get_node("%ToolLabel").text.contains("Pulaski"), "HUD shows current tool")
	await process_frame  # process_frame fires before nodes' _process: wait one more
	var ps := root.get_node_or_null("PlayerState")
	check(ps != null and ps.stamina < ps.energy_config.max_stamina, "tool uses spent stamina")
	check(hud.get_node("%StaminaBar").value == ps.stamina and hud.get_node("%HealthBar").value == ps.health,
		"HUD stamina and health bars track PlayerState")
	check_eq(hud.get_node("%ToolButtons").get_child_count(), 5, "HUD builds one button per hotbar slot")
	var trees := 0
	for y in grid.grid_size.y:
		for x in grid.grid_size.x:
			if grid.get_farm_tree(Vector2i(x, y)):
				trees += 1
	check(trees > 0, "farm starts with trees")
	# Save / load the running game through the SaveManager autoload.
	var sm := root.get_node_or_null("SaveManager")
	var path := "user://test_boot_save.json"
	check(sm != null and sm.save_game(path), "SaveManager saves the running game")
	grid.get_plot(Vector2i(3, 1)).state = FarmPlot.State.EMPTY
	player.global_position = Vector2(500, 300)
	check(sm.load_game(path), "SaveManager loads it back")
	check_eq(grid.get_plot(Vector2i(3, 1)).state, FarmPlot.State.TILLED, "farm restored from save")
	var bed := main.get_node_or_null("Farm/Bed")
	check(bed != null and player.global_position.is_equal_approx(bed.get_wake_position()),
		"player placed at the bed after loading")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	main.queue_free()
	await process_frame
