class_name EconomyConfig
extends Resource
## Coins and inventory tuning. GDD: the currency is Coins and every item has a
## buying and a selling value; nothing else here is in the GDD. Every value is
## NOT GDD, PLACEHOLDER (see docs/PLACEHOLDERS.md).

## Coins on a new game. Placeholder (Stardew starts at 500).
@export var starting_coins: int = 500
## Items on a new game: item id -> count. Placeholder.
@export var starting_items: Dictionary = {&"turnip_seeds": 10}
## Inventory slots. Placeholder.
@export_range(1, 99) var inventory_slots: int = 24
## How many of the first inventory slots appear on the hotbar after the tools
## (keys 5-9 with four tools). Placeholder.
@export_range(0, 9) var hotbar_item_slots: int = 5
