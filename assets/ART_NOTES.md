# MBOA Art Notes (Milestone 1 + creatures)

Style: strict 16-bit, cozy, Stardew-like. Clean pixels, no anti-aliasing, no blur,
one pixel scale. Colored (plum-brown / dark green / dark red) outlines, never pure black.

## Palette
- Master palette (38 colors): `tools/art/palette.py` (`PALETTE`, index order = swatch order).
  Indices 0-31 are the original M1 colors and never change; new colors are only appended.
- Swatch: `tools/art/palette.png` (8 columns of 16x16 swatches, left-to-right, top-to-bottom;
  8x5 grid now, last row partly filled).
- Ember extension (added for Cinderkin, use for any fire / glow art):

| idx | name | hex | use |
|----:|------|-----|-----|
| 32 | ember_deep | `#c23b22` | flame edges (deep red-orange) |
| 33 | ember_orange | `#f26b2a` | flame body, membrane centres |
| 34 | ember_amber | `#ffa23a` | flame mid, eyes, lit membrane rims |
| 35 | ember_yellow | `#ffd25a` | flame core, ear-glow flicker |
| 36 | ember_cream | `#fff2c2` | hottest highlight (flame tips/core) |
| 37 | ember_glow | `#e8894e` | soft glow: ear interiors, gliding membranes |

  Flames are outlined with `red_dark` (20); fur with `outline` (0).
- Every opaque pixel in shipped PNGs is a palette color; alpha is only 0 or 255.

## Regenerating
`python3 tools/art/gen_m1_farm.py` (farm, player, crops) and
`python3 tools/art/gen_cinderkin.py` (Cinderkin sheet, portrait, Wet Waxweed icon), Pillow.
Both take an optional `--preview DIR` that writes 8x nearest-neighbor previews outside the repo. Do not hand-edit the PNGs; change the generator.

## Godot import
Use nearest filtering (already set in `project.godot`), no mipmaps, integer scaling.
Frame/tile indices below are 0-based, row-major (index = row * columns + col).

## assets/tilesets/farm_tiles.png (128x32, 16x16 tiles, 8 columns x 2 rows)
| idx | atlas (col,row) | tile | notes |
|----:|-----------------|------|-------|
| 0 | (0,0) | grass_a | seamless |
| 1 | (1,0) | grass_b | seamless variant |
| 2 | (2,0) | grass_flowers | seamless variant, use sparingly |
| 3 | (3,0) | dirt | seamless, untilled ground |
| 4 | (4,0) | tilled_soil | seamless |
| 5 | (5,0) | watered_soil | seamless, same layout as 4 (swap 4 <-> 5 when watered) |
| 6 | (6,0) | path_stone | seamless cobbles |
| 7 | (7,0) | path_packed | seamless packed dirt |
| 8 | (0,1) | fence_post | transparent bg, overlay layer |
| 9 | (1,1) | fence_rail_h | transparent, tiles horizontally |
| 10 | (2,1) | fence_rail_v | transparent, tiles vertically |
| 11 | (3,1) | fence_post_rail_h | post with rails both sides (horizontal run) |
| 12 | (4,1) | fence_post_rail_v | post on a vertical run |
| 13-15 | (5..7,1) | empty | reserved |

Tiles 0-7 are fully opaque ground tiles; 8-12 belong on a layer above the ground.

## assets/sprites/player_base.png (128x128, 16x32 frames, 8 columns x 4 rows)
- Rows (direction): 0 = down, 1 = left, 2 = right, 3 = up.
- Columns: 0-3 = idle frames 1-4 (subtle breathing bob), 4-7 = walk frames 1-4.
- Frame index = row * 8 + col. Example: walk left = 12, 13, 14, 15; idle up = 24..27.
- Suggested speeds: idle 4-5 fps, walk 8 fps, both looping.
- Feet sit on the bottom pixel row (y = 31); origin/pivot at bottom-center (8, 32),
  so the character's feet align to a 16x16 tile when offset by (0, -16).
