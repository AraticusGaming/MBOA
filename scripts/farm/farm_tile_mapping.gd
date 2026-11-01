class_name FarmTileMapping
extends Resource
## Data-driven mapping from FarmPlot state (and decoration) to tiles in the
## farm TileSet (resources/farm_tileset.tres, built from
## assets/tilesets/farm_tiles.png). Atlas coords follow assets/ART_NOTES.md
## (col,row, 16x16 tiles, index = row * 8 + col).
##
##   EMPTY                     -> empty_tile   (3,0) dirt; some cells use the
##                                dirt variants 17/18 (seeded by cell)
##   TILLED / PLANTED          -> tilled_tile  (4,0) tilled_soil
##   TILLED / PLANTED, watered -> watered_tile (5,0) watered_soil
## Crops are drawn on top from their own CropData sprite sheet.
##
## Fence and path autotiles (ART_NOTES "Autotile bitmask"): one bit per
## orthogonal neighbour of the same kind, N = 1, E = 2, S = 4, W = 8;
## tile index = base + mask (fence 24-39, path 40-55).

const N := 1
const E := 2
const S := 4
const W := 8

@export var source_id: int = 0
@export var columns: int = 8
@export var empty_tile: Vector2i = Vector2i(3, 0)
@export var tilled_tile: Vector2i = Vector2i(4, 0)
@export var watered_tile: Vector2i = Vector2i(5, 0)
## Dirt variants (ART_NOTES: 17 dirt_pebbles, 18 dirt_stones_twig, ~15% each).
@export var empty_variants: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2)]
## Chance (0..1) an empty cell uses a variant instead of plain dirt.
@export_range(0.0, 1.0, 0.01) var empty_variant_chance: float = 0.3
@export var fence_base: int = 24
@export var path_base: int = 40


func get_atlas_coords(plot: FarmPlot, cell: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	if plot == null or plot.state == FarmPlot.State.EMPTY:
		return empty_coords(cell)
	return watered_tile if plot.watered else tilled_tile


## Plain dirt or a dirt variant, stable per cell (cell -1,-1 = always plain).
func empty_coords(cell: Vector2i) -> Vector2i:
	if empty_variants.is_empty() or cell.x < 0 or cell.y < 0:
		return empty_tile
	var h := _hash01(cell)
	if h >= empty_variant_chance:
		return empty_tile
	var i := int(h / empty_variant_chance * empty_variants.size())
	return empty_variants[clampi(i, 0, empty_variants.size() - 1)]


func index_to_coords(index: int) -> Vector2i:
	return Vector2i(index % columns, index / columns)


func fence_coords(mask: int) -> Vector2i:
	return index_to_coords(fence_base + (mask & 15))


func path_coords(mask: int) -> Vector2i:
	return index_to_coords(path_base + (mask & 15))


## ART_NOTES bitmask of `cell` against a set of same-kind cells (a Dictionary
## used as a set, keys Vector2i). N is y - 1.
static func mask_for(cell: Vector2i, same: Dictionary) -> int:
	var m := 0
	if same.has(cell + Vector2i.UP):
		m |= N
	if same.has(cell + Vector2i.RIGHT):
		m |= E
	if same.has(cell + Vector2i.DOWN):
		m |= S
	if same.has(cell + Vector2i.LEFT):
		m |= W
	return m


static func _hash01(cell: Vector2i) -> float:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h ^ (h >> 16)) % 10007) / 10007.0
