class_name AssessmentSession
extends RefCounted
## Pure Assessment logic (no nodes): creatures wander, traps lure, catch or
## fail, captures are kept or released, one is chosen. Driven by update(delta)
## and a seeded RandomNumberGenerator so tests are deterministic.
## Rules: AssessmentConfig (GDD values + placeholders).

signal creature_spawned(index: int)
signal trap_placed(index: int)
signal trap_shaking(index: int)
signal trap_caught(index: int, monster: Monster)
signal trap_failed(index: int)
signal traps_refilled
signal finished(monster: Monster)

enum TrapState { SET, LURING, SHAKING, CAUGHT, FAILED }

var config: AssessmentConfig
var rng: RandomNumberGenerator
var catalog: SpeciesCatalog
## Each creature: {monster, pos, vel, timer, target_trap (-1), spooked, active}
var creatures: Array = []
## Each trap: {pos, state, creature (-1), timer}
var traps: Array = []
## Captured monsters waiting for the player's choice.
var captures: Array = []
var traps_left: int = 0
var chosen: Monster
var is_finished: bool = false


func _init(cfg: AssessmentConfig = null, seed_value: int = -1, species_catalog: SpeciesCatalog = null) -> void:
	config = cfg if cfg else AssessmentConfig.new()
	rng = RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	catalog = species_catalog if species_catalog else SpeciesCatalog.get_default()


func start() -> void:
	creatures.clear()
	traps.clear()
	captures.clear()
	chosen = null
	is_finished = false
	traps_left = config.trap_count
	for i in config.creature_count:
		spawn_creature()


