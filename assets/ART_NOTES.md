# MBOA Art Notes (Milestone 1)

Style: strict 16-bit, cozy, Stardew-like. Clean pixels, no anti-aliasing, no blur,
one pixel scale. Colored (plum-brown / dark green / dark red) outlines, never pure black.

## Palette
- Master palette (32 colors): `tools/art/palette.py` (`PALETTE`, index order = swatch order).
- Swatch: `tools/art/palette.png` (8x4 grid of 16x16 swatches, left-to-right, top-to-bottom).
- Every opaque pixel in shipped PNGs is a palette color; alpha is only 0 or 255.

## Regenerating
`python3 tools/art/gen_m1_farm.py` (Pillow). Optional `--preview DIR` writes 8x
nearest-neighbor previews outside the repo. Do not hand-edit the PNGs; change the generator.

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

## Coming later
- Starter monsters default to **32x32** frames; idle animations will be **2-4 frames**,
  one row per animation, transparent PNG sheets in `assets/sprites/`.
- NPC portraits 64x64 in `assets/portraits/`. UI (bond hearts, clock, inventory) to follow.
