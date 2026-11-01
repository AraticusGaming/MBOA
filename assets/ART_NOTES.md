# MBOA Art Notes (Milestone 1, 1b polish, creatures, slice 3 Woodland)

Style: strict 16-bit, cozy, Stardew-like. Clean pixels, no anti-aliasing, no blur,
one pixel scale. Colored (plum-brown / dark green / dark red) outlines, never pure black.

## Palette
- Master palette (42 colors): `tools/art/palette.py` (`PALETTE`, index order = swatch order).
  Indices 0-31 are the original M1 colors and never change; new colors are only appended.
- Swatch: `tools/art/palette.png` (8 columns of 16x16 swatches, left-to-right, top-to-bottom;
  8x6 grid now, last row partly filled).
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
- Woodland extension (slice 3, for forest floor and the tree wall):

| idx | name | hex | use |
|----:|------|-----|-----|
| 38 | loam | `#5b4a31` | olive-brown forest floor base (darker, greener than farm dirt) |
| 39 | loam_dark | `#3f3427` | floor specks, contact shadows, canopy shadow dither, path rim |
| 40 | moss | `#85963d` | muted olive moss (patches, mossy floor, log/rock caps) |
| 41 | canopy_deep | `#1a3126` | deepest gaps between canopy clumps in the tree wall |
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
- `python3 tools/art/gen_cinderkin.py` writes the Cinderkin sheet, portrait and Wet Waxweed icon (Pillow, optional `--preview DIR`).
- `python3 tools/art/gen_slice3_woodland.py` writes the Woodland tileset, the composed room
  background, the trap sheet and the bait icon (optional `--preview DIR`; `preview_slice3.py`
  renders a tiling test and a mock room with traps, bait, player and Cinderkin).
  `python3 tools/art/palette.py` rewrites the swatch after palette changes.

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
- farm_tiles.png -> `resources/farm_tileset.tres` (atlas source 0, tiles 0-18 and 24-55; empty 19-23
  skipped; `TILE_COUNT = 56` in `tools/godot/build_art_resources.gd`).
- Ground (`GroundLayer`): grass 0/1 bulk, 13/14/15 ~8% each, 2 and 16 ~2% (seeded).
- Plots (`resources/farm_tile_mapping.tres`): 3 dirt with 17/18 on ~30% of empty cells (stable per
  cell), 4 tilled, 5 watered.
- Fences and paths: `FarmDecor` (`scripts/farm/farm_decor.gd`, node `Farm/Decor`) places the
  autotiles by script, `base + mask` with N=1 E=2 S=4 W=8 (`FarmTileMapping.mask_for`). Layout
  (fence rectangles + gates, path rectangles) is data in `scenes/farm/farm.tscn`.
- player_base.png -> `resources/player_frames.tres`: `idle_<dir>` (cols 0-3, 4 fps) and
  `walk_<dir>` (cols 4-7, 8 fps), AnimatedSprite2D offset (0, -16), origin = feet.
- cinderkin.png -> `resources/monsters/cinderkin_frames.tres` (same names, idle 6 fps, walk 8 fps,
  32x32), set as `SpeciesData.sprite_frames`; the portrait is `SpeciesData.portrait`.
- crop_basic.png -> `resources/crops/placeholder_crop.tres` (`stage_frames` [0,1,2,3]).
- tree_stages.png -> `TreeData.sprite_sheet` (32x48 frames, bottom-center on the cell).
- bed.png -> Sprite2D in `scenes/world/bed.tscn`, collision 16x32.
- Tool icons -> `ToolData.icon`; item_wet_waxweed.png -> `ItemData.icon` (other items still use a
  colored square).
- HUD: `hud_panel` (info panel), `bar_frame` + fills (health/stamina), `toolbar_frame` +
  `toolbar_slot(_selected)` (hotbar). `hud_icons.png` is not used yet.
- Regenerate the .tres files with `tools/godot/build_art_resources.gd` if a layout changes.

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

## assets/tilesets/woodland_tiles.png (128x144, 16x16 tiles, 8 columns x 9 rows)
Woodland Assessment room. Index = row * 8 + col; atlas coords = (idx % 8, idx / 8).
Opaque ground tiles: 0-7, 26, 27, 34, 35, 38. Everything else is a transparent overlay.

