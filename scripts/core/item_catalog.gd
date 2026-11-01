class_name ItemCatalog
extends Resource
## Every item known to the game (resources/items/item_catalog.tres). Listed
## explicitly instead of scanning the folder so it also works in exports.

const DEFAULT_PATH := "res://resources/items/item_catalog.tres"

@export var items: Array[ItemData] = []

var _index: Dictionary = {}


## The shared catalog loaded from DEFAULT_PATH (Godot's resource cache keeps
## one instance while anything holds it; no static reference, so nothing
## leaks at exit).
static func get_default() -> ItemCatalog:
	var cat := load(DEFAULT_PATH) as ItemCatalog
	return cat if cat else ItemCatalog.new()


func get_item(id: StringName) -> ItemData:
	if _index.size() != items.size():
		_index.clear()
		for it in items:
			if it != null:
				_index[it.id] = it
	return _index.get(id)


func has_item(id: StringName) -> bool:
	return get_item(id) != null


## Seed item that plants `crop_id`, or null.
func get_seed_for_crop(crop_id: StringName) -> ItemData:
	for it in items:
		if it and it.is_seed() and it.crop_id == crop_id:
			return it
	return null
