class_name FarmTree
extends RefCounted
## State of one tree standing on a farm cell. Pure data; FarmGrid owns the
## rules and TreeData holds the numbers.

var tree_id: StringName = &""
var stage: int = TreeData.Stage.SEED
## Pulaski hits taken in the current stage (resets when the stage changes).
var hits: int = 0
## Days spent in the current growth stage.
var days_in_stage: int = 0


static func create(id: StringName, start_stage: int) -> FarmTree:
	var t := FarmTree.new()
	t.tree_id = id
	t.stage = start_stage
	return t


func to_dict() -> Dictionary:
	return {"tree_id": String(tree_id), "stage": stage, "hits": hits,
		"days_in_stage": days_in_stage}


static func from_dict(data: Dictionary) -> FarmTree:
	var t := FarmTree.new()
	t.tree_id = StringName(data.get("tree_id", ""))
	t.stage = int(data.get("stage", TreeData.Stage.SEED))
	t.hits = int(data.get("hits", 0))
	t.days_in_stage = int(data.get("days_in_stage", 0))
	return t
