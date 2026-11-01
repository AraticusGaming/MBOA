class_name TreeData
extends Resource
## Data definition for one tree type. One .tres per tree in res://resources/trees/.
##
## GDD (Farm work): trees have four growth stages - seed, seedling, sapling,
## grown. Seeds and seedlings can be dug out of the ground; saplings and grown
## trees have to be cut down with the Pulaski. A sapling takes 3 hits; a grown
## tree takes 10 swings: 6 to bring it down, then 4 to clear the stump.
## The hit counts below are GDD values; everything marked PLACEHOLDER is not.

## STUMP is what a grown tree leaves after it is felled (not a growth stage).
enum Stage { SEED, SEEDLING, SAPLING, GROWN, STUMP }

const STAGE_NAMES := ["seed", "seedling", "sapling", "grown", "stump"]

@export var id: StringName = &""
@export var display_name: String = ""
## GDD: a sapling takes 3 Pulaski hits.
@export var sapling_hits: int = 3
## GDD: a grown tree takes 6 swings to fall...
@export var fell_hits: int = 6
## ...and 4 more to clear the stump (10 total).
@export var stump_hits: int = 4
## Digs to remove a seed or seedling. PLACEHOLDER: the GDD says they "can be
## dug out" but not how many digs or with which tool (assumed: Pulaski, the hoe).
@export var dig_out_hits: int = 1
## Days spent as seed, seedling and sapling before the next stage.
## Not GDD, placeholder (Ledan ruling: placeholder growth times as data).
## 0 = never advances.
@export var stage_days: PackedInt32Array = PackedInt32Array([7, 7, 7])

## Item dropped by cutting trees. Not GDD, placeholder (Ledan ruling: trees
## drop wood); the amounts below are placeholders too. Seeds and seedlings
## that are dug out drop nothing.
@export var drop_item_id: StringName = &"wood"
## Wood from cutting down a sapling.
@export_range(0, 99) var sapling_wood: int = 1
## Wood when a grown tree falls (6th swing).
@export_range(0, 99) var fell_wood: int = 8
## Wood from clearing the stump.
@export_range(0, 99) var stump_wood: int = 2

@export_group("Placeholder colors")
## No tree art yet: trees are drawn as rectangles in these colors.
@export var color_trunk: Color = Color(0.42, 0.27, 0.15)
@export var color_canopy: Color = Color(0.16, 0.46, 0.22)


## Hits needed to clear (or fell, for GROWN) a tree in `stage`.
func get_hits_for_stage(stage: int) -> int:
	match stage:
		Stage.SEED, Stage.SEEDLING:
			return maxi(dig_out_hits, 1)
		Stage.SAPLING:
			return maxi(sapling_hits, 1)
		Stage.GROWN:
			return maxi(fell_hits, 1)
		Stage.STUMP:
			return maxi(stump_hits, 1)
	return 1


## Days before `stage` grows into the next one (0 = never). GROWN/STUMP = 0.
func get_days_for_stage(stage: int) -> int:
	if stage < 0 or stage >= stage_days.size() or stage >= Stage.GROWN:
		return 0
	return maxi(stage_days[stage], 0)


static func stage_from_name(stage_name: String) -> int:
	return STAGE_NAMES.find(stage_name.to_lower())


## Wood dropped when the tree in `stage` is cleared (or felled, for GROWN).
func get_drop_for_stage(stage: int) -> int:
	match stage:
		Stage.SAPLING:
			return sapling_wood
		Stage.GROWN:
			return fell_wood
		Stage.STUMP:
			return stump_wood
	return 0
