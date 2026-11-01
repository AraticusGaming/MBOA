extends MboaTestBase
## Clock tests: continuity, midnight/tired, 2 AM pass-out rollover, seasons,
## phases, pause reasons, time strings and save/load.


func _run_tests() -> void:
	_test_initial_state()
	_test_continuous_process()
	_test_midnight_once()
	_test_pass_out_rollover()
	_test_voluntary_sleep()
	_test_season_rollover()
	_test_phases_and_darkness()
	_test_pause_reasons()
	_test_time_strings()
	_test_save_load()


func _test_initial_state() -> void:
	var c := make_clock()
	check_eq(c.day, 1, "starts on day 1")
	check_eq(c.time_minutes, c.config.wake_hour * 60.0, "starts at wake hour")
	check_eq(c.season, GameClock.Season.SPRING, "starts in spring")
	check(not c.is_tired, "not tired at start")
	var cfg := load("res://resources/clock_config.tres") as ClockConfig
	check_eq(cfg.wake_hour, 6.0, "ruling: wake at 6:00 AM")
	check_eq(cfg.days_per_season, 30, "ruling: 30 days per season")
	check_eq(cfg.real_seconds_per_game_hour, 60.0, "ruling: 60 real seconds per game hour")
	check_eq(c.get_minutes_per_real_second(), 1.0, "1 game minute per real second at x1")
	for i in 29:
		c.sleep()
	check_eq(c.day, 30, "day 30")
	check_eq(c.season, GameClock.Season.SPRING, "day 30 is still spring")
	c.sleep()
	check_eq(c.season, GameClock.Season.SUMMER, "day 31 is summer")
	c.free()


func _test_continuous_process() -> void:
	var c := make_clock()
	var start := c.time_minutes
	var per_sec := c.get_minutes_per_real_second()
	for i in 10:
		c._process(0.016)
	check(absf(c.time_minutes - (start + per_sec * 0.16)) < 0.0001,
		"_process advances time continuously by delta")
	check(c.time_minutes != floor(c.time_minutes), "time is fractional (not tick-stepped)")
	c.time_scale = 10.0
	var t := c.time_minutes
	c._process(1.0)
	check(absf(c.time_minutes - t - per_sec * 10.0) < 0.0001, "time_scale multiplies speed")
	c.free()


func _test_midnight_once() -> void:
	var c := make_clock()
	var count := [0]
	c.midnight_reached.connect(func(): count[0] += 1)
	c.advance_minutes((24.0 - c.config.wake_hour) * 60.0 - 1.0)  # 23:59
	check_eq(count[0], 0, "midnight not fired at 23:59")
	check(not c.is_tired, "not tired at 23:59")
	c.advance_minutes(1.0)
	check_eq(count[0], 1, "midnight_reached fires at 24:00")
	check(c.is_tired, "is_tired true at midnight")
	check_eq(c.day, 1, "still the same game day after midnight")
	check_eq(c.get_time_string(true), "00:00", "clock shows 00:00")
	c.advance_minutes(30.0)
	check_eq(count[0], 1, "midnight_reached fires only once")
	c.free()


func _test_pass_out_rollover() -> void:
	var c := make_clock()
	var events: Array = []
	c.pass_out_reached.connect(func(): events.append("pass_out"))
	c.sleep_started.connect(func(p): events.append("sleep_started:%s" % p))
	c.day_ended.connect(func(d, p): events.append("day_ended:%d:%s" % [d, p]))
	c.day_started.connect(func(d): events.append("day_started:%d" % d))
	c.advance_minutes((26.0 - c.config.wake_hour) * 60.0 - 1.0)  # 01:59
	check(events.is_empty(), "nothing at 01:59")
	check_eq(c.day, 1, "day 1 at 01:59")
	c.advance_minutes(5.0)
	check_eq(events, ["pass_out", "sleep_started:true", "day_ended:1:true", "day_started:2"],
		"2 AM: pass_out -> sleep(true) -> day_ended -> day_started in order")
	check_eq(c.day, 2, "rolled over to day 2")
	check_eq(c.time_minutes, c.config.wake_hour * 60.0, "wakes at wake_hour")
	check(not c.is_tired, "tired cleared after sleeping")
	check(not c.is_sleeping, "no longer sleeping")
	# One huge frame must still fire midnight then pass-out exactly once each.
	var mid := [0]
	var po := [0]
	c.midnight_reached.connect(func(): mid[0] += 1)
	c.pass_out_reached.connect(func(): po[0] += 1)
	c.advance_minutes(10000.0)
	check(mid[0] == 1 and po[0] == 1 and c.day == 3, "huge step fires midnight+pass_out once, day 3")
	c.free()


