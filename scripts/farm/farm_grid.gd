class_name FarmGrid
extends Node2D
## Grid of farm plots (16x16 cells by default) with till / plant / water /
## grow / harvest rules.
##
## Rendering: with `tileset` + `tile_mapping` set, soil is a child TileMapLayer
## ("SoilLayer", drawn behind this node) using FarmTileMapping (state -> tile),
## and crops are drawn on top from each CropData sprite sheet. Without them
## (e.g. in logic tests) it falls back to placeholder rectangles.
##
## Growth rule: on Clock.day_started, every planted, not-yet-mature plot that
## was watered the previous day grows by one day; then all watered flags reset.
## Trees (TreeData) advance through seed -> seedling -> sapling -> grown.
##
## Tools (ToolData, one tile each): Pulaski hits a tree on the cell or tills
## empty soil; watering can waters (seeds are planted with plant()). Not GDD, placeholder (Ledan
## ruling): the sickle clears grass and weeds, the pickaxe breaks rocks
## (ObstacleData, resources/obstacles/*.tres). Cleared trees and obstacles
## report their drops through `items_dropped` (wood, stone).

signal plot_changed(cell: Vector2i)
signal harvested(crop_id: StringName, cell: Vector2i)
## A crop died because the season changed and it doesn't grow in the new one.
signal crop_died(cell: Vector2i, crop_id: StringName)
## Emitted when a tool/interact is attempted on a cell (success or not).
signal action_performed(cell: Vector2i, action: StringName, success: bool)
## A Pulaski hit landed on a tree (hits = hits taken in its current stage).
signal tree_hit(cell: Vector2i, stage: int, hits: int)
## A grown tree came down and left a stump.
signal tree_felled(cell: Vector2i, tree_id: StringName)
## A tree (seed/seedling dug out, sapling cut, or stump cleared) left the cell.
signal tree_removed(cell: Vector2i, tree_id: StringName, from_stage: int)
## A sickle/pickaxe hit landed on an obstacle (hits taken so far).
signal obstacle_hit(cell: Vector2i, obstacle_id: StringName, hits: int)
## An obstacle was cleared from the cell.
signal obstacle_cleared(cell: Vector2i, obstacle_id: StringName)
## Items produced on `cell` (wood from trees, stone from rocks...). The player
## puts them in the inventory.
signal items_dropped(cell: Vector2i, item_id: StringName, amount: int)

## Grid size in cells. PLACEHOLDER.
@export var grid_size: Vector2i = Vector2i(12, 8)
## Cell size in pixels (art spec: 16x16 tiles).
@export var cell_size: int = 16
## Crops known to this grid (data-driven, see resources/crops/*.tres).
@export var crops: Array[CropData] = []
## GDD: crops are tied to seasons. When true, a crop can only be planted in a
## season listed in its CropData.seasons.
@export var enforce_crop_seasons: bool = true
## Not GDD, placeholder (Ledan ruling, Stardew rule): when the season changes,
## crops that don't grow in the new season die (the plot goes back to tilled
## soil). Toggle off to keep them.
@export var kill_out_of_season_crops: bool = true
## Tree types known to this grid (resources/trees/*.tres).
@export var trees: Array[TreeData] = []
## Trees placed on a new farm: cell (Vector2i) -> stage name ("seed",
## "seedling", "sapling", "grown", "stump"); uses the first entry of `trees`.
## Loading a save replaces them.
@export var starting_trees: Dictionary = {}
## Obstacle types known to this grid (resources/obstacles/*.tres).
@export var obstacles: Array[ObstacleData] = []
## Obstacles placed on a new farm: cell (Vector2i) -> obstacle id. Placeholder
## layout. Loading a save replaces them.
@export var starting_obstacles: Dictionary = {}

@export_group("Art")
## Farm TileSet (resources/farm_tileset.tres). null = placeholder rectangles.
@export var tileset: TileSet
## Plot state -> atlas tile (resources/farm_tile_mapping.tres).
@export var tile_mapping: FarmTileMapping
## Thin grid lines over the plots (always drawn in placeholder mode).
@export var show_grid_lines: bool = false

