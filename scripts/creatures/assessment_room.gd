class_name AssessmentRoom
extends Node2D
## The Assessment Biome room (GDD opening step 3; Slice 2: Woodland only).
## Placeholder art: colored rects. The player walks in, presses interact (or
## clicks/taps within reach) to set one of Angie's 5 baited traps; creatures
## wander and show their rank; a lured creature is caught (trap shakes) or
## knocks the trap over. Captured monsters can be kept (ends the Assessment)
## or released. The chosen monster sets the farm's starting biome
## (PlayerState.complete_assessment). The exit stone returns to the farm
## without finishing.

signal exited(chosen: Monster)

const PAUSE_REASON := &"assessment"

@export var config: AssessmentConfig
## RNG seed (-1 = random). Tests and the preview use fixed seeds.
@export var session_seed: int = -1
@export var spawn_position: Vector2 = Vector2(320, 300)
@export var exit_position: Vector2 = Vector2(48, 320)
@export var color_ground: Color = Color(0.24, 0.38, 0.2)
@export var color_ground_dark: Color = Color(0.18, 0.3, 0.16)
@export var color_trunk: Color = Color(0.36, 0.24, 0.14)
@export var color_canopy: Color = Color(0.14, 0.42, 0.18)
@export var color_trap: Color = Color(0.62, 0.5, 0.3)
@export var color_bait: Color = Color(0.85, 0.3, 0.3)

var session: AssessmentSession
var player: Node2D
var player_state: Node
var clock: GameClock

var _farm: Node2D
var _old_parent: Node
var _old_position: Vector2
var _old_bounds: Rect2
var _old_grid: FarmGrid
var _ui: CanvasLayer
var _status: Label
var _captures_box: VBoxContainer
var _message: Label
var _exit: Area2D
var _time: float = 0.0
var _trees: Array[Vector2] = []


func _ready() -> void:
	add_to_group(&"assessment_room")
	if config == null:
		config = load("res://resources/assessment/woodland.tres") as AssessmentConfig
	if player_state == null:
		player_state = get_node_or_null("/root/PlayerState")
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	session = AssessmentSession.new(config, session_seed)
	session.trap_caught.connect(_on_trap_caught)
	session.trap_failed.connect(_on_trap_failed)
	session.traps_refilled.connect(_on_traps_refilled)
	session.start()
	var deco := RandomNumberGenerator.new()
	deco.seed = 1234
	for i in 9:
		_trees.append(Vector2(deco.randf_range(40, 600), deco.randf_range(70, 330)))
	_build_exit()
	_build_ui()
	_refresh_ui()


## Moves `p` (the Player) in from `farm` and hides the farm.
func enter(p: Node2D, farm: Node2D = null) -> void:
	player = p
	_farm = farm
	if _farm:
		_farm.visible = false
		_farm.process_mode = Node.PROCESS_MODE_DISABLED
	if player:
		_old_parent = player.get_parent()
		_old_position = player.global_position
		if player.has_method(&"set_farm_grid"):
			_old_grid = player.farm_grid
			player.set_farm_grid(null)
			player.clear_interactables()
			_old_bounds = player.world_bounds
			player.world_bounds = config.room_rect.grow(8.0)
			player.interact_fallback = _on_player_interact
		if _old_parent:
			player.reparent(self)
		else:
			add_child(player)
		player.global_position = spawn_position
	if clock and config.pause_clock:
		clock.pause(PAUSE_REASON)


## Returns to the farm. If a monster was chosen it becomes the player's
## first monster.
func leave() -> void:
	var chosen := session.chosen
	if chosen and player_state and player_state.has_method(&"complete_assessment"):
		player_state.complete_assessment(chosen, config.first_monster_joins_party)
	if clock and config.pause_clock:
		clock.resume(PAUSE_REASON)
	if player:
		if player.has_method(&"set_farm_grid"):
			player.interact_fallback = Callable()
			player.clear_interactables()
			player.world_bounds = _old_bounds
		if _old_parent:
			player.reparent(_old_parent)
			player.global_position = _old_position
		if player.has_method(&"set_farm_grid"):
			player.set_farm_grid(_old_grid)
	if _farm:
		_farm.visible = true
		_farm.process_mode = Node.PROCESS_MODE_INHERIT
	exited.emit(chosen)
	queue_free()


## Places a trap at `pos` (room-local). Returns the trap index or -1.
func place_trap(pos: Vector2) -> int:
	var i := session.place_trap(pos)
	if i >= 0:
		_message.text = "Trap set. Wait nearby..."
	elif session.traps_left <= 0:
		_message.text = "No traps left"
	else:
		_message.text = "Can't set a trap there"
	_refresh_ui()
	queue_redraw()
	return i


func keep(capture_index: int) -> Monster:
	var m := session.choose(capture_index)
	if m:
		_message.text = "Angie: %s it is!" % m.get_display_name()
		_refresh_ui()
		leave()
	return m


func release(capture_index: int) -> void:
	session.release(capture_index)
	_message.text = "Released"
	_refresh_ui()


