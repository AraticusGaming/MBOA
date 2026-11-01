class_name ShopCounter
extends Area2D
## Placeholder shop counter + shopkeeper. Not GDD, placeholder: the GDD shop
## is in the Village (not built yet), so for Milestone 2 a counter stands on
## the farm. Stand at it and press interact to open the ShopUI (group
## "shop_ui") for `shop`.

signal opened(shop: ShopData)

@export var shop: ShopData
@export var size: Vector2 = Vector2(32, 14)
@export var color_counter: Color = Color(0.55, 0.36, 0.2)
@export var color_top: Color = Color(0.72, 0.52, 0.3)
@export var color_keeper: Color = Color(0.8, 0.35, 0.55)
@export var color_keeper_head: Color = Color(0.95, 0.8, 0.65)


func _ready() -> void:
	add_to_group(&"shop_counter")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Called by Player.interact(). Opens the shop UI.
func use(by: Node = null) -> bool:
	opened.emit(shop)
	var ui := get_tree().get_first_node_in_group(&"shop_ui") if is_inside_tree() else null
	if ui and ui.has_method(&"open"):
		ui.open(shop)
		return true
	return ui == null and by != null


func _draw() -> void:
	# Shopkeeper behind the counter, counter in front.
	draw_rect(Rect2(-4, -size.y - 14, 8, 10), color_keeper)
	draw_rect(Rect2(-4, -size.y - 22, 8, 8), color_keeper_head)
	var r := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	draw_rect(r, color_counter)
	draw_rect(Rect2(r.position, Vector2(size.x, 3)), color_top)
	draw_rect(r, color_counter.darkened(0.4), false, 1.0)


func _on_body_entered(body: Node) -> void:
	if body.has_method(&"register_interactable"):
		body.register_interactable(self, true)


func _on_body_exited(body: Node) -> void:
	if body.has_method(&"register_interactable"):
		body.register_interactable(self, false)
