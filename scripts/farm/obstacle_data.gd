class_name ObstacleData
extends Resource
## Data definition for one farm obstacle (grass, weeds, rocks...). One .tres per
## obstacle in res://resources/obstacles/.
##
## GDD: the farm starts "overrun and needs a lot of work to clear, the same as
## Stardew Valley", and the player has a sickle and a pickaxe, but the GDD does
## not say what they act on. Not GDD, placeholder (Ledan ruling, Stardew-style):
## the sickle clears grass and weeds, the pickaxe breaks rocks. Every value in
## the obstacle .tres files is a placeholder.

## Placeholder drawing style (no obstacle art yet).
enum Look { GRASS, WEED, ROCK }

@export var id: StringName = &""
@export var display_name: String = ""
## Tool that clears this obstacle (one use = one hit, costs stamina as usual).
@export var tool_kind: ToolData.Kind = ToolData.Kind.SICKLE
## Hits needed to clear it. Placeholder.
@export_range(1, 20) var hits: int = 1
## Item dropped when cleared (&"" = nothing) and how many. Placeholder.
@export var drop_item_id: StringName = &""
@export_range(0, 99) var drop_amount: int = 0

@export_group("Placeholder art")
@export var look: Look = Look.GRASS
@export var color: Color = Color(0.3, 0.7, 0.25)


## True if `tool` can clear this obstacle.
func is_cleared_by(tool: ToolData) -> bool:
	return tool != null and tool.kind == tool_kind
