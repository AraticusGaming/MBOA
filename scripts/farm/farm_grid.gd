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
## empty soil; watering can waters; seeds plant. Sickle and pickaxe have no
## target yet (GDD does not say what they act on) and report failure.

signal plot_changed(cell: Vector2i)
signal harvested(crop_id: StringName, cell: Vector2i)
## Emitted when a tool/interact is attempted on a cell (success or not).
signal action_performed(cell: Vector2i, action: StringName, success: bool)
## A Pulaski hit landed on a tree (hits = hits taken in its current stage).
signal tree_hit(cell: Vector2i, stage: int, hits: int)
## A grown tree came down and left a stump.
signal tree_felled(cell: Vector2i, tree_id: StringName)
## A tree (seed/seedling dug out, sapling cut, or stump cleared) left the cell.
## Drops (wood etc.) are not designed yet; listen here when they are.
signal tree_removed(cell: Vector2i, tree_id: StringName, from_stage: int)

## Grid size in cells. PLACEHOLDER.
@export var grid_size: Vector2i = Vector2i(12, 8)
## Cell size in pixels (art spec: 16x16 tiles).
@export var cell_size: int = 16
## Crops known to this grid (data-driven, see resources/crops/*.tres).
@export var crops: Array[CropData] = []
## Crop planted by the Seed tool (empty = first entry of `crops`).
@export var selected_seed_id: StringName = &""
## GDD: crops are tied to seasons. When true, a crop can only be planted in a
## season listed in its CropData.seasons. (What happens to crops when the
## season changes is not specified by the GDD, so nothing happens yet.)
@export var enforce_crop_seasons: bool = true
## Tree types known to this grid (resources/trees/*.tres).
@export var trees: Array[TreeData] = []
## Trees placed on a new farm: cell (Vector2i) -> stage name ("seed",
## "seedling", "sapling", "grown", "stump"); uses the first entry of `trees`.
## Loading a save replaces them.
@export var starting_trees: Dictionary = {}

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
var _starting_trees_placed: bool = false


func _init() -> void:
	_build_plots()


func _ready() -> void:
	_rebuild_crop_index()
	_rebuild_tree_index()
	_place_starting_trees()
	_setup_soil_layer()
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	if clock and not clock.day_started.is_connected(_on_day_started):
		clock.day_started.connect(_on_day_started)


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


## Tree on `cell`, or null.
func get_farm_tree(cell: Vector2i) -> FarmTree:
	var plot := get_plot(cell)
	return plot.tree if plot else null


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
			return hit_tree(cell) if get_plot(cell).has_tree() else till(cell)
		ToolData.Kind.WATERING_CAN:
			return water(cell)
		ToolData.Kind.SEEDS:
			return plant(cell, _get_seed_id())
		ToolData.Kind.SICKLE:
			action_performed.emit(cell, &"sickle", false)  # target not in GDD yet
		ToolData.Kind.PICKAXE:
			action_performed.emit(cell, &"pickaxe", false)  # target not in GDD yet
	return false


func till(cell: Vector2i) -> bool:
	var plot := get_plot(cell)
	var ok := plot != null and plot.state == FarmPlot.State.EMPTY and not plot.has_tree()
	if ok:
		plot.state = FarmPlot.State.TILLED
		_changed(cell)
	action_performed.emit(cell, &"till", ok)
	return ok


func plant(cell: Vector2i, crop_id: StringName) -> bool:
	var plot := get_plot(cell)
	var crop := get_crop(crop_id)
	var ok := plot != null and plot.state == FarmPlot.State.TILLED and crop != null \
		and can_plant_now(crop)
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
## &"" on failure. Inventory handling is Milestone 2 (listen to `harvested`).
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
	if plot == null or plot.state != FarmPlot.State.EMPTY or plot.has_tree() \
			or get_tree_data(tree_id) == null:
		return false
	plot.tree = FarmTree.create(tree_id, stage)
	_changed(cell)
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
	_changed(cell)
	var is_dig := stage == TreeData.Stage.SEED or stage == TreeData.Stage.SEEDLING
	action_performed.emit(cell, &"dig_out" if is_dig else &"chop", true)
	return true


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
		draw_texture_rect_region(crop.sprite_sheet, Rect2(pos.round(), region.size), region)
		return
	var t := float(crop.get_stage(plot.growth_days)) / float(CropData.STAGE_COUNT - 1)
	var size := lerpf(4.0, cell_size - 4.0, t)
	var col := color_seedling.lerp(crop.placeholder_color, t)
	var r := Rect2(rect.get_center() - Vector2(size, size) * 0.5, Vector2(size, size))
	draw_rect(r, col)
	if t >= 1.0:
		draw_rect(r.grow(1.0), Color.WHITE, false, 1.0)


## Placeholder tree drawing (no tree art yet): size grows with the stage; a
## grown tree's canopy extends above its cell.
func _draw_tree(tree: FarmTree, rect: Rect2) -> void:
	var data := get_tree_data(tree.tree_id)
	if data == null:
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


func _place_starting_trees() -> void:
	if _starting_trees_placed or trees.is_empty() or trees[0] == null:
		return
	_starting_trees_placed = true
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


func _get_seed_id() -> StringName:
	if selected_seed_id != &"":
		return selected_seed_id
	return crops[0].id if not crops.is_empty() and crops[0] != null else &""


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
		soil_layer.set_cell(cell, tile_mapping.source_id, tile_mapping.get_atlas_coords(get_plot(cell)))


func _changed(cell: Vector2i) -> void:
	_update_tile(cell)
	plot_changed.emit(cell)
	queue_redraw()


func _on_day_started(_day: int) -> void:
	advance_day()
