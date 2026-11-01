extends SceneTree
## Regenerates Godot resources from ART's sheets (see assets/ART_NOTES.md):
##   resources/farm_tileset.tres   <- assets/tilesets/farm_tiles.png (16x16 atlas)
##   resources/player_frames.tres  <- assets/sprites/player_base.png (16x32 frames)
## Run after ART changes a sheet layout:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/godot/build_art_resources.gd

const FARM_TILES := "res://assets/tilesets/farm_tiles.png"
const PLAYER_SHEET := "res://assets/sprites/player_base.png"
const TILESET_OUT := "res://resources/farm_tileset.tres"
const FRAMES_OUT := "res://resources/player_frames.tres"

const TILE := Vector2i(16, 16)
## ART_NOTES: tiles 0-12 used (13-15 reserved/empty), 8 columns.
const TILE_COUNT := 13
const TILE_COLUMNS := 8

const PLAYER_FRAME := Vector2i(16, 32)
## ART_NOTES rows: 0 = down, 1 = left, 2 = right, 3 = up.
const DIRECTIONS := ["down", "left", "right", "up"]
## Columns 0-3 idle, 4-7 walk. Suggested speeds: idle 4-5 fps, walk 8 fps.
const ANIMS := {"idle": [0, 4.0], "walk": [4, 8.0]}
const FRAMES_PER_ANIM := 4


func _initialize() -> void:
	var ok := _build_tileset() and _build_player_frames()
	quit(0 if ok else 1)


func _build_tileset() -> bool:
	var tex := load(FARM_TILES) as Texture2D
	if tex == null:
		printerr("missing ", FARM_TILES)
		return false
	var ts := TileSet.new()
	ts.tile_size = TILE
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = TILE
	for i in TILE_COUNT:
		src.create_tile(Vector2i(i % TILE_COLUMNS, i / TILE_COLUMNS))
	ts.add_source(src, 0)
	var err := ResourceSaver.save(ts, TILESET_OUT)
	print("saved ", TILESET_OUT, " err=", err)
	return err == OK


func _build_player_frames() -> bool:
	var tex := load(PLAYER_SHEET) as Texture2D
	if tex == null:
		printerr("missing ", PLAYER_SHEET)
		return false
	var sf := SpriteFrames.new()
	if sf.has_animation(&"default"):
		sf.remove_animation(&"default")
	for anim in ANIMS:
		var first_col: int = ANIMS[anim][0]
		var fps: float = ANIMS[anim][1]
		for row in DIRECTIONS.size():
			var name := StringName("%s_%s" % [anim, DIRECTIONS[row]])
			sf.add_animation(name)
			sf.set_animation_loop(name, true)
			sf.set_animation_speed(name, fps)
			for c in FRAMES_PER_ANIM:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(Vector2((first_col + c) * PLAYER_FRAME.x, row * PLAYER_FRAME.y),
					Vector2(PLAYER_FRAME))
				sf.add_frame(name, at)
	var err := ResourceSaver.save(sf, FRAMES_OUT)
	print("saved ", FRAMES_OUT, " err=", err)
	return err == OK
