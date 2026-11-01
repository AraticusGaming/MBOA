extends MboaTestBase
## Farm tests: till -> plant -> water -> day rollover grows; unwatered does not
## grow; maturity and harvest; tool rules; save/load.

const CROP_PATH := "res://resources/crops/placeholder_crop.tres"
const TREE_PATH := "res://resources/trees/placeholder_tree.tres"
var PULASKI := load("res://resources/tools/pulaski.tres") as ToolData
var SICKLE := load("res://resources/tools/sickle.tres") as ToolData
var PICKAXE := load("res://resources/tools/pickaxe.tres") as ToolData
var CAN := load("res://resources/tools/watering_can.tres") as ToolData


func _make_grid(clock: GameClock) -> FarmGrid:
	var grid := FarmGrid.new()
	grid.crops = [load(CROP_PATH) as CropData]
	grid.trees = [load(TREE_PATH) as TreeData]
	grid.clock = clock
	root.add_child(grid)
	grid._ready()  # root may not be "ready" inside _initialize; wire explicitly
	return grid


func _run_tests() -> void:
	var crop := load(CROP_PATH) as CropData
	check(crop != null and crop.id == &"placeholder_crop", "placeholder crop .tres loads")
	_test_full_cycle(crop)
	_test_unwatered(crop)
	_test_rules()
	_test_interact_and_save(crop)
	_test_crop_data(crop)
	_test_tool_data()
	_test_trees()
	_test_obstacles()
	_test_seasonal_crops()
	_test_tree_adjacent_crop()


func _test_full_cycle(crop: CropData) -> void:
	var clock := make_clock()
	var grid := _make_grid(clock)
	var cell := Vector2i(2, 3)
	check(grid.till(cell), "till empty plot")
	check(grid.plant(cell, crop.id), "plant on tilled plot")
	check(grid.water(cell), "water planted plot")
	clock.sleep()
	var plot := grid.get_plot(cell)
	check_eq(plot.growth_days, 1, "watered crop grew one day after rollover")
	check(not plot.watered, "watered flag reset at day start")
	check(not grid.is_mature(cell) or crop.get_days_to_mature() <= 1, "not mature yet")
	for i in crop.get_days_to_mature() - 1:
		grid.water(cell)
		clock.sleep()
	check(grid.is_mature(cell), "mature after days_to_mature watered days")
	grid.water(cell)
	clock.sleep()
	check_eq(plot.growth_days, crop.get_days_to_mature(), "growth stops at maturity")
	var got: Array = []
	grid.harvested.connect(func(id, c): got.append([id, c]))
	check_eq(grid.harvest(cell), crop.id, "harvest returns crop id")
	check_eq(got, [[crop.id, cell]], "harvested(crop_id, cell) emitted")
	check_eq(plot.state, FarmPlot.State.TILLED, "plot returns to TILLED after harvest")
	check_eq(grid.harvest(cell), &"", "cannot harvest twice")
	grid.free()
	clock.free()


func _test_unwatered(crop: CropData) -> void:
	var clock := make_clock()
	var grid := _make_grid(clock)
	var cell := Vector2i(0, 0)
	grid.till(cell)
	grid.plant(cell, crop.id)
	for i in 3:
		clock.sleep()
	check_eq(grid.get_plot(cell).growth_days, 0, "unwatered crop does not grow")
	grid.water(cell)
	clock.sleep()
	clock.sleep()
	check_eq(grid.get_plot(cell).growth_days, 1, "only the watered day counts")
	grid.free()
	clock.free()


