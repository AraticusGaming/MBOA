class_name ToolData
extends Resource
## Data definition for one hotbar item (tool or seed bag). One .tres per item
## in res://resources/tools/.
##
## GDD basic tools: Pulaski (axe + hoe: clears trees and tills soil), sickle,
## pickaxe, watering can. At the basic level each works on ONE tile (upgrades
## that widen the area are not designed yet, so only 1 tile is supported).
## Every tool use costs stamina; at 0 stamina tools can't be used.

enum Kind { PULASKI, SICKLE, PICKAXE, WATERING_CAN, SEEDS }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.PULASKI
## True for GDD tools: a use costs stamina and is blocked at 0 stamina.
## Seeds are an item, not a tool, so seeds.tres sets this false.
@export var is_tool: bool = true
## Stamina (percent of the bar) spent per use. PLACEHOLDER: the GDD does not
## give per-tool costs (open question).
@export_range(0.0, 100.0, 0.5) var stamina_cost: float = 2.0
