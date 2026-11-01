class_name ItemData
extends Resource
## Data definition for one inventory item. One .tres per item in
## res://resources/items/, listed in resources/items/item_catalog.tres.
##
## GDD (Progression): "Prices are set as items are added, and each item gets a
## buying value and a selling value." The GDD sets no prices, stack sizes or
## item list, so every value in the item .tres files is NOT GDD, PLACEHOLDER.

enum Kind { MATERIAL, SEED, CROP, FOOD }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.MATERIAL
## Price to buy one from a shop (0 = not sold). Placeholder.
@export_range(0, 100000) var buy_price: int = 0
## Coins for selling one (0 = can't be sold). Placeholder.
@export_range(0, 100000) var sell_price: int = 0
## Max items per inventory stack. Placeholder (Stardew-style 999 is common;
## 99 here).
@export_range(1, 999) var max_stack: int = 99
## SEED items: id of the crop they plant (resources/crops/<id>.tres). An id,
## not a CropData reference, to keep the script dependency graph acyclic.
@export var crop_id: StringName = &""
## True if the player can eat it (flat stamina refill, see EnergyConfig).
@export var edible: bool = false
## Stamina refilled when the player eats one (DECISIONS.md: refill depends
## on the food). Placeholder values; -1 = EnergyConfig.eat_stamina_refill.
@export var stamina_refill: float = -1.0
## Placeholder icon color (items without art).
@export var color: Color = Color(0.8, 0.8, 0.8)
## 16x16 icon (ART: assets/sprites/item_<name>.png). null = colored square.
@export var icon: Texture2D


func is_seed() -> bool:
	return kind == Kind.SEED and crop_id != &""


## The CropData this seed plants (loaded by id), or null.
func get_crop() -> Resource:
	if crop_id == &"":
		return null
	var path := "res://resources/crops/%s.tres" % crop_id
	return load(path) if ResourceLoader.exists(path) else null


func can_sell() -> bool:
	return sell_price > 0


func can_buy() -> bool:
	return buy_price > 0
