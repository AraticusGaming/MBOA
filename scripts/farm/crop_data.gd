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