- Placeholder only; male/female variants will come later with the same layout.

## assets/sprites/crop_basic.png (64x16, 16x16 frames, 4 columns x 1 row)
| frame | stage |
|------:|-------|
| 0 | seed (just planted) |
| 1 | growth stage 1 (sprout) |
| 2 | growth stage 2 (leafy) |
| 3 | harvest-ready (turnip-style root) |
Transparent background; draw on a layer above tilled/watered soil (tiles 4/5).

## assets/sprites/cinderkin.png (256x128, 32x32 frames, 8 columns x 4 rows)
Cinderkin (Critter + Fire), first creature sprite. **32x32**, not 16x16: at 16x16 the big
ears with their glow, the eyes, the membranes, the crest and the flame tail could not all stay
readable, so it uses the starter-monster default of 32x32 (2x2 tiles).
- Same layout as `player_base.png`. Rows (direction): 0 = down, 1 = left, 2 = right
  (mirror of left), 3 = up.
- Columns: 0-3 = idle frames 1-4 (flame tail/crest flicker, ear glow pulse, 1px breathing
  bob on frames 3-4), 4-7 = walk/scurry frames 1-4 (alternating feet, 1px bounce,
  membranes flap up on frames 1-3).
- Frame index = row * 8 + col: idle down 0-3, walk down 4-7, idle left 8-11, walk left
  12-15, idle right 16-19, walk right 20-23, idle up 24-27, walk up 28-31.
- Suggested speeds: idle 6 fps (flame flicker reads better a bit faster than the player),
  walk 8 fps, both looping.
- Feet sit on the bottom pixel row (y = 31). Origin/pivot at bottom-center (16, 32), i.e.
  AnimatedSprite2D offset (0, -16) with the node at the creature's feet. Body footprint is
  about x 7-24, so it collides like one 16x16 tile; ears/tail/membranes overhang.
- No separate glide row yet; the walk cycle doubles as a short hop-glide. A spread-wing glide
  row (row 4) can be appended later without moving existing indices.

## assets/portraits/cinderkin_portrait.png (64x64)
Bust/face view, transparent background (a few loose ember pixels around the head). Same
palette; frame it with the dialogue/UI box like the NPC portraits.

## Items
- `assets/sprites/item_wet_waxweed.png` (16x16): Wet Waxweed, Cinderkin's favorite food.
  Damp moss clump with water sheen and a drip. Transparent; item icons use `item_<snake_name>.png`
  in `assets/sprites/` until there are enough items for an atlas.

## Godot integration status (Cody)
- farm_tiles.png -> `resources/farm_tileset.tres` (atlas source 0, tiles 0-12). Ground uses
  grass 0-2 (weighted, seeded); plots use 3 dirt / 4 tilled / 5 watered via
  `resources/farm_tile_mapping.tres`. Paths (6-7) and fences (8-12) not placed yet.
- player_base.png -> `resources/player_frames.tres`: `idle_<dir>` (cols 0-3, 4 fps) and
  `walk_<dir>` (cols 4-7, 8 fps), AnimatedSprite2D offset (0, -16), origin = feet.
- crop_basic.png -> `resources/crops/placeholder_crop.tres` (`stage_frames` [0,1,2,3], one
  frame per GDD growth stage; frame 3 = harvest-ready), drawn bottom-centered on the plot cell.
- Trees have no art yet: `FarmGrid` draws placeholder rectangles for the seed, seedling,
  sapling, grown (canopy extends one cell above) and stump states.
- Regenerate the .tres files with `tools/godot/build_art_resources.gd` if a layout changes.
- Still placeholder shapes: bed, HUD.

## Coming later
- Starter monsters default to **32x32** frames and follow the Cinderkin sheet layout
  (direction rows, 4 idle + 4 walk columns), transparent PNG sheets in `assets/sprites/`.
- NPC portraits 64x64 in `assets/portraits/`. UI (bond hearts, clock, inventory) to follow.
