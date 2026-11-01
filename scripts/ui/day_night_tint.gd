class_name DayNightTint
extends CanvasModulate
## Tints the world (not the HUD, which lives on its own CanvasLayer) from
## Clock.get_darkness(). Colors are PLACEHOLDERS.

@export var day_color: Color = Color.WHITE
@export var night_color: Color = Color(0.2, 0.25, 0.5)

var clock: GameClock


func _ready() -> void:
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	if clock == null:
		return
	color = day_color.lerp(night_color, clock.get_darkness())
