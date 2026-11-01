extends SceneTree
## M2 preview: the Woodland Assessment room (left) and the seed shop on the
## farm (right), side by side in one PNG. Needs a display (Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##     --script res://tools/godot/render_m2_preview.gd -- /tmp/m2.png

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://m2_preview.png"
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var clock := root.get_node("Clock") as GameClock
	clock.pause(&"preview")
	clock.from_dict({"day": 3, "time_minutes": 11 * 60.0})
	var ps := root.get_node("PlayerState")
	ps.coins = 640
	ps.add_item(&"carrot", 6)
	ps.add_item(&"wet_waxweed", 2)
	var player := main.get_node("Farm/Player") as Player
	var door := main.get_node("Farm/AssessmentDoor") as AssessmentDoor
	# --- Assessment room: two traps set, one capture, creatures wandering.
	door.use(player)
	var room: AssessmentRoom
	for n in main.get_children():
		if n is AssessmentRoom:
			room = n
	room.config = room.config.duplicate()
	room.config.catch_chance = 1.0
	room.session.config = room.config
	var s := room.session
	var t := s.place_trap(s.creatures[0].pos)
	for i in 120:
		s.update(0.1)
		if s.traps[t].state == AssessmentSession.TrapState.CAUGHT:
			break
	room._on_trap_caught(t, s.captures[0]) if not s.captures.is_empty() else null
	room.place_trap(s.creatures[2].pos + Vector2(30, 0))
	room.place_trap(Vector2(200, 250))
	player.global_position = Vector2(230, 260)
	player.facing = Vector2i.RIGHT
	for i in 20:
		await process_frame
	var room_img := root.get_texture().get_image()
	# --- Back on the farm with the shop open.
	room.leave()
	await process_frame
	player.global_position = Vector2(540, 120)
	player.facing = Vector2i.UP
	var ui := main.get_node("ShopUI") as ShopUI
	ui.open()
	for i in 20:
		await process_frame
	var shop_img := root.get_texture().get_image()
	var w := room_img.get_width() + shop_img.get_width()
	var h := maxi(room_img.get_height(), shop_img.get_height())
	var img := Image.create(w, h, false, room_img.get_format())
	img.blit_rect(room_img, Rect2i(Vector2i.ZERO, room_img.get_size()), Vector2i.ZERO)
	img.blit_rect(shop_img, Rect2i(Vector2i.ZERO, shop_img.get_size()), Vector2i(room_img.get_width(), 0))
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	ui.close()
	main.free()
	quit()