@export_group("Placeholder colors")
@export var color_empty: Color = Color(0.36, 0.55, 0.27)
@export var color_tilled: Color = Color(0.55, 0.38, 0.22)
@export var color_watered: Color = Color(0.36, 0.24, 0.14)
@export var color_seedling: Color = Color(0.45, 0.8, 0.35)
@export var color_grid_line: Color = Color(0, 0, 0, 0.18)
@export var color_highlight: Color = Color(1, 1, 1, 0.9)

var plots: Array[FarmPlot] = []
## Cell outlined as the player's current target (-1,-1 = none).
var highlight_cell: Vector2i = Vector2i(-1, -1)
var clock: GameClock
## Soil TileMapLayer created in _ready when art is configured.
var soil_layer: TileMapLayer

var _crop_index: Dictionary = {}
var _tree_index: Dictionary = {}
var _obstacle_index: Dictionary = {}
var _starting_trees_placed: bool = false


func _init() -> void:
	_build_plots()


func _ready() -> void:
	add_to_group(&"farm_grid")
	_rebuild_crop_index()
	_rebuild_tree_index()
	_place_starting_trees()
	_setup_soil_layer()
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	if clock and not clock.day_started.is_connected(_on_day_started):
		clock.day_started.connect(_on_day_started)
	if clock and not clock.season_changed.is_connected(_on_season_changed):
		clock.season_changed.connect(_on_season_changed)


# --- Queries ----------------------------------------------------------------

func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func get_plot(cell: Vector2i) -> FarmPlot:
	if not is_in_bounds(cell):
		return null
	if plots.size() != grid_size.x * grid_size.y:
		_build_plots()
	return plots[cell.y * grid_size.x + cell.x]


func get_crop(crop_id: StringName) -> CropData:
	if _crop_index.size() != crops.size():
		_rebuild_crop_index()
	return _crop_index.get(crop_id)


func get_tree_data(tree_id: StringName) -> TreeData:
	if _tree_index.size() != trees.size():
		_rebuild_tree_index()
	return _tree_index.get(tree_id)


func get_obstacle_data(obstacle_id: StringName) -> ObstacleData:
	if _obstacle_index.size() != obstacles.size():
		_rebuild_obstacle_index()
	return _obstacle_index.get(obstacle_id)


## Tree on `cell`, or null.
func get_farm_tree(cell: Vector2i) -> FarmTree:
	var plot := get_plot(cell)
	return plot.tree if plot else null


## True if a tree of at least `min_stage` (TreeData.Stage) stands within
## `radius` cells (Chebyshev) of `cell`, not counting `cell` itself.
func is_near_tree(cell: Vector2i, radius: int = 1, min_stage: int = TreeData.Stage.SAPLING) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			var t := get_farm_tree(cell + Vector2i(dx, dy))
			if t != null and t.stage >= min_stage:
				return true
	return false


## Placement rules from CropData (e.g. Wet Waxweed must be near a tree).
func meets_placement(cell: Vector2i, crop: CropData) -> bool:
	if crop == null or not crop.requires_adjacent_tree:
		return true
	return is_near_tree(cell, crop.tree_search_radius, crop.min_tree_stage)


## CropData planted on `cell`, or null.
func get_crop_at(cell: Vector2i) -> CropData:
	var plot := get_plot(cell)
	return get_crop(plot.crop_id) if plot and plot.is_planted() else null


## True if `crop` may be planted in the current season (see enforce_crop_seasons).
func can_plant_now(crop: CropData) -> bool:
	if crop == null:
		return false
	if not enforce_crop_seasons or clock == null:
		return true
	return crop.grows_in(clock.season)


func is_mature(cell: Vector2i) -> bool:
	var plot := get_plot(cell)
	if plot == null or not plot.is_planted():
		return false
	var crop := get_crop(plot.crop_id)
	return crop != null and crop.is_mature(plot.growth_days)


## Converts a global position to a cell (may be out of bounds).
func world_to_cell(global_pos: Vector2) -> Vector2i:
	var local := to_local(global_pos)
	return Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))


func cell_to_world_center(cell: Vector2i) -> Vector2:
	return to_global(Vector2(cell) * cell_size + Vector2.ONE * cell_size * 0.5)


func get_pixel_size() -> Vector2:
	return Vector2(grid_size * cell_size)


# --- Actions ----------------------------------------------------------------

