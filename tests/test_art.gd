extends MboaTestBase
## Art integration: TileSet / SpriteFrames / crop sheet load and match
## assets/ART_NOTES.md; farm soil tiles follow plot state; crop frame mapping;
## player animations follow facing and movement.

const TILESET := "res://resources/farm_tileset.tres"
const MAPPING := "res://resources/farm_tile_mapping.tres"
const FRAMES := "res://resources/player_frames.tres"
const CROP := "res://resources/crops/placeholder_crop.tres"
## Slice 3 Woodland Assessment art (ART_NOTES "Woodland"): path -> expected size.
const WOODLAND_ART := {
	"res://assets/tilesets/woodland_tiles.png": Vector2i(128, 144),
	"res://assets/backgrounds/woodland_room.png": Vector2i(640, 360),
	"res://assets/sprites/trap_basic.png": Vector2i(64, 16),
	"res://assets/sprites/item_bait.png": Vector2i(16, 16),
}
## Slice 3 Woodland creatures: 256x128 sheets (Cinderkin layout) + 64x64 portraits.
const WOODLAND_CREATURES := ["moss_bun", "blue_jay", "bramble_cub"]
const BUILDING_ART := {
	"res://assets/tilesets/pasture_tiles.png": Vector2i(128, 48),
	"res://assets/sprites/habitat_woodland.png": Vector2i(64, 64),
	"res://assets/sprites/habitat_woodland_ground.png": Vector2i(64, 64),
	"res://assets/sprites/habitat_woodland_objects.png": Vector2i(64, 64),
	"res://assets/sprites/barn_stages.png": Vector2i(400, 80),
}
## Woodland trees (ART_NOTES "Woodland trees"): 240x320, 48x80 cells,
## columns = TreeData.Stage (seed..stump), rows = GameClock.Season.
const TREE_SPECIES := ["oak", "pine", "birch", "maple"]
const TREE_CELL := Vector2i(48, 80)


func _run_tests() -> void:
	_test_tileset()
	_test_player_frames()
	_test_crop_frames()
	_test_farm_tiles()
	_test_woodland_art()
	_test_woodland_creatures()
	_test_buildings()
	_test_trees()
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
	check_eq(src.get_tiles_count(), 13, "13 tiles defined (ART_NOTES 0-12)")
	var map := load(MAPPING) as FarmTileMapping
	check(map != null, "tile mapping loads")
	for coords in [map.empty_tile, map.tilled_tile, map.watered_tile]:
		check(src.has_tile(coords), "mapped tile %s exists" % str(coords))


func _test_woodland_art() -> void:
	for path in WOODLAND_ART:
		var tex := load(path) as Texture2D
		check(tex != null, "%s loads" % path)
		if tex == null:
			continue
		check_eq(Vector2i(tex.get_size()), WOODLAND_ART[path], "%s size" % path.get_file())
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var alpha_ok := true
		for y in img.get_height():
			for x in img.get_width():
				var a := img.get_pixel(x, y).a8
				if a != 0 and a != 255:
					alpha_ok = false
		check(alpha_ok, "%s alpha is only 0 or 255" % path.get_file())
	# The room background equals the Assessment room's draw area and is fully opaque.
	var room := (load("res://assets/backgrounds/woodland_room.png") as Texture2D).get_image()
	check(not room.detect_alpha(), "woodland_room.png is opaque")
	var cfg := load("res://resources/assessment/woodland.tres") as AssessmentConfig
	check(cfg != null and Rect2(0, 0, 640, 360).encloses(cfg.room_rect),
		"room_rect fits inside the 640x360 background")


func _alpha_binary(img: Image) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a8
			if a != 0 and a != 255:
				return false
	return true


func _img(path: String) -> Image:
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img


