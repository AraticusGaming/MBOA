class_name Player
extends CharacterBody2D
## Top-down farmer. 4-direction movement, tool selection and interaction with
## the faced cell (or a tapped/clicked nearby cell for mouse/touch).
## Origin is at the feet (bottom-center). Art: child AnimatedSprite2D "Sprite"
## using resources/player_frames.tres (animations idle_/walk_ + down/left/
## right/up), offset (0, -16) per assets/ART_NOTES.md so the 16x32 frame's
## bottom row sits on the origin. Without a Sprite it draws a placeholder rect.

signal tool_changed(slot: int)

## Hotbar used when `tools` is left empty (GDD basic tools + seed bag).
const DEFAULT_TOOL_PATHS := [
	"res://resources/tools/pulaski.tres",
	"res://resources/tools/sickle.tres",
	"res://resources/tools/pickaxe.tres",
	"res://resources/tools/watering_can.tres",
	"res://resources/tools/seeds.tres",
]

## Walk speed in px/s. PLACEHOLDER.
@export var move_speed: float = 80.0
## Speed multiplier while Clock.is_tired (after midnight). PLACEHOLDER.
@export_range(0.05, 1.0, 0.05) var tired_speed_multiplier: float = 0.75
@export var farm_grid_path: NodePath
## Hotbar: slot i is selected with input action tool_<i+1> (keys 1-5).
@export var tools: Array[ToolData] = []
## Movement is clamped to this rect (world pixels).
@export var world_bounds: Rect2 = Rect2(8, 32, 624, 320)
## Max cell distance (Chebyshev) for tap/click actions.
@export var tap_reach_cells: int = 1

## Sprite tint while tired (PLACEHOLDER feedback until there is tired art).
@export var tired_sprite_tint: Color = Color(0.82, 0.82, 1.0)

@export_group("Placeholder colors")
@export var color_body: Color = Color(0.25, 0.45, 0.85)
@export var color_head: Color = Color(0.95, 0.8, 0.65)
@export var color_tired: Color = Color(0.5, 0.5, 0.75)

var facing: Vector2i = Vector2i.DOWN
## Selected hotbar slot (index into `tools`).
var current_slot: int = 0
## Selected tool resource (null if the hotbar is empty).
var current_tool: ToolData:
	get:
		return tools[current_slot] if current_slot >= 0 and current_slot < tools.size() else null
var farm_grid: FarmGrid
var clock: GameClock
var sprite: AnimatedSprite2D
var is_moving: bool = false
var _nearby_beds: Array[Node] = []

const DIRECTION_NAMES := {
	Vector2i.DOWN: "down",
	Vector2i.LEFT: "left",
	Vector2i.RIGHT: "right",
	Vector2i.UP: "up",
}


func _ready() -> void:
	add_to_group(&"player")
	if tools.is_empty():
		for path in DEFAULT_TOOL_PATHS:
			var t := load(path) as ToolData
			if t:
				tools.append(t)
	sprite = get_node_or_null(^"Sprite") as AnimatedSprite2D
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
	is_moving = dir != Vector2.ZERO
	move_and_slide()
	global_position = global_position.clamp(world_bounds.position, world_bounds.end)
	if farm_grid:
		farm_grid.set_highlight(get_target_cell())
	update_animation()
	if sprite == null:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_act():
		return
	if event.is_action_pressed(&"interact"):
		interact()
		return
	for i in tools.size():
		var action := StringName("tool_%d" % (i + 1))
		if InputMap.has_action(action) and event.is_action_pressed(action):
			set_tool(i)
			return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# Touch taps arrive here too (emulate_mouse_from_touch is on by default).
		if tap_at(get_global_mouse_position()):
			get_viewport().set_input_as_handled()


# --- Public API -------------------------------------------------------------

## Animation name for the current facing/movement, e.g. "walk_left".
func get_animation_name() -> StringName:
	return StringName("%s_%s" % ["walk" if is_moving else "idle",
		DIRECTION_NAMES.get(facing, "down")])


func update_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim := get_animation_name()
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	elif not sprite.is_playing():
		sprite.play()
	var tired := clock != null and clock.is_tired
	sprite.self_modulate = tired_sprite_tint if tired else Color.WHITE


func get_current_speed() -> float:
	var tired := clock != null and clock.is_tired
	return move_speed * (tired_speed_multiplier if tired else 1.0)


## Selects hotbar slot `slot`.
func set_tool(slot: int) -> void:
	if slot >= 0 and slot < tools.size() and slot != current_slot:
		current_slot = slot
		tool_changed.emit(slot)


## Selects the hotbar slot holding the tool with `id`. Returns false if absent.
func select_tool_by_id(id: StringName) -> bool:
	for i in tools.size():
		if tools[i] and tools[i].id == id:
			set_tool(i)
			return true
	return false


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
	return act_on_cell(get_target_cell())


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
	return act_on_cell(cell)


## Harvests a mature crop on `cell` (free), otherwise uses the current tool.
func act_on_cell(cell: Vector2i) -> bool:
	if farm_grid == null or not farm_grid.is_in_bounds(cell):
		return false
	if farm_grid.is_mature(cell):
		return farm_grid.harvest(cell) != &""
	return farm_grid.use_tool(cell, current_tool)


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
	if sprite != null:
		return
	var tired := clock != null and clock.is_tired
	draw_rect(Rect2(-6, -22, 12, 22), color_tired if tired else color_body)
	draw_rect(Rect2(-5, -31, 10, 10), color_head)
	# Facing marker.
	var f := Vector2(facing)
	draw_rect(Rect2(Vector2(-1.5, -12) + f * 6.0, Vector2(3, 3)), Color.BLACK)
