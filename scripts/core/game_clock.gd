class_name GameClock
extends Node
## Continuous game clock. Registered as the autoload "Clock".
##
## Time advances smoothly every frame from _process(delta) (not tick-stepped).
## time_minutes counts minutes since 00:00 of the current game day's date and
## keeps growing past midnight (1440 = 00:00, 1560 = 02:00) because the game
## day lasts from wake_hour until the player sleeps or passes out.
##
## Flow: wake -> ... -> midnight_reached (is_tired = true) -> pass_out_reached
## at pass_out_hour -> forced sleep(true). Voluntary sleep() can happen any time.
## sleep() emits sleep_started, waits config.sleep_transition_seconds (fade),
## then emits day_ended and starts the next day at wake_hour (day_started).

enum Season { SPRING, SUMMER, FALL, WINTER }
enum Phase { DAWN, DAY, DUSK, NIGHT }

const MINUTES_PER_HOUR := 60.0
const MINUTES_PER_DAY := 1440.0
const SEASON_COUNT := 4
const CONFIG_PATH := "res://resources/clock_config.tres"
const CLIMATE_PATH := "res://resources/climate_config.tres"
const PASS_OUT_CONFIG_PATH := "res://resources/pass_out_config.tres"

## Emitted when the whole in-game minute changes (at most once per frame).
signal minute_changed(minute_of_day: int)
## Emitted for every whole hour crossed (0..23 clock hour).
signal hour_changed(hour: int)
signal phase_changed(phase: Phase)
signal day_started(day: int)
signal season_changed(season: Season, year: int)
## Fired once per game day when midnight_hour is reached; is_tired becomes true.
signal midnight_reached
## Fired once when pass_out_hour is reached; a forced sleep(true) follows.
signal pass_out_reached
signal sleep_started(pass_out: bool)
signal day_ended(day: int, pass_out: bool)
signal paused_changed(paused: bool)

var config: ClockConfig
## Placeholder (unused) climate data, see ClimateConfig.
var climate: ClimateConfig
## Pass-out penalties (open design question). Clock applies wake_hour_delay;
## the PlayerState autoload applies the rest.
var pass_out_config: PassOutConfig

## Current game day, 1-based, counted from the start of the save.
var day: int = 1
## Minutes since 00:00 of the game day's date (exceeds 1440 after midnight).
var time_minutes: float = 360.0
var season: Season = Season.SPRING
var year: int = 1
var phase: Phase = Phase.DAY
var is_tired: bool = false
var is_sleeping: bool = false
## True if the last day ended by passing out rather than sleeping.
var last_sleep_was_pass_out: bool = false
## Mirrors config.time_scale at start; change at runtime (debug keys).
var time_scale: float = 1.0

var _midnight_fired := false
var _pass_out_fired := false
var _pause_reasons: Dictionary = {}
var _last_minute: int = -1
var _last_hour: int = -1


func _init() -> void:
	config = _load_or_default(CONFIG_PATH, ClockConfig) as ClockConfig
	climate = _load_or_default(CLIMATE_PATH, ClimateConfig) as ClimateConfig
	pass_out_config = _load_or_default(PASS_OUT_CONFIG_PATH, PassOutConfig) as PassOutConfig
	_on_config_loaded()
	_reset_to_day(1)


func _process(delta: float) -> void:
	if is_paused() or is_sleeping:
		return
	advance_minutes(delta * get_minutes_per_real_second())


# --- Public API -------------------------------------------------------------

## Starts a fresh game on day 1 at wake time and emits day_started(1).
func start_new_game() -> void:
	_pause_reasons.clear()
	_reset_to_day(1)
	season_changed.emit(season, year)
	phase_changed.emit(phase)
	day_started.emit(day)


## Game minutes that pass per real second at the current time_scale.
func get_minutes_per_real_second() -> float:
	return MINUTES_PER_HOUR / maxf(config.real_seconds_per_game_hour, 0.001) * time_scale


