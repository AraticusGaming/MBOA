class_name FarmDecor
extends TileMapLayer
## Fence and path overlay on the farm (ART_NOTES autotiles, drawn above the
## ground). Placement is data: rectangles of fence (with gaps for gates) and
## path cells, in ground-tile coordinates (16 px). Each cell picks its tile
## from the 4-bit neighbour mask (FarmTileMapping.mask_for).

@export var tile_mapping: FarmTileMapping
## Fenced rectangles (the fence runs along each rectangle's border cells).
@export var fence_rects: Array[Rect2i] = []
## Border cells left open (gates).
@export var fence_gaps: Array[Vector2i] = []
## Single fence cells (in addition to the rectangles).
@export var fence_cells: Array[Vector2i] = []
## Path rectangles (filled) and single path cells.
@export var path_rects: Array[Rect2i] = []
@export var path_cells: Array[Vector2i] = []

var fences: Dictionary = {}
var paths: Dictionary = {}


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	clear()
	fences.clear()
	paths.clear()
	if tile_mapping == null:
		tile_mapping = load("res://resources/farm_tile_mapping.tres") as FarmTileMapping
	for r in fence_rects:
		for c in border_cells(r):
			fences[c] = true
	for c in fence_cells:
		fences[c] = true
	for g in fence_gaps:
		fences.erase(g)
	for r in path_rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				paths[Vector2i(x, y)] = true
	for c in path_cells:
		if not fences.has(c):
			paths[c] = true
	for c in paths:
		fences.erase(c)
	if tile_set == null:
		return
	for c in paths:
		set_cell(c, tile_mapping.source_id, tile_mapping.path_coords(FarmTileMapping.mask_for(c, paths)))
	for c in fences:
		set_cell(c, tile_mapping.source_id, tile_mapping.fence_coords(FarmTileMapping.mask_for(c, fences)))


static func border_cells(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if r.size.x <= 0 or r.size.y <= 0:
		return out
	for x in range(r.position.x, r.end.x):
		out.append(Vector2i(x, r.position.y))
		if r.size.y > 1:
			out.append(Vector2i(x, r.end.y - 1))
	for y in range(r.position.y + 1, r.end.y - 1):
		out.append(Vector2i(r.position.x, y))
		if r.size.x > 1:
			out.append(Vector2i(r.end.x - 1, y))
	return out
