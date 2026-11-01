extends MboaTestBase
## Art integration: TileSet / SpriteFrames / crop sheet load and match
## assets/ART_NOTES.md; farm soil tiles follow plot state; crop frame mapping;
## player animations follow facing and movement.

const TILESET := "res://resources/farm_tileset.tres"
const MAPPING := "res://resources/farm_tile_mapping.tres"
const FRAMES := "res://resources/player_frames.tres"
const CROP := "res://resources/crops/placeholder_crop.tres"


func _run_tests() -> void:
	_test_tileset()
	_test_player_frames()
	_test_autotile_mapping()
	_test_decor_layer()
	_test_new_assets()
	_test_crop_frames()
	_test_farm_tiles()
	await _test_player_animation()


func _test_tileset() -> void:
	var ts := load(TILESET) as TileSet
	check(ts != null, "farm tileset loads")
	if ts == null:
		return
	check_eq(ts.tile_size, Vector2i(16, 16), "tile size 16x16")
	var src := ts.get_source(0) as TileSetAtlasSource
	check(src != null and src.texture != null, "atlas source 0 has farm_tiles.png")
	if src == null:
		return
	check_eq(src.texture.get_size(), Vector2(128, 112), "farm_tiles.png is 128x112 (8 cols; M1b rows appended)")
	check_eq(src.get_tiles_count(), 51, "51 tiles defined (ART_NOTES 0-55 minus empty 19-23)")
	var missing := []
	for i in 56:
		var has := src.has_tile(Vector2i(i % 8, i / 8))
		if has == (i >= 19 and i <= 23):
			missing.append(i)
	check(missing.is_empty(), "tiles 0-18 and 24-55 exist, 19-23 skipped (bad: %s)" % str(missing))
	var map := load(MAPPING) as FarmTileMapping
	check(map != null, "tile mapping loads")
	for coords in [map.empty_tile, map.tilled_tile, map.watered_tile]:
		check(src.has_tile(coords), "mapped tile %s exists" % str(coords))


func _test_player_frames() -> void:
	var sf := load(FRAMES) as SpriteFrames
	check(sf != null, "player SpriteFrames loads")
	if sf == null:
		return
	check(not sf.has_animation(&"default"), "no stray 'default' animation")
	for anim in ["idle", "walk"]:
		for dir in ["down", "left", "right", "up"]:
			var n := StringName("%s_%s" % [anim, dir])
			check(sf.has_animation(n) and sf.get_frame_count(n) == 4 and sf.get_animation_loop(n),
				"%s: 4 looping frames" % n)
	var f := sf.get_frame_texture(&"walk_left", 0) as AtlasTexture
	check(f != null and f.region == Rect2(64, 32, 16, 32), "walk_left frame 0 = sheet index 12 (16x32)")
	var u := sf.get_frame_texture(&"idle_up", 3) as AtlasTexture
	check(u != null and u.region == Rect2(48, 96, 16, 32), "idle_up frame 3 = sheet index 27")
	check_eq(sf.get_animation_speed(&"walk_down"), 8.0, "walk 8 fps")


func _test_crop_frames() -> void:
	var crop := load(CROP) as CropData
	check(crop.sprite_sheet != null and crop.sprite_sheet.get_size() == Vector2(64, 16),
		"crop sheet crop_basic.png 64x16")
	check_eq(crop.get_days_to_mature(), 3, "placeholder crop: 3 watered days (1 per stage)")
	var frames: Array = []
	for d in crop.get_days_to_mature() + 2:
		frames.append(crop.get_frame_for_growth(d))
	check_eq(frames, [0, 1, 2, 3, 3], "growth days -> seed, sprout, leafy, ready, ready")
	check_eq(crop.get_frame_region(3), Rect2(48, 0, 16, 16), "frame 3 region")
	var long_crop := crop.duplicate() as CropData
	long_crop.stage_days = PackedInt32Array([2, 1, 3])
	var stages: Array = []
	for d in 7:
		stages.append(long_crop.get_stage(d))
	check_eq(stages, [0, 0, 1, 2, 2, 2, 3], "per-stage day data drives the 4 stages")


