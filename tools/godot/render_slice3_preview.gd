extends SceneTree
## Slice 3 preview: the farm with the starting habitat, pasture and barn
## (monsters wandering, ART tiles/HUD) on the left, and the care window
## open on the barn on the right. Needs a display (Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##     --script res://tools/godot/render_slice3_preview.gd -- /tmp/s3.png

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://slice3_preview.png"
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var clock := root.get_node("Clock") as GameClock
	clock.pause(&"preview")
	clock.from_dict({"day": 4, "time_minutes": 10 * 60.0})
	var ps := root.get_node("PlayerState")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cat = load("res://resources/monsters/species_catalog.tres")
	var mk := func(id: StringName, rank: String, biome: int, bond: float):
		var m = MonsterFactory.create(cat.get_species(id), rank, rng)
		m.origin_biome = biome
		m.bond = bond
		return m
	# First monster via the Assessment path (habitat + Angie's gift).
	ps.complete_assessment(mk.call(&"cinderkin", "C", 1, 18.0))
	for b in [8.0, 31.0]:
		ps.add_wild_monster(mk.call(&"cinderkin", "D", 1, b))
	for spec in [[&"rockback", 2, 12.0], [&"robin", 0, 6.0], [&"blue_jay", 0, 22.0]]:
		ps.add_wild_monster(mk.call(spec[0], "D", spec[1], spec[2]))
	var barn := [mk.call(&"cinderkin", "B", 1, 100.0), mk.call(&"cinderkin", "C", 1, 64.0),
		mk.call(&"crow", "D", 0, 41.0), mk.call(&"rockback", "C", 2, 27.0)]
	for m in barn:
		ps.monsters.append(m)
		m.home = &"barn"
	ps.add_to_party(barn[0])
	ps.add_to_party(barn[1])
	ps.add_item(&"wet_waxweed", 6)
	ps.feed_monster(barn[2], &"wet_waxweed")
	ps.water_barn()
	ps.care_changed.emit()
	var player := main.get_node("Farm/Player") as Player
	player.global_position = Vector2(312, 120)
	player.facing = Vector2i.UP
	for i in 40:
		await process_frame
	var farm_img := root.get_texture().get_image()
	var ui := main.get_node("CareUI") as CareUI
	ui.open(&"barn")
	ui.food_id = &"wet_waxweed"
	ui.feed(barn[3])
	for i in 10:
		await process_frame
	var care_img := root.get_texture().get_image()
	var w := farm_img.get_width() + care_img.get_width()
	var h := maxi(farm_img.get_height(), care_img.get_height())
	var img := Image.create(w, h, false, farm_img.get_format())
	img.blit_rect(farm_img, Rect2i(Vector2i.ZERO, farm_img.get_size()), Vector2i.ZERO)
	img.blit_rect(care_img, Rect2i(Vector2i.ZERO, care_img.get_size()), Vector2i(farm_img.get_width(), 0))
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	ui.close()
	main.free()
	quit()