## Player-facing entry point: harvest if mature (no tool needed, GDD: walk up
## and click), otherwise use `tool` on the cell.
func interact(cell: Vector2i, tool: ToolData) -> bool:
	if not is_in_bounds(cell):
		return false
	if is_mature(cell):
		return harvest(cell) != &""
	return use_tool(cell, tool)


## Applies one use of `tool` to one tile. Returns true if it had an effect.
## (Stamina is handled by the caller, see Player.)
func use_tool(cell: Vector2i, tool: ToolData) -> bool:
	if tool == null or not is_in_bounds(cell):
		return false
	match tool.kind:
		ToolData.Kind.PULASKI:
			if get_plot(cell).has_obstacle():
				action_performed.emit(cell, &"till", false)
				return false
			return hit_tree(cell) if get_plot(cell).has_tree() else till(cell)
		ToolData.Kind.WATERING_CAN:
			return water(cell)
		ToolData.Kind.SICKLE:
			return hit_obstacle(cell, tool, &"sickle")
		ToolData.Kind.PICKAXE:
			return hit_obstacle(cell, tool, &"pickaxe")
	return false


func till(cell: Vector2i) -> bool:
	var plot := get_plot(cell)
	var ok := plot != null and plot.state == FarmPlot.State.EMPTY and not plot.is_blocked()
	if ok:
		plot.state = FarmPlot.State.TILLED
		_changed(cell)
	action_performed.emit(cell, &"till", ok)
	return ok


func plant(cell: Vector2i, crop_id: StringName) -> bool:
	var plot := get_plot(cell)
	var crop := get_crop(crop_id)
	var ok := plot != null and plot.state == FarmPlot.State.TILLED and crop != null \
		and can_plant_now(crop) and meets_placement(cell, crop)
	if ok:
		plot.state = FarmPlot.State.PLANTED
		plot.crop_id = crop_id
		plot.growth_days = 0
		_changed(cell)
	action_performed.emit(cell, &"plant", ok)
	return ok


## Waters tilled soil or a growing crop (watering soil before planting counts).
func water(cell: Vector2i) -> bool:
	var plot := get_plot(cell)
	var ok := plot != null and plot.state != FarmPlot.State.EMPTY and not plot.watered
	if ok:
		plot.watered = true
		_changed(cell)
	action_performed.emit(cell, &"water", ok)
	return ok


## Harvests a mature crop; the plot returns to TILLED. Returns the crop id or
## &"" on failure. The Player puts the crop's item in the inventory.
func harvest(cell: Vector2i) -> StringName:
	if not is_mature(cell):
		action_performed.emit(cell, &"harvest", false)
		return &""
	var plot := get_plot(cell)
	var crop_id := plot.crop_id
	plot.clear_crop()
	plot.state = FarmPlot.State.TILLED
	_changed(cell)
	action_performed.emit(cell, &"harvest", true)
	harvested.emit(crop_id, cell)
	return crop_id


## Puts a tree on an empty, untilled cell. Returns false if the cell is taken.
func place_tree(cell: Vector2i, tree_id: StringName, stage: int = TreeData.Stage.SEED) -> bool:
	var plot := get_plot(cell)
	if plot == null or plot.state != FarmPlot.State.EMPTY or plot.is_blocked() \
			or get_tree_data(tree_id) == null:
		return false
	plot.tree = FarmTree.create(tree_id, stage)
	_changed(cell)
	return true


## Puts an obstacle on an empty, untilled, unblocked cell.
func place_obstacle(cell: Vector2i, obstacle_id: StringName) -> bool:
	var plot := get_plot(cell)
	if plot == null or plot.state != FarmPlot.State.EMPTY or plot.is_blocked() \
			or get_obstacle_data(obstacle_id) == null:
		return false
	plot.obstacle_id = obstacle_id
	plot.obstacle_hits = 0
	_changed(cell)
	return true


