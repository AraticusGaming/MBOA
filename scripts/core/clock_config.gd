class_name ClockConfig
extends Resource
## Tunables for the GameClock autoload ("Clock").
##
## Values come from docs/DECISIONS.md (2026-11-01 ruling: wake 6:00 AM, 30 days
## per season, 60 real seconds per in-game hour) and the GDD (tired at midnight,
## pass out at 2:00 AM). Everything marked PLACEHOLDER is still undecided.
## Edit res://resources/clock_config.tres, not this script.
##
## Hours use an "extended" 0..26 scale for the game day: the day starts at
## wake_hour (e.g. 6.0) and continues past midnight (24.0 = 00:00) up to
## pass_out_hour (26.0 = 02:00 next morning), all counted as the SAME game day.

@export_group("Speed")
## Real seconds for one in-game hour at time_scale 1.0 (ruling: 60).
@export_range(0.1, 3600.0, 0.1) var real_seconds_per_game_hour: float = 60.0
## Global multiplier on clock speed (debug keys F1-F3 change it at runtime).
@export_range(0.0, 1000.0, 0.1) var time_scale: float = 1.0

@export_group("Day")
## Hour the player wakes on a new day (ruling: 6.0 = 06:00).
@export_range(0.0, 23.99, 0.25) var wake_hour: float = 6.0
## Extended hour at which the player becomes tired (24.0 = midnight).
@export_range(0.0, 30.0, 0.25) var midnight_hour: float = 24.0
## Extended hour at which the player passes out (26.0 = 02:00 next morning).
@export_range(0.0, 30.0, 0.25) var pass_out_hour: float = 26.0

@export_group("Phases")
## Phase boundaries in hours (0..24). PLACEHOLDER. Night wraps past midnight.
@export_range(0.0, 24.0, 0.25) var dawn_start_hour: float = 5.0
@export_range(0.0, 24.0, 0.25) var day_start_hour: float = 7.0
@export_range(0.0, 24.0, 0.25) var dusk_start_hour: float = 18.0
@export_range(0.0, 24.0, 0.25) var night_start_hour: float = 20.0
## Darkness reached at full night (0 = none, 1 = black). PLACEHOLDER.
@export_range(0.0, 1.0, 0.01) var night_darkness: float = 0.7

@export_group("Calendar")
## Days in each of the 4 seasons (ruling: 30).
@export_range(1, 365) var days_per_season: int = 30

@export_group("Display")
## true = "18:30", false = "6:30 PM".
@export var use_24h: bool = false
## Clock display granularity in minutes (time itself stays continuous).
@export_range(1, 60) var display_minute_step: int = 10

@export_group("Sleep")
## Real seconds between sleep_started and the day rollover (fade-out time).
## 0 = roll over immediately (used by tests).
@export_range(0.0, 10.0, 0.05) var sleep_transition_seconds: float = 0.6
