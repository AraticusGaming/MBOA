extends SceneTree
## Renders the main scene with a showcase farm state and saves a PNG.
## Needs a real display (not --headless), e.g. under Xvfb:
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##     --script res://tools/godot/render_preview.gd -- /tmp/preview.png [hour]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://preview.png"
	var hour := float(args[1]) if args.size() > 1 else 10.0
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var clock := root.get_node("Clock") as GameClock
	clock.pause(&"preview")
	clock.from_dict({"day": 1, "time_minutes": hour * 60.0})
	var grid := main.get_node("Farm/FarmGrid") as FarmGrid
	var crop := grid.crops[0]
	# Row 0: tilled / watered; row 1: one plot per growth stage up to harvest-ready.
	for x in 4:
		grid.till(Vector2i(x, 0))
	grid.water(Vector2i(2, 0))
	grid.water(Vector2i(3, 0))
	for x in crop.get_days_to_mature() + 1:
		var c := Vector2i(x, 1)
		grid.till(c)
		grid.plant(c, crop.id)
		grid.get_plot(c).growth_days = x
	grid.water(Vector2i(1, 1))
	grid.queue_redraw()
	var player := main.get_node("Farm/Player") as Player
	player.global_position = grid.cell_to_world_center(Vector2i(5, 0)) + Vector2(0, 8)
	player.facing = Vector2i.LEFT
	for i in 30:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