| idx | name | notes |
|----:|------|-------|
| 0 | floor_a | forest floor (loam), seamless; bulk ground |
| 1 | floor_b | seamless variant (a moss speck, a pebble) |
| 2 | leaf_litter_a | seamless, 3 fallen leaves |
| 3 | leaf_litter_b | seamless, 4 fallen leaves |
| 4 | floor_twigs | seamless, forked twig + leaf + pebble |
| 5 | floor_pebbles | seamless, pebbles |
| 6 | floor_mossy | seamless, floor partly grown over with moss (moss stays off the edge pixels) |
| 7 | floor_sprouts | seamless, 4 small green sprouts |
| 8 | moss_patch_small | overlay, flat moss blob |
| 9 | moss_patch_large | overlay, larger moss blob |
| 10 | rock_small | overlay, outlined rock with contact shadow |
| 11 | rock_pair | overlay, two small rocks |
| 12 | rock_mossy | overlay, rock with a moss cap |
| 13 | mushrooms_red | overlay, two red-capped toadstools |
| 14 | mushrooms_brown | overlay, cluster of three brown mushrooms |
| 15 | fern | overlay, low fern |
| 16 | bush | overlay, round bush (fills the tile, bottom row = ground shadow) |
| 17 | bush_berries | overlay, bush with red berries |
| 18 | fern_tall | overlay, tall fern |
| 19 | stump | overlay, mossy cut stump |
| 20 | log_left | overlay, fallen log: cut end (rings) + bark; continues E |
| 21 | log_mid | overlay, bark, tiles horizontally (repeat for longer logs) |
| 22 | log_right | overlay, rounded broken end; log runs 20, 21..., 22 |
| 23 | log_short | overlay, a whole 1-tile log with a sprout |
| 24, 25 / 32, 33 | boulder_tl, boulder_tr / boulder_bl, boulder_br | overlay, 2x2 mossy boulder (32x32): TL at (x,y), TR (x+1,y), BL (x,y+1), BR (x+1,y+1) |
| 26, 27, 34, 35 | canopy_fill_00, _10, _01, _11 | opaque canopy, one 32x32 seamless block (see tree wall) |
| 28, 29 | canopy_bottom_a, _b | overlay, lower fringe of the far (top) tree wall + canopy shadow; a has a trunk top |
| 30, 31 | trunk_base_a, _b | overlay, the row under 28/29: a = trunk with roots, b = undergrowth fern; shadow fades out |
| 36, 37 | canopy_top_a, _b | overlay, sunlit upper rim of the near (bottom) tree wall |
| 38 | path_fill | opaque, packed forest-dirt path, seamless (interior texture of the path set) |
| 39 | leaf_pile | overlay, heap of autumn leaves |
| 40, 41 | canopy_left_0, _1 | overlay, left tree wall (foliage on the left, edge on the right) |
| 42, 43 | canopy_right_0, _1 | overlay, right tree wall |
| 44, 45 | canopy_corner_tl, _tr | overlay, where the top wall's fringe meets the left / right wall |
| 46, 47 | canopy_corner_bl, _br | overlay, where the bottom wall's rim meets the left / right wall |
| 48-63 | path autotile | `48 + mask`, overlay on the floor (see bitmask) |
| 64 | flowers | overlay, white wood anemones + bluebells |
| 65 | twig_pinecone | overlay, fallen branch and a pinecone |
| 66-71 | empty | reserved |

### Tree wall (canopy tiles 26-47)
All canopy tiles are cut from ONE seamless 32x32 canopy block, so each one has a block position
`(bx, by)`; **put a canopy tile only on a cell where `(x % 2, y % 2) == (bx, by)`** (any 2x2-aligned
grid works). Then fill, fringe, rim, side and corner tiles all join with no seams.

| tiles | (bx, by) | | tiles | (bx, by) |
|-------|----------|-|-------|----------|
| 26 fill_00 | (0,0) | | 36 top_a | (0,1) |
| 27 fill_10 | (1,0) | | 37 top_b | (1,1) |
| 34 fill_01 | (0,1) | | 40 left_0 / 41 left_1 | (1,0) / (1,1) |
| 35 fill_11 | (1,1) | | 42 right_0 / 43 right_1 | (0,0) / (0,1) |
| 28 bottom_a | (0,0) | | 44 corner_tl / 45 corner_tr | (1,0) / (0,0) |
| 29 bottom_b | (1,0) | | 46 corner_bl / 47 corner_br | (1,1) / (0,1) |

