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
signal monsters_changed
signal assessment_completed(monster: RefCounted)
## A monster's home, party membership, bond or care flags changed.
signal care_changed
## End-of-day care results (see apply_daily_care).
signal daily_care_applied(report: Dictionary)

const MONSTER_CONFIG_PATH := "res://resources/monsters/monster_config.tres"
const PASS_OUT_CONFIG_PATH := "res://resources/pass_out_config.tres"
const ENERGY_CONFIG_PATH := "res://resources/energy_config.tres"
const ECONOMY_CONFIG_PATH := "res://resources/economy_config.tres"
const CARE_CONFIG_PATH := "res://resources/monsters/care_config.tres"
const ITEM_CATALOG_PATH := "res://resources/items/item_catalog.tres"
const HOME_PASTURE := &"pasture"
const HOME_BARN := &"barn"

var pass_out_config: PassOutConfig
var energy_config: EnergyConfig
var economy_config: EconomyConfig
var care_config: CareConfig
## PenData for the pasture and barn (resources/buildings/).
var pasture_data: PenData
var barn_data: PenData
## Barn upgrades bought (GDD: up to four, 20 -> 100 stalls).
var barn_upgrades: int = 0
var health: float = 100.0
var stamina: float = 100.0
## Coins the player is carrying (GDD currency). New games start with
## economy_config.starting_coins (placeholder).
var coins: int = 0
## Items the player carries (stacks; the first slots are on the hotbar).
var inventory: Inventory
## Every monster the player owns (Monster instances), wherever it lives.
var monsters: Array = []
## Monsters with the player (GDD: up to two, MonsterConfig.party_max). Each
## member with add_bond(delta: float) receives the pass-out bonding drop
## (0 and inactive by default).
var party: Array = []
## Farm's starting biome (SpeciesData.Biome), set by the first monster
## (GDD opening step 5); -1 before the Assessment.
var farm_biome: int = -1
## Habitats on the farm: [{id, biome, built}].
var habitats: Array = []
## True once the Assessment chose the first monster.
var assessment_done: bool = false
## True if the most recent day ended by passing out (2 AM) instead of sleeping.
var last_sleep_was_pass_out: bool = false
var pass_out_count: int = 0
var clock: GameClock


func _init() -> void:
	pass_out_config = GameClock._load_or_default(PASS_OUT_CONFIG_PATH, PassOutConfig) as PassOutConfig
	energy_config = GameClock._load_or_default(ENERGY_CONFIG_PATH, EnergyConfig) as EnergyConfig
	economy_config = GameClock._load_or_default(ECONOMY_CONFIG_PATH, EconomyConfig) as EconomyConfig
	care_config = GameClock._load_or_default(CARE_CONFIG_PATH, CareConfig) as CareConfig
	pasture_data = GameClock._load_or_default(CareConfig.PASTURE_PATH, PenData) as PenData
	barn_data = GameClock._load_or_default(CareConfig.BARN_PATH, PenData) as PenData
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


## GDD: eating food refills stamina. DECISIONS.md: the refill depends on the
## food (Player passes ItemData.stamina_refill); stamina_amount < 0 uses the
## placeholder fallback energy_config.eat_stamina_refill. Health outside
## battle stays a stub (on hold per DECISIONS.md).
func eat(stamina_amount: float = -1.0, health_amount: float = 0.0) -> void:
	refill_stamina(energy_config.eat_stamina_refill if stamina_amount < 0.0 else stamina_amount)
	if health_amount > 0.0:
		heal(health_amount)


## GDD: resting in a hot spring refills stamina. DECISIONS.md: at a steady
## rate; call every frame/tick while soaking with the elapsed seconds
## (rate: energy_config.hot_spring_stamina_per_second, placeholder). No hot
## spring is placed in the world yet.
func soak_in_hot_spring(delta_seconds: float) -> void:
	refill_stamina(energy_config.hot_spring_stamina_per_second * maxf(delta_seconds, 0.0))


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


# --- Monsters ---------------------------------------------------------------

## Adds a monster to the roster and, if there is room and `to_party`, to the
## party. Returns true if it joined the party.
func add_monster(m: RefCounted, to_party: bool = true) -> bool:
	if m == null:
		return false
	if not monsters.has(m):
		monsters.append(m)
	var joined := false
	if to_party and not party.has(m) and party.size() < get_party_max():
		party.append(m)
		if m.home == &"":
			m.home = HOME_BARN
		joined = true
	monsters_changed.emit()
	return joined


func get_monster(uid: String) -> RefCounted:
	for m in monsters:
		if m.uid == uid:
			return m
	return null


