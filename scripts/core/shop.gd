class_name Shop
extends RefCounted
## Buy/sell rules shared by the shop UI and tests. Works on any object with
## `coins`, `add_coins(int)` and `inventory` (PlayerState).


## Items `shop` offers in `season` (GameClock.Season; -1 = ignore seasons).
static func get_stock(shop: ShopData, season: int = -1, catalog: ItemCatalog = null) -> Array[ItemData]:
	var cat := catalog if catalog else ItemCatalog.get_default()
	var out: Array[ItemData] = []
	if shop == null:
		return out
	for id in shop.stock:
		var item := cat.get_item(id)
		if item == null or not item.can_buy():
			continue
		if shop.seasonal_seeds and season >= 0 and item.is_seed() and not item.get_crop().call(&"grows_in", season):
			continue
		out.append(item)
	return out


## Buys `amount` of `item`. Fails (changes nothing) without enough Coins or
## inventory space.
static func buy(state: Object, item: ItemData, amount: int = 1) -> bool:
	if item == null or not item.can_buy() or amount <= 0:
		return false
	var cost := item.buy_price * amount
	var inv: Inventory = state.inventory
	if state.coins < cost or not inv.can_add(item.id, amount):
		return false
	state.add_coins(-cost)
	inv.add(item.id, amount)
	return true


## Sells up to `amount` from inventory slot `slot_index`. Returns Coins earned.
static func sell_slot(state: Object, slot_index: int, amount: int = 1) -> int:
	var inv: Inventory = state.inventory
	var item := inv.get_item_in_slot(slot_index)
	if item == null or not item.can_sell():
		return 0
	var n := inv.remove_from_slot(slot_index, amount)
	var earned := n * item.sell_price
	if earned > 0:
		state.add_coins(earned)
	return earned
