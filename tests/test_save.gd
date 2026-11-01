extends MboaTestBase
## SaveManager tests: versioned save data, file round-trip, and continuing a
## loaded game across a day and across a season rollover.

const SaveManagerScript := preload("res://scripts/core/save_manager.gd")
const PlayerStateScript := preload("res://scripts/core/player_state.gd")
const CROP_PATH := "res://resources/crops/placeholder_crop.tres"
const TREE_PATH := "res://resources/trees/placeholder_tree.tres"
const TEST_PATH := "user://test_save_roundtrip.json"

var sm: Node
var _cleanup: Array = []


func _run_tests() -> void:
	sm = SaveManagerScript.new()
	sm.autosave_on_new_day = false
	root.add_child(sm)
	check(root.get_node_or_null("SaveManager") != null, "SaveManager autoload present")
	_test_versioning()
	_test_roundtrip_across_day()
	_test_roundtrip_across_season()
	for n in _cleanup:
		n.free()
	sm.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


## A fresh game world: clock (2-day seasons), PlayerState, farm with crops/trees.
func _make_world() -> Array:
	var clock := make_clock()
	clock.config.days_per_season = 2
	clock._on_config_loaded()
	var ps: Node = PlayerStateScript.new()
	ps.pass_out_config = ps.pass_out_config.duplicate()
	ps.energy_config = ps.energy_config.duplicate()
	root.add_child(ps)
	ps.bind_clock(clock)
	var grid := FarmGrid.new()
	grid.crops = [load(CROP_PATH) as CropData]
	var tree_data := (load(TREE_PATH) as TreeData).duplicate() as TreeData
	tree_data.stage_days = PackedInt32Array([1, 1, 1])
	grid.trees = [tree_data]
	grid.clock = clock
	root.add_child(grid)
	grid._ready()
	_cleanup.append_array([grid, ps, clock])
	return [clock, ps, grid]


func _save_and_reload(world: Array) -> Array:
	var data: Dictionary = sm.build_save_data(world[0], world[1], world[2])
	check(sm.write_file(data, TEST_PATH), "save written to user://")
	var read: Dictionary = sm.read_file(TEST_PATH)
	check_eq(int(read.get("version", -1)), SaveManagerScript.SAVE_VERSION, "save is versioned")
	check(read.has("clock") and read.has("player_state") and read.has("farm"), "save has all sections")
	var loaded := _make_world()
	check(sm.apply_save_data(read, loaded[0], loaded[1], loaded[2]), "save applied")
	return loaded


## Normalizes values through JSON so ints/floats compare equal.
func _norm(d: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)), "", true)


func _same_state(a: Array, b: Array, label: String) -> void:
	check_eq(_norm(b[0].to_dict()), _norm(a[0].to_dict()), label + ": clock matches")
	check_eq(_norm(b[1].to_dict()), _norm(a[1].to_dict()), label + ": player state matches")
	check_eq(_norm(b[2].to_dict()), _norm(a[2].to_dict()), label + ": farm + trees match")
	check(b[0].season == a[0].season and b[0].year == a[0].year, label + ": season/year match")


## Same daily routine on any world: water the crop, sleep.
func _water_and_sleep(world: Array) -> void:
	world[2].water(Vector2i(2, 2))
	world[0].sleep()


func _test_versioning() -> void:
	check(not sm.apply_save_data({}, null, null, null), "save without version rejected")
	check(not sm.apply_save_data({"version": SaveManagerScript.SAVE_VERSION + 1}, null, null, null),
		"save from a newer version rejected")
	check(sm.read_file("user://does_not_exist.json").is_empty(), "missing file -> {}")


func _test_roundtrip_across_day() -> void:
	var w := _make_world()
	var clock: GameClock = w[0]
	var grid: FarmGrid = w[2]
	grid.till(Vector2i(2, 2))
	grid.plant(Vector2i(2, 2), &"placeholder_crop")
	grid.place_tree(Vector2i(5, 1), grid.trees[0].id, TreeData.Stage.SAPLING)
	grid.place_tree(Vector2i(7, 3), grid.trees[0].id, TreeData.Stage.SEED)
	w[1].coins = 120
	_water_and_sleep(w)  # -> day 2 (sapling grows to grown with 1-day stages)
	grid.hit_tree(Vector2i(5, 1))
	w[1].spend_stamina(35.0)
	w[1].damage(10.0)
	clock.advance_minutes(5.0 * 60.0 + 30.0)  # 11:30
	var loaded := _save_and_reload(w)
	_same_state(w, loaded, "after a day")
	check_eq(loaded[0].day, 2, "loaded day 2")
	check_eq(loaded[0].get_time_string(true), "11:30", "loaded time 11:30")
	check(loaded[1].stamina == 65.0 and loaded[1].health == 90.0 and loaded[1].coins == 120,
		"loaded stamina/health/coins")
	check_eq(loaded[2].get_plot(Vector2i(2, 2)).growth_days, 1, "loaded crop growth")
	var t: FarmTree = loaded[2].get_farm_tree(Vector2i(5, 1))
	check(t.stage == TreeData.Stage.GROWN and t.hits == 1, "loaded tree stage and damage")
	# Continue both games one more day: they stay identical.
	_water_and_sleep(w)
	_water_and_sleep(loaded)
	_same_state(w, loaded, "next day after load")
	check(loaded[2].is_mature(Vector2i(2, 2)) == w[2].is_mature(Vector2i(2, 2)), "crop maturity matches")


func _test_roundtrip_across_season() -> void:
	var w := _make_world()
	w[2].till(Vector2i(2, 2))
	w[2].plant(Vector2i(2, 2), &"placeholder_crop")
	w[2].place_tree(Vector2i(9, 4), w[2].trees[0].id, TreeData.Stage.SEED)
	_water_and_sleep(w)  # day 2 = last day of spring (2-day seasons)
	check_eq(w[0].season, GameClock.Season.SPRING, "day 2 is still spring")
	var loaded := _save_and_reload(w)
	var seasons: Array = []
	loaded[0].season_changed.connect(func(s, y): seasons.append([s, y]))
	_water_and_sleep(w)
	_water_and_sleep(loaded)
	check_eq(loaded[0].season, GameClock.Season.SUMMER, "loaded game rolls over into summer")
	check_eq(seasons, [[GameClock.Season.SUMMER, 1]], "season_changed fires after load")
	_same_state(w, loaded, "across season rollover")
	# Save in summer and load again: season restored from the save.
	var loaded2 := _save_and_reload(loaded)
	check_eq(loaded2[0].season, GameClock.Season.SUMMER, "summer save loads as summer")
	_same_state(loaded, loaded2, "summer save")
	# Roll through to the next year with both games.
	for i in 6:
		_water_and_sleep(loaded)
		_water_and_sleep(loaded2)
	check(loaded2[0].year == 2 and loaded2[0].season == GameClock.Season.SPRING, "year 2 spring")
	_same_state(loaded, loaded2, "after a full year")
	check_eq(loaded2[2].get_farm_tree(Vector2i(9, 4)).stage, TreeData.Stage.GROWN, "tree grew to grown")
