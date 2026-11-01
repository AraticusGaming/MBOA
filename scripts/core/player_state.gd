extends Node
## Autoload "PlayerState": player data that outlives scenes, and the sleep
## handler that applies the GDD pass-out penalty when a day ends.

signal sleep_resolved(pass_out: bool, penalties: Dictionary)
signal coins_changed(coins: int)

const PASS_OUT_CONFIG_PATH := "res://resources/pass_out_config.tres"

var pass_out_config: PassOutConfig
## Coins the player is carrying (GDD currency). Economy is Milestone 2.
var coins: int = 0
## Monsters with the player (GDD: up to two from the barn). Empty until
## monsters exist; any member with add_bond(delta: float) receives the
## pass-out bonding drop.
var party: Array = []
## True if the most recent day ended by passing out (2 AM) instead of sleeping.
var last_sleep_was_pass_out: bool = false
var pass_out_count: int = 0
var clock: GameClock


func _init() -> void:
	pass_out_config = GameClock._load_or_default(PASS_OUT_CONFIG_PATH, PassOutConfig) as PassOutConfig


func _ready() -> void:
	if clock == null:
		bind_clock(get_node_or_null("/root/Clock") as GameClock)


func bind_clock(c: GameClock) -> void:
	if clock and clock.day_ended.is_connected(_on_day_ended):
		clock.day_ended.disconnect(_on_day_ended)
	clock = c
	if clock:
		clock.day_ended.connect(_on_day_ended)


func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)


## Resolves a night's sleep. Passing out applies the PassOutConfig penalty
## (carried-Coins percentage + fixed party bond drop). Returns what was applied.
func apply_sleep(pass_out: bool) -> Dictionary:
	last_sleep_was_pass_out = pass_out
	var penalties := {"coins_lost": 0, "party_bond_drop": 0.0}
	if pass_out:
		pass_out_count += 1
		var lost := int(floor(coins * clampf(pass_out_config.gold_penalty_fraction, 0.0, 1.0)))
		penalties.coins_lost = lost
		if lost != 0:
			add_coins(-lost)
		var drop := maxf(pass_out_config.party_bond_drop, 0.0)
		if drop > 0.0:
			for member in party:
				if member != null and member.has_method(&"add_bond"):
					member.add_bond(-drop)
			penalties.party_bond_drop = drop
	sleep_resolved.emit(pass_out, penalties)
	return penalties


func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"last_sleep_was_pass_out": last_sleep_was_pass_out,
		"pass_out_count": pass_out_count,
	}


func from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	last_sleep_was_pass_out = bool(data.get("last_sleep_was_pass_out", false))
	pass_out_count = int(data.get("pass_out_count", 0))


func _on_day_ended(_day: int, pass_out: bool) -> void:
	apply_sleep(pass_out)
