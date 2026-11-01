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
## Obstacle on this cell (ObstacleData id, &"" = none) and hits it has taken.
var obstacle_id: StringName = &""
var obstacle_hits: int = 0


func is_planted() -> bool:
	return state == State.PLANTED


func has_tree() -> bool:
	return tree != null


func has_obstacle() -> bool:
	return obstacle_id != &""


## True if something stands on the cell (a tree or an obstacle).
func is_blocked() -> bool:
	return has_tree() or has_obstacle()


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
		"obstacle": {"id": String(obstacle_id), "hits": obstacle_hits} if has_obstacle() else null,
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
	var obstacle_data = data.get("obstacle")
	if obstacle_data is Dictionary:
		p.obstacle_id = StringName(obstacle_data.get("id", ""))
		p.obstacle_hits = int(obstacle_data.get("hits", 0))
	return p
