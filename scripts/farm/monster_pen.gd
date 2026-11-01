class_name MonsterPen
extends Area2D
## A monster home on the farm (GDD "Farm habitats and pasture"): the pasture,
## the starting biome habitat (DECISIONS.md: pre-built for the first
## monster's biome) or the barn. Residents wander inside `area` (local px)
## using their species SpriteFrames (colored box fallback); the barn is a
## placeholder building and hides its residents. Standing at the gate and
## pressing interact opens the CareUI (group "care_ui"). The fence itself is
## drawn by Farm/Decor (fence_rects in farm.tscn).

enum Kind { PASTURE, STARTING_HABITAT, BARN }

signal opened(home: StringName)

@export var kind: Kind = Kind.PASTURE
## Wander/draw area in local pixels.
@export var area: Rect2 = Rect2(0, 0, 96, 64)
## Interaction spot (local px) and its size.
@export var gate: Vector2 = Vector2(0, 32)
@export var gate_size: Vector2 = Vector2(24, 24)
## Placeholder colors (no pen/barn art yet).
@export var color_wall: Color = Color(0.62, 0.28, 0.22)
@export var color_roof: Color = Color(0.4, 0.22, 0.2)
@export var color_door: Color = Color(0.3, 0.18, 0.12)
@export var color_sign: Color = Color(0.72, 0.52, 0.3)
## Wander speed (px/s, placeholder).
@export var wander_speed: float = 14.0

## PlayerState autoload; injectable for tests.
var player_state: Node
var _walkers: Dictionary = {}  # uid -> Node2D


func _ready() -> void:
	add_to_group(&"monster_pen")
	if player_state == null:
		player_state = get_node_or_null("/root/PlayerState")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = gate_size
	shape.shape = rect
	shape.position = gate
	add_child(shape)
	if kind == Kind.BARN:
		# Placeholder walls block the player; the door (gate) is below them.
		var wall := StaticBody2D.new()
		var ws := CollisionShape2D.new()
		var wr := RectangleShape2D.new()
		wr.size = Vector2(area.size.x, area.size.y - 16)
		ws.shape = wr
		ws.position = area.position + Vector2(area.size.x * 0.5, 16 + wr.size.y * 0.5)
		wall.add_child(ws)
		add_child(wall)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if player_state:
		player_state.care_changed.connect(refresh)
		player_state.monsters_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if player_state and player_state.care_changed.is_connected(refresh):
		player_state.care_changed.disconnect(refresh)
		player_state.monsters_changed.disconnect(refresh)


## PlayerState home id this pen shows (&"" = starting habitat not built yet).
func get_home() -> StringName:
	match kind:
		Kind.PASTURE:
			return &"pasture"
		Kind.BARN:
			return &"barn"
	if player_state == null or player_state.farm_biome < 0:
		return &""
	var h: Dictionary = player_state.get_habitat(player_state.farm_biome)
	return StringName(h.id) if not h.is_empty() and h.built else &""


## Monsters shown wandering here (barn: none, they're inside; party members
## are out with the player).
func get_visible_residents() -> Array:
	var home := get_home()
	if player_state == null or home == &"" or kind == Kind.BARN:
		return []
	return player_state.get_residents(home).filter(func(m): return not player_state.party.has(m))


func get_walker_count() -> int:
	return _walkers.size()


func refresh() -> void:
	var shown := {}
	for m in get_visible_residents():
		shown[m.uid] = true
		if not _walkers.has(m.uid):
			_walkers[m.uid] = _make_walker(m)
	for uid in _walkers.keys():
		if not shown.has(uid):
			(_walkers[uid] as Node).queue_free()
			_walkers.erase(uid)
	queue_redraw()


## Called by Player.interact().
func use(by: Node = null) -> bool:
	var home := get_home()
	if home == &"":
		return false
	opened.emit(home)
	var ui := get_tree().get_first_node_in_group(&"care_ui") if is_inside_tree() else null
	if ui and ui.has_method(&"open"):
		ui.open(home)
		return true
	return ui == null and by != null


