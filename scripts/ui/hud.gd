class_name Hud
extends CanvasLayer
## Placeholder HUD: day / season / time / phase / tired / current tool, hotbar
## buttons for mouse & touch (built from Player.tools), and the sleep
## fade-to-black transition.

## Seconds to fade back in after the new day starts.
@export var fade_in_seconds: float = 0.8
@export var pass_out_message: String = "You passed out..."
@export var sleep_message: String = "Zzz..."

@onready var _day_label: Label = %DayLabel
@onready var _time_label: Label = %TimeLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _tired_label: Label = %TiredLabel
@onready var _tool_label: Label = %ToolLabel
@onready var _fade: ColorRect = %Fade
@onready var _fade_label: Label = %FadeLabel
@onready var _tool_buttons: HBoxContainer = %ToolButtons

var clock: GameClock
var player: Player
var _fade_tween: Tween


func _ready() -> void:
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	if clock:
		clock.sleep_started.connect(_on_sleep_started)
		clock.day_started.connect(_on_day_started)
	_fade.modulate.a = 0.0
	_fade.visible = false
	_bind_player.call_deferred()
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _bind_player() -> void:
	player = get_tree().get_first_node_in_group(&"player") as Player
	_build_tool_buttons()
	_refresh()


## One toggle button per hotbar slot, labelled "<key> <name>".
func _build_tool_buttons() -> void:
	for c in _tool_buttons.get_children():
		_tool_buttons.remove_child(c)
		c.queue_free()
	if player == null:
		return
	for i in player.tools.size():
		var t := player.tools[i]
		var b := Button.new()
		b.text = "%d %s" % [i + 1, t.display_name if t else "?"]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tool_button.bind(i))
		_tool_buttons.add_child(b)


func _refresh() -> void:
	if clock:
		_day_label.text = "Y%d %s %d (Day %d)" % [clock.year, clock.get_season_name().capitalize(),
			clock.get_day_of_season(), clock.day]
		_time_label.text = clock.get_time_string()
		_phase_label.text = clock.get_phase_name().capitalize()
		_tired_label.visible = clock.is_tired
	if player:
		var tool := player.current_tool
		_tool_label.text = "Tool: " + (tool.display_name if tool else "-")
		for i in _tool_buttons.get_child_count():
			(_tool_buttons.get_child(i) as Button).button_pressed = i == player.current_slot


func _on_tool_button(index: int) -> void:
	if player:
		player.set_tool(index)


func _on_sleep_started(pass_out: bool) -> void:
	_fade_label.text = pass_out_message if pass_out else sleep_message
	_fade.visible = true
	_kill_tween()
	var dur := clock.config.sleep_transition_seconds if clock else 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "modulate:a", 1.0, maxf(dur * 0.9, 0.01))


func _on_day_started(_day: int) -> void:
	if not _fade.visible:
		return
	_kill_tween()
	_fade.modulate.a = 1.0
	clock.pause(&"sleep_fade")
	_fade_tween = create_tween()
	_fade_tween.tween_interval(0.25)
	_fade_tween.tween_property(_fade, "modulate:a", 0.0, maxf(fade_in_seconds, 0.01))
	_fade_tween.finished.connect(_on_fade_in_done)


func _on_fade_in_done() -> void:
	_fade.visible = false
	if clock:
		clock.resume(&"sleep_fade")


func _kill_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		if clock and clock.get_pause_reasons().has(&"sleep_fade"):
			clock.resume(&"sleep_fade")