## One sickle/pickaxe hit on the obstacle at `cell`. Only the obstacle's own
## tool works (placeholder ruling). Returns true if a hit landed.
func hit_obstacle(cell: Vector2i, tool: ToolData, action: StringName = &"clear") -> bool:
	var plot := get_plot(cell)
	var data := get_obstacle_data(plot.obstacle_id) if plot and plot.has_obstacle() else null
	if data == null or not data.is_cleared_by(tool):
		action_performed.emit(cell, action, false)
		return false
	plot.obstacle_hits += 1
	obstacle_hit.emit(cell, data.id, plot.obstacle_hits)
	if plot.obstacle_hits >= data.hits:
		plot.obstacle_id = &""
		plot.obstacle_hits = 0
		obstacle_cleared.emit(cell, data.id)
		if data.drop_item_id != &"" and data.drop_amount > 0:
			items_dropped.emit(cell, data.drop_item_id, data.drop_amount)
	_changed(cell)
	action_performed.emit(cell, action, true)
	return true


## One Pulaski hit on the tree at `cell` (GDD hit counts from TreeData).
## Seed/seedling: dug out; sapling: cut; grown: felled to a stump; stump:
## cleared. Returns true if a hit landed.
func hit_tree(cell: Vector2i) -> bool:
	var plot := get_plot(cell)
	var tree := plot.tree if plot else null
	var data := get_tree_data(tree.tree_id) if tree else null
	if data == null:
		action_performed.emit(cell, &"chop", false)
		return false
	tree.hits += 1
	var stage := tree.stage
	tree_hit.emit(cell, stage, tree.hits)
	if tree.hits >= data.get_hits_for_stage(stage):
		if stage == TreeData.Stage.GROWN:
			tree.stage = TreeData.Stage.STUMP
			tree.hits = 0
			tree.days_in_stage = 0
			tree_felled.emit(cell, tree.tree_id)
		else:
			plot.tree = null
			tree_removed.emit(cell, tree.tree_id, stage)
		var wood := data.get_drop_for_stage(stage)
		if wood > 0 and data.drop_item_id != &"":
			items_dropped.emit(cell, data.drop_item_id, wood)
	_changed(cell)
	var is_dig := stage == TreeData.Stage.SEED or stage == TreeData.Stage.SEEDLING
	action_performed.emit(cell, &"dig_out" if is_dig else &"chop", true)
	return true


## Season change (Stardew rule, placeholder): crops that don't grow in
## `season` die. Returns how many died. No-op when kill_out_of_season_crops
## is off.
func kill_out_of_season(season: int) -> int:
	if not kill_out_of_season_crops:
		return 0
	var died := 0
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			var plot := get_plot(cell)
			if not plot.is_planted():
				continue
			var crop := get_crop(plot.crop_id)
			if crop != null and crop.grows_in(season):
				continue
			var crop_id := plot.crop_id
			plot.clear_crop()
			plot.state = FarmPlot.State.TILLED
			died += 1
			_changed(cell)
			crop_died.emit(cell, crop_id)
	return died


## Day rollover: grow watered crops, then reset watered flags.
func advance_day() -> void:
	for i in plots.size():
		var plot := plots[i]
		if plot.is_planted() and plot.watered:
			var crop := get_crop(plot.crop_id)
			if crop != null and not crop.is_mature(plot.growth_days):
				plot.growth_days += 1
		plot.watered = false
		if plot.tree:
			_grow_tree(plot.tree)
	refresh_tiles()
	queue_redraw()


## True when soil is rendered from the TileSet instead of placeholder rects.
func uses_tiles() -> bool:
	return soil_layer != null


## Re-syncs every soil tile from plot state.
func refresh_tiles() -> void:
	if soil_layer == null:
		return
	for y in grid_size.y:
		for x in grid_size.x:
			_update_tile(Vector2i(x, y))


func set_highlight(cell: Vector2i) -> void:
	if cell != highlight_cell:
		highlight_cell = cell
		queue_redraw()


func to_dict() -> Dictionary:
	var arr: Array = []
	for p in plots:
		arr.append(p.to_dict())
	return {"grid_size": [grid_size.x, grid_size.y], "plots": arr}  # plots carry trees


func from_dict(data: Dictionary) -> void:
	var size_arr: Array = data.get("grid_size", [grid_size.x, grid_size.y])
	grid_size = Vector2i(int(size_arr[0]), int(size_arr[1]))
	_build_plots()
	_starting_trees_placed = true  # the save decides where trees are
	var arr: Array = data.get("plots", [])
	for i in mini(arr.size(), plots.size()):
		plots[i] = FarmPlot.from_dict(arr[i])
	refresh_tiles()
	queue_redraw()