func _process(delta: float) -> void:
	_time += delta
	session.update(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_local_mouse_position()
		if pos.distance_to(to_local(player.global_position)) <= config.place_reach:
			place_trap(pos)
			get_viewport().set_input_as_handled()


func _on_player_interact(p: Node) -> bool:
	var feet: Vector2 = to_local(p.global_position)
	var facing: Vector2 = Vector2(p.facing) if p.get(&"facing") != null else Vector2.DOWN
	place_trap(feet + facing * 14.0)
	return true


func _on_trap_caught(_i: int, m: Monster) -> void:
	_message.text = "Caught a %s-rank %s!" % [m.get_rank(), m.get_display_name()]
	_refresh_ui()


func _on_trap_failed(_i: int) -> void:
	_message.text = "The trap was knocked over. The bait is gone."
	_refresh_ui()


func _on_traps_refilled() -> void:
	_message.text = "Angie: Here, take %d more traps." % config.trap_count
	_refresh_ui()


# --- Drawing (placeholder art) -------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), color_ground_dark)
	draw_rect(config.room_rect, color_ground)
	for t in _trees:
		draw_rect(Rect2(t + Vector2(-3, -4), Vector2(6, 10)), color_trunk)
		draw_circle(t + Vector2(0, -10), 11.0, color_canopy)
	var font := ThemeDB.fallback_font
	for t in session.traps:
		_draw_trap(t)
	for c in session.creatures:
		if not c.active:
			continue
		var m: Monster = c.monster
		var s := m.get_species()
		var col: Color = s.color if s else Color.GRAY
		if m.variant == &"blue_flame":
			col = Color(0.35, 0.55, 1.0)
		var p: Vector2 = c.pos
		draw_rect(Rect2(p + Vector2(-6, -10), Vector2(12, 10)), col)
		draw_rect(Rect2(p + Vector2(-6, -10), Vector2(12, 10)), col.darkened(0.5), false, 1.0)
		var rank := m.get_rank()
		draw_string(font, p + Vector2(-4, -13), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _rank_color(rank))
	draw_rect(Rect2(exit_position + Vector2(-10, -14), Vector2(20, 18)), Color(0.55, 0.55, 0.65))
	draw_string(font, exit_position + Vector2(-12, -17), "Exit", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


func _draw_trap(t: Dictionary) -> void:
	var p: Vector2 = t.pos
	match t.state:
		AssessmentSession.TrapState.SET, AssessmentSession.TrapState.LURING:
			draw_rect(Rect2(p + Vector2(-5, -3), Vector2(10, 6)), color_trap)
			draw_circle(p + Vector2(0, -1), 2.0, color_bait)
			draw_arc(p, config.lure_radius, 0, TAU, 24, Color(1, 1, 1, 0.12), 1.0)
		AssessmentSession.TrapState.SHAKING:
			var shake := sin(_time * 40.0) * 2.0
			draw_rect(Rect2(p + Vector2(-6 + shake, -6), Vector2(12, 9)), color_trap.darkened(0.2))
		AssessmentSession.TrapState.CAUGHT:
			draw_rect(Rect2(p + Vector2(-6, -6), Vector2(12, 9)), color_trap.darkened(0.2))
			draw_rect(Rect2(p + Vector2(-6, -6), Vector2(12, 9)), Color(1, 0.9, 0.3), false, 1.0)
		AssessmentSession.TrapState.FAILED:
			draw_rect(Rect2(p + Vector2(-3, -5), Vector2(6, 10)), color_trap.darkened(0.4))


static func _rank_color(rank: String) -> Color:
	match rank:
		"S": return Color(0.5, 0.75, 1.0)
		"A": return Color(1.0, 0.5, 0.9)
		"B": return Color(1.0, 0.85, 0.3)
		"C": return Color(0.6, 1.0, 0.6)
	return Color(0.9, 0.9, 0.9)


# --- Exit stone and UI ---------------------------------------------------------

func _build_exit() -> void:
	_exit = Area2D.new()
	_exit.name = "Exit"
	_exit.position = exit_position
	_exit.set_script(load("res://scripts/creatures/room_exit.gd"))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 26)
	shape.shape = rect
	_exit.add_child(shape)
	add_child(_exit)
	_exit.used.connect(leave)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "AssessmentUI"
	_ui.layer = 15
	add_child(_ui)
	var top := PanelContainer.new()
	top.position = Vector2(8, 4)
	top.size = Vector2(624, 44)
	_ui.add_child(top)
	var v := VBoxContainer.new()
	top.add_child(v)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 10)
	v.add_child(_status)
	_message = Label.new()
	_message.add_theme_font_size_override(&"font_size", 10)
	_message.text = "Angie: Set a trap near the creature you want. Ranks show above each one."
	v.add_child(_message)
	var side := PanelContainer.new()
	side.name = "Captures"
	side.position = Vector2(470, 60)
	_ui.add_child(side)
	_captures_box = VBoxContainer.new()
	side.add_child(_captures_box)


func _refresh_ui() -> void:
	if _status == null:
		return
	_status.text = "%s Assessment   Traps left: %d   Captured: %d" % [
		SpeciesData.biome_name(config.biome), session.traps_left, session.captures.size()]
	for c in _captures_box.get_children():
		c.queue_free()
		_captures_box.remove_child(c)
	if session.captures.is_empty():
		_captures_box.get_parent().visible = false
		return
	_captures_box.get_parent().visible = true
	var title := Label.new()
	title.text = "Choose your first monster" if session.all_traps_used() else "Keep one now, or set more traps"
	title.add_theme_font_size_override(&"font_size", 9)
	_captures_box.add_child(title)
	for i in session.captures.size():
		var m: Monster = session.captures[i]
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s %s (%s)" % [m.get_rank(), m.get_display_name(), m.get_gender_name()[0]]
		l.add_theme_font_size_override(&"font_size", 9)
		row.add_child(l)
		row.add_child(_button("Keep", keep.bind(i)))
		row.add_child(_button("Release", release.bind(i)))
		_captures_box.add_child(row)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override(&"font_size", 9)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
