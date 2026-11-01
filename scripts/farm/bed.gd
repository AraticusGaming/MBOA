class_name Bed
extends Area2D
## Placeholder bed: stand on it and press interact to sleep (ends the day).

signal used(by: Node)

@export var size: Vector2 = Vector2(16, 24)
@export var color_frame: Color = Color(0.45, 0.28, 0.18)
@export var color_sheet: Color = Color(0.85, 0.85, 0.95)
@export var color_pillow: Color = Color.WHITE

var clock: GameClock


func _ready() -> void:
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Called by Player.interact(). Starts voluntary sleep.
func use(by: Node = null) -> bool:
	if clock == null or clock.is_sleeping:
		return false
	used.emit(by)
	clock.sleep(false)
	return true


func _draw() -> void:
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
