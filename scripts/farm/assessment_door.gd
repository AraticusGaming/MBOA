class_name AssessmentDoor
extends Area2D
## Placeholder portal from the farm into the Assessment room. Not GDD: in the
## GDD the Assessment happens at the Association before the farm exists; the
## opening and character creation are skipped in Slice 2, so this door on the
## farm starts it. Usable until the first monster is chosen (unless
## `repeatable`).

signal entered_room(room: Node)

@export var room_scene: PackedScene
## Allow more Assessments after the first monster (debug). PLACEHOLDER.
@export var repeatable: bool = false
@export var color_frame: Color = Color(0.45, 0.4, 0.55)
@export var color_glow: Color = Color(0.55, 0.85, 0.6)

var player_state: Node


func _ready() -> void:
	add_to_group(&"assessment_door")
	if player_state == null:
		player_state = get_node_or_null("/root/PlayerState")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_available() -> bool:
	return repeatable or player_state == null or not player_state.get(&"assessment_done")


## Called by Player.interact(). Opens the room as a sibling of the farm.
func use(by: Node = null) -> bool:
	if not is_available() or room_scene == null:
		return false
	var farm := get_parent() as Node2D
	var host: Node = farm.get_parent() if farm and farm.get_parent() else get_tree().current_scene
	var room := room_scene.instantiate()
	if player_state:
		room.player_state = player_state
	host.add_child(room)
	room.enter(by as Node2D, farm)
	entered_room.emit(room)
	return true


func _draw() -> void:
	draw_rect(Rect2(-10, -24, 20, 24), color_frame)
	var glow := color_glow if is_available() else color_glow.darkened(0.6)
	draw_rect(Rect2(-7, -21, 14, 21), glow)


func _on_body_entered(body: Node) -> void:
	if body.has_method(&"register_interactable"):
		body.register_interactable(self, true)
	queue_redraw()


func _on_body_exited(body: Node) -> void:
	if body.has_method(&"register_interactable"):
		body.register_interactable(self, false)