func _test_buildings() -> void:
	for path in BUILDING_ART:
		var img := _img(path)
		check(img != null, "%s loads" % path)
		if img == null:
			continue
		check_eq(Vector2i(img.get_size()), BUILDING_ART[path], "%s size" % path.get_file())
		check(_alpha_binary(img), "%s alpha is only 0 or 255" % path.get_file())
	var past := _img("res://assets/tilesets/pasture_tiles.png")
	if past != null:
		var empty := 0
		for i in 23:  # 0-15 fence mask tiles, 16-19 gates, 20-22 props
			if past.get_region(Rect2i((i % 8) * 16, (i / 8) * 16, 16, 16)).get_used_rect().size == Vector2i.ZERO:
				empty += 1
		check_eq(empty, 0, "pasture tiles 0-22 all drawn")
		# Rails reach the tile edge exactly where the mask says (E bit -> x=15 opaque on rail row 3).
		var edges_ok := true
		for m in 16:
			var t := past.get_region(Rect2i((m % 8) * 16, (m / 8) * 16, 16, 16))
			edges_ok = edges_ok and (t.get_pixel(15, 3).a8 > 0) == bool(m & 2)
			edges_ok = edges_ok and (t.get_pixel(0, 3).a8 > 0) == bool(m & 8)
			edges_ok = edges_ok and (t.get_pixel(7, 15).a8 > 0) == bool(m & 4)
		check(edges_ok, "pasture fence autotile edges follow the N=1,E=2,S=4,W=8 mask")
	var ground := _img("res://assets/sprites/habitat_woodland_ground.png")
	if ground != null:
		check(ground.detect_alpha() == Image.ALPHA_NONE, "habitat ground layer is fully opaque")
	var hab := _img("res://assets/sprites/habitat_woodland.png")
	if hab != null:
		# gate opening: bottom-centre x 24-39 on the last row is ground, not fence
		check(hab.get_pixel(31, 63) == ground.get_pixel(31, 63), "habitat gate opening is clear")
	var barn := _img("res://assets/sprites/barn_stages.png")
	if barn != null:
		var grounded := true
		for i in 5:  # frame = barn_upgrades (0-4); bottom-centre anchor (40, 80)
			var r := barn.get_region(Rect2i(i * 80, 0, 80, 80)).get_used_rect()
			grounded = grounded and r.size != Vector2i.ZERO and r.end.y == 80
			grounded = grounded and barn.get_pixel(i * 80 + 40, 79).a8 == 255  # door sill
		check(grounded, "barn: 5 stages drawn, standing on the bottom row with the door at x=40")


func _palette_colors() -> Dictionary:
	# Swatch is 8 columns of 16x16 cells; sample each cell's centre.
	var sw := Image.load_from_file(ProjectSettings.globalize_path("res://tools/art/palette.png"))
	var cols := {}
	if sw == null:
		return cols
	for y in range(8, sw.get_height(), 16):
		for x in range(8, sw.get_width(), 16):
			var p := sw.get_pixel(x, y)
			if p.a8 == 255:
				cols[p.to_html(false)] = true
	return cols


