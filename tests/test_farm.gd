extends MboaTestBase
## Farm tests: till -> plant -> water -> day rollover grows; unwatered does not
## grow; maturity and harvest; tool rules; save/load.

const CROP_PATH := "res://resources/crops/placeholder_crop.tres"


func _make_grid(clock: GameClock) -> FarmGrid:
	var grid := FarmGrid.new()
	grid.crops = [load(CROP_PATH) as CropData]
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
	check(grid.interact(cell, FarmTools.Tool.HOE), "interact with hoe tills")
	check(grid.interact(cell, FarmTools.Tool.SEED), "interact with seeds plants default crop")
	check_eq(grid.get_plot(cell).crop_id, crop.id, "default seed is first crop")
	for i in crop.get_days_to_mature():
		check(grid.interact(cell, FarmTools.Tool.WATERING_CAN), "interact waters (day %d)" % (i + 1))
		clock.sleep()
	var harvested := [false]
	grid.harvested.connect(func(_id, _c): harvested[0] = true)
	check(grid.interact(cell, FarmTools.Tool.HOE), "interact on mature crop harvests (any tool)")
	check(harvested[0], "harvest signal via interact")
	grid.interact(cell, FarmTools.Tool.SEED)
	grid.interact(cell, FarmTools.Tool.WATERING_CAN)
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