## GDD opening: the chosen Assessment monster becomes the player's first
## monster and decides the farm's starting biome; DECISIONS.md: that biome's
## habitat is already built. GDD: a wild-caught monster lives in its biome's
## habitat (or the pasture) until bonded, so it goes there unless
## `join_party` (AssessmentConfig.first_monster_joins_party, off). The first
## monster also brings Angie's gift (CareConfig, the opening is skipped).
func complete_assessment(m: RefCounted, join_party: bool = false) -> void:
	if m == null:
		return
	var biome: int = m.origin_biome
	var first := not assessment_done
	if farm_biome < 0 and biome >= 0:
		farm_biome = biome
		build_habitat(biome)
	if join_party:
		add_monster(m, true)
	if not party.has(m):
		add_wild_monster(m)
	if first:
		give_angie_gift(m)
	assessment_done = true
	assessment_completed.emit(m)


## Marks the habitat for `biome` as built (data from HabitatData). Returns the
## state entry.
func build_habitat(biome: int) -> Dictionary:
	var existing := get_habitat(biome)
	if not existing.is_empty():
		existing.built = true
		return existing
	var data := HabitatData.for_biome(biome)
	var entry := {"id": String(data.id) if data else "habitat_%d" % biome, "biome": biome, "built": true}
	habitats.append(entry)
	return entry


func get_habitat(biome: int) -> Dictionary:
	for h in habitats:
		if int(h.biome) == biome:
			return h
	return {}


func get_habitat_by_id(id: StringName) -> Dictionary:
	for h in habitats:
		if StringName(h.id) == id:
			return h
	return {}


# --- Homes, capacity, party (Slice 3) ---------------------------------------

## Spots in `home` (pasture, barn or a built habitat id); 0 if unknown.
func get_capacity(home: StringName) -> int:
	if home == HOME_PASTURE:
		return pasture_data.get_capacity()
	if home == HOME_BARN:
		return barn_data.get_capacity(barn_upgrades)
	var h := get_habitat_by_id(home)
	if h.is_empty() or not h.built:
		return 0
	var data = HabitatData.for_biome(int(h.biome))
	return data.capacity if data else 12


## Monsters whose home is `home` (party members included: they keep their stall).
func get_residents(home: StringName) -> Array:
	return monsters.filter(func(m): return m.home == home)


func get_free_spots(home: StringName) -> int:
	return maxi(get_capacity(home) - get_residents(home).size(), 0)


func has_room(home: StringName) -> bool:
	return get_free_spots(home) > 0


## GDD: a wild-caught monster goes to its biome's habitat if it has a spot,
## otherwise the pasture (max 6). Returns the home, or &"" if both are full
## (nothing changes then).
func get_wild_home(m: RefCounted) -> StringName:
	var hab := get_habitat(m.origin_biome)
	if not hab.is_empty() and hab.built and has_room(StringName(hab.id)):
		return StringName(hab.id)
	return HOME_PASTURE if has_room(HOME_PASTURE) else &""


## Adds a wild-caught monster to the roster in its habitat or the pasture.
## Returns false (and adds nothing) when there is no room.
func add_wild_monster(m: RefCounted) -> bool:
	var home := get_wild_home(m)
	if home == &"":
		return false
	m.home = home
	if not monsters.has(m):
		monsters.append(m)
	monsters_changed.emit()
	care_changed.emit()
	return true


## Why `m` can't move to `home` ("" = it can). GDD: only bonded monsters (25%)
## go to the barn; a habitat only takes monsters of its biome.
func get_move_block(m: RefCounted, home: StringName) -> String:
	if m == null or not monsters.has(m):
		return "Not your monster"
	if m.home == home:
		return "Already there"
	if home == HOME_BARN:
		if not m.can_go_to_barn():
			var mc := load(MONSTER_CONFIG_PATH) as MonsterConfig
			return "Needs %d%% bond" % int(mc.barn_bond if mc else 25.0)
	elif home != HOME_PASTURE:
		var h := get_habitat_by_id(home)
		if h.is_empty() or not h.built:
			return "No such habitat"
		var sp = m.get_species()
		if sp == null or not sp.lives_in(int(h.biome)):
			return "Wrong biome"
	if not has_room(home):
		return "%s is full" % get_home_name(home)
	return ""


func can_move(m: RefCounted, home: StringName) -> bool:
	return get_move_block(m, home) == ""


## Moves `m` to `home` if allowed. Leaving the barn also leaves the party
## (GDD: the party comes from the barn).
func move_monster(m: RefCounted, home: StringName) -> bool:
	if not can_move(m, home):
		return false
	m.home = home
	if home != HOME_BARN and party.has(m):
		party.erase(m)
	monsters_changed.emit()
	care_changed.emit()
	return true