# --- Drawing (placeholder art) ---------------------------------------------

func _draw() -> void:
	var cs := float(cell_size)
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			var plot := get_plot(cell)
			var rect := Rect2(Vector2(x, y) * cs, Vector2(cs, cs))
			if soil_layer == null:
				var base := color_empty
				if plot.state != FarmPlot.State.EMPTY:
					base = color_watered if plot.watered else color_tilled
				draw_rect(rect, base)
			if soil_layer == null or show_grid_lines:
				draw_rect(rect, color_grid_line, false, 1.0)
			if plot.is_planted():
				_draw_crop(plot, rect)
			elif plot.has_tree():
				_draw_tree(plot.tree, rect)
			if plot.has_obstacle():
				_draw_obstacle(plot, rect)
	if is_in_bounds(highlight_cell):
		var hr := Rect2(Vector2(highlight_cell) * cs, Vector2(cs, cs)).grow(-0.5)
		draw_rect(hr, color_highlight, false, 1.0)


func _draw_crop(plot: FarmPlot, rect: Rect2) -> void:
	var crop := get_crop(plot.crop_id)
	if crop == null:
		return
	if crop.sprite_sheet != null:
		var region := crop.get_frame_region(crop.get_frame_for_growth(plot.growth_days))
		# Bottom-center the frame on the cell (taller crop frames grow upward).
		var pos := Vector2(rect.position.x + (rect.size.x - region.size.x) * 0.5,
			rect.end.y - region.size.y)
		draw_texture_rect_region(crop.sprite_sheet, Rect2(pos.round(), region.size), region,
			crop.sprite_tint)
		return
	var t := float(crop.get_stage(plot.growth_days)) / float(CropData.STAGE_COUNT - 1)
	var size := lerpf(4.0, cell_size - 4.0, t)
	var col := color_seedling.lerp(crop.placeholder_color, t)
	var r := Rect2(rect.get_center() - Vector2(size, size) * 0.5, Vector2(size, size))
	draw_rect(r, col)
	if t >= 1.0:
		draw_rect(r.grow(1.0), Color.WHITE, false, 1.0)


## Tree drawing: the TreeData sheet when set, else placeholder rects whose size grows with the stage; a
## grown tree's canopy extends above its cell.
func _draw_tree(tree: FarmTree, rect: Rect2) -> void:
	var data := get_tree_data(tree.tree_id)
	if data == null:
		return
	var region := data.get_frame_region(tree.stage)
	if region.has_area():
		# ART_NOTES anchor: frame bottom-center on the cell's bottom-center.
		var pos := Vector2(rect.get_center().x - region.size.x * 0.5, rect.end.y - region.size.y)
		draw_texture_rect_region(data.sprite_sheet, Rect2(pos.round(), region.size), region)
		return
	var c := rect.get_center()
	var bottom := rect.end.y
	match tree.stage:
		TreeData.Stage.SEED:
			draw_rect(Rect2(c.x - 1.5, bottom - 5, 3, 3), data.color_trunk)
		TreeData.Stage.SEEDLING:
			draw_rect(Rect2(c.x - 0.5, bottom - 8, 1, 6), data.color_trunk)
			draw_rect(Rect2(c.x - 3, bottom - 10, 6, 3), data.color_canopy)
		TreeData.Stage.SAPLING:
			draw_rect(Rect2(c.x - 1, bottom - 12, 2, 10), data.color_trunk)
			draw_rect(Rect2(c.x - 5, bottom - 18, 10, 8), data.color_canopy)
		TreeData.Stage.GROWN:
			draw_rect(Rect2(c.x - 2, bottom - 14, 4, 12), data.color_trunk)
			draw_rect(Rect2(c.x - 9, bottom - 34, 18, 22), data.color_canopy)
			draw_rect(Rect2(c.x - 9, bottom - 34, 18, 22), data.color_canopy.darkened(0.3), false, 1.0)
		TreeData.Stage.STUMP:
			draw_rect(Rect2(c.x - 4, bottom - 6, 8, 4), data.color_trunk)
			draw_rect(Rect2(c.x - 4, bottom - 7, 8, 1), data.color_trunk.lightened(0.3))


