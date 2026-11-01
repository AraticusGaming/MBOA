class_name Hud
extends CanvasLayer
## Placeholder HUD: day / season / time / phase / health + stamina bars
## (GDD Energy) / Coins / tired / exhausted / current tool or item, the hotbar
## along the bottom for mouse & touch (Player tools, then the first inventory
## slots with their counts), and the sleep fade-to-black transition.

## Seconds to fade back in after the new day starts.
@export var fade_in_seconds: float = 0.8
@export var pass_out_message: String = "You passed out..."
@export var sleep_message: String = "Zzz..."

@onready var _day_label: Label = %DayLabel
@onready var _time_label: Label = %TimeLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _tired_label: Label = %TiredLabel
@onready var _tool_label: Label = %ToolLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _stamina_bar: ProgressBar = %StaminaBar
@onready var _exhausted_label: Label = %ExhaustedLabel
@onready var _fade: ColorRect = %Fade
@onready var _fade_label: Label = %FadeLabel
@onready var _tool_buttons: HBoxContainer = %ToolButtons

var clock: GameClock
var player: Player
## PlayerState autoload (health/stamina); injectable for tests.
var player_state: Node
var _fade_tween: Tween


func _ready() -> void:
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	if clock:
		clock.sleep_started.connect(_on_sleep_started)
		clock.day_started.connect(_on_day_started)
	if player_state == null:
		player_state = get_node_or_null("/root/PlayerState")
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


## One toggle button per hotbar slot (tools, then inventory slots).
func _build_tool_buttons() -> void:
	for c in _tool_buttons.get_children():
		_tool_buttons.remove_child(c)
		c.queue_free()
	if player == null:
		return
	for i in player.get_hotbar_size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.custom_minimum_size = Vector2(20, 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tool_button.bind(i))
		_tool_buttons.add_child(b)
	_update_slot_texts()


## Label for hotbar slot `i`: "<key> <tool>" or "<key> <item> x<count>".
func get_slot_text(i: int) -> String:
	if player == null:
		return ""
	if i < player.tools.size():
		var t := player.tools[i]
		return "%d %s" % [i + 1, t.display_name if t else "?"]
	var inv: Inventory = player_state.inventory if player_state else null
	var slot = inv.get_slot(i - player.tools.size()) if inv else null
	if slot == null:
		return "%d -" % (i + 1)
	var item := inv.get_item_in_slot(i - player.tools.size())
	return "%d %s x%d" % [i + 1, item.display_name if item else String(slot.id), slot.count]


func _update_slot_texts() -> void:
	for i in _tool_buttons.get_child_count():
		var b := _tool_buttons.get_child(i) as Button
		var t := get_slot_text(i)
		if b.text != t:
			b.text = t


func _refresh() -> void:
	if clock:
		_day_label.text = "Y%d %s %d (Day %d)" % [clock.year, clock.get_season_name().capitalize(),
			clock.get_day_of_season(), clock.day]
		_time_label.text = clock.get_time_string()
		_phase_label.text = clock.get_phase_name().capitalize()
		_tired_label.visible = clock.is_tired
	if player_state:
		var cfg: EnergyConfig = player_state.energy_config
		_health_bar.max_value = cfg.max_health
		_health_bar.value = player_state.health
		_stamina_bar.max_value = cfg.max_stamina
		_stamina_bar.value = player_state.stamina
		_exhausted_label.visible = player_state.is_exhausted()
		_coins_label.text = "Coins: %d" % player_state.coins
	if player:
		var tool := player.current_tool
		if tool:
			_tool_label.text = "Tool: " + tool.display_name
		else:
			var item: ItemData = player.get_current_item()
			_tool_label.text = "Item: " + (item.display_name if item else "-")
		if _tool_buttons.get_child_count() != player.get_hotbar_size():
			_build_tool_buttons()
		_update_slot_texts()
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