func move_to_barn(m: RefCounted) -> bool:
	return move_monster(m, HOME_BARN)


func get_home_name(home: StringName) -> String:
	if home == HOME_PASTURE:
		return pasture_data.display_name
	if home == HOME_BARN:
		return barn_data.display_name
	var h := get_habitat_by_id(home)
	if not h.is_empty():
		var data = HabitatData.for_biome(int(h.biome))
		if data:
			return data.display_name
	return String(home)


## GDD: up to two barn monsters can be taken out at a time.
func can_join_party(m: RefCounted) -> bool:
	return m != null and monsters.has(m) and m.home == HOME_BARN and not party.has(m) \
		and party.size() < get_party_max()


func add_to_party(m: RefCounted) -> bool:
	if not can_join_party(m):
		return false
	party.append(m)
	monsters_changed.emit()
	care_changed.emit()
	return true


func remove_from_party(m: RefCounted) -> bool:
	if not party.has(m):
		return false
	party.erase(m)
	monsters_changed.emit()
	care_changed.emit()
	return true


## GDD: the barn can be upgraded four times (costs OPEN: upgrade_costs,
## empty = free placeholder). Returns true if upgraded.
func upgrade_barn() -> bool:
	if barn_upgrades >= barn_data.max_upgrades:
		return false
	var cost := barn_data.get_upgrade_cost(barn_upgrades)
	if cost > coins:
		return false
	if cost > 0:
		add_coins(-cost)
	barn_upgrades += 1
	care_changed.emit()
	return true


# --- Feeding and daily care ---------------------------------------------------

## Bond points feeding `item` to `m` would give (before the per-day limit).
## GDD: the favorite food raises bonding more ("continuously": streak bonus);
## each monster has a preferred food type. Numbers: CareConfig (placeholders).
## `item` is an ItemData (untyped: naming ItemData here trips the engine's
## "resources still in use at exit" quirk, see player.gd).
func get_feed_bond(m: RefCounted, item: Resource) -> float:
	if m == null or item == null or not item.is_feedable():
		return 0.0
	var cfg := care_config
	if is_favorite_food(m, item):
		return cfg.feed_bond_favorite + cfg.favorite_streak_bonus * mini(m.favorite_streak, cfg.favorite_streak_cap)
	var sp = m.get_species()
	if sp and sp.preferred_food_type != &"" and item.food_type == sp.preferred_food_type:
		return cfg.feed_bond_preferred
	return cfg.feed_bond_other


func is_favorite_food(m: RefCounted, item: Resource) -> bool:
	if item.always_favorite:
		return true
	var fav: StringName = m.favorite_food_id
	if fav == &"":
		var sp = m.get_species()
		fav = sp.favorite_food_id if sp else &""
	return fav != &"" and item.id == fav


## Feeds one `item_id` from the inventory to `m`. Returns {ok, bond, reason}.
## Counts as the barn's daily food; bond only for the first
## CareConfig.bond_feeds_per_day feeds a day.
func feed_monster(m: RefCounted, item_id: StringName) -> Dictionary:
	var result := {"ok": false, "bond": 0.0, "reason": ""}
	if m == null or not monsters.has(m):
		result.reason = "Not your monster"
		return result
	var item = _items().get_item(item_id)
	if item == null or not item.is_feedable():
		result.reason = "Not food"
		return result
	if inventory.count(item_id) <= 0:
		result.reason = "None left"
		return result
	inventory.remove(item_id, 1)
	var gain := 0.0
	if m.bond_feeds_today < care_config.bond_feeds_per_day:
		gain = get_feed_bond(m, item)
		m.bond_feeds_today += 1
	var before: float = m.bond
	m.add_bond(gain)
	m.fed_today = true
	if is_favorite_food(m, item):
		m.fed_favorite_today = true
	result.ok = true
	result.bond = m.bond - before
	care_changed.emit()
	return result


## GDD: barn monsters need water every day. Fills the barn troughs (every
## barn monster is watered today). Placeholder: one free action.
func water_barn() -> int:
	var n := 0
	for m in get_residents(HOME_BARN):
		if not m.watered_today:
			m.watered_today = true
			n += 1
	care_changed.emit()
	return n


## Barn monsters (not out with the party) still missing food or water today.
func get_barn_needs() -> Dictionary:
	var hungry := 0
	var thirsty := 0
	for m in get_residents(HOME_BARN):
		if care_config.party_skips_barn_care and party.has(m):
			continue
		if not m.fed_today:
			hungry += 1
		if not m.watered_today:
			thirsty += 1
	return {"hungry": hungry, "thirsty": thirsty}