## Placeholder obstacle drawing (no art yet).
func _draw_obstacle(plot: FarmPlot, rect: Rect2) -> void:
	var data := get_obstacle_data(plot.obstacle_id)
	if data == null:
		return
	var c := rect.get_center()
	var bottom := rect.end.y
	match data.look:
		ObstacleData.Look.GRASS:
			for i in 4:
				draw_rect(Rect2(rect.position.x + 2 + i * 3.5, bottom - 7 - (i % 2) * 2, 2, 5 + (i % 2) * 2), data.color)
		ObstacleData.Look.WEED:
			draw_rect(Rect2(c.x - 0.5, bottom - 10, 1, 8), data.color)
			draw_rect(Rect2(c.x - 5, bottom - 9, 4, 3), data.color)
			draw_rect(Rect2(c.x + 1, bottom - 11, 4, 3), data.color)
			draw_rect(Rect2(c.x - 1, bottom - 13, 2, 2), Color(0.85, 0.75, 0.2))
		ObstacleData.Look.ROCK:
			var r := Rect2(c.x - 5, bottom - 9, 10, 7)
			draw_rect(r, data.color)
			draw_rect(Rect2(r.position.x + 1, r.position.y, 6, 2), data.color.lightened(0.3))
			draw_rect(r, data.color.darkened(0.4), false, 1.0)


# --- Internals --------------------------------------------------------------

func _build_plots() -> void:
	plots.clear()
	for i in grid_size.x * grid_size.y:
		plots.append(FarmPlot.new())


func _rebuild_crop_index() -> void:
	_crop_index.clear()
	for c in crops:
		if c != null:
			_crop_index[c.id] = c


func _rebuild_tree_index() -> void:
	_tree_index.clear()
	for t in trees:
		if t != null:
			_tree_index[t.id] = t


func _rebuild_obstacle_index() -> void:
	_obstacle_index.clear()
	for o in obstacles:
		if o != null:
			_obstacle_index[o.id] = o


## Places starting_trees and starting_obstacles once on a new farm (a loaded
## save sets _starting_trees_placed and decides instead).
func _place_starting_trees() -> void:
	if _starting_trees_placed:
		return
	_starting_trees_placed = true
	for cell in starting_obstacles:
		if cell is Vector2i:
			place_obstacle(cell, StringName(starting_obstacles[cell]))
	if trees.is_empty() or trees[0] == null:
		return
	for cell in starting_trees:
		var stage_value = starting_trees[cell]
		var stage := TreeData.stage_from_name(stage_value) if stage_value is String \
			else int(stage_value)
		if stage >= 0 and cell is Vector2i:
			place_tree(cell, trees[0].id, stage)


func _grow_tree(tree: FarmTree) -> void:
	var data := get_tree_data(tree.tree_id)
	if data == null:
		return
	var need := data.get_days_for_stage(tree.stage)
	if need <= 0:
		return
	tree.days_in_stage += 1
	if tree.days_in_stage >= need:
		tree.stage += 1
		tree.days_in_stage = 0
		tree.hits = 0


func _setup_soil_layer() -> void:
	if tileset == null or tile_mapping == null:
		return
	if soil_layer == null:
		soil_layer = get_node_or_null(^"SoilLayer") as TileMapLayer
	if soil_layer == null:
		soil_layer = TileMapLayer.new()
		soil_layer.name = "SoilLayer"
		add_child(soil_layer, false, Node.INTERNAL_MODE_FRONT)
	soil_layer.tile_set = tileset
	soil_layer.show_behind_parent = true  # crops/highlight (this node's _draw) on top
	refresh_tiles()


func _update_tile(cell: Vector2i) -> void:
	if soil_layer and is_in_bounds(cell):
		soil_layer.set_cell(cell, tile_mapping.source_id, tile_mapping.get_atlas_coords(get_plot(cell), cell))


func _changed(cell: Vector2i) -> void:
	_update_tile(cell)
	plot_changed.emit(cell)
	queue_redraw()


func _on_season_changed(new_season: int, _year: int) -> void:
	kill_out_of_season(new_season)


func _on_day_started(_day: int) -> void:
	advance_day()
