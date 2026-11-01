class_name ShopData
extends Resource
## What a shop sells (GDD Village: "Shop: seeds and other goods"). Prices come
## from each ItemData.buy_price; selling uses ItemData.sell_price. The stock
## list and the seasonal rule are NOT GDD, PLACEHOLDER.

@export var id: StringName = &""
@export var display_name: String = ""
## Item ids for sale.
@export var stock: Array[StringName] = []
## Stardew-style: only sell seeds for crops that grow in the current season.
## Placeholder (Stardew's general store does this).
@export var seasonal_seeds: bool = true
## True if the player can sell crops/goods here. Placeholder: the GDD says the
## player can sell crops but not where.
@export var buys_from_player: bool = true