func _test_rules() -> void:
	var clock := make_clock()
	var grid := _make_grid(clock)
	check_eq(grid.grid_size, Vector2i(12, 8), "default grid 12x8")
	check_eq(grid.plots.size(), 96, "96 plots")
	check(not grid.plant(Vector2i(1, 1), &"placeholder_crop"), "cannot plant untilled")
	check(not grid.water(Vector2i(1, 1)), "cannot water untilled")
	check(not grid.till(Vector2i(-1, 0)), "out of bounds rejected")
	grid.till(Vector2i(1, 1))
	check(not grid.till(Vector2i(1, 1)), "cannot re-till")
	check(not grid.plant(Vector2i(1, 1), &"no_such_crop"), "unknown crop rejected")
	check(grid.water(Vector2i(1, 1)), "can water tilled soil before planting")
	check(grid.plant(Vector2i(1, 1), &"placeholder_crop"), "plant on watered soil")
	check(grid.get_plot(Vector2i(1, 1)).watered, "watered flag kept when planting")
	check(not grid.plant(Vector2i(1, 1), &"placeholder_crop"), "cannot plant twice")
	grid.position = Vector2(224, 144)
	check_eq(grid.world_to_cell(Vector2(224 + 17, 144 + 33)), Vector2i(1, 2), "world_to_cell")
	check_eq(grid.cell_to_world_center(Vector2i(1, 2)), Vector2(224 + 24, 144 + 40), "cell_to_world_center")
	grid.free()
	clock.free()


func _test_interact_and_save(crop: CropData) -> void:
	var clock := make_clock()
	var grid := _make_grid(clock)
	var cell := Vector2i(5, 5)
	check(grid.interact(cell, PULASKI), "interact with Pulaski tills")
	check(grid.plant(cell, crop.id), "plant the crop")
	check_eq(grid.get_plot(cell).crop_id, crop.id, "crop id stored")
	for i in crop.get_days_to_mature():
		check(grid.interact(cell, CAN), "interact waters (day %d)" % (i + 1))
		clock.sleep()
	var harvested := [false]
	grid.harvested.connect(func(_id, _c): harvested[0] = true)
	check(grid.interact(cell, PULASKI), "interact on mature crop harvests (any tool)")
	check(harvested[0], "harvest signal via interact")
	grid.plant(cell, crop.id)
	grid.interact(cell, CAN)
	var data := JSON.parse_string(JSON.stringify(grid.to_dict())) as Dictionary
	var grid2 := _make_grid(clock)
	grid2.from_dict(data)
	var p2 := grid2.get_plot(cell)
	check(p2.state == FarmPlot.State.PLANTED and p2.watered and p2.crop_id == crop.id,
		"farm save/load roundtrip")
	grid.free()
	grid2.free()
	clock.free()


func _test_crop_data(crop: CropData) -> void:
	check_eq(CropData.STAGE_COUNT, 4, "GDD: four growth stages")
	check_eq(crop.stage_days.size(), 3, "stage_days covers stages 1-3")
	check_eq(crop.stage_frames.size(), 4, "one sprite frame per stage")
	for s in 4:
		check(crop.grows_in(s), "placeholder crop tagged for season %d" % s)
	var clock := make_clock()
	clock.config.days_per_season = 2
	var grid := _make_grid(clock)
	var summer_only := crop.duplicate() as CropData
	summer_only.id = &"summer_only"
	summer_only.seasons = 1 << GameClock.Season.SUMMER
	grid.crops.append(summer_only)
	grid.till(Vector2i(0, 0))
	check(not grid.plant(Vector2i(0, 0), &"summer_only"), "out-of-season crop can't be planted (spring)")
	clock.sleep()
	clock.sleep()
	check_eq(clock.season, GameClock.Season.SUMMER, "now summer")
	check(grid.plant(Vector2i(0, 0), &"summer_only"), "in-season crop plants")
	grid.enforce_crop_seasons = false
	clock.sleep()
	clock.sleep()
	grid.till(Vector2i(1, 0))
	check(grid.plant(Vector2i(1, 0), &"summer_only"), "season rule can be disabled")
	grid.free()
	clock.free()