## Advances the clock by game minutes, firing all threshold signals in order.
## Used by _process; also handy for tests and debug tools.
func advance_minutes(minutes: float) -> void:
	if minutes <= 0.0 or is_sleeping:
		return
	var pass_out_min := config.pass_out_hour * MINUTES_PER_HOUR
	_set_time(minf(time_minutes + minutes, maxf(pass_out_min, time_minutes)))
	if not _pass_out_fired and time_minutes >= pass_out_min:
		_pass_out_fired = true
		pass_out_reached.emit()
		sleep(true)


## Ends the current day. pass_out = true for the forced 2 AM sleep.
## Rolls over after config.sleep_transition_seconds (0 = immediately).
func sleep(pass_out: bool = false) -> void:
	if is_sleeping:
		return
	is_sleeping = true
	sleep_started.emit(pass_out)
	var wait := config.sleep_transition_seconds
	if wait > 0.0 and is_inside_tree():
		await get_tree().create_timer(wait).timeout
	_finish_sleep(pass_out)


func pause(reason: StringName = &"default") -> void:
	var was_paused := is_paused()
	_pause_reasons[reason] = int(_pause_reasons.get(reason, 0)) + 1
	if not was_paused:
		paused_changed.emit(true)


func resume(reason: StringName = &"default") -> void:
	if not _pause_reasons.has(reason):
		return
	_pause_reasons[reason] = int(_pause_reasons[reason]) - 1
	if int(_pause_reasons[reason]) <= 0:
		_pause_reasons.erase(reason)
	if not is_paused():
		paused_changed.emit(false)


func is_paused() -> bool:
	return not _pause_reasons.is_empty()


func get_pause_reasons() -> Array:
	return _pause_reasons.keys()


## Clock hour 0..23 (wraps after midnight).
func get_hour() -> int:
	return int(floor(time_minutes / MINUTES_PER_HOUR)) % 24


## Clock minute 0..59.
func get_minute() -> int:
	return int(floor(time_minutes)) % 60


## Extended hours since the date's 00:00 (e.g. 25.5 = 01:30 after midnight).
func get_hours_float() -> float:
	return time_minutes / MINUTES_PER_HOUR


## 1-based day within the current season.
func get_day_of_season() -> int:
	return ((day - 1) % maxi(config.days_per_season, 1)) + 1


func get_season_name(s: int = season) -> String:
	return Season.keys()[s]


func get_phase_name(p: int = phase) -> String:
	return Phase.keys()[p]


## "6:30 AM" or "06:30". Pass true/false to override config.use_24h.
func get_time_string(use_24h = null) -> String:
	var h24: bool = config.use_24h if use_24h == null else bool(use_24h)
	var total := int(floor(time_minutes)) % int(MINUTES_PER_DAY)
	var step := maxi(config.display_minute_step, 1)
	total -= total % step
	var h := total / 60
	var m := total % 60
	if h24:
		return "%02d:%02d" % [h, m]
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


## 0 (full daylight) .. config.night_darkness (night). Smooth ramps at dawn/dusk.
func get_darkness() -> float:
	var h := fmod(get_hours_float(), 24.0)
	var c := config
	match _phase_for_hour(h):
		Phase.DAWN:
			return lerpf(c.night_darkness, 0.0, _ratio(h, c.dawn_start_hour, c.day_start_hour))
		Phase.DUSK:
			return lerpf(0.0, c.night_darkness, _ratio(h, c.dusk_start_hour, c.night_start_hour))
		Phase.NIGHT:
			return c.night_darkness
	return 0.0


## Placeholder climate lookup (unused; climate is an open design question).
func get_climate() -> Dictionary:
	return climate.get_for_season(get_season_name()) if climate else {}


func to_dict() -> Dictionary:
	return {
		"day": day,
		"time_minutes": time_minutes,
		"is_tired": is_tired,
		"midnight_fired": _midnight_fired,
		"pass_out_fired": _pass_out_fired,
		"time_scale": time_scale,
		"last_sleep_was_pass_out": last_sleep_was_pass_out,
	}