func _make_walker(m: RefCounted) -> Node2D:
	var w := Node2D.new()
	w.name = "Monster_%s" % m.uid
	# Spread newcomers out (golden-ratio steps) so they don't start stacked.
	var i := _walkers.size()
	var fx := fposmod(0.17 + i * 0.618034, 1.0)
	var fy := fposmod(0.5 + i * 0.381966, 1.0)
	w.position = Vector2(lerpf(area.position.x + 12, area.end.x - 12, fx),
		lerpf(area.position.y + 20, area.end.y - 4, fy))
	w.set_meta(&"target", w.position)
	w.set_meta(&"wait", 0.4 * i)
	var sp = m.get_species()
	if sp and sp.sprite_frames:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = sp.sprite_frames
		a.offset = Vector2(0, -12)
		a.animation = &"idle_down"
		a.play()
		w.add_child(a)
	else:
		var box := ColorRect.new()
		box.color = sp.color if sp else Color.GRAY
		box.size = Vector2(10, 10)
		box.position = Vector2(-5, -10)
		w.add_child(box)
	add_child(w)
	return w


func _process(delta: float) -> void:
	for w in _walkers.values():
		_step_walker(w, delta)


func _step_walker(w: Node2D, delta: float) -> void:
	var wait: float = w.get_meta(&"wait")
	var a := w.get_child(0) as AnimatedSprite2D
	if wait > 0.0:
		w.set_meta(&"wait", wait - delta)
		return
	var target: Vector2 = w.get_meta(&"target")
	var to := target - w.position
	if to.length() < 1.0:
		w.set_meta(&"target", Vector2(randf_range(area.position.x + 12, area.end.x - 12),
			randf_range(area.position.y + 20, area.end.y - 4)))
		w.set_meta(&"wait", randf_range(1.0, 3.5))
		if a:
			a.animation = StringName(String(a.animation).replace("walk_", "idle_"))
			a.play()
		return
	var step := to.normalized() * minf(wander_speed * delta, to.length())
	w.position += step
	if a:
		var dir := "right" if step.x > 0 else "left"
		if absf(step.y) > absf(step.x):
			dir = "down" if step.y > 0 else "up"
		var anim := StringName("walk_" + dir)
		if a.animation != anim:
			a.play(anim)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var home := get_home()
	if kind == Kind.BARN:
		# Placeholder barn: walls, roof, door at `gate`.
		draw_rect(Rect2(area.position + Vector2(0, 16), area.size - Vector2(0, 16)), color_wall)
		draw_colored_polygon(PackedVector2Array([area.position + Vector2(-4, 18), area.position + Vector2(area.size.x * 0.5, 0),
			area.position + Vector2(area.size.x + 4, 18)]), color_roof)
		draw_rect(Rect2(gate + Vector2(-8, -gate_size.y * 0.5 - 18), Vector2(16, 18)), color_door)
		draw_rect(Rect2(area.position + Vector2(0, 16), area.size - Vector2(0, 16)), color_wall.darkened(0.4), false, 1.0)
	# Sign: name + occupancy.
	if player_state and home != &"":
		var text := "%s %d/%d" % [player_state.get_home_name(home), player_state.get_residents(home).size(),
			player_state.get_capacity(home)]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6
		var pos := Vector2(area.get_center().x - w * 0.5, area.position.y - 11) if kind != Kind.BARN \
			else Vector2(area.get_center().x - w * 0.5, area.position.y + 22)
		draw_rect(Rect2(pos, Vector2(w, 10)), color_sign)
		draw_rect(Rect2(pos, Vector2(w, 10)), color_sign.darkened(0.5), false, 1.0)
		draw_string(font, pos + Vector2(3, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.25, 0.15, 0.1))


func _on_body_entered(body: Node) -> void:
	if body.has_method(&"register_interactable"):
		body.register_interactable(self, true)


func _on_body_exited(body: Node) -> void:
	if body.has_method(&"register_interactable"):
		body.register_interactable(self, false)
