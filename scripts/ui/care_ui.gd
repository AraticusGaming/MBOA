class_name CareUI
extends CanvasLayer
## Placeholder monster care window (Slice 3), built in code like ShopUI and
## framed with the ART HUD panel: lists the monsters in one home (pasture,
## habitat or barn) with their Bond bar and star, feeds the selected food,
## moves monsters (barn needs 25% bond), fills the barn's water troughs and
## adds/removes party members (barn only, up to two). The selected monster's
## portrait and details show on the right. Time pauses while it is open
## (placeholder, like the shop). Close with the button or cancel (Esc).

signal closed

const PAUSE_REASON := &"care"
const PANEL_TEX := "res://assets/ui/hud_panel.png"
const BAR_BG_TEX := "res://assets/ui/bar_frame.png"
const BAR_FILL_TEX := "res://assets/ui/bar_fill_stamina.png"
const STAR := "*"

var home: StringName = &""
var clock: GameClock
## PlayerState autoload; injectable for tests.
var player_state: Node
## Food item id used by Feed (one of get_food_ids()).
var food_id: StringName = &""
var selected: RefCounted

var _panel: PanelContainer
var _title: Label
var _needs: Label
var _food: OptionButton
var _water: Button
var _list: VBoxContainer
var _portrait: TextureRect
var _detail: Label
var _message: Label


func _ready() -> void:
	layer = 21
	add_to_group(&"care_ui")
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


func open(h: StringName) -> void:
	home = h
	if _panel == null:
		_build()
	if clock and not visible:  # pauses are counted: once per open window
		clock.pause(PAUSE_REASON)
	visible = true
	_message.text = ""
	selected = null
	if player_state and not player_state.care_changed.is_connected(refresh):
		player_state.care_changed.connect(refresh)
		player_state.inventory_changed.connect(refresh)
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	if clock:
		clock.resume(PAUSE_REASON)
	if player_state and player_state.care_changed.is_connected(refresh):
		player_state.care_changed.disconnect(refresh)
		player_state.inventory_changed.disconnect(refresh)
	closed.emit()


## Monsters listed (everyone living in `home`, party members included).
func get_monsters() -> Array:
	return player_state.get_residents(home) if player_state else []


## Feedable item ids the player carries (inventory order).
func get_food_ids() -> Array:
	var out: Array = []
	if player_state == null:
		return out
	var inv: Inventory = player_state.inventory
	for i in inv.size():
		var item = inv.get_item_in_slot(i)
		if item and item.is_feedable() and not out.has(item.id):
			out.append(item.id)
	return out


func feed(m: RefCounted) -> bool:
	if food_id == &"":
		_message.text = "No food to give"
		return false
	var r: Dictionary = player_state.feed_monster(m, food_id)
	selected = m
	_message.text = ("Fed %s: +%.0f%% bond" % [m.get_display_name(), r.bond]) if r.ok and r.bond > 0.0 \
		else ("Fed %s (no more bond from food today)" % m.get_display_name() if r.ok else r.reason)
	refresh()
	return r.ok


func move(m: RefCounted, to: StringName) -> bool:
	var why: String = player_state.get_move_block(m, to)
	var ok: bool = why == "" and player_state.move_monster(m, to)
	_message.text = ("%s moved to the %s" % [m.get_display_name(), player_state.get_home_name(to)]) if ok else why
	refresh()
	return ok


func toggle_party(m: RefCounted) -> bool:
	var ok: bool
	if player_state.party.has(m):
		ok = player_state.remove_from_party(m)
		_message.text = "%s stays in the barn" % m.get_display_name()
	else:
		ok = player_state.add_to_party(m)
		_message.text = ("%s joins your party" % m.get_display_name()) if ok \
			else "Party is full (%d)" % player_state.get_party_max()
	refresh()
	return ok


func water() -> int:
	var n: int = player_state.water_barn()
	_message.text = "Filled the water troughs"
	refresh()
	return n


func select(m: RefCounted) -> void:
	selected = m
	refresh()


## Where a monster in this home can be moved (besides the barn).
func get_move_targets() -> Array:
	var out: Array = []
	if player_state == null:
		return out
	if home != &"pasture":
		out.append(&"pasture")
	if player_state.farm_biome >= 0:
		var h: Dictionary = player_state.get_habitat(player_state.farm_biome)
		if not h.is_empty() and StringName(h.id) != home:
			out.append(StringName(h.id))
	return out


func refresh() -> void:
	if _panel == null or player_state == null:
		return
	var list := get_monsters()
	_title.text = "%s  %d/%d" % [player_state.get_home_name(home), list.size(), player_state.get_capacity(home)]
	# Food picker.
	var foods := get_food_ids()
	if not foods.has(food_id):
		food_id = foods[0] if not foods.is_empty() else &""
	_food.clear()
	var cat = load("res://resources/items/item_catalog.tres")
	for id in foods:
		var it = cat.get_item(id)
		_food.add_item("%s x%d" % [it.display_name, player_state.inventory.count(id)])
		if id == food_id:
			_food.select(_food.item_count - 1)
	if foods.is_empty():
		_food.add_item("No food")
	_food.disabled = foods.is_empty()
	var is_barn := home == &"barn"
	_water.visible = is_barn
	if is_barn:
		var needs: Dictionary = player_state.get_barn_needs()
		_needs.text = "Hungry %d  Thirsty %d  Party %d/%d" % [needs.hungry, needs.thirsty,
			player_state.party.size(), player_state.get_party_max()]
	else:
		_needs.text = "No daily food needed; feeding helps bonding"
	# Rows.
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if selected == null or not list.has(selected):
		selected = list[0] if not list.is_empty() else null
	for m in list:
		_list.add_child(_monster_row(m, is_barn))
	if list.is_empty():
		_list.add_child(_label("Nobody lives here yet"))
	_update_detail()