## Day-end bond tick (GDD: party monsters gain passive bonding; barn monsters
## need food and water every day). Updates the favorite-food streak and
## resets the daily flags. Returns {party_gain, neglected, streaks}.
func apply_daily_care() -> Dictionary:
	var cfg := care_config
	var report := {"party_gain": 0.0, "neglected": 0, "streaks": 0}
	for m in monsters:
		if party.has(m) and cfg.party_bond_per_day > 0.0:
			m.add_bond(cfg.party_bond_per_day)
			report.party_gain = cfg.party_bond_per_day
		var cared_for: bool = m.fed_today and m.watered_today
		var exempt: bool = cfg.party_skips_barn_care and party.has(m)
		if m.home == HOME_BARN and not exempt and not cared_for:
			m.add_bond(-maxf(cfg.barn_neglect_bond_drop, 0.0))
			report.neglected += 1
		m.favorite_streak = m.favorite_streak + 1 if m.fed_favorite_today else 0
		if m.favorite_streak > 0:
			report.streaks += 1
		m.fed_today = false
		m.watered_today = false
		m.fed_favorite_today = false
		m.bond_feeds_today = 0
	care_changed.emit()
	daily_care_applied.emit(report)
	return report


## GDD opening (skipped): Angie gives 20 always-favorite foods and 45 seeds of
## the monster's favorite crop (this season's, else its first). Returns
## {treats, seed_id, seeds} actually added.
func give_angie_gift(m: RefCounted) -> Dictionary:
	var cfg := care_config
	var out := {"treats": 0, "seed_id": "", "seeds": 0}
	if not cfg.angie_gift_enabled or m == null:
		return out
	if cfg.angie_treat_count > 0 and _items().has_item(cfg.angie_treat_id):
		out.treats = add_item(cfg.angie_treat_id, cfg.angie_treat_count)
	var sp = m.get_species()
	if sp and cfg.angie_seed_count > 0:
		var season := clock.season if clock else 0
		var crop := ""
		if season < sp.favorite_crops.size():
			crop = sp.favorite_crops[season]
		if crop == "":
			for c in sp.favorite_crops:
				if c != "":
					crop = c
					break
		var seed = _items().get_seed_for_crop(StringName(crop)) if crop != "" else null
		if seed:
			out.seed_id = String(seed.id)
			out.seeds = add_item(seed.id, cfg.angie_seed_count)
	return out


func get_party_max() -> int:
	var cfg := load(MONSTER_CONFIG_PATH) as MonsterConfig
	return cfg.party_max if cfg else 2


func to_dict() -> Dictionary:
	return {
		"coins": coins,
		"inventory": inventory.to_array(),
		"monsters": monsters.map(func(m): return m.to_dict()),
		"party": party.map(func(m): return m.uid),
		"farm_biome": farm_biome,
		"habitats": habitats.duplicate(true),
		"assessment_done": assessment_done,
		"health": health,
		"stamina": stamina,
		"last_sleep_was_pass_out": last_sleep_was_pass_out,
		"pass_out_count": pass_out_count,
		"barn_upgrades": barn_upgrades,
	}


func from_dict(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	coins_changed.emit(coins)
	if data.get("inventory") is Array:
		inventory.from_array(data["inventory"])
	monsters.clear()
	party.clear()
	for md in data.get("monsters", []):
		if md is Dictionary:
			monsters.append(Monster.from_dict(md))
	for uid in data.get("party", []):
		var m := get_monster(String(uid))
		if m and not party.has(m) and party.size() < get_party_max():
			party.append(m)
	monsters_changed.emit()
	farm_biome = int(data.get("farm_biome", -1))
	habitats = []
	for h in data.get("habitats", []):
		if h is Dictionary:
			habitats.append({"id": String(h.get("id", "")), "biome": int(h.get("biome", -1)),
				"built": bool(h.get("built", false))})
	assessment_done = bool(data.get("assessment_done", false))
	_set_health(float(data.get("health", energy_config.max_health)))
	_set_stamina(float(data.get("stamina", energy_config.max_stamina)))
	last_sleep_was_pass_out = bool(data.get("last_sleep_was_pass_out", false))
	pass_out_count = int(data.get("pass_out_count", 0))
	barn_upgrades = clampi(int(data.get("barn_upgrades", 0)), 0, barn_data.max_upgrades)
	care_changed.emit()


func _on_inventory_changed() -> void:
	inventory_changed.emit()


func _on_day_ended(_day: int, pass_out: bool) -> void:
	apply_sleep(pass_out)
	apply_daily_care()


## The item catalog, loaded by path: naming ItemCatalog (which names
## ItemData) in this autoload trips the "resources still in use" quirk.
func _items() -> Resource:
	return load(ITEM_CATALOG_PATH)
