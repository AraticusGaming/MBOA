extends MboaTestBase
## Items, inventory, Coins and the seed shop (Milestone 2, step 1). Prices,
## stack sizes and slot counts are placeholders (docs/PLACEHOLDERS.md).

const PlayerStateScript := preload("res://scripts/core/player_state.gd")
const SHOP_PATH := "res://resources/shop/seed_shop.tres"
const SHOP_UI_SCENE := "res://scenes/ui/shop_ui.tscn"

var _cleanup: Array = []


func _run_tests() -> void:
	_test_catalog()
	_test_inventory()
	_test_starting_kit()
	_test_shop_logic()
	await _test_shop_ui()
	_test_eat_item()
	for n in _cleanup:
		if is_instance_valid(n):
			n.free()


func _make_state() -> Node:
	var ps: Node = PlayerStateScript.new()
	root.add_child(ps)
	_cleanup.append(ps)
	return ps


func _test_catalog() -> void:
	var cat := ItemCatalog.get_default()
	check(cat != null and cat.items.size() >= 10, "item catalog loads")
	for id in [&"wood", &"stone", &"turnip_seeds", &"carrot_seeds", &"tomato_seeds",
			&"pumpkin_seeds", &"turnip", &"carrot", &"tomato", &"pumpkin", &"placeholder_crop"]:
		check(cat.has_item(id), "catalog has %s" % id)
	var ids := {}
	for it in cat.items:
		check(not ids.has(it.id), "unique item id %s" % it.id)
		ids[it.id] = true
	var wood := cat.get_item(&"wood")
	check(wood.can_sell() and not wood.can_buy(), "wood: sell only")
	var seeds := cat.get_item(&"turnip_seeds")
	check(seeds.is_seed() and seeds.can_buy() and seeds.get_crop() != null, "turnip seeds plant a crop")
	check_eq(cat.get_seed_for_crop(&"pumpkin").id, &"pumpkin_seeds", "seed lookup by crop")
	# Every seed's crop exists and every crop's harvest item exists.
	for it in cat.items:
		if it.kind == ItemData.Kind.SEED:
			var crop = it.get_crop()
			check(crop != null, "%s -> crop .tres exists" % it.id)
			if crop:
				check(cat.has_item(crop.get_harvest_item_id()), "%s harvest item exists" % crop.id)
		if it.kind == ItemData.Kind.CROP and it.id != &"wet_waxweed":
			check(it.edible and it.can_sell(), "%s is edible and sellable" % it.id)
	var wax := cat.get_item(&"wet_waxweed")
	check(wax != null and not wax.edible and wax.can_sell(), "Wet Waxweed: monster food, sellable, not eaten by the player")
	check_eq(cat.get_seed_for_crop(&"wet_waxweed").id, &"waxweed_starter", "Waxweed Starter plants Wet Waxweed")


func _test_inventory() -> void:
	var inv := Inventory.new(3)
	check_eq(inv.size(), 3, "3 slots")
	var changes := [0]
	inv.changed.connect(func(): changes[0] += 1)
	check_eq(inv.add(&"wood", 150), 150, "150 wood fit into 2 stacks of 99")
	check_eq(inv.get_slot(0).count, 99, "first stack full (max_stack 99)")
	check_eq(inv.get_slot(1).count, 51, "second stack 51")
	check_eq(inv.add(&"wood", 60), 60, "tops up stack 2, then a new slot")
	check_eq(inv.count(&"wood"), 210, "count sums stacks")
	check_eq(inv.space_for(&"stone"), 0, "no free slot for stone")
	check_eq(inv.add(&"stone", 5), 0, "full inventory: nothing added")
	check(not inv.can_add(&"wood", 100), "can't add over capacity")
	check(not inv.remove(&"wood", 500), "remove more than owned fails")
	check_eq(inv.count(&"wood"), 210, "failed remove changes nothing")
	check(inv.remove(&"wood", 110), "remove 110 across stacks")
	check_eq(inv.count(&"wood"), 100, "100 left")
	check_eq(inv.add(&"no_such_item", 1), 0, "unknown item rejected")
	check(changes[0] > 0, "changed signal fires")
	var arr := inv.to_array()
	var inv2 := Inventory.new(3)
	inv2.from_array(JSON.parse_string(JSON.stringify(arr)))
	check_eq(inv2.to_array(), arr, "inventory survives JSON round-trip")
	check_eq(inv2.remove_from_slot(0, 999), inv.get_slot(0).count if inv.get_slot(0) else 0,
		"remove_from_slot caps at stack size")


func _test_starting_kit() -> void:
	var ps := _make_state()
	var econ: EconomyConfig = ps.economy_config
	check_eq(ps.coins, econ.starting_coins, "new game Coins from economy config")
	check_eq(ps.inventory.size(), econ.inventory_slots, "inventory slots from config")
	check_eq(ps.inventory.count(&"turnip_seeds"), int(econ.starting_items.get(&"turnip_seeds",
		econ.starting_items.get("turnip_seeds", 0))), "starting turnip seeds")
	ps.add_coins(-100000)
	check_eq(ps.coins, 0, "Coins never go negative")


