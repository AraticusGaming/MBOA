class_name FarmPlot
extends RefCounted
## State of one 16x16 farm cell. Pure data; FarmGrid owns the rules.
## A cell holding a tree stays EMPTY soil until the tree is cleared.

enum State { EMPTY, TILLED, PLANTED }

var state: State = State.EMPTY
var crop_id: StringName = &""
## Number of watered days the crop has grown so far.
var growth_days: int = 0
## Watered today. Reset at the start of every new day.
var watered: bool = false
## Tree standing on this cell (null = none).
var tree: FarmTree = null


func is_planted() -> bool:
	return state == State.PLANTED


func has_tree() -> bool:
	return tree != null


func clear_crop() -> void:
	crop_id = &""
	growth_days = 0


func to_dict() -> Dictionary:
	return {
		"state": int(state),
		"crop_id": String(crop_id),
		"growth_days": growth_days,
		"watered": watered,
		"tree": tree.to_dict() if tree else null,
	}


static func from_dict(data: Dictionary) -> FarmPlot:
	var p := FarmPlot.new()
	p.state = int(data.get("state", State.EMPTY)) as State
	p.crop_id = StringName(data.get("crop_id", ""))
	p.growth_days = int(data.get("growth_days", 0))
	p.watered = bool(data.get("watered", false))
	var tree_data = data.get("tree")
	if tree_data is Dictionary:
		p.tree = FarmTree.from_dict(tree_data)
	return p