func _monster_row(m: RefCounted, is_barn: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 3)
	var sp = m.get_species()
	var name_btn := _button("%s%s" % [m.get_display_name(), " >" if m == selected else ""], select.bind(m))
	name_btn.custom_minimum_size = Vector2(104, 0)
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if sp and sp.portrait:
		name_btn.icon = sp.portrait
		name_btn.expand_icon = true
		name_btn.add_theme_constant_override(&"icon_max_width", 14)
	row.add_child(name_btn)
	row.add_child(_label("%s %s" % [m.get_rank(), "M" if m.gender == Monster.Gender.MALE else "F"], 22))
	var bar := _bond_bar(m.bond)
	row.add_child(bar)
	row.add_child(_label(("%3d%%" % int(m.bond)) + (" " + STAR if m.has_star() else ""), 34))
	var feed_b := _button("Feed", feed.bind(m))
	feed_b.disabled = food_id == &""
	row.add_child(feed_b)
	if not is_barn:
		var barn_b := _button("Barn", move.bind(m, &"barn"))
		barn_b.disabled = not player_state.can_move(m, &"barn")
		barn_b.tooltip_text = player_state.get_move_block(m, &"barn")
		row.add_child(barn_b)
	for t in get_move_targets():
		var b := _button("Pasture" if t == &"pasture" else "Habitat", move.bind(m, t))
		b.disabled = not player_state.can_move(m, t)
		b.tooltip_text = player_state.get_move_block(m, t)
		row.add_child(b)
	if is_barn:
		var in_party: bool = player_state.party.has(m)
		var p := _button("Leave" if in_party else "Party", toggle_party.bind(m))
		p.disabled = not in_party and not player_state.can_join_party(m)
		row.add_child(p)
	return row


func _update_detail() -> void:
	var m := selected
	if m == null:
		_portrait.texture = null
		_detail.text = ""
		return
	var sp = m.get_species()
	_portrait.texture = sp.portrait if sp else null
	var fav := String(m.favorite_food_id)
	var item = load("res://resources/items/item_catalog.tres").get_item(m.favorite_food_id)
	if item:
		fav = item.display_name
	var letters: Array = m.get_stat_letters()
	var stats := ""
	for i in Monster.STAT_LABELS.size():
		stats += "%s %s  " % [Monster.STAT_LABELS[i], letters[i]]
	var status := "Bond %d%%%s" % [int(m.bond), "  " + STAR + " star" if m.has_star() else ""]
	if not m.can_go_to_barn():
		var mc = load("res://resources/monsters/monster_config.tres")
		status += "\nBarn at %d%%" % int(mc.barn_bond)
	var lines := [m.get_display_name(), "%s, rank %s" % [m.get_gender_name(), m.get_rank()], stats.strip_edges(),
		status, "Favorite: %s" % fav]
	if home == &"barn":
		lines.append("Food %s  Water %s" % ["yes" if m.fed_today else "no", "yes" if m.watered_today else "no"])
		if player_state.party.has(m):
			lines.append("In your party")
	if m.favorite_streak > 0:
		lines.append("Favorite streak: %d days" % m.favorite_streak)
	_detail.text = "\n".join(lines)


# --- UI construction -----------------------------------------------------------

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font_size = 9
	theme.set_color(&"font_color", &"Label", Color(0.29, 0.18, 0.16))
	root.theme = theme
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.position = Vector2(28, 24)
	_panel.custom_minimum_size = Vector2(584, 290)
	var sb := StyleBoxTexture.new()
	sb.texture = load(PANEL_TEX)
	sb.set_texture_margin_all(6)
	sb.set_content_margin_all(8)
	_panel.add_theme_stylebox_override(&"panel", sb)
	root.add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = _label("Care")
	_title.add_theme_font_size_override(&"font_size", 11)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(_label("Food:"))
	_food = OptionButton.new()
	_food.focus_mode = Control.FOCUS_NONE
	_food.custom_minimum_size = Vector2(110, 0)
	_food.item_selected.connect(_on_food_selected)
	head.add_child(_food)
	_water = _button("Water troughs", water)
	head.add_child(_water)
	head.add_child(_button("Close", close))
	_needs = _label("")
	v.add_child(_needs)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(128, 0)
	body.add_child(side)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(64, 64)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	side.add_child(_portrait)
	_detail = _label("")
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(128, 0)
	side.add_child(_detail)
	_message = _label("")
	v.add_child(_message)


func _on_food_selected(index: int) -> void:
	var foods := get_food_ids()
	if index >= 0 and index < foods.size():
		food_id = foods[index]
	refresh()


func _bond_bar(value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = value
	bar.custom_minimum_size = Vector2(60, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxTexture.new()
	bg.texture = load(BAR_BG_TEX)
	bg.set_texture_margin_all(3)
	var fill := StyleBoxTexture.new()
	fill.texture = load(BAR_FILL_TEX)
	fill.set_texture_margin_all(3)
	fill.set_expand_margin_all(-2)
	bar.add_theme_stylebox_override(&"background", bg)
	bar.add_theme_stylebox_override(&"fill", fill)
	return bar


func _label(text: String, min_width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = min_width
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
