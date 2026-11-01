class_name ShopUI
extends CanvasLayer
## Placeholder shop window (Stardew-like, built in code): buy the shop's stock
## (seasonal seeds) and sell sellable inventory stacks. Prices come from
## ItemData (placeholders). Time pauses while it is open (Stardew rule,
## placeholder). Close with the Close button or the cancel action (Esc).

signal closed

const PAUSE_REASON := &"shop"

## Shop shown when open() is called without one.
@export var default_shop: ShopData

var shop: ShopData
var clock: GameClock
## PlayerState autoload; injectable for tests.
var player_state: Node

var _panel: PanelContainer
var _title: Label
var _coins_label: Label
var _buy_list: VBoxContainer
var _sell_list: VBoxContainer
var _message: Label


func _ready() -> void:
	layer = 20
	add_to_group(&"shop_ui")
	if clock == null:
		clock = get_node_or_null("/root/Clock") as GameClock
	if player_state == null:
		player_state = get_node_or_null("/root/PlayerState")
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"cancel"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func open(s: ShopData = null) -> void:
	shop = s if s else default_shop
	if _panel == null:
		_build()
	visible = true
	if clock:
		clock.pause(PAUSE_REASON)
	_message.text = ""
	if player_state and not player_state.inventory_changed.is_connected(refresh):
		player_state.inventory_changed.connect(refresh)
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	if clock:
		clock.resume(PAUSE_REASON)
	if player_state and player_state.inventory_changed.is_connected(refresh):
		player_state.inventory_changed.disconnect(refresh)
	closed.emit()


## Buys `amount` of `item` for the player. Returns true on success.
func buy(item: ItemData, amount: int = 1) -> bool:
	var ok := player_state != null and Shop.buy(player_state, item, amount)
	_message.text = ("Bought %d %s" % [amount, item.display_name]) if ok \
		else "Not enough Coins or space"
	refresh()
	return ok


## Sells up to `amount` from inventory slot `slot`. Returns Coins earned.
func sell(slot: int, amount: int = 1) -> int:
	var earned := Shop.sell_slot(player_state, slot, amount) if player_state else 0
	if earned > 0:
		_message.text = "Sold for %d Coins" % earned
	refresh()
	return earned


func refresh() -> void:
	if _panel == null or player_state == null:
		return
	_title.text = shop.display_name if shop else "Shop"
	_coins_label.text = "Coins: %d" % player_state.coins
	_clear(_buy_list)
	_clear(_sell_list)
	var season := clock.season if clock else -1
	for item in Shop.get_stock(shop, season):
		var row := _row("%s  %dc" % [item.display_name, item.buy_price], item.color)
		row.add_child(_button("Buy", buy.bind(item, 1)))
		row.add_child(_button("x5", buy.bind(item, 5)))
		_buy_list.add_child(row)
	if _buy_list.get_child_count() == 0:
		_buy_list.add_child(_label("Nothing for sale this season"))
	if shop == null or shop.buys_from_player:
		var inv: Inventory = player_state.inventory
		for i in inv.size():
			var item := inv.get_item_in_slot(i)
			if item == null or not item.can_sell():
				continue
			var row := _row("%s x%d  %dc" % [item.display_name, inv.get_slot(i).count, item.sell_price],
				item.color)
			row.add_child(_button("Sell", sell.bind(i, 1)))
			row.add_child(_button("All", sell.bind(i, 999)))
			_sell_list.add_child(row)
		if _sell_list.get_child_count() == 0:
			_sell_list.add_child(_label("Nothing to sell"))


# --- UI construction -----------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 10
	root.theme = theme
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.position = Vector2(110, 40)
	_panel.custom_minimum_size = Vector2(420, 280)
	root.add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = _label("Shop")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_coins_label = _label("Coins: 0")
	head.add_child(_coins_label)
	head.add_child(_button("Close", close))
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	_buy_list = _column(cols, "Buy")
	_sell_list = _column(cols, "Sell")
	_message = _label("")
	v.add_child(_message)


func _column(parent: Container, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(col)
	col.add_child(_label(title))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _row(text: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var icon := ColorRect.new()
	icon.color = color
	icon.custom_minimum_size = Vector2(10, 10)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var l := _label(text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
