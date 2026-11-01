extends Node
## Autoload "PlayerState": persistent player stats that outlive scenes, and the
## sleep handler that applies PassOutConfig penalties when a day ends.
##
## Energy and gold are PLACEHOLDERS (no energy/economy design yet) so the
## pass-out penalty has something to act on; Milestone 2+ will flesh them out.

signal sleep_resolved(pass_out: bool, penalties: Dictionary)
signal energy_changed(energy: float, max_energy: float)
signal gold_changed(gold: int)

const PASS_OUT_CONFIG_PATH := "res://resources/pass_out_config.tres"

## PLACEHOLDER: energy system not designed yet.
@export var max_energy: float = 100.0

var config: PassOutConfig
var energy: float = 100.0
var gold: int = 0
## True if the most recent day ended by passing out (2 AM) instead of sleeping.
var last_sleep_was_pass_out: bool = false
var pass_out_count: int = 0
var clock: GameClock


func _init() -> void:
	config = GameClock._load_or_default(PASS_OUT_CONFIG_PATH, PassOutConfig) as PassOutConfig
	energy = max_energy


func _ready() -> void:
	if clock == null:
		bind_clock(get_node_or_null("/root/Clock") as GameClock)


func bind_clock(c: GameClock) -> void:
	if clock and clock.day_ended.is_connected(_on_day_ended):
		clock.day_ended.disconnect(_on_day_ended)
	clock = c
	if clock:
		clock.day_ended.connect(_on_day_ended)


## Resolves a night's sleep. Normal sleep fully restores energy; passing out
## applies the configured (placeholder) penalties. Returns what was applied.
func apply_sleep(pass_out: bool) -> Dictionary:
	last_sleep_was_pass_out = pass_out
	var penalties := {"energy_lost": 0.0, "gold_lost": 0, "wake_hour_delay": 0.0}
	var restored := max_energy
	if pass_out:
		pass_out_count += 1
		penalties.energy_lost = max_energy * clampf(config.energy_penalty_fraction, 0.0, 1.0)
		restored -= penalties.energy_lost
		var lost := int(floor(gold * clampf(config.gold_penalty_fraction, 0.0, 1.0)))
		if config.gold_penalty_max > 0:
			lost = mini(lost, config.gold_penalty_max)
		penalties.gold_lost = lost
		penalties.wake_hour_delay = config.wake_hour_delay  # applied by Clock
		if lost != 0:
			gold -= lost
			gold_changed.emit(gold)
	energy = restored
	energy_changed.emit(energy, max_energy)
	sleep_resolved.emit(pass_out, penalties)
	return penalties


func to_dict() -> Dictionary:
	return {
		"energy": energy,
		"gold": gold,
		"last_sleep_was_pass_out": last_sleep_was_pass_out,
		"pass_out_count": pass_out_count,
	}


func from_dict(data: Dictionary) -> void:
	energy = float(data.get("energy", max_energy))
	gold = int(data.get("gold", 0))
	last_sleep_was_pass_out = bool(data.get("last_sleep_was_pass_out", false))
	pass_out_count = int(data.get("pass_out_count", 0))


func _on_day_ended(_day: int, pass_out: bool) -> void:
	apply_sleep(pass_out)