func _test_voluntary_sleep() -> void:
	var c := make_clock()
	var flags: Array = []
	c.day_ended.connect(func(_d, p): flags.append(p))
	c.advance_minutes(14.0 * 60.0)  # 20:00
	c.sleep()
	check_eq(flags, [false], "voluntary sleep emits day_ended(pass_out=false)")
	check_eq(c.day, 2, "voluntary sleep rolls to next day")
	check_eq(c.get_time_string(true), "06:00", "wakes at 06:00")
	c.free()


func _test_season_rollover() -> void:
	var c := make_clock()
	c.config.days_per_season = 3
	c._update_calendar()
	var seasons: Array = []
	c.season_changed.connect(func(s, y): seasons.append([s, y]))
	for i in 2:
		c.sleep()
	check_eq(c.day, 3, "day 3")
	check_eq(c.season, GameClock.Season.SPRING, "still spring on day 3 (3 days/season)")
	check(seasons.is_empty(), "no season_changed yet")
	c.sleep()
	check_eq(c.season, GameClock.Season.SUMMER, "summer on day 4")
	check_eq(c.get_day_of_season(), 1, "day_of_season resets to 1")
	check_eq(seasons, [[GameClock.Season.SUMMER, 1]], "season_changed(SUMMER, 1) emitted once")
	for i in 9:
		c.sleep()
	check_eq(c.day, 13, "day 13")
	check_eq(c.season, GameClock.Season.SPRING, "back to spring after winter")
	check_eq(c.year, 2, "year 2")
	check_eq(seasons.size(), 4, "4 season changes total")
	c.free()


func _test_phases_and_darkness() -> void:
	var c := make_clock()
	check_eq(c.phase, GameClock.Phase.DAWN, "06:00 is dawn (placeholder boundaries)")
	var phases: Array = []
	c.phase_changed.connect(func(p): phases.append(p))
	c.advance_minutes(60.0)
	check_eq(c.phase, GameClock.Phase.DAY, "07:00 is day")
	check_eq(c.get_darkness(), 0.0, "no darkness during day")
	c.advance_minutes(11.0 * 60.0 + 60.0)  # 19:00
	check_eq(c.phase, GameClock.Phase.DUSK, "19:00 is dusk")
	var d := c.get_darkness()
	check(d > 0.0 and d < c.config.night_darkness, "dusk darkness ramps (%f)" % d)
	c.advance_minutes(60.0)
	check_eq(c.phase, GameClock.Phase.NIGHT, "20:00 is night")
	check_eq(c.get_darkness(), c.config.night_darkness, "full night darkness")
	c.advance_minutes(300.0)  # 01:00 next morning
	check_eq(c.phase, GameClock.Phase.NIGHT, "01:00 still night")
	check_eq(phases, [GameClock.Phase.DAY, GameClock.Phase.DUSK, GameClock.Phase.NIGHT],
		"phase_changed sequence")
	c.free()


func _test_pause_reasons() -> void:
	var c := make_clock()
	var t := c.time_minutes
	c.pause(&"menu")
	c.pause(&"dialog")
	c._process(1.0)
	check_eq(c.time_minutes, t, "paused clock does not advance")
	c.resume(&"menu")
	check(c.is_paused(), "still paused while another reason is active")
	c.resume(&"dialog")
	check(not c.is_paused(), "resumed when all reasons released")
	c._process(1.0)
	check(c.time_minutes > t, "advances after resume")
	c.free()


func _test_time_strings() -> void:
	var c := make_clock()
	check_eq(c.get_time_string(false), "6:00 AM", "12h format")
	c.advance_minutes(7.0 * 60.0 + 37.0)  # 13:37 -> step 10 -> 13:30
	check_eq(c.get_time_string(true), "13:30", "24h format with 10-min display step")
	check_eq(c.get_time_string(false), "1:30 PM", "12h PM")
	c.advance_minutes(11.0 * 60.0)  # 00:37 next morning
	check_eq(c.get_time_string(false), "12:30 AM", "after midnight shows 12:30 AM")
	c.free()


func _test_save_load() -> void:
	var c := make_clock()
	c.config.days_per_season = 5
	for i in 6:
		c.sleep()
	c.advance_minutes(18.0 * 60.0 + 12.5)  # past midnight -> tired
	var data := c.to_dict()
	var json := JSON.stringify(data)
	var c2 := make_clock()
	c2.config.days_per_season = 5
	c2.from_dict(JSON.parse_string(json))
	check_eq(c2.day, c.day, "load: day")
	check(absf(c2.time_minutes - c.time_minutes) < 0.0001, "load: time_minutes")
	check_eq(c2.season, GameClock.Season.SUMMER, "load: season derived (day 7, 5/season)")
	check_eq(c2.is_tired, true, "load: tired flag")
	check_eq(c2.phase, c.phase, "load: phase")
	var mid := [0]
	c2.midnight_reached.connect(func(): mid[0] += 1)
	c2.advance_minutes(1.0)
	check_eq(mid[0], 0, "load: midnight not re-fired")
	c.free()
	c2.free()
