class_name StatLetterBands
extends Resource
## Maps a monster stat value to its letter (GDD "Stats and rank": each stat
## has its own range and its own letter, S at the top, D at the bottom).
## One resource per stat range; the monster resource (Milestone 2+) will point
## each stat at the bands for its range.
##
## resources/stats/stat_letters_1_20.tres follows docs/DECISIONS.md
## (2026-11-01): D 1-4, C 5-9, B 10-14, A 15-17, S 18-20. (The GDD text said
## D was 1-5; the ruling wins.) Bands for other ranges (e.g. 1-25) are not
## decided yet.

## Letters from lowest to highest.
const LETTERS: PackedStringArray = ["D", "C", "B", "A", "S"]

## Lowest valid stat value for this range.
@export var stat_min: int = 1
## Highest value of each band, in LETTERS order (D, C, B, A, S). The last
## entry is the top of the range.
@export var band_max: PackedInt32Array = PackedInt32Array([4, 9, 14, 17, 20])


func get_stat_max() -> int:
	return band_max[band_max.size() - 1] if not band_max.is_empty() else stat_min


func is_valid_value(value: int) -> bool:
	return value >= stat_min and value <= get_stat_max()


## Letter for `value` ("D".."S"), or "" if the value is outside the range.
func get_letter(value: int) -> String:
	if not is_valid_value(value):
		return ""
	for i in mini(band_max.size(), LETTERS.size()):
		if value <= band_max[i]:
			return LETTERS[i]
	return ""


## Inclusive [min, max] stat values for `letter` (Vector2i(-1, -1) if unknown).
func get_band(letter: String) -> Vector2i:
	var i := LETTERS.find(letter.to_upper())
	if i < 0 or i >= band_max.size():
		return Vector2i(-1, -1)
	var lo := stat_min if i == 0 else band_max[i - 1] + 1
	return Vector2i(lo, band_max[i])


## True if the bands are contiguous, ascending and cover all five letters.
func is_valid() -> bool:
	if band_max.size() != LETTERS.size() or band_max[0] < stat_min:
		return false
	for i in range(1, band_max.size()):
		if band_max[i] <= band_max[i - 1]:
			return false
	return true


## Letter index (D = 0 ... S = 4), -1 if unknown.
static func letter_index(letter: String) -> int:
	return LETTERS.find(letter.to_upper())


## GDD: "The monster's overall rank is the average of its stat letters,
## rounded down." Letters are averaged by index (D = 0 ... S = 4), which
## reproduces all three GDD examples (3D+2C = D, 2D+C+2B = C, S+4B = B).
static func overall_rank(letters: Array) -> String:
	var total := 0
	var count := 0
	for l in letters:
		var i := letter_index(String(l))
		if i >= 0:
			total += i
			count += 1
	return LETTERS[total / count] if count > 0 else ""
