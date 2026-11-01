extends MboaTestBase
## Stat letter tests: docs/DECISIONS.md bands for 1-20 stats and the GDD
## overall-rank rule.

const BANDS_PATH := "res://resources/stats/stat_letters_1_20.tres"


func _run_tests() -> void:
	var bands := load(BANDS_PATH) as StatLetterBands
	check(bands != null, "stat_letters_1_20.tres loads")
	if bands == null:
		return
	check(bands.is_valid(), "bands are contiguous and cover D..S")
	check(bands.stat_min == 1 and bands.get_stat_max() == 20, "range 1-20")
	var expected := {"D": Vector2i(1, 4), "C": Vector2i(5, 9), "B": Vector2i(10, 14),
		"A": Vector2i(15, 17), "S": Vector2i(18, 20)}
	for letter in expected:
		check_eq(bands.get_band(letter), expected[letter], "ruling band %s" % letter)
	var letters := ""
	for v in range(1, 21):
		letters += bands.get_letter(v)
	check_eq(letters, "DDDDCCCCCBBBBBAAASSS", "every value 1-20 maps to its letter")
	check(bands.get_letter(0) == "" and bands.get_letter(21) == "", "out of range -> empty")
	check_eq(bands.get_band("x"), Vector2i(-1, -1), "unknown letter")
	check_eq(bands.get_band("s"), Vector2i(18, 20), "letter lookup is case-insensitive")
	# GDD overall-rank examples.
	check_eq(StatLetterBands.overall_rank(["D", "D", "D", "C", "C"]), "D", "3 D + 2 C = D")
	check_eq(StatLetterBands.overall_rank(["D", "D", "C", "B", "B"]), "C", "2 D + C + 2 B = C")
	check_eq(StatLetterBands.overall_rank(["S", "B", "B", "B", "B"]), "B", "S + 4 B = B")
	check_eq(StatLetterBands.overall_rank(["S", "S", "S", "S", "S"]), "S", "all S = S")
	check_eq(StatLetterBands.overall_rank([]), "", "no letters -> empty")
	# A future 1-25 range only needs a new resource.
	var wide := StatLetterBands.new()
	wide.band_max = PackedInt32Array([5, 11, 17, 21, 25])
	check(wide.is_valid() and wide.get_letter(25) == "S" and wide.get_letter(6) == "C",
		"other ranges are data-only (values here are test data, not design)")
	var broken := StatLetterBands.new()
	broken.band_max = PackedInt32Array([4, 4, 14, 17, 20])
	check(not broken.is_valid(), "overlapping bands rejected")
