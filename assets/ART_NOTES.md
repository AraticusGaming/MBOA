# MBOA Art Notes (Milestone 1 + 1b polish)

Style: strict 16-bit, cozy, Stardew-like. Clean pixels, no anti-aliasing, no blur,
one pixel scale. Colored (plum-brown / dark green / dark red) outlines, never pure black.

## Palette
- Master palette (32 colors): `tools/art/palette.py` (`PALETTE`, index order = swatch order).
- Swatch: `tools/art/palette.png` (8x4 grid of 16x16 swatches, left-to-right, top-to-bottom).
- Every opaque pixel in shipped PNGs is a palette color; alpha is only 0 or 255.

## Regenerating
- `python3 tools/art/gen_m1b_polish.py` (Pillow) writes the tileset, bed, tool icons, tree
  stages and `assets/ui/*`. It owns `farm_tiles.png` (it reuses the M1 tile functions for
  every tile that did not change, so tiles 0-2 and 6-12 are pixel-identical to M1).
- `python3 tools/art/gen_m1_farm.py` writes the player sheet, crop sheet and palette swatch
  (and the same tileset, via `gen_m1b_polish.build_tileset()`).
- Both take `--preview DIR` for 8x nearest-neighbor previews outside the repo
  (`tools/art/preview_m1b.py` also renders a mock farm scene and a mock HUD).
- Do not hand-edit the PNGs; change the generator. M1b added no palette colors (0-31 only).

## Godot import
Use nearest filtering (already set in `project.godot`), no mipmaps, integer scaling.
Frame/tile indices below are 0-based, row-major (index = row * columns + col).

## assets/tilesets/farm_tiles.png (128x112, 16x16 tiles, 8 columns x 7 rows)
Indices 0-12 mean the same as in M1 (atlas coords unchanged). M1b redrew 3-5 in place and
appended everything else. Index = row * 8 + col; atlas coords = (idx % 8, idx / 8).

| idx | atlas (col,row) | tile | notes |
|----:|-----------------|------|-------|
| 0 | (0,0) | grass_a | seamless |
| 1 | (1,0) | grass_b | seamless variant |
| 2 | (2,0) | grass_flowers | seamless variant, use sparingly |
| 3 | (3,0) | dirt | seamless, untilled ground (M1b redraw, same role) |
| 4 | (4,0) | tilled_soil | seamless; dry: warm brown, horizontal furrows with sunlit ridge tops (M1b redraw) |
| 5 | (5,0) | watered_soil | seamless; same furrow layout as 4 but much darker/wetter, cool glints on ridges, blue-dark puddles in grooves (M1b redraw). Swap 4 <-> 5 when watered |
| 6 | (6,0) | path_stone | seamless cobbles |
| 7 | (7,0) | path_packed | seamless packed dirt (also the interior texture of the path autotile set) |
| 8 | (0,1) | fence_post | transparent bg, overlay layer (M1 piece; prefer the autotile set below) |
| 9 | (1,1) | fence_rail_h | transparent, tiles horizontally |
| 10 | (2,1) | fence_rail_v | transparent, tiles vertically |
| 11 | (3,1) | fence_post_rail_h | post with rails both sides (horizontal run) |
| 12 | (4,1) | fence_post_rail_v | post on a vertical run |
| 13 | (5,1) | grass_tufts | seamless grass variant: tall 3-blade tufts |
| 14 | (6,1) | grass_stones | seamless grass variant: two small stones + pebbles |
| 15 | (7,1) | grass_clover | seamless grass variant: clover patches, one blossom |
| 16 | (0,2) | grass_flowers_yellow | seamless grass variant: small yellow flowers, use sparingly |
| 17 | (1,2) | dirt_pebbles | seamless dirt variant (more pebbles, one stone) |
| 18 | (2,2) | dirt_stones_twig | seamless dirt variant (stone + twig) |
| 19-23 | (3..7,2) | empty | reserved |
| 24-39 | rows 3-4 | fence autotile | `24 + mask`, transparent overlay (see bitmask) |
| 40-55 | rows 5-6 | path autotile | `40 + mask`, transparent overlay on grass (see bitmask) |

