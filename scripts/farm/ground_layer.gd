class_name GroundLayer
extends TileMapLayer
## Fills a rectangle with grass tiles from the farm TileSet. ART_NOTES: grass
## 0/1 as the bulk, 13/14/15 (tufts, stones, clover) at about 5-10% each,
## 2 and 16 (flowers) at 1-3%. Deterministic (seeded) so the map looks the
## same every run.

@export var size_in_tiles: Vector2i = Vector2i(40, 23)
@export var source_id: int = 0
## Grass atlas coords and their relative weights.
@export var tiles: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1), Vector2i(0, 2)]
@export var weights: PackedFloat32Array = [0.44, 0.28, 0.02, 0.08, 0.07, 0.09, 0.02]
@export var random_seed: int = 1337


func _ready() -> void:
	fill()


func fill() -> void:
	clear()
	if tile_set == null or tiles.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var w := weights if weights.size() == tiles.size() else PackedFloat32Array()
	for y in size_in_tiles.y:
		for x in size_in_tiles.x:
			var idx := rng.rand_weighted(w) if not w.is_empty() else rng.randi_range(0, tiles.size() - 1)
			set_cell(Vector2i(x, y), source_id, tiles[idx])
