extends MboaTestBase
## Slice 3 farm side: the habitat, pasture and barn pens in farm.tscn (homes,
## fences, wandering residents with species sprites), the barn walls, and
## the care window (feed, move, water, party) opened from a pen.

const PlayerStateScript := preload("res://scripts/core/player_state.gd")

var _cleanup: Array = []
var _rng := RandomNumberGenerator.new()


func _run_tests() -> void:
	_rng.seed = 5
	await _test_farm_pens()
	await _test_care_ui()
	for n in _cleanup:
		if is_instance_valid(n):
			n.free()


func _mon(species: StringName, biome: int, bond: float = 0.0) -> RefCounted:
	var m := MonsterFactory.create(SpeciesCatalog.get_default().get_species(species), "D", _rng)
	m.origin_biome = biome
	m.bond = bond
	return m


func _state() -> Node:
	var ps: Node = PlayerStateScript.new()
	root.add_child(ps)
	_cleanup.append(ps)
	ps.care_config = ps.care_config.duplicate()
	ps.care_config.angie_gift_enabled = false
	return ps


func _farm(ps: Node) -> Node2D:
	var farm := (load("res://scenes/farm/farm.tscn") as PackedScene).instantiate() as Node2D
	for pen_name in ["Habitat", "Pasture", "Barn"]:
		farm.get_node(pen_name).player_state = ps
	root.add_child(farm)
	_cleanup.append(farm)
	await process_frame
	return farm


func _test_farm_pens() -> void:
	var ps := _state()
	var farm := await _farm(ps)
	var hab := farm.get_node("Habitat") as MonsterPen
	var pasture := farm.get_node("Pasture") as MonsterPen
	var barn := farm.get_node("Barn") as MonsterPen
	check(hab.get_home() == &"" and not hab.use(null), "habitat pen inactive before the first monster")
	check_eq(pasture.get_home(), &"pasture", "pasture pen")
	check_eq(barn.get_home(), &"barn", "barn pen")
	ps.complete_assessment(_mon(&"cinderkin", SpeciesData.Biome.WOODLAND))
	check_eq(hab.get_home(), &"woodland_habitat", "M2 starting habitat is the habitat pen")
	ps.add_wild_monster(_mon(&"cinderkin", SpeciesData.Biome.WOODLAND))
	ps.add_wild_monster(_mon(&"rockback", SpeciesData.Biome.MARSH))
	check_eq(hab.get_walker_count(), 2, "two Cinderkin wander in the habitat")
	check_eq(pasture.get_walker_count(), 1, "Rockback wanders in the pasture")
	var w := hab.get_child(hab.get_child_count() - 1) as Node2D
	check(w.get_child(0) is AnimatedSprite2D, "Cinderkin uses its SpriteFrames")
	var start := w.position
	for i in 90:
		await process_frame
	var moved := false
	for x in hab._walkers.values():
		moved = moved or (x as Node2D).position != start
	check(moved, "residents wander")
	var inside := true
	for x in hab._walkers.values():
		inside = inside and hab.area.grow(1).has_point((x as Node2D).position)
	check(inside, "and stay inside the pen")
	var m: RefCounted = ps.get_residents(&"woodland_habitat")[0]
	m.bond = 30.0
	ps.move_to_barn(m)
	check(hab.get_walker_count() == 1 and barn.get_walker_count() == 0, "barn residents are inside the barn")
	check(barn.get_children().any(func(c): return c is StaticBody2D), "barn walls block the player")
	# Fences around each pen with a gate (Farm/Decor).
	var decor := farm.get_node("Decor") as FarmDecor
	decor.rebuild()
	var tile := func(n: MonsterPen, local: Vector2) -> Vector2i:
		return Vector2i((n.position + local) / 16.0)
	check(decor.fences.has(tile.call(hab, Vector2(0, 0))) and decor.fences.has(tile.call(pasture, Vector2(0, 0))),
		"habitat and pasture are fenced")
	check(not decor.fences.has(tile.call(hab, hab.gate + Vector2(0, 4))), "habitat gate is open")
	check(not decor.fences.has(tile.call(pasture, pasture.gate)), "pasture gate is open")
	check(decor.paths.has(tile.call(barn, barn.gate)), "a path leads to the barn door")


func _test_care_ui() -> void:
	var ps := _state()
	var farm := await _farm(ps)
	var ui := (load("res://scenes/ui/care_ui.tscn") as PackedScene).instantiate() as CareUI
	ui.player_state = ps
	root.add_child(ui)
	_cleanup.append(ui)
	var clock := make_clock()
	_cleanup.append(clock)
	ui.clock = clock
	ps.complete_assessment(_mon(&"cinderkin", SpeciesData.Biome.WOODLAND, 20.0))
	var hab := farm.get_node("Habitat") as MonsterPen
	check(hab.use(null) and ui.is_open() and ui.home == &"woodland_habitat", "pen gate opens the care window")
	check(clock.is_paused(), "time pauses while caring")
	var m: RefCounted = ui.get_monsters()[0]
	check(ui.food_id == &"", "no food carried")
	ps.inventory.clear()
	ps.add_item(&"wet_waxweed", 3)
	ps.add_item(&"turnip", 1)
	ps.add_item(&"stone", 1)
	check_eq(ui.get_food_ids(), [&"wet_waxweed", &"turnip"], "food picker lists only food")
	check(ui.food_id == &"wet_waxweed", "first food selected")
	check(ui.feed(m) and m.bond > 20.0, "Feed raises bond")
	check_eq(ps.inventory.count(&"wet_waxweed"), 2, "Feed uses the food")
	m.bond = 24.0
	check(not ui.move(m, &"barn") and ui._message.text.contains("25%"), "Barn refused below 25%")
	m.bond = 25.0
	check(ui.move(m, &"barn") and m.home == &"barn", "Barn at 25%")
	ui.open(&"barn")
	check_eq(ui.get_monsters().size(), 1, "barn lists it")
	check(ui.water() == 1 and m.watered_today, "Water troughs")
	var other := _mon(&"cinderkin", SpeciesData.Biome.WOODLAND, 50.0)
	var third := _mon(&"crow", SpeciesData.Biome.WOODLAND, 50.0)
	for x in [other, third]:
		ps.monsters.append(x)
		x.home = &"barn"
	ui.refresh()
	check(ui.toggle_party(m) and ui.toggle_party(other), "two join the party from the care window")
	check(not ui.toggle_party(third) and ui._message.text.contains("full"), "third: party full")
	check(ui.toggle_party(m) and not ps.party.has(m), "Leave")
	check(ui.move(other, &"pasture") and not ps.party.has(other), "moving out of the barn leaves the party")
	ui.select(third)
	check(ui._detail.text.contains("Crow") and ui._detail.text.contains("Bond 50%"), "detail panel")
	third.bond = 100.0
	ui.refresh()
	check(ui._detail.text.contains("star"), "100%: star shown")
	ui.close()
	check(not ui.is_open() and not clock.is_paused(), "close resumes time")
