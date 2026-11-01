class_name CropData
extends Resource
## Data definition for one crop type. One .tres per crop in res://resources/crops/.
## Milestone 1 only uses placeholder values; real crops come from the GDD.

## Unique id used in plots, saves and harvested signals.
@export var id: StringName = &""
@export var display_name: String = ""
## Watered days needed to reach maturity. PLACEHOLDER per crop.
@export_range(1, 100) var days_to_mature: int = 3
## Placeholder draw color of the mature crop (until ART delivers sprites).
@export var placeholder_color: Color = Color(0.9, 0.75, 0.2)

@export_group("Sprite")
## Stage sheet for this crop (e.g. assets/sprites/crop_basic.png). null = draw
## a placeholder rectangle in placeholder_color instead.
@export var sprite_sheet: Texture2D
## Size of one frame in the sheet; frames are indexed row-major.
@export var frame_size: Vector2i = Vector2i(16, 16)
## Frames shown while growing, spread evenly over growth progress 0..<1
## (first entry = just planted / seed). crop_basic: [0 seed, 1 sprout, 2 leafy].
@export var growth_frames: PackedInt32Array = PackedInt32Array([0, 1, 2])
## Frame shown once growth_days >= days_to_mature (harvest-ready).
@export var mature_frame: int = 3


## Sheet frame for a crop that has grown `growth_days` watered days.
func get_frame_for_growth(growth_days: int) -> int:
	if growth_days >= days_to_mature or growth_frames.is_empty():
		return mature_frame
	var progress := clampf(float(growth_days) / float(maxi(days_to_mature, 1)), 0.0, 0.9999)
	return growth_frames[int(floor(progress * growth_frames.size()))]


## Pixel region of `frame` inside sprite_sheet (empty Rect2 if no sheet).
func get_frame_region(frame: int) -> Rect2:
	if sprite_sheet == null or frame_size.x <= 0 or frame_size.y <= 0:
		return Rect2()
	var columns := maxi(int(sprite_sheet.get_width()) / frame_size.x, 1)
	return Rect2(Vector2((frame % columns) * frame_size.x, (frame / columns) * frame_size.y),
		Vector2(frame_size))