func _test_shop_logic() -> void:
	var shop := load(SHOP_PATH) as ShopData
	check(shop != null and shop.stock.size() == 5, "seed shop with 5 seeds")
	var spring := Shop.get_stock(shop, GameClock.Season.SPRING)
	var ids := spring.map(func(i): return i.id)
	check(ids.has(&"turnip_seeds") and ids.has(&"carrot_seeds"), "spring stock: turnip, carrot")
	check(not ids.has(&"tomato_seeds") and not ids.has(&"pumpkin_seeds"), "spring stock: no summer/fall seeds")
	var fall := Shop.get_stock(shop, GameClock.Season.FALL).map(func(i): return i.id)
	check(fall.has(&"pumpkin_seeds") and fall.has(&"carrot_seeds") and not fall.has(&"turnip_seeds"),
		"fall stock: pumpkin, carrot")
	check_eq(Shop.get_stock(shop, GameClock.Season.WINTER).size(), 0, "winter: no seeds")
	check_eq(Shop.get_stock(shop).size(), 5, "season -1: everything")

	var ps := _make_state()
	ps.inventory.clear()
	ps.coins = 100
	var cat := ItemCatalog.get_default()
	var turnip_seeds := cat.get_item(&"turnip_seeds")
	check(Shop.buy(ps, turnip_seeds, 3), "buy 3 turnip seeds")
	check_eq(ps.coins, 100 - 3 * turnip_seeds.buy_price, "Coins spent")
	check_eq(ps.inventory.count(&"turnip_seeds"), 3, "seeds in inventory")
	check(not Shop.buy(ps, cat.get_item(&"pumpkin_seeds"), 1), "can't afford pumpkin seeds")
	check(not Shop.buy(ps, cat.get_item(&"wood"), 1), "wood not for sale")
	check_eq(ps.coins, 100 - 3 * turnip_seeds.buy_price, "failed buys change nothing")
	ps.add_item(&"turnip", 4)
	var slot := -1
	for i in ps.inventory.size():
		var it = ps.inventory.get_item_in_slot(i)
		if it and it.id == &"turnip":
			slot = i
	var before: int = ps.coins
	var turnip := cat.get_item(&"turnip")
	check_eq(Shop.sell_slot(ps, slot, 1), turnip.sell_price, "sell one turnip")
	check_eq(Shop.sell_slot(ps, slot, 99), 3 * turnip.sell_price, "sell the rest (capped)")
	check_eq(ps.coins, before + 4 * turnip.sell_price, "Coins earned")
	check_eq(ps.inventory.count(&"turnip"), 0, "turnips gone")
	check_eq(Shop.sell_slot(ps, slot, 1), 0, "empty slot sells nothing")
	# Full inventory blocks buying.
	var tiny := _make_state()
	tiny.inventory = Inventory.new(1)
	tiny.coins = 10000
	tiny.inventory.add(&"wood", 1)
	check(not Shop.buy(tiny, turnip_seeds, 1), "no space: buy fails")
	check_eq(tiny.coins, 10000, "no Coins taken when buy fails")


func _test_shop_ui() -> void:
	var clock := make_clock()
	_cleanup.append(clock)
	var ps := _make_state()
	ps.inventory.clear()
	ps.coins = 200
	ps.add_item(&"carrot", 2)
	var ui := (load(SHOP_UI_SCENE) as PackedScene).instantiate() as ShopUI
	ui.clock = clock
	ui.player_state = ps
	root.add_child(ui)
	_cleanup.append(ui)
	await process_frame
	check(ui.default_shop != null, "shop UI has the seed shop")
	check(not ui.is_open(), "shop starts closed")
	ui.open()
	check(ui.is_open(), "shop opens")
	check(clock.is_paused(), "clock paused while shopping")
	check(ui.buy(ItemCatalog.get_default().get_item(&"turnip_seeds"), 5), "UI buy x5")
	check_eq(ps.inventory.count(&"turnip_seeds"), 5, "bought seeds in inventory")
	check_eq(ps.coins, 200 - 5 * 20, "UI buy cost (20c placeholder)")
	var carrot_slot := 0
	check_eq(ui.sell(carrot_slot, 999), 2 * 45, "UI sell all carrots (45c placeholder)")
	check_eq(ps.coins, 100 + 90, "Coins after selling")
	ui.close()
	check(not ui.is_open() and not clock.is_paused(), "close resumes the clock")
	# The farm counter opens the UI (group lookup).
	var counter := (load("res://scenes/world/shop_counter.tscn") as PackedScene).instantiate()
	root.add_child(counter)
	_cleanup.append(counter)
	counter.use(null)
	check(ui.is_open(), "shop counter opens the shop UI")
	ui.close()


func _test_eat_item() -> void:
	var ps := _make_state()
	ps.inventory.clear()
	ps.add_item(&"turnip", 1)
	ps.spend_stamina(50.0)
	var p := Player.new()
	p.player_state = ps
	root.add_child(p)
	_cleanup.append(p)
	p.set_tool(p.tools.size())  # first item slot
	check_eq(p.get_current_item().id, &"turnip", "turnip selected on the hotbar")
	check(p.eat_current_item(), "eat the turnip")
	var turnip := ItemCatalog.get_default().get_item(&"turnip")
	check(turnip.stamina_refill > 0.0, "turnip has its own refill value")
	check_eq(ps.stamina, 50.0 + turnip.stamina_refill, "eating refills by the food's value")
	check_eq(ps.inventory.count(&"turnip"), 0, "turnip consumed")
	check(not p.eat_current_item(), "nothing left to eat")
	# Drops from the farm (wood from trees, stone from rocks) go to the inventory.
	var grid := FarmGrid.new()
	root.add_child(grid)
	_cleanup.append(grid)
	p.set_farm_grid(grid)
	grid.items_dropped.emit(Vector2i.ZERO, &"wood", 8)
	grid.items_dropped.emit(Vector2i.ZERO, &"stone", 1)
	check(ps.inventory.count(&"wood") == 8 and ps.inventory.count(&"stone") == 1,
		"farm drops land in the inventory")