func _test_tool_data() -> void:
	var expected := {&"pulaski": ToolData.Kind.PULASKI, &"sickle": ToolData.Kind.SICKLE,
		&"pickaxe": ToolData.Kind.PICKAXE, &"watering_can": ToolData.Kind.WATERING_CAN}
	for t in [PULASKI, SICKLE, PICKAXE, CAN]:
		check(t != null and expected.get(t.id) == t.kind and t.is_tool and t.stamina_cost > 0.0,
			"GDD tool resource: %s" % (t.id if t else "missing"))
	check(not ResourceLoader.exists("res://resources/tools/seeds.tres"),
		"seeds are inventory items now, not a hotbar tool")
	var clock := make_clock()
	var grid := _make_grid(clock)
	check(not grid.use_tool(Vector2i(0, 0), SICKLE), "sickle: nothing to clear on empty soil")
	check(not grid.use_tool(Vector2i(0, 0), PICKAXE), "pickaxe: nothing to break on empty soil")
	check(grid.use_tool(Vector2i(0, 0), PULASKI), "Pulaski tills (hoe half)")
	check_eq(grid.get_plot(Vector2i(1, 0)).state, FarmPlot.State.EMPTY, "basic tool affects 1 tile only")
	grid.free()
	clock.free()


func _test_trees() -> void:
	var data := load(TREE_PATH) as TreeData
	check(data != null, "placeholder tree .tres loads")
	check(data.sapling_hits == 3 and data.fell_hits == 6 and data.stump_hits == 4,
		"GDD hit counts: sapling 3, grown 6 + stump 4")
	var clock := make_clock()
	var grid := _make_grid(clock)
	var felled: Array = []
	var removed: Array = []
	grid.tree_felled.connect(func(c, _id): felled.append(c))
	grid.tree_removed.connect(func(c, _id, st): removed.append([c, st]))
	var wood := {"n": 0}
	grid.items_dropped.connect(func(_c, id, n): if id == &"wood": wood.n += n)
	check(data.drop_item_id == &"wood", "trees drop wood (placeholder ruling)")
	# Sapling: 3 hits.
	var c := Vector2i(1, 1)
	check(grid.place_tree(c, data.id, TreeData.Stage.SAPLING), "place sapling")
	check(not grid.place_tree(c, data.id), "cell already has a tree")
	check(not grid.till(c), "can't till under a tree")
	check(not grid.use_tool(c, CAN), "can't water a tree cell")
	grid.use_tool(c, PULASKI)
	grid.use_tool(c, PULASKI)
	check(grid.get_farm_tree(c) != null, "sapling stands after 2 hits")
	check(grid.use_tool(c, PULASKI), "3rd hit lands")
	check(grid.get_farm_tree(c) == null, "sapling cut after 3 hits")
	check_eq(removed, [[c, TreeData.Stage.SAPLING]], "tree_removed(sapling)")
	check_eq(wood.n, data.sapling_wood, "sapling drops sapling_wood")
	wood.n = 0
	check(grid.use_tool(c, PULASKI) and grid.get_plot(c).state == FarmPlot.State.TILLED,
		"cleared cell can be tilled")
	# Grown: 6 to fell, 4 for the stump = 10.
	var g := Vector2i(4, 2)
	grid.place_tree(g, data.id, TreeData.Stage.GROWN)
	var swings := 0
	while grid.get_farm_tree(g) != null and swings < 20:
		grid.use_tool(g, PULASKI)
		swings += 1
		if swings == 5:
			check_eq(grid.get_farm_tree(g).stage, TreeData.Stage.GROWN, "still standing after 5")
		if swings == 6:
			check_eq(grid.get_farm_tree(g).stage, TreeData.Stage.STUMP, "falls on swing 6 -> stump")
	check_eq(swings, 10, "grown tree fully cleared in 10 swings")
	check_eq(felled, [g], "tree_felled once")
	check_eq(wood.n, data.fell_wood + data.stump_wood, "grown tree drops fell + stump wood")
	wood.n = 0
	# Seed and seedling dig out.
	for st in [TreeData.Stage.SEED, TreeData.Stage.SEEDLING]:
		var d := Vector2i(6 + st, 0)
		grid.place_tree(d, data.id, st)
		check(grid.use_tool(d, PULASKI) and grid.get_farm_tree(d) == null,
			"%s dug out" % TreeData.STAGE_NAMES[st])
	check_eq(wood.n, 0, "dug-out seeds/seedlings drop nothing")
	# Other tools don't affect trees.
	var o := Vector2i(0, 5)
	grid.place_tree(o, data.id, TreeData.Stage.SAPLING)
	grid.use_tool(o, SICKLE)
	grid.use_tool(o, PICKAXE)
	check_eq(grid.get_farm_tree(o).hits, 0, "sickle/pickaxe don't hit trees")
	# Growth: seed -> seedling -> sapling -> grown with stage_days data.
	var data2 := data.duplicate() as TreeData
	data2.id = &"fast_tree"
	data2.stage_days = PackedInt32Array([1, 2, 1])
	grid.trees.append(data2)
	var f := Vector2i(10, 6)
	grid.place_tree(f, &"fast_tree", TreeData.Stage.SEED)
	var stages: Array = []
	for i in 5:
		clock.sleep()
		stages.append(grid.get_farm_tree(f).stage)
	check_eq(stages, [1, 1, 2, 3, 3], "tree grows through 4 stages and stops at grown")
	# Save roundtrip with a damaged stump.
	grid.place_tree(Vector2i(11, 7), data.id, TreeData.Stage.GROWN)
	for i in 7:
		grid.use_tool(Vector2i(11, 7), PULASKI)
	var saved := JSON.parse_string(JSON.stringify(grid.to_dict())) as Dictionary
	var grid2 := _make_grid(clock)
	grid2.from_dict(saved)
	var t2 := grid2.get_farm_tree(Vector2i(11, 7))
	check(t2 != null and t2.stage == TreeData.Stage.STUMP and t2.hits == 1, "tree state saves")
	check(grid2.get_farm_tree(f).tree_id == &"fast_tree", "tree id saves")
	# starting_trees
	var grid3 := FarmGrid.new()
	grid3.trees = [data]
	grid3.starting_trees = {Vector2i(2, 2): "grown", Vector2i(3, 3): TreeData.Stage.SEED}
	grid3.clock = clock
	root.add_child(grid3)
	grid3._ready()
	check(grid3.get_farm_tree(Vector2i(2, 2)).stage == TreeData.Stage.GROWN
		and grid3.get_farm_tree(Vector2i(3, 3)).stage == TreeData.Stage.SEED, "starting_trees placed")
	grid.free()
	grid2.free()
	grid3.free()
	clock.free()


