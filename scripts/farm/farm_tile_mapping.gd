class_name FarmTileMapping
extends Resource
## Data-driven mapping from FarmPlot state to a tile in the farm TileSet
## (resources/farm_tileset.tres, built from assets/tilesets/farm_tiles.png).
## Atlas coords follow assets/ART_NOTES.md (col,row, 16x16 tiles).
##
##   EMPTY                     -> empty_tile   (3,0) dirt, untilled ground
##   TILLED / PLANTED          -> tilled_tile  (4,0) tilled_soil
##   TILLED / PLANTED, watered -> watered_tile (5,0) watered_soil
## Crops are drawn on top from their own CropData sprite sheet.

@export var source_id: int = 0
@export var empty_tile: Vector2i = Vector2i(3, 0)
@export var tilled_tile: Vector2i = Vector2i(4, 0)
@export var watered_tile: Vector2i = Vector2i(5, 0)


func get_atlas_coords(plot: FarmPlot) -> Vector2i:
	if plot == null or plot.state == FarmPlot.State.EMPTY:
		return empty_tile
	return watered_tile if plot.watered else tilled_tile
