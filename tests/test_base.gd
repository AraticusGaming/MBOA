class_name MboaTestBase
extends SceneTree
## Minimal headless test harness. Subclasses implement _run_tests() and call
## check(). Run: godot --headless --path . --script res://tests/<name>.gd

var _passed := 0
var _failed := 0
var _suite := "tests"


func _initialize() -> void:
	_suite = get_script().resource_path.get_file().get_basename()
	print("== %s ==" % _suite)
	await _run_tests()
	print("%s: %d passed, %d failed" % [_suite, _passed, _failed])
	quit(1 if _failed > 0 else 0)


## Override in subclasses (may use await).
func _run_tests() -> void:
	pass


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + label)
	else:
		_failed += 1
		printerr("  FAIL  " + label)


func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, "%s (got %s, expected %s)" % [label, str(actual), str(expected)])


## A fresh, isolated GameClock (not the autoload) with instant sleep rollover.
func make_clock() -> GameClock:
	var clock := GameClock.new()
	clock.config = clock.config.duplicate()
	clock.config.sleep_transition_seconds = 0.0
	clock._on_config_loaded()
	clock._reset_to_day(1)
	clock.set_process(false)
	root.add_child(clock)
	return clock
