extends Node
## Autoload "SaveManager": versioned save data for the Clock, PlayerState and
## the farm (plots, crops and trees - trees are stored on their plot), written
## as JSON to user://. GDD technical requirement: saving across seasons.
##
## Save layout (SAVE_VERSION 1):
##   {"version": 1, "clock": {...}, "player_state": {...}, "farm": {...}}
## farm.plots[i].tree holds the tree on that cell (or null).
##
## The game autosaves at the start of each day (after the farm has grown and
## the player has woken in bed). Loading is manual for now (F9 in debug builds)
## until there is a title / continue menu.

signal saved(path: String)
signal loaded(path: String)

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://save_slot_0.json"

## Save to DEFAULT_PATH whenever a new day starts.
var autosave_on_new_day: bool = true
var clock: GameClock
var player_state: Node


func _ready() -> void:
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	if player_state == null:
		player_state = get_node_or_null("/root/PlayerState")
	if clock:
		clock.day_started.connect(_on_day_started)


# --- Pure data (used by tests and by the file helpers) ----------------------

## Builds the save dictionary. Any argument may be null (its key is omitted).
func build_save_data(c: GameClock, ps: Node, grid: FarmGrid) -> Dictionary:
	var data := {"version": SAVE_VERSION}
	if c:
		data["clock"] = c.to_dict()
	if ps:
		data["player_state"] = ps.to_dict()
	if grid:
		data["farm"] = grid.to_dict()
	return data


## Applies save data to the given objects. Returns false (and changes nothing)
## if the data is missing a version or comes from a newer game version.
func apply_save_data(data: Dictionary, c: GameClock, ps: Node, grid: FarmGrid) -> bool:
	var migrated := migrate(data)
	if migrated.is_empty():
		return false
	if c and migrated.has("clock"):
		c.from_dict(migrated["clock"])
	if ps and migrated.has("player_state"):
		ps.from_dict(migrated["player_state"])
	if grid and migrated.has("farm"):
		grid.from_dict(migrated["farm"])
	return true


## Upgrades older save layouts to SAVE_VERSION. Returns {} if unusable.
func migrate(data: Dictionary) -> Dictionary:
	if not data.has("version"):
		push_warning("SaveManager: save has no version")
		return {}
	var version := int(data["version"])
	if version > SAVE_VERSION:
		push_warning("SaveManager: save version %d is newer than %d" % [version, SAVE_VERSION])
		return {}
	var out := data.duplicate(true)
	# (Future: `if version < 2: ...` steps go here.)
	out["version"] = SAVE_VERSION
	return out


# --- Files ------------------------------------------------------------------

func write_file(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: can't write %s (%s)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


## Returns the parsed save, or {} if the file is missing or invalid.
func read_file(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


## Saves the running game (autoloads + the farm grid in group "farm_grid").
func save_game(path: String = DEFAULT_PATH) -> bool:
	var ok := write_file(build_save_data(clock, player_state, _find_grid()), path)
	if ok:
		saved.emit(path)
	return ok


## Loads into the running game and puts the player at the bed's wake spot.
func load_game(path: String = DEFAULT_PATH) -> bool:
	var data := read_file(path)
	if data.is_empty() or not apply_save_data(data, clock, player_state, _find_grid()):
		return false
	if is_inside_tree():
		var bed := get_tree().get_first_node_in_group(&"bed")
		if bed and bed.has_method(&"wake_player"):
			bed.wake_player(get_tree().get_first_node_in_group(&"player"))
	loaded.emit(path)
	return true


func _find_grid() -> FarmGrid:
	return get_tree().get_first_node_in_group(&"farm_grid") as FarmGrid if is_inside_tree() else null


func _on_day_started(_day: int) -> void:
	if autosave_on_new_day:
		# Deferred so the farm (also on day_started) has grown first.
		_autosave.call_deferred()


func _autosave() -> void:
	if _find_grid() != null:
		save_game()