func _test_farm_tiles() -> void:
	var clock := make_clock()
	var grid := FarmGrid.new()
	grid.crops = [load(CROP) as CropData]
	grid.tileset = load(TILESET)
	grid.tile_mapping = load(MAPPING)
	grid.clock = clock
	root.add_child(grid)
	grid._ready()
	check(grid.uses_tiles(), "grid renders soil with the TileSet")
	var map := grid.tile_mapping
	var c := Vector2i(2, 2)
	var at := func() -> Vector2i: return grid.soil_layer.get_cell_atlas_coords(c)
	check_eq(at.call(), map.get_atlas_coords(grid.get_plot(c), c), "empty plot -> its dirt tile")
	check(at.call() == map.empty_tile or map.empty_variants.has(at.call()), "empty plot is dirt or a dirt variant")
	var variants := 0
	for cell in grid.soil_layer.get_used_cells():
		if map.empty_variants.has(grid.soil_layer.get_cell_atlas_coords(cell)):
			variants += 1
	check(variants > 5 and variants < 60, "some (not all) dirt cells use variants 17/18 (%d)" % variants)
	check_eq(grid.soil_layer.get_used_cells().size(), 96, "every plot has a soil tile")
	grid.till(c)
	check_eq(at.call(), map.tilled_tile, "tilled -> tilled_soil")
	grid.plant(c, &"placeholder_crop")
	grid.water(c)
	check_eq(at.call(), map.watered_tile, "watered -> watered_soil")
	clock.sleep()
	check_eq(at.call(), map.tilled_tile, "watered tile reverts after day rollover")
	check_eq(grid.get_plot(c).growth_days, 1, "grid logic unchanged with tiles")
	grid.free()
	clock.free()


func _test_player_animation() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var player := main.get_node("Farm/Player") as Player
	var sprite := player.sprite
	check(sprite != null and sprite.sprite_frames != null, "player has AnimatedSprite2D with frames")
	if sprite == null:
		return
	check_eq(sprite.offset, Vector2(0, -16), "sprite offset (0,-16): feet on origin")
	check(sprite.centered, "sprite centered (16x32 frame bottom at origin)")
	check_eq(sprite.animation, &"idle_down", "starts idle_down")
	Input.action_press(&"move_left")
	for i in 3:
		await physics_frame
	check_eq(sprite.animation, &"walk_left", "walking left plays walk_left")
	check(sprite.is_playing(), "animation playing")
	Input.action_release(&"move_left")
	Input.action_press(&"move_up")
	for i in 3:
		await physics_frame
	check_eq(sprite.animation, &"walk_up", "walking up plays walk_up")
	Input.action_release(&"move_up")
	for i in 2:
		await physics_frame
	check_eq(sprite.animation, &"idle_up", "stopping keeps facing: idle_up")
	# Feet alignment: a player standing at a cell's bottom edge has feet in that cell.
	var grid := main.get_node("Farm/FarmGrid") as FarmGrid
	player.global_position = grid.cell_to_world_center(Vector2i(4, 2)) + Vector2(0, 8)
	check_eq(player.get_feet_cell(), Vector2i(4, 2), "feet cell matches grid cell")
	main.queue_free()
	await process_frame


func _test_autotile_mapping() -> void:
	var map := load(MAPPING) as FarmTileMapping
	check_eq([FarmTileMapping.N, FarmTileMapping.E, FarmTileMapping.S, FarmTileMapping.W], [1, 2, 4, 8],
		"ART bitmask N=1 E=2 S=4 W=8")
	var ok := true
	for mask in 16:
		var f := map.fence_coords(mask)
		var p := map.path_coords(mask)
		if f != Vector2i((24 + mask) % 8, (24 + mask) / 8) or p != Vector2i((40 + mask) % 8, (40 + mask) / 8):
			ok = false
	check(ok, "fence = 24 + mask, path = 40 + mask for all 16 masks")
	check_eq(map.fence_coords(0), Vector2i(0, 3), "fence lone post = tile 24 (0,3)")
	check_eq(map.fence_coords(10), Vector2i(2, 4), "fence E+W straight = tile 34")
	check_eq(map.path_coords(15), Vector2i(7, 6), "path cross = tile 55")
	var c := Vector2i(5, 5)
	var set := {c + Vector2i.UP: true, c + Vector2i.RIGHT: true}
	check_eq(FarmTileMapping.mask_for(c, set), 3, "N+E neighbours -> mask 3 (corner)")
	set[c + Vector2i.DOWN] = true
	set[c + Vector2i.LEFT] = true
	check_eq(FarmTileMapping.mask_for(c, set), 15, "all neighbours -> 15")
	check_eq(FarmTileMapping.mask_for(c, {Vector2i(6, 6): true}), 0, "diagonals don't count")
	check_eq(map.get_atlas_coords(null), map.empty_tile, "no cell -> plain dirt")
	var stable := map.empty_coords(Vector2i(3, 4)) == map.empty_coords(Vector2i(3, 4))
	check(stable, "dirt variant is stable per cell")


