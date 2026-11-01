extends Area2D
## Placeholder exit stone in a room: the player stands on it and presses
## interact (Player.interact -> use()).

signal used


func _ready() -> void:
	body_entered.connect(func(b): if b.has_method(&"register_interactable"): b.register_interactable(self, true))
	body_exited.connect(func(b): if b.has_method(&"register_interactable"): b.register_interactable(self, false))


func use(_by: Node = null) -> bool:
	used.emit()
	return true
