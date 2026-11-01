class_name FarmTools
extends RefCounted
## Tool identifiers used by Player and FarmGrid.

enum Tool { HOE, SEED, WATERING_CAN }

const NAMES := {
	Tool.HOE: "Hoe",
	Tool.SEED: "Seeds",
	Tool.WATERING_CAN: "Watering Can",
}


static func get_tool_name(tool: int) -> String:
	return NAMES.get(tool, "?")
