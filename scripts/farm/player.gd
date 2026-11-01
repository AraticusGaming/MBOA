class_name Player
extends CharacterBody2D
## Top-down farmer. 4-direction movement, tool selection and interaction with
## the faced cell (or a tapped/clicked nearby cell for mouse/touch).
## Placeholder art: a 16x32 rectangle with origin at the feet (bottom-center).

signal tool_changed(tool: int)

## Walk speed in px/s. PLACEHOLDER.
@export var move_speed: float = 80.0
## Speed multiplier while Clock.is_tired (after midnight). PLACEHOLDER.
@export_range(0.05, 1.0, 0.05) var tired_speed_multiplier: float = 0.75
@export var farm_grid_path: NodePath
## Movement is clamped to this rect (world pixels).
@export var world_bounds: Rect2 = Rect2(8, 32, 624, 320)
## Max cell distance (Chebyshev) for tap/click actions.
@export var tap_reach_cells: int = 1

@export_group("Placeholder colors")
@export var color_body: Color = Color(0.25, 0.45, 0.85)
@export var color_head: Color = Color(0.95, 0.8, 0.65)
@export var color_tired: Color = Color(0.5, 0.5, 0.75)

var facing: Vector2i = Vector2i.DOWN
var current_tool: int = FarmTools.Tool.HOE
var farm_grid: FarmGrid
var clock: GameClock
var _nearby_beds: Array[Node] = []


func _ready() -> void:
	add_to_group(&"player")
	if farm_grid == null and not farm_grid_path.is_empty():
		farm_grid = get_node_or_null(farm_grid_path) as FarmGrid
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if _can_act():
		dir = _read_direction()
	if dir != Vector2.ZERO:
		facing = Vector2i(dir)
	velocity = dir * get_current_speed()
	move_and_slide()
	global_position = global_position.clamp(world_bounds.position, world_bounds.end)
	if farm_grid:
		farm_grid.set_highlight(get_target_cell())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_act():
		return
	if event.is_action_pressed(&"interact"):
		interact()
	elif event.is_action_pressed(&"tool_1"):
		set_tool(FarmTools.Tool.HOE)
	elif event.is_action_pressed(&"tool_2"):
		set_tool(FarmTools.Tool.SEED)
	elif event.is_action_pressed(&"tool_3"):
		set_tool(FarmTools.Tool.WATERING_CAN)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# Touch taps arrive here too (emulate_mouse_from_touch is on by default).
		if tap_at(get_global_mouse_position()):
			get_viewport().set_input_as_handled()


# --- Public API -------------------------------------------------------------

func get_current_speed() -> float:
	var tired := clock != null and clock.is_tired
	return move_speed * (tired_speed_multiplier if tired else 1.0)


func set_tool(tool: int) -> void:
	if tool != current_tool:
		current_tool = tool
		tool_changed.emit(tool)


## Cell under the player's feet.
func get_feet_cell() -> Vector2i:
	if farm_grid == null:
		return Vector2i(-1, -1)
	return farm_grid.world_to_cell(global_position - Vector2(0, 1))


## Cell in front of the player (target of tools).
func get_target_cell() -> Vector2i:
	return get_feet_cell() + facing


## Interact key: sleep if standing at a bed, otherwise use the tool on the
## faced cell (harvests automatically when the crop is mature).
func interact() -> bool:
	if not _nearby_beds.is_empty():
		_nearby_beds[0].call(&"use", self)
		return true
	if farm_grid == null:
		return false
	return farm_grid.interact(get_target_cell(), current_tool)


## Mouse/touch: act on a cell within tap_reach_cells of the player.
func tap_at(global_pos: Vector2) -> bool:
	if farm_grid == null:
		return false
	var cell := farm_grid.world_to_cell(global_pos)
	if not farm_grid.is_in_bounds(cell):
		return false
	var d := cell - get_feet_cell()
	if maxi(absi(d.x), absi(d.y)) > tap_reach_cells:
		return false
	if d != Vector2i.ZERO:
		facing = Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
	return farm_grid.interact(cell, current_tool)


func register_bed(bed: Node, inside: bool) -> void:
	if inside and not _nearby_beds.has(bed):
		_nearby_beds.append(bed)
	elif not inside:
		_nearby_beds.erase(bed)


func is_near_bed() -> bool:
	return not _nearby_beds.is_empty()


# --- Internals --------------------------------------------------------------

func _can_act() -> bool:
	return clock == null or (not clock.is_sleeping and not clock.is_paused())


func _read_direction() -> Vector2:
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if v == Vector2.ZERO:
		return v
	# 4-direction only: keep the dominant axis.
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0)
	return Vector2(0, signf(v.y))


func _draw() -> void:
	var tired := clock != null and clock.is_tired
	draw_rect(Rect2(-6, -22, 12, 22), color_tired if tired else color_body)
	draw_rect(Rect2(-5, -31, 10, 10), color_head)
	# Facing marker.
	var f := Vector2(facing)
	draw_rect(Rect2(Vector2(-1.5, -12) + f * 6.0, Vector2(3, 3)), Color.BLACK)
