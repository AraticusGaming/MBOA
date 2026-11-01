extends Node
## Autoload "PlayerState": player data that outlives scenes (coins,
## inventory, health, stamina, party), and the sleep handler: sleeping refills stamina (GDD) and
## passing out applies the GDD pass-out penalty.
##
## Health outside battle is an OPEN QUESTION in the GDD: it is tracked and
## shown, with damage()/heal() hooks, but nothing reduces it yet.

signal sleep_resolved(pass_out: bool, penalties: Dictionary)
signal coins_changed(coins: int)
signal health_changed(health: float, max_health: float)
signal stamina_changed(stamina: float, max_stamina: float)
## The inventory's contents changed (forwarded from Inventory.changed).
signal inventory_changed

const PASS_OUT_CONFIG_PATH := "res://resources/pass_out_config.tres"
const ENERGY_CONFIG_PATH := "res://resources/energy_config.tres"
const ECONOMY_CONFIG_PATH := "res://resources/economy_config.tres"

var pass_out_config: PassOutConfig
var energy_config: EnergyConfig
var economy_config: EconomyConfig
var health: float = 100.0
var stamina: float = 100.0
## Coins the player is carrying (GDD currency). New games start with
## economy_config.starting_coins (placeholder).
var coins: int = 0
## Items the player carries (stacks; the first slots are on the hotbar).
var inventory: Inventory
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
	energy_config = GameClock._load_or_default(ENERGY_CONFIG_PATH, EnergyConfig) as EnergyConfig
	economy_config = GameClock._load_or_default(ECONOMY_CONFIG_PATH, EconomyConfig) as EconomyConfig
	health = energy_config.max_health
	stamina = energy_config.max_stamina
	inventory = Inventory.new(economy_config.inventory_slots)
	inventory.changed.connect(_on_inventory_changed)
	apply_starting_kit()


func _ready() -> void:
	if clock == null:
		bind_clock(get_node_or_null("/root/Clock") as GameClock)


func bind_clock(c: GameClock) -> void:
	if clock and clock.day_ended.is_connected(_on_day_ended):
		clock.day_ended.disconnect(_on_day_ended)
	clock = c
	if clock:
		clock.day_ended.connect(_on_day_ended)


## New-game Coins and items from economy_config (placeholders). Replaces the
## current Coins and inventory.
func apply_starting_kit() -> void:
	coins = maxi(economy_config.starting_coins, 0)
	inventory.clear()
	for id in economy_config.starting_items:
		inventory.add(StringName(id), int(economy_config.starting_items[id]))
	coins_changed.emit(coins)


## Adds harvested/dropped items. Returns how many fit (the rest is lost;
## placeholder: there are no ground drops yet).
func add_item(id: StringName, amount: int = 1) -> int:
	return inventory.add(id, amount)


func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)


# --- Stamina / health -------------------------------------------------------

## GDD: at 0 stamina the player can't use tools.
func can_use_tools() -> bool:
	return stamina > 0.0


## GDD: at 0 stamina the player is slowed.
func is_exhausted() -> bool:
	return stamina <= 0.0


## Speed multiplier from stamina (1.0, or the placeholder slow at 0).
func get_speed_multiplier() -> float:
	return energy_config.exhausted_speed_multiplier if is_exhausted() else 1.0


## Pays for one tool use. Fails (and changes nothing) at 0 stamina; a use that
## costs more than what is left still happens and empties the bar.
func spend_stamina(amount: float) -> bool:
	if not can_use_tools():
		return false
	_set_stamina(stamina - maxf(amount, 0.0))
	return true


## Adds stamina (amount < 0 = refill to full).
func refill_stamina(amount: float = -1.0) -> void:
	_set_stamina(energy_config.max_stamina if amount < 0.0 else stamina + amount)


## GDD: eating food refills stamina. Not GDD, placeholder (Ledan ruling): a
## flat refill of energy_config.eat_stamina_refill; pass stamina_amount >= 0 to
## override. Health outside battle stays a stub (GDD open question).
func eat(stamina_amount: float = -1.0, health_amount: float = 0.0) -> void:
	refill_stamina(energy_config.eat_stamina_refill if stamina_amount < 0.0 else stamina_amount)
	if health_amount > 0.0:
		heal(health_amount)


## GDD: resting in a hot spring refills stamina. Not GDD, placeholder (Ledan
## ruling): a flat refill of energy_config.hot_spring_stamina_refill per rest.
## No hot spring is placed in the world yet.
func rest_in_hot_spring() -> void:
	refill_stamina(energy_config.hot_spring_stamina_refill)


## Health hooks (what health does outside battle is a GDD open question).
func damage(amount: float) -> void:
	_set_health(health - maxf(amount, 0.0))


func heal(amount: float) -> void:
	_set_health(health + maxf(amount, 0.0))


func _set_stamina(value: float) -> void:
	var v := clampf(value, 0.0, energy_config.max_stamina)
	if v != stamina:
		stamina = v
		stamina_changed.emit(stamina, energy_config.max_stamina)


func _set_health(value: float) -> void:
	var v := clampf(value, 0.0, energy_config.max_health)
	if v != health:
		health = v
		health_changed.emit(health, energy_config.max_health)


# --- Sleep --------------------------------------------------------------------

## Resolves a night's sleep. Stamina refills (GDD: sleeping refills it; the
## GDD pass-out penalty does not mention stamina, so passing out refills too). Passing out applies the PassOutConfig penalty
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
	refill_stamina()
	sleep_resolved.emit(pass_out, penalties)
	return penalties


func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"inventory": inventory.to_array(),
		"health": health,
		"stamina": stamina,
		"last_sleep_was_pass_out": last_sleep_was_pass_out,
		"pass_out_count": pass_out_count,
	}


func from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	coins_changed.emit(coins)
	if data.get("inventory") is Array:
		inventory.from_array(data["inventory"])
	_set_health(float(data.get("health", energy_config.max_health)))
	_set_stamina(float(data.get("stamina", energy_config.max_stamina)))
	last_sleep_was_pass_out = bool(data.get("last_sleep_was_pass_out", false))
	pass_out_count = int(data.get("pass_out_count", 0))


func _on_inventory_changed() -> void:
	inventory_changed.emit()


func _on_day_ended(_day: int, pass_out: bool) -> void:
	apply_sleep(pass_out)