## GDD rank odds (config.rank_weights). Static so it can be tested alone.
static func roll_rank(weights: Dictionary, r: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += maxf(float(weights[k]), 0.0)
	if total <= 0.0:
		return "D"
	var x := r.randf() * total
	var last := "D"
	for k in StatLetterBands.LETTERS:
		if not weights.has(k):
			continue
		last = k
		x -= maxf(float(weights[k]), 0.0)
		if x < 0.0:
			return k
	return last


func pick_species() -> SpeciesData:
	var pool := catalog.get_wild_in_biome(config.biome)
	if pool.is_empty():
		return null
	var total := 0.0
	for s in pool:
		total += float(config.species_weights.get(String(s.id), config.species_weights.get(s.id, 1.0)))
	var x := rng.randf() * total
	for s in pool:
		x -= float(config.species_weights.get(String(s.id), config.species_weights.get(s.id, 1.0)))
		if x < 0.0:
			return s
	return pool[pool.size() - 1]


## Adds a wandering creature with a rank rolled from the GDD odds.
func spawn_creature() -> int:
	var species := pick_species()
	if species == null:
		return -1
	var m := MonsterFactory.create(species, roll_rank(config.rank_weights, rng), rng)
	m.origin_biome = config.biome
	var r := config.room_rect
	creatures.append({
		"monster": m,
		"pos": Vector2(rng.randf_range(r.position.x + 8, r.end.x - 8), rng.randf_range(r.position.y + 8, r.end.y - 8)),
		"vel": Vector2.ZERO, "timer": 0.0, "target_trap": -1, "spooked": 0.0, "active": true,
	})
	creature_spawned.emit(creatures.size() - 1)
	return creatures.size() - 1


func get_active_creatures() -> Array:
	return creatures.filter(func(c): return c.active)


func can_place_trap(pos: Vector2) -> bool:
	if is_finished or traps_left <= 0 or not config.room_rect.has_point(pos):
		return false
	for t in traps:
		if t.state != TrapState.FAILED and t.pos.distance_to(pos) < config.min_trap_spacing:
			return false
	return true


## Sets a baited trap at `pos`. Returns its index or -1.
func place_trap(pos: Vector2) -> int:
	if not can_place_trap(pos):
		return -1
	traps_left -= 1
	traps.append({"pos": pos, "state": TrapState.SET, "creature": -1, "timer": 0.0})
	trap_placed.emit(traps.size() - 1)
	return traps.size() - 1


## Traps still working (set, luring, shaking).
func pending_traps() -> int:
	var n := 0
	for t in traps:
		if t.state == TrapState.SET or t.state == TrapState.LURING or t.state == TrapState.SHAKING:
			n += 1
	return n


## GDD: after one capture the player may end and keep it; after all traps
## they choose one of the captures.
func can_choose() -> bool:
	return not is_finished and not captures.is_empty()


## True once every trap is used up and resolved.
func all_traps_used() -> bool:
	return traps_left <= 0 and pending_traps() == 0


func update(delta: float) -> void:
	if is_finished:
		return
	for i in creatures.size():
		var c: Dictionary = creatures[i]
		if not c.active:
			continue
		c.spooked = maxf(c.spooked - delta, 0.0)
		if c.target_trap >= 0:
			_move_to_trap(i, delta)
		else:
			_wander(c, delta)
	for ti in traps.size():
		var t: Dictionary = traps[ti]
		match t.state:
			TrapState.SET:
				_try_lure(ti)
			TrapState.SHAKING:
				t.timer -= delta
				if t.timer <= 0.0:
					_confirm_catch(ti)
	if config.refill_when_empty and captures.is_empty() and all_traps_used() and not traps.is_empty():
		traps_left = config.trap_count
		traps_refilled.emit()


## GDD trapping: after a catch, keep or release. Releasing returns nothing.
func release(capture_index: int) -> void:
	if capture_index >= 0 and capture_index < captures.size():
		captures.remove_at(capture_index)


## Ends the Assessment with the chosen capture. Returns it (null if invalid).
func choose(capture_index: int) -> Monster:
	if not can_choose() or capture_index < 0 or capture_index >= captures.size():
		return null
	chosen = captures[capture_index]
	is_finished = true
	finished.emit(chosen)
	return chosen


func _wander(c: Dictionary, delta: float) -> void:
	c.timer -= delta
	if c.timer <= 0.0:
		c.timer = config.wander_change_seconds * rng.randf_range(0.6, 1.4)
		if rng.randf() < config.idle_chance:
			c.vel = Vector2.ZERO
		else:
			c.vel = Vector2.RIGHT.rotated(rng.randf() * TAU) * config.creature_speed
	var p: Vector2 = c.pos + c.vel * delta
	var r := config.room_rect.grow(-6.0)
	if p.x < r.position.x or p.x > r.end.x:
		c.vel.x = -c.vel.x
	if p.y < r.position.y or p.y > r.end.y:
		c.vel.y = -c.vel.y
	c.pos = p.clamp(r.position, r.end)


func _try_lure(ti: int) -> void:
	var t: Dictionary = traps[ti]
	var best := -1
	var best_d := config.lure_radius
	for i in creatures.size():
		var c: Dictionary = creatures[i]
		if not c.active or c.target_trap >= 0 or c.spooked > 0.0:
			continue
		var d: float = c.pos.distance_to(t.pos)
		if d <= best_d:
			best_d = d
			best = i
	if best >= 0:
		t.state = TrapState.LURING
		t.creature = best
		creatures[best].target_trap = ti


func _move_to_trap(ci: int, delta: float) -> void:
	var c: Dictionary = creatures[ci]
	var t: Dictionary = traps[c.target_trap]
	var to: Vector2 = t.pos - c.pos
	var step := config.lure_speed * delta
	if to.length() > step:
		c.pos += to.normalized() * step
		return
	c.pos = t.pos
	var ti: int = c.target_trap
	c.target_trap = -1
	if rng.randf() < config.catch_chance:
		c.active = false
		t.state = TrapState.SHAKING
		t.timer = config.shake_seconds
		trap_shaking.emit(ti)
	else:
		# GDD: the trap is knocked over and the bait is gone.
		t.state = TrapState.FAILED
		t.creature = -1
		c.spooked = config.spooked_seconds
		c.vel = Vector2.RIGHT.rotated(rng.randf() * TAU) * config.creature_speed * 2.0
		c.timer = config.wander_change_seconds
		trap_failed.emit(ti)


func _confirm_catch(ti: int) -> void:
	var t: Dictionary = traps[ti]
	t.state = TrapState.CAUGHT
	var m: Monster = creatures[t.creature].monster
	captures.append(m)
	trap_caught.emit(ti, m)
