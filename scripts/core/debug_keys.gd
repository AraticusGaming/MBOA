extends Node
## Debug-only shortcuts: F1/F2/F3 = clock speed x1/x10/x60, F4 = sleep now.
## Disabled in release exports.

@export var enabled_in_release: bool = false

var clock: GameClock


func _ready() -> void:
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	set_process_unhandled_input(OS.is_debug_build() or enabled_in_release)


func _unhandled_input(event: InputEvent) -> void:
	if clock == null:
		return
	if event.is_action_pressed(&"debug_time_x1"):
		clock.time_scale = 1.0
	elif event.is_action_pressed(&"debug_time_x10"):
		clock.time_scale = 10.0
	elif event.is_action_pressed(&"debug_time_x60"):
		clock.time_scale = 60.0
	elif event.is_action_pressed(&"debug_sleep"):
		clock.sleep(false)
	else:
		return
	get_viewport().set_input_as_handled()