func _test_decor_layer() -> void:
	var d := FarmDecor.new()
	d.tile_set = load(TILESET)
	d.tile_mapping = load(MAPPING)
	d.fence_rects = [Rect2i(0, 0, 4, 3)]
	d.fence_gaps = [Vector2i(3, 1)]
	d.path_rects = [Rect2i(6, 0, 3, 1)]
	d.path_cells = [Vector2i(7, 1)]
	root.add_child(d)
	d.rebuild()  # _ready doesn't run during _initialize
	var map := d.tile_mapping
	check_eq(d.fences.size(), 9, "fence border of a 4x3 rect minus one gap")
	check_eq(d.get_cell_atlas_coords(Vector2i(0, 0)), map.fence_coords(FarmTileMapping.E | FarmTileMapping.S),
		"top-left fence corner = E+S (tile 30)")
	check_eq(d.get_cell_atlas_coords(Vector2i(1, 0)), map.fence_coords(10), "top fence = E+W straight")
	check_eq(d.get_cell_atlas_coords(Vector2i(0, 1)), map.fence_coords(5), "left fence = N+S straight")
	check_eq(d.get_cell_atlas_coords(Vector2i(3, 0)), map.fence_coords(FarmTileMapping.W), "gate: fence end cap W")
	check_eq(d.get_cell_atlas_coords(Vector2i(3, 1)), Vector2i(-1, -1), "gate cell is open")
	check_eq(d.get_cell_atlas_coords(Vector2i(7, 0)), map.path_coords(FarmTileMapping.E | FarmTileMapping.S | FarmTileMapping.W),
		"path T-junction (E+S+W)")
	check_eq(d.get_cell_atlas_coords(Vector2i(7, 1)), map.path_coords(FarmTileMapping.N), "path end cap N")
	d.free()
	var farm := (load("res://scenes/farm/farm.tscn") as PackedScene).instantiate()
	root.add_child(farm)
	var decor := farm.get_node_or_null("Decor") as FarmDecor
	if decor:
		decor.rebuild()
	check(decor != null and decor.fences.size() > 10 and decor.paths.size() > 10, "farm has fences and paths")
	var used := 0
	if decor:
		used = decor.get_used_cells().size()
	check(decor != null and used == decor.fences.size() + decor.paths.size(), "every fence/path cell has a tile")
	farm.free()


func _test_new_assets() -> void:
	var bed := (load("res://scenes/world/bed.tscn") as PackedScene).instantiate()
	var spr := bed.get_node_or_null("Sprite2D") as Sprite2D
	check(spr != null and spr.texture != null and spr.texture.get_size() == Vector2(16, 32), "bed uses bed.png (16x32)")
	var shape := (bed.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check_eq(shape.size, Vector2(16, 32), "bed collision 16x32")
	bed.free()
	for t in ["pulaski", "sickle", "pickaxe", "watering_can"]:
		var td := load("res://resources/tools/%s.tres" % t) as ToolData
		check(td.icon != null and td.icon.get_size() == Vector2(16, 16), "%s has its 16x16 icon" % t)
	var wax := load("res://resources/items/wet_waxweed.tres") as ItemData
	check(wax.icon != null and wax.icon.get_size() == Vector2(16, 16), "Wet Waxweed item icon")
	var tree := load("res://resources/trees/placeholder_tree.tres") as TreeData
	check(tree.sprite_sheet != null and tree.sprite_sheet.get_size() == Vector2(160, 48), "tree_stages.png 160x48")
	check_eq(tree.get_frame_region(TreeData.Stage.GROWN), Rect2(96, 0, 32, 48), "grown tree = frame 3")
	check_eq(tree.get_frame_region(TreeData.Stage.STUMP), Rect2(128, 0, 32, 48), "stump = frame 4")
	# Loaded untyped by path: naming SpeciesCatalog in this suite trips the
	# engine's "resources still in use at exit" quirk.
	var cinder = load("res://resources/monsters/species/cinderkin.tres")
	var sf: SpriteFrames = cinder.sprite_frames
	check(sf != null, "Cinderkin has SpriteFrames")
	if sf:
		var ok := true
		for anim in ["idle", "walk"]:
			for dir in ["down", "left", "right", "up"]:
				var n := StringName("%s_%s" % [anim, dir])
				if not sf.has_animation(n) or sf.get_frame_count(n) != 4:
					ok = false
		check(ok, "Cinderkin idle/walk x 4 directions, 4 frames each")
		var f := sf.get_frame_texture(&"walk_left", 0) as AtlasTexture
		check(f != null and f.region == Rect2(128, 32, 32, 32), "walk_left frame 0 = sheet index 12 (32x32)")
		check_eq(sf.get_animation_speed(&"idle_down"), 6.0, "Cinderkin idle 6 fps")
	check(cinder.portrait != null and cinder.portrait.get_size() == Vector2(64, 64), "Cinderkin portrait 64x64")
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	var panel := hud.get_node("Root/InfoPanel") as PanelContainer
	var sb := panel.get_theme_stylebox(&"panel") as StyleBoxTexture
	check(sb != null and sb.texture.resource_path.ends_with("hud_panel.png"), "HUD panel uses hud_panel.png")
	var bar := hud.get_node("%StaminaBar") as ProgressBar
	var bg := bar.get_theme_stylebox(&"background") as StyleBoxTexture
	check(bg != null and bg.texture.resource_path.ends_with("bar_frame.png"), "bars use bar_frame.png")
	var tb := (hud.get_node("%Toolbar") as PanelContainer).get_theme_stylebox(&"panel") as StyleBoxTexture
	check(tb != null and tb.texture.resource_path.ends_with("toolbar_frame.png"), "hotbar uses toolbar_frame.png")
	hud.free()