## Placeholder ruling: sickle clears grass/weeds, pickaxe breaks rocks.
func _test_obstacles() -> void:
	var grass := load("res://resources/obstacles/grass.tres") as ObstacleData
	var weed := load("res://resources/obstacles/weed.tres") as ObstacleData
	var rock := load("res://resources/obstacles/rock.tres") as ObstacleData
	check(grass != null and weed != null and rock != null, "obstacle .tres load")
	check(grass.tool_kind == ToolData.Kind.SICKLE and weed.tool_kind == ToolData.Kind.SICKLE,
		"sickle clears grass and weeds")
	check(rock.tool_kind == ToolData.Kind.PICKAXE, "pickaxe breaks rocks")
	var clock := make_clock()
	var grid := _make_grid(clock)
	grid.obstacles = [grass, weed, rock]
	var drops: Array = []
	var cleared: Array = []
	grid.items_dropped.connect(func(c, id, n): drops.append([c, id, n]))
	grid.obstacle_cleared.connect(func(c, id): cleared.append([c, id]))
	var g := Vector2i(0, 0)
	var w := Vector2i(1, 0)
	var r := Vector2i(2, 0)
	check(grid.place_obstacle(g, &"grass") and grid.place_obstacle(w, &"weed")
		and grid.place_obstacle(r, &"rock"), "place obstacles")
	check(not grid.place_obstacle(g, &"rock"), "cell already blocked")
	check(not grid.place_tree(g, grid.trees[0].id), "no tree on an obstacle")
	check(not grid.till(g) and not grid.use_tool(g, PULASKI), "can't till grass")
	check(not grid.use_tool(r, SICKLE), "sickle doesn't break rocks")
	check(not grid.use_tool(g, PICKAXE), "pickaxe doesn't cut grass")
	check(grid.use_tool(g, SICKLE) and not grid.get_plot(g).has_obstacle(), "sickle clears grass")
	check(grid.use_tool(w, SICKLE) and not grid.get_plot(w).has_obstacle(), "sickle clears weeds")
	for i in rock.hits - 1:
		check(grid.use_tool(r, PICKAXE), "rock hit lands")
	check(grid.get_plot(r).has_obstacle(), "rock stands until its last hit")
	check(grid.use_tool(r, PICKAXE) and not grid.get_plot(r).has_obstacle(), "pickaxe breaks the rock")
	check_eq(cleared, [[g, &"grass"], [w, &"weed"], [r, &"rock"]], "obstacle_cleared")
	check_eq(drops, [[r, &"stone", rock.drop_amount]], "rock drops stone (placeholder)")
	check(grid.use_tool(g, PULASKI), "cleared cell can be tilled")
	# Save roundtrip of a damaged rock + starting_obstacles.
	grid.place_obstacle(Vector2i(5, 5), &"rock")
	grid.use_tool(Vector2i(5, 5), PICKAXE)
	var saved := JSON.parse_string(JSON.stringify(grid.to_dict())) as Dictionary
	var grid2 := FarmGrid.new()
	grid2.obstacles = [grass, weed, rock]
	grid2.starting_obstacles = {Vector2i(1, 1): "grass"}
	grid2.clock = clock
	root.add_child(grid2)
	grid2._ready()
	check(grid2.get_plot(Vector2i(1, 1)).obstacle_id == &"grass", "starting_obstacles placed")
	grid2.from_dict(saved)
	var p := grid2.get_plot(Vector2i(5, 5))
	check(p.obstacle_id == &"rock" and p.obstacle_hits == 1, "obstacle state saves")
	check(not grid2.get_plot(Vector2i(1, 1)).has_obstacle(), "the save replaces starting obstacles")
	grid.free()
	grid2.free()
	clock.free()