- Far (top) wall: canopy fill rows, then a row of 28/29 (a at even x, b at odd x) on top of the
  floor, then a row of 30/31 under it (30 under 28, 31 under 29). Trunks repeat every 32 px with
  ferns between.
- Near (bottom) wall: a row of 36/37 (even/odd x) on the floor, canopy fill below it.
- Side walls: a column of 40/41 (left; must be on an odd x) or 42/43 (right; even x), with fill
  beyond. Corners 44-47 go where those runs meet. All wall overlays draw above the floor.
- The canopy is drawn top-down, not y-sorted: put the near (bottom) wall on a layer above
  actors if creatures should walk "under" it; the background PNG below is flat.

### Path autotile (48-63)
Same 4-bit order as the farm sets: `N = 1, E = 2, S = 4, W = 8`, `tile = 48 + mask` of the
orthogonal path neighbors (mask 0 = lone pad, 5 = vertical, 10 = horizontal, 15 = cross; full
table under farm_tiles). Packed dirt (38 inside), brown lips, a `loam_dark` rim outside and a
couple of drifted leaves; transparent outside the path so it sits on any floor tile. Corners
fill only when both adjacent sides connect.

Ground mix used in the room: 0 ~40%, 1 ~24%, 2 ~12%, 3 ~6%, 4/5/6/7 ~4-5% each, then overlays
(moss patches, rocks, ferns, mushrooms, flowers) at roughly one per 25 cells.

## assets/backgrounds/woodland_room.png (640x360, opaque)
Ready-made background for `scenes/world/assessment_room.tscn`, composed only from
woodland_tiles (grid 40x23 at 16 px, bottom row cut to 8 px; nothing hand-placed off-grid).
The GDD gives no room size, so it matches the room's existing draw area: the 640x360 viewport
with `room_rect` = (24, 56, 592, 280) from `resources/assessment/woodland.tres`.
- Draw at (0, 0) (Sprite2D `centered = false` or a TextureRect) under everything else.
- Tree wall: canopy rows 0-1, fringe row 2, trunks row 3 (y 48-64, so trunk feet sit at the
  room_rect top y = 56); left wall columns 0-1 (x 0-32), right wall columns 38-39 (x 608-640); near wall from row 21 (y 336).
- Path from the exit (48, 320) along y ~320 to the spawn (320, 300), with a spur north-east
  to (392, 232); it continues under the near canopy at x 48-64 as the way out.
- Props (logs, boulder at (544, 128) 32x32, bushes, ferns, stump) are decoration only, kept
  near the walls; there is no collision. The middle of the room stays open for wandering.
- Regenerate rather than edit; `room_layers()` in the generator holds the layout.

## assets/sprites/trap_basic.png (64x16, 16x16 frames, 4 columns x 1 row)
Basic Woodland trap: a slatted wooden crate with a prop stick, same wood colors and plum outline
as the fence/bed. **16x16**: it stays readable at 16 (crate, slats, stick, bait all read) and
matches an item/tile; 32x32 would make it as big as a creature.

| frame | state | look |
|------:|-------|------|
| 0 | idle | crate resting closed, prop stick lying in front (inventory / not yet set) |
| 1 | set | crate propped up on the stick, bait (red berry lump) visible underneath |
| 2 | shaking | snapped shut, amber eyes peering through the slats, jiggle marks; also shake the node 1 px left/right while `shake_seconds` runs |
| 3 | knocked_over | crate tipped toward the viewer, empty and dark inside, stick and dust scattered (bait gone) |

- Anchor: ground contact at pixel (8, 13) in every frame. Sprite2D `centered = true`,
  `offset = (0, -5)`, node at the trap position. Footprint about 14x11 px (one tile).
- Visible bounds: idle (1,2)-(15,16), set (1,0)-(15,15), shaking (0,2)-(16,14), knocked (0,2)-(16,16).

## assets/sprites/item_bait.png (16x16)
Bait: a tied cloth pouch with berries peeking out and a little sparkle. The GDD names no
specific bait item (crops or crops turned into biome bait), so this is the generic basic bait
icon. Visible (2,0)-(14,15); centered in the 16x16 slot like the other item icons.

## Coming later
- Starter monsters default to **32x32** frames and follow the Cinderkin sheet layout
  (direction rows, 4 idle + 4 walk columns), transparent PNG sheets in `assets/sprites/`.
- NPC portraits 64x64 in `assets/portraits/`. Still to come: inventory panel and clock face art
  (the HUD panel above holds the clock text for now).
