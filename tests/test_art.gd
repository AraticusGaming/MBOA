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


func _run_tests() -> void:
	_test_tileset()
	_test_player_frames()
	_test_crop_frames()
	_test_farm_tiles()
	_test_woodland_art()
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