## Placeholder crops across seasons + Stardew season death (config toggle).
func _test_seasonal_crops() -> void:
	var ids := [&"turnip", &"carrot", &"tomato", &"pumpkin"]
	var covered := 0
	var all: Array[CropData] = [load(CROP_PATH) as CropData]
	for id in ids:
		var c := load("res://resources/crops/%s.tres" % id) as CropData
		check(c != null and c.id == id and c.stage_days.size() == CropData.STAGE_COUNT - 1,
			"crop %s loads with 3 stage-day entries" % id)
		covered |= c.seasons
		all.append(c)
	check_eq(covered & 0b0111, 0b0111, "placeholder crops cover spring, summer and fall")
	check_eq((load("res://resources/crops/carrot.tres") as CropData).get_season_names(),
		PackedStringArray(["Spring", "Fall"]), "season names")
	var clock := make_clock()
	var grid := _make_grid(clock)
	grid.crops = all
	check(grid.kill_out_of_season_crops, "season death on by default")
	var keep := FarmGrid.new()
	keep.crops = all
	keep.kill_out_of_season_crops = false
	keep.clock = clock
	root.add_child(keep)
	keep._ready()
	for g in [grid, keep]:
		for x in 3:
			g.till(Vector2i(x, 0))
		g.plant(Vector2i(0, 0), &"placeholder_crop")
		g.plant(Vector2i(1, 0), &"turnip")
		g.plant(Vector2i(2, 0), &"carrot")
	check(not grid.plant(Vector2i(3, 0), &"tomato"), "tomato can't be planted in spring")
	var died: Array = []
	grid.crop_died.connect(func(c, id): died.append([c, id]))
	var guard := 0
	while clock.season == GameClock.Season.SPRING and guard < 100:
		clock.sleep()
		guard += 1
	check_eq(clock.season, GameClock.Season.SUMMER, "reached summer")
	check_eq(died, [[Vector2i(1, 0), &"turnip"], [Vector2i(2, 0), &"carrot"]],
		"spring-only crops die at the season change")
	check(grid.get_plot(Vector2i(1, 0)).state == FarmPlot.State.TILLED, "dead crop leaves tilled soil")
	check(grid.get_plot(Vector2i(0, 0)).is_planted(), "all-season crop survives")
	check(keep.get_plot(Vector2i(1, 0)).is_planted() and keep.get_plot(Vector2i(2, 0)).is_planted(),
		"toggle off: crops survive")
	grid.till(Vector2i(3, 0))
	check(grid.plant(Vector2i(3, 0), &"tomato"), "tomato plants in summer")
	grid.free()
	keep.free()
	clock.free()


