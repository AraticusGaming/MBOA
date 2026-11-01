class_name CropData
extends Resource
## Data definition for one crop type. One .tres per crop in res://resources/crops/.
##
## GDD: each crop has four growth stages and crops are tied to seasons.
## OPEN QUESTIONS (GDD): crop types, days per growth stage, season assignments.
## Not GDD, placeholder (Ledan ruling): every crop, its stage days and its
## seasons in resources/crops/*.tres are placeholders until those are decided.

## The GDD fixes four growth stages; the 4th is harvest-ready.
const STAGE_COUNT := 4

## Unique id used in plots, saves and harvested signals.
@export var id: StringName = &""
@export var display_name: String = ""
## Seasons this crop can be planted in (bit per GameClock.Season). PLACEHOLDER.
@export_flags("Spring", "Summer", "Fall", "Winter") var seasons: int = 0b1111
## Watered days spent in stages 1-3 before reaching stage 4 (harvest-ready).
## Size must be STAGE_COUNT - 1. PLACEHOLDER (GDD open question).
@export var stage_days: PackedInt32Array = PackedInt32Array([1, 1, 1])
## Item put in the inventory on harvest (&"" = the item with the crop's id).
@export var harvest_item_id: StringName = &""
## Items per harvest. Not GDD, placeholder.
@export_range(1, 20) var harvest_amount: int = 1
## Placeholder draw color of the mature crop when there is no sprite sheet.
@export var placeholder_color: Color = Color(0.9, 0.75, 0.2)

@export_group("Sprite")
## Stage sheet for this crop (e.g. assets/sprites/crop_basic.png). null = draw
## a placeholder rectangle in placeholder_color instead.
@export var sprite_sheet: Texture2D
## Size of one frame in the sheet; frames are indexed row-major.
@export var frame_size: Vector2i = Vector2i(16, 16)
## Sheet frame for each of the four stages. crop_basic.png: [0 seed,
## 1 sprout, 2 leafy, 3 harvest-ready].
@export var stage_frames: PackedInt32Array = PackedInt32Array([0, 1, 2, 3])
## Modulate applied to the sheet so placeholder crops sharing crop_basic.png
## look different (white = unchanged).
@export var sprite_tint: Color = Color.WHITE


func get_harvest_item_id() -> StringName:
	return harvest_item_id if harvest_item_id != &"" else id


## Total watered days from planting to harvest-ready.
func get_days_to_mature() -> int:
	var total := 0
	for d in stage_days:
		total += maxi(d, 0)
	return maxi(total, 1)


## Growth stage 0..3 (0 = just planted, 3 = harvest-ready) for growth_days.
func get_stage(growth_days: int) -> int:
	var acc := 0
	for i in mini(stage_days.size(), STAGE_COUNT - 1):
		acc += maxi(stage_days[i], 0)
		if growth_days < acc:
			return i
	return STAGE_COUNT - 1


func is_mature(growth_days: int) -> bool:
	return growth_days >= get_days_to_mature()


## True if the crop can be planted in `season` (GameClock.Season value).
func grows_in(season: int) -> bool:
	return (seasons & (1 << season)) != 0


## Season names this crop grows in, e.g. ["Spring", "Fall"].
func get_season_names() -> PackedStringArray:
	var names := PackedStringArray()
	var all := ["Spring", "Summer", "Fall", "Winter"]
	for i in all.size():
		if grows_in(i):
			names.append(all[i])
	return names


## Sheet frame for a crop that has grown `growth_days` watered days.
func get_frame_for_growth(growth_days: int) -> int:
	var stage := get_stage(growth_days)
	return stage_frames[stage] if stage < stage_frames.size() else stage


## Pixel region of `frame` inside sprite_sheet (empty Rect2 if no sheet).
func get_frame_region(frame: int) -> Rect2:
	if sprite_sheet == null or frame_size.x <= 0 or frame_size.y <= 0:
		return Rect2()
	var columns := maxi(int(sprite_sheet.get_width()) / frame_size.x, 1)
	return Rect2(Vector2((frame % columns) * frame_size.x, (frame / columns) * frame_size.y),
		Vector2(frame_size))