## Restores state saved by to_dict(). Does not emit day/season signals.
func from_dict(data: Dictionary) -> void:
	day = maxi(int(data.get("day", 1)), 1)
	time_minutes = float(data.get("time_minutes", config.wake_hour * MINUTES_PER_HOUR))
	is_tired = bool(data.get("is_tired", false))
	_midnight_fired = bool(data.get("midnight_fired", is_tired))
	_pass_out_fired = bool(data.get("pass_out_fired", false))
	time_scale = float(data.get("time_scale", config.time_scale))
	last_sleep_was_pass_out = bool(data.get("last_sleep_was_pass_out", false))
	is_sleeping = false
	_update_calendar()
	phase = _phase_for_hour(fmod(get_hours_float(), 24.0))
	_sync_last_marks()


# --- Internals --------------------------------------------------------------

## Re-applies config-derived state; call after swapping `config` at runtime.
func _on_config_loaded() -> void:
	time_scale = config.time_scale


func _reset_to_day(new_day: int) -> void:
	day = new_day
	time_minutes = config.wake_hour * MINUTES_PER_HOUR
	is_tired = false
	is_sleeping = false
	_midnight_fired = false
	_pass_out_fired = false
	_update_calendar()
	phase = _phase_for_hour(fmod(get_hours_float(), 24.0))
	_sync_last_marks()


func _finish_sleep(pass_out: bool) -> void:
	last_sleep_was_pass_out = pass_out
	day_ended.emit(day, pass_out)
	var old_season := season
	var old_year := year
	var old_phase := phase
	_reset_to_day(day + 1)
	time_minutes += _get_wake_delay_minutes(pass_out)
	phase = _phase_for_hour(fmod(get_hours_float(), 24.0))
	_sync_last_marks()
	if phase != old_phase:
		phase_changed.emit(phase)
	if season != old_season or year != old_year:
		season_changed.emit(season, year)
	day_started.emit(day)


## Extra minutes added to wake time: PassOutConfig.wake_hour_delay after a
## pass-out (placeholder, default 0), none after normal sleep.
func _get_wake_delay_minutes(pass_out: bool) -> float:
	if pass_out and pass_out_config:
		return maxf(pass_out_config.wake_hour_delay, 0.0) * MINUTES_PER_HOUR
	return 0.0


func _set_time(new_minutes: float) -> void:
	time_minutes = new_minutes
	var hour_index := int(floor(time_minutes / MINUTES_PER_HOUR))
	while _last_hour < hour_index:
		_last_hour += 1
		hour_changed.emit(_last_hour % 24)
	var minute_index := int(floor(time_minutes))
	if minute_index != _last_minute:
		_last_minute = minute_index
		minute_changed.emit(minute_index % int(MINUTES_PER_DAY))
	if not _midnight_fired and time_minutes >= config.midnight_hour * MINUTES_PER_HOUR:
		_midnight_fired = true
		is_tired = true
		midnight_reached.emit()
	var new_phase := _phase_for_hour(fmod(get_hours_float(), 24.0))
	if new_phase != phase:
		phase = new_phase
		phase_changed.emit(phase)


func _sync_last_marks() -> void:
	_last_minute = int(floor(time_minutes))
	_last_hour = int(floor(time_minutes / MINUTES_PER_HOUR))


func _update_calendar() -> void:
	var dps := maxi(config.days_per_season, 1)
	var season_index := (day - 1) / dps
	season = (season_index % SEASON_COUNT) as Season
	year = season_index / SEASON_COUNT + 1


func _phase_for_hour(h: float) -> Phase:
	var c := config
	if h >= c.night_start_hour or h < c.dawn_start_hour:
		return Phase.NIGHT
	if h >= c.dusk_start_hour:
		return Phase.DUSK
	if h >= c.day_start_hour:
		return Phase.DAY
	return Phase.DAWN


static func _ratio(v: float, a: float, b: float) -> float:
	return clampf((v - a) / maxf(b - a, 0.0001), 0.0, 1.0)


static func _load_or_default(path: String, type: Variant) -> Resource:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res != null:
			return res
	return type.new()