Ground layer suggestion: grass 0/1 as the bulk, 13/14/15 at roughly 5-10% each, 2 and 16 at
1-3%; dirt 3 with 17/18 at about 15% each. All ground tiles (0-7, 13-18) are fully opaque.

### Autotile bitmask (fence 24-39, path 40-55)
4-bit, one bit per orthogonal neighbor of the same kind (fence next to fence, path next to path):
`N = 1, E = 2, S = 4, W = 8`; `mask = N|E|S|W` of the connected sides; `tile = base + mask`.

| mask | sides | fence tile | path tile | shape |
|----:|-------|-----:|-----:|-------|
| 0 | none | 24 | 40 | lone post / single path pad |
| 1 | N | 25 | 41 | end cap (open to N) |
| 2 | E | 26 | 42 | end cap (open to E) |
| 3 | N E | 27 | 43 | corner (L: N+E) |
| 4 | S | 28 | 44 | end cap (open to S) |
| 5 | N S | 29 | 45 | vertical straight |
| 6 | E S | 30 | 46 | corner (E+S) |
| 7 | N E S | 31 | 47 | T-junction (no W) |
| 8 | W | 32 | 48 | end cap (open to W) |
| 9 | N W | 33 | 49 | corner (N+W) |
| 10 | E W | 34 | 50 | horizontal straight |
| 11 | N E W | 35 | 51 | T-junction (no S) |
| 12 | S W | 36 | 52 | corner (S+W) |
| 13 | N S W | 37 | 53 | T-junction (no E) |
| 14 | E S W | 38 | 54 | T-junction (no N) |
| 15 | all | 39 | 55 | cross |

- Fence: every tile has a post; connected sides get rails (horizontal rails E/W, a thin
  vertical rail N/S). Draw on a layer above the ground; draw rows top-to-bottom.
- Path: packed-dirt path with a sunlit top lip, shaded lip and a dark-grass rim, transparent
  outside, so it sits on any grass tile. Corners of a tile are filled only when both adjacent
  sides connect, so 2-wide paths/plazas fill solid (inner corners of an L stay square).
- Godot: either place by script (`base + mask`), or set up a TileSet terrain later; the
  order above is the plain 4-bit order, not Godot's terrain peering layout.

Tiles 0-7 and 13-18 are fully opaque ground tiles; 8-12 and 24-55 belong on a layer above the ground.

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

## Godot integration status (Cody)
- farm_tiles.png -> `resources/farm_tileset.tres` (atlas source 0, tiles 0-12; M1b tiles 13-55
  are not in the .tres yet: raise `TILE_COUNT` in `tools/godot/build_art_resources.gd` to 56 and
  skip empty 19-23 when wiring them). Ground uses
  grass 0-2 (weighted, seeded); plots use 3 dirt / 4 tilled / 5 watered via
  `resources/farm_tile_mapping.tres`. Paths (6-7) and fences (8-12) not placed yet.
- player_base.png -> `resources/player_frames.tres`: `idle_<dir>` (cols 0-3, 4 fps) and
  `walk_<dir>` (cols 4-7, 8 fps), AnimatedSprite2D offset (0, -16), origin = feet.
- crop_basic.png -> `resources/crops/placeholder_crop.tres` (`stage_frames` [0,1,2,3], one
  frame per GDD growth stage; frame 3 = harvest-ready), drawn bottom-centered on the plot cell.
- Trees have no art yet: `FarmGrid` draws placeholder rectangles for the seed, seedling,
  sapling, grown (canopy extends one cell above) and stump states.
- Regenerate the .tres files with `tools/godot/build_art_resources.gd` if a layout changes.
- M1b art for bed, HUD, toolbar, tool icons and trees exists (below) but is not wired in yet.

## assets/sprites/bed.png (16x32, single frame)
- Cozy single bed seen top-down: wooden headboard (rows 0-4), pillow (rows 6-12), turned-down
  sheet (13-15), red patchwork quilt (16-26), footboard (27-31). Fully fills 16x32.