## Wet Waxweed (cinderkin.md ruling): farmable, but only near trees.
func _test_tree_adjacent_crop() -> void:
	var wax := load("res://resources/crops/wet_waxweed.tres") as CropData
	check(wax != null and wax.requires_adjacent_tree, "Wet Waxweed requires an adjacent tree")
	check(not (load("res://resources/crops/turnip.tres") as CropData).requires_adjacent_tree,
		"ordinary crops don't")
	var clock := make_clock()
	var grid := _make_grid(clock)
	grid.crops = [wax, load(CROP_PATH) as CropData]
	var tree_id: StringName = grid.trees[0].id
	var far := Vector2i(1, 1)
	grid.till(far)
	check(not grid.plant(far, &"wet_waxweed"), "no tree nearby: planting fails")
	check_eq(grid.get_plot(far).state, FarmPlot.State.TILLED, "plot stays tilled")
	check(grid.plant(far, &"placeholder_crop"), "an ordinary crop still plants there")
	# A grown tree next to a tilled cell (diagonal counts, radius 1).
	var tree_cell := Vector2i(6, 3)
	grid.place_tree(tree_cell, tree_id, TreeData.Stage.GROWN)
	var diag := tree_cell + Vector2i(1, 1)
	var two_away := tree_cell + Vector2i(2, 0)
	grid.till(diag)
	grid.till(two_away)
	check(grid.is_near_tree(diag), "diagonal neighbour is near the tree")
	check(not grid.is_near_tree(two_away), "two cells away is not")
	check(not grid.plant(two_away, &"wet_waxweed"), "2 cells from the tree: fails")
	check(grid.plant(diag, &"wet_waxweed"), "next to a grown tree: plants")
	# Buried seeds/seedlings don't count as trees; saplings do.
	var seed_cell := Vector2i(2, 6)
	grid.place_tree(seed_cell, tree_id, TreeData.Stage.SEEDLING)
	var by_seedling := seed_cell + Vector2i(0, -1)
	grid.till(by_seedling)
	check(not grid.plant(by_seedling, &"wet_waxweed"), "a seedling isn't a tree yet")
	var sap_cell := Vector2i(9, 6)
	grid.place_tree(sap_cell, tree_id, TreeData.Stage.SAPLING)
	var by_sapling := sap_cell + Vector2i(-1, 0)
	grid.till(by_sapling)
	check(grid.plant(by_sapling, &"wet_waxweed"), "a sapling counts")
	# Grows and harvests like any crop.
	for i in wax.get_days_to_mature():
		grid.water(diag)
		grid.advance_day()
	check(grid.is_mature(diag), "Wet Waxweed matures")
	check_eq(grid.harvest(diag), &"wet_waxweed", "harvest Wet Waxweed")
	check_eq(wax.get_harvest_item_id(), &"wet_waxweed", "harvest item is the wet_waxweed item")
	grid.free()
	clock.free()
