class_name Inventory
extends RefCounted
## Player inventory: a fixed number of slots, each empty or holding one stack
## {id, count} of an ItemData from the ItemCatalog. The first slots double as
## the item part of the hotbar (see Player). Slot count and stack sizes are
## NOT GDD, PLACEHOLDER (EconomyConfig / ItemData.max_stack).

signal changed

var catalog: ItemCatalog
## Array of {"id": StringName, "count": int} or null for an empty slot.
var slots: Array = []


func _init(slot_count: int = 24, item_catalog: ItemCatalog = null) -> void:
	catalog = item_catalog if item_catalog else ItemCatalog.get_default()
	slots.resize(maxi(slot_count, 1))


func size() -> int:
	return slots.size()


## Stack in `index` ({id, count}) or null.
func get_slot(index: int):
	return slots[index] if index >= 0 and index < slots.size() else null


func get_item_in_slot(index: int) -> ItemData:
	var s = get_slot(index)
	return catalog.get_item(s.id) if s else null


func count(id: StringName) -> int:
	var n := 0
	for s in slots:
		if s and s.id == id:
			n += s.count
	return n


## How many of `id` would fit right now.
func space_for(id: StringName) -> int:
	var item := catalog.get_item(id)
	if item == null:
		return 0
	var free := 0
	for s in slots:
		if s == null:
			free += item.max_stack
		elif s.id == id:
			free += maxi(item.max_stack - s.count, 0)
	return free


func can_add(id: StringName, amount: int = 1) -> bool:
	return amount > 0 and space_for(id) >= amount


## Adds up to `amount` of `id`: tops up existing stacks first, then fills empty
## slots. Returns how many were added (less than amount when full; unknown
## items add nothing).
func add(id: StringName, amount: int = 1) -> int:
	var item := catalog.get_item(id)
	if item == null or amount <= 0:
		return 0
	var left := amount
	for s in slots:
		if left <= 0:
			break
		if s and s.id == id and s.count < item.max_stack:
			var n := mini(item.max_stack - s.count, left)
			s.count += n
			left -= n
	for i in slots.size():
		if left <= 0:
			break
		if slots[i] == null:
			var n := mini(item.max_stack, left)
			slots[i] = {"id": id, "count": n}
			left -= n
	if left != amount:
		changed.emit()
	return amount - left


## Removes `amount` of `id` from any slots (last slots first). All or nothing.
func remove(id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or count(id) < amount:
		return false
	var left := amount
	for i in range(slots.size() - 1, -1, -1):
		var s = slots[i]
		if left > 0 and s and s.id == id:
			var n := mini(s.count, left)
			s.count -= n
			left -= n
			if s.count <= 0:
				slots[i] = null
	changed.emit()
	return true


## Removes up to `amount` from slot `index`. Returns how many were removed.
func remove_from_slot(index: int, amount: int = 1) -> int:
	var s = get_slot(index)
	if s == null or amount <= 0:
		return 0
	var n := mini(s.count, amount)
	s.count -= n
	if s.count <= 0:
		slots[index] = null
	changed.emit()
	return n


func clear() -> void:
	for i in slots.size():
		slots[i] = null
	changed.emit()


func to_array() -> Array:
	var arr: Array = []
	for s in slots:
		arr.append({"id": String(s.id), "count": s.count} if s else null)
	return arr


## Restores slots from to_array() data. Unknown item ids are dropped.
func from_array(arr: Array) -> void:
	for i in slots.size():
		slots[i] = null
	for i in mini(arr.size(), slots.size()):
		var d = arr[i]
		if d is Dictionary and catalog.has_item(StringName(d.get("id", ""))) \
				and int(d.get("count", 0)) > 0:
			slots[i] = {"id": StringName(d.id), "count": int(d.count)}
	changed.emit()