- Size decision: 16x32 (one tile wide, two tall), matching the player frame.
- Anchor: top-left at a tile corner, covering 1x2 cells; or bottom-center (8, 32) if placed
  like the player. Current `scenes/world/bed.tscn` collision is 20x28; 16x32 is suggested.

## Tool icons (assets/sprites/item_*.png, 16x16 each, transparent, outlined)
| file | tool |
|------|------|
| item_pulaski.png | Pulaski: red head with axe blade (top-left) and adze/hoe blade (bottom-right), wood handle |
| item_sickle.png | sickle: crescent steel blade, short wood handle |
| item_pickaxe.png | pickaxe |
| item_watering_can.png | blue watering can with spout and rose |
Drawn with a 1px plum outline and at least a 0-1px transparent margin; center in a 16x16 slot.

## assets/sprites/tree_stages.png (160x48, 32x48 frames, 5 columns x 1 row)
| frame | stage | visible pixels (x0,y0)-(x1,y1) in frame | footprint |
|------:|-------|--------------------------|-----------|
| 0 | seed (planted, dirt mound) | (11,43)-(21,48) | 1 cell |
| 1 | seedling | (9,37)-(21,48) | 1 cell |
| 2 | sapling | (8,17)-(24,48) | 1 cell wide, ~2 tall |
| 3 | grown | (1,0)-(31,48) | trunk on 1 cell; canopy ~2 cells wide, 3 tall |
| 4 | stump (after felling, for the 4 stump hits) | (9,40)-(23,48) | 1 cell |
- All frames share one size so a single region size works. Anchor = bottom-center (16, 48):
  put that point on the bottom-center of the tree's cell (frame top-left = cell bottom-center
  + (-16, -48)). Trunk/base sits in the bottom 16 rows, centered on x = 15-16.
- Sprite2D: `centered = true`, `offset = (0, -24)`, position = cell bottom-center.
- Draw trees y-sorted with the player so the canopy covers things behind it.

## UI (assets/ui/, wood-and-parchment, palette colors only)
Use NinePatchRect (or StyleBoxTexture) with nearest filtering. Edge strips are uniform along
their length, so `axis_stretch` STRETCH and TILE both work. Scale UI only by integers.

| file | size | 9-slice margins (L,T,R,B) | use |
|------|------|---------------------------|-----|
| hud_panel.png | 18x18 | 6,6,6,6 | panel for clock / date / gold; parchment center (`sand`); content padding 7px from the outer edge |
| toolbar_frame.png | 18x18 | 6,6,6,6 | hotbar background; dark recessed wood center (`brown`) |
| toolbar_slot.png | 20x20 | not sliced | slot: 2px frame, 16x16 item area at (2,2) |
| toolbar_slot_selected.png | 20x20 | not sliced | selected slot: red + yellow frame, same item area (2,2) |
| bar_frame.png | 32x10 | 3,3,3,3 | health/stamina bar frame; inner trough is 4px tall, starts at (3,3) |
| bar_fill_stamina.png | 4x4 | stretch/tile horizontally | stamina fill (green) for the trough |
| bar_fill_health.png | 4x4 | stretch/tile horizontally | health fill (red) |
| hud_icons.png | 32x8 (8x8 frames) | - | 0 health heart, 1 stamina bolt, 2 gold coin, 3 bond heart (pink) |

Hotbar layout used in the mock: width = 12 + 20*n + (n-1) (6px frame each side, 1px gaps),
height 32; slot i at (6 + 21*i, 6); item icon at slot + (2, 2).
For a TextureProgressBar: `texture_under`/`texture_over` = bar_frame (nine_patch_stretch,
margins 3), `texture_progress` = a fill, `texture_progress_offset` = (3, 3), and size the
fill to the 4px trough. The wood ring is: outline, bevel light/dark, mid wood, inner bevel,
dark inner edge; brass nail heads sit at (3,3) in each corner of the 18x18 frames.

## Coming later
- Starter monsters default to **32x32** frames; idle animations will be **2-4 frames**,
  one row per animation, transparent PNG sheets in `assets/sprites/`.
- NPC portraits 64x64 in `assets/portraits/`. Still to come: inventory panel and clock face art
  (the HUD panel above holds the clock text for now).