func _test_trees() -> void:
	check_eq(TreeData.Stage.size(), 5, "5 tree sheet columns = TreeData.Stage (seed..stump)")
	check_eq(GameClock.Season.size(), 4, "4 tree sheet rows = GameClock.Season")
	var pal := _palette_colors()
	check(pal.size() >= 48, "palette swatch has the 48 colors")
	for sp in TREE_SPECIES:
		var path := "res://assets/sprites/tree_%s.png" % sp
		var img := _img(path)
		check(img != null, "%s loads" % path)
		if img == null:
			continue
		check_eq(Vector2i(img.get_size()), Vector2i(240, 320), "tree_%s.png size (5x4 cells of 48x80)" % sp)
		var alpha_ok := true
		var pal_ok := true
		for y in img.get_height():
			for x in img.get_width():
				var p := img.get_pixel(x, y)
				if p.a8 != 0 and p.a8 != 255:
					alpha_ok = false
				elif p.a8 == 255 and not pal.has(p.to_html(false)):
					pal_ok = false
		check(alpha_ok, "tree_%s alpha is only 0 or 255" % sp)
		check(pal_ok, "tree_%s uses palette colors only" % sp)
		# Every cell is drawn, stands on its bottom row (anchor bottom-centre (24, 80)),
		# and its base row sits inside the trunk tile column x 16-31.
		var grounded := true
		var base_ok := true
		for row in 4:
			for col in 5:
				var cell := Rect2i(col * TREE_CELL.x, row * TREE_CELL.y, TREE_CELL.x, TREE_CELL.y)
				var used := img.get_region(cell).get_used_rect()
				grounded = grounded and used.size != Vector2i.ZERO and used.end.y == TREE_CELL.y
				for x in TREE_CELL.x:
					var on := img.get_pixel(cell.position.x + x, cell.end.y - 1).a8 > 0
					if on and (x < 16 or x > 31):
						base_ok = false
		check(grounded, "tree_%s: all 20 cells drawn and touch y = 79" % sp)
		check(base_ok, "tree_%s: base row stays inside the trunk tile (x 16-31)" % sp)
		# Grown trees are full size: canopy reaches near the cell top in every season.
		var tall := true
		for row in 4:
			var used := img.get_region(Rect2i(3 * TREE_CELL.x, row * TREE_CELL.y, TREE_CELL.x, TREE_CELL.y)).get_used_rect()
			tall = tall and used.position.y <= 12 and used.size.x >= 32
		check(tall, "tree_%s: grown frames fill the 48x80 cell" % sp)


func _test_woodland_creatures() -> void:
	for n in WOODLAND_CREATURES:
		var sheet := load("res://assets/sprites/%s.png" % n) as Texture2D
		var portrait := load("res://assets/portraits/%s_portrait.png" % n) as Texture2D
		check(sheet != null and portrait != null, "%s sheet + portrait load" % n)
		if sheet == null or portrait == null:
			continue
		check_eq(Vector2i(sheet.get_size()), Vector2i(256, 128), "%s.png size (8x4 frames of 32x32)" % n)
		check_eq(Vector2i(portrait.get_size()), Vector2i(64, 64), "%s_portrait.png size" % n)
		var img := sheet.get_image()
		if img.is_compressed():
			img.decompress()
		var pimg := portrait.get_image()
		if pimg.is_compressed():
			pimg.decompress()
		check(_alpha_binary(img) and _alpha_binary(pimg), "%s alpha is only 0 or 255" % n)
		check(pimg.detect_alpha() != Image.ALPHA_NONE, "%s portrait background is transparent" % n)
		var empty := 0
		for i in 32:
			var r := img.get_region(Rect2i((i % 8) * 32, (i / 8) * 32, 32, 32))
			if r.get_used_rect().size == Vector2i.ZERO:
				empty += 1
		check_eq(empty, 0, "%s: all 32 frames drawn" % n)
		# Row 2 (right) is the mirror of row 1 (left).
		var left := img.get_region(Rect2i(0, 32, 256, 32))
		var right := img.get_region(Rect2i(0, 64, 256, 32))
		left.flip_x()  # frame i of the flipped row is frame 7 - i, so compare frame-wise
		var mirrored := true
		for y in 32:
			for x in 256:
				var src := left.get_pixel((7 - x / 32) * 32 + x % 32, y)
				var dst := right.get_pixel(x, y)
				# fix_alpha_border changes RGB under transparent pixels; compare visible ones
				if src.a8 != dst.a8 or (src.a8 > 0 and src != dst):
					mirrored = false
		check(mirrored, "%s: right row mirrors left" % n)
		# Idle frames stand on the bottom row (pivot bottom-center (16, 32)).
		var grounded := true
		for row in 4:
			var f := img.get_region(Rect2i(0, row * 32, 32, 32)).get_used_rect()
			if f.end.y != 32:
				grounded = false
		check(grounded, "%s: idle frames touch y = 31" % n)


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
	check_eq(at.call(), map.empty_tile, "empty plot -> dirt tile")
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
