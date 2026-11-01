class_name Bed
extends Area2D
## Bed (ART assets/sprites/bed.png, 16x32, a Sprite2D child): stand on it and press interact to sleep (ends the day).
## GDD: after sleeping or passing out the player wakes up in their bed, so on
## every Clock.day_started the player is moved to wake_offset from the bed.

signal used(by: Node)

## Footprint (ART_NOTES: 16x32, one tile wide, two tall).
@export var size: Vector2 = Vector2(16, 32)
## Where the player stands on waking, relative to the bed (just below it, so
## they are not standing on the bed's interact area).
@export var wake_offset: Vector2 = Vector2(0, 24)
@export var color_frame: Color = Color(0.45, 0.28, 0.18)
@export var color_sheet: Color = Color(0.85, 0.85, 0.95)
@export var color_pillow: Color = Color.WHITE

var clock: GameClock


func _ready() -> void:
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	add_to_group(&"bed")
	if clock and not clock.day_started.is_connected(_on_day_started):
		clock.day_started.connect(_on_day_started)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Called by Player.interact(). Starts voluntary sleep.
func use(by: Node = null) -> bool:
	if clock == null or clock.is_sleeping:
		return false
	used.emit(by)
	clock.sleep(false)
	return true


## Global position where the player wakes up.
func get_wake_position() -> Vector2:
	return global_position + wake_offset


## Moves the player to the bed's wake spot facing down.
func wake_player(player: Node2D) -> void:
	if player == null:
		return
	player.global_position = get_wake_position()
	if "facing" in player:
		player.facing = Vector2i.DOWN


func _on_day_started(_day: int) -> void:
	if is_inside_tree():
		wake_player(get_tree().get_first_node_in_group(&"player") as Node2D)


## Placeholder drawing only when there is no sprite.
func _draw() -> void:
	if get_node_or_null(^"Sprite2D") != null:
		return
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, color_frame)
	draw_rect(r.grow(-2), color_sheet)
	draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(size.x - 6, 5)), color_pillow)


func _on_body_entered(body: Node) -> void:
	if body.has_method(&"register_bed"):
		body.register_bed(self, true)


func _on_body_exited(body: Node) -> void:
	if body.has_method(&"register_bed"):
		body.register_bed(self, false)
