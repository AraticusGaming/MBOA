"""Milestone 1b "polish" art generator (procedural, pixel-level, reproducible).

Owns (relative to repo root):
  assets/tilesets/farm_tiles.png      8-column 16x16 atlas; indices 0-12 keep their M1 meaning
                                      (3-5 redrawn), new ground variants + fence/path autotile sets
  assets/sprites/bed.png              16x32 single bed
  assets/sprites/item_pulaski.png     16x16 tool icons (also item_sickle, item_pickaxe,
  ...                                 item_watering_can)
  assets/sprites/tree_stages.png      32x48 frames: seed, seedling, sapling, grown, stump
  assets/ui/*.png                     toolbar / slot / HUD panel / bar frames, 8x8 HUD icons

Uses only tools/art/palette.py indices 0-31 (no new colors). Alpha is only 0 or 255.
Player and crop sheets are still produced by gen_m1_farm.py (it imports build_tileset from here).
Usage:  python3 tools/art/gen_m1b_polish.py [--preview DIR]
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from palette import RGBA, TRANSPARENT, c  # noqa: E402
import gen_m1_farm as m1  # noqa: E402

T = 16
new, blit_map, put, tile_fill = m1.new, m1.blit_map, m1.put, m1.tile_fill

# Autotile bitmask: N=1, E=2, S=4, W=8 (a neighbor of the same kind in that direction).
N, E, S, W = 1, 2, 4, 8
FENCE_BASE = 24   # tiles 24..39 = fence mask 0..15
PATH_BASE = 40    # tiles 40..55 = path mask 0..15


# --------------------------------------------------------------------------
# Ground tiles (seamless; wrap mod 16)
# --------------------------------------------------------------------------

def pebble(px, x, y, big=False):
    """Small stone with a shadow under it (wraps)."""
    put(px, x, y, "stone_pale")
    put(px, x + 1, y, "stone_light")
    put(px, x, y + 1, "stone_light")
    put(px, x + 1, y + 1, "stone")
    put(px, x, y + 2, "brown"); put(px, x + 1, y + 2, "brown")
    if big:
        put(px, x + 2, y, "stone_light"); put(px, x + 2, y + 1, "stone")
        put(px, x - 1, y + 1, "stone_light"); put(px, x + 2, y + 2, "brown")
        put(px, x - 1, y + 2, "brown")


def grass_base(seed):
    return m1.grass(seed)


def grass_tufts(seed=101):
    t = grass_base(seed)
    px = t.load()
    r = random.Random(seed)
    for (x, y) in ((2, 3), (10, 1), (6, 9), (13, 11), (1, 13)):
        x += r.choice((0, 1)); y += r.choice((0, 1))
        #  l.l.l   tall tuft, 3 blades
        #  GlGlG
        #  .GGG.
        for dx in (0, 2, 4):
            put(px, x + dx, y, "green_pale" if dx == 2 else "green_light")
        for dx in range(5):
            put(px, x + dx, y + 1, "green_light" if dx % 2 else "green")
        for dx in (1, 2, 3):
            put(px, x + dx, y + 2, "green_forest")
    return t


def grass_stones(seed=102):
    t = grass_base(seed)
    px = t.load()
    for (x, y) in ((3, 4), (11, 10)):
        # rounded stone with outline-ish dark bottom, sits in grass
        put(px, x + 1, y, "stone_pale"); put(px, x + 2, y, "stone_light")
        put(px, x, y + 1, "stone_pale"); put(px, x + 1, y + 1, "stone_light")
        put(px, x + 2, y + 1, "stone_light"); put(px, x + 3, y + 1, "stone")
        put(px, x, y + 2, "stone"); put(px, x + 1, y + 2, "stone")
        put(px, x + 2, y + 2, "stone"); put(px, x + 3, y + 2, "stone_dark")
        for dx in range(4):
            put(px, x + dx, y + 3, "green_forest")
    put(px, 8, 2, "stone_light"); put(px, 8, 3, "green_forest")
    put(px, 14, 5, "stone_light"); put(px, 14, 6, "green_forest")
    put(px, 5, 13, "stone_light"); put(px, 5, 14, "green_forest")
    return t


def grass_clover(seed=103):
    t = grass_base(seed)
    px = t.load()
    for (x, y) in ((2, 2), (9, 4), (4, 10), (12, 12)):
        # three-leaf clover: .L.  /  LdL  / .s.
        put(px, x + 1, y, "green_light")
        put(px, x, y + 1, "green_light"); put(px, x + 2, y + 1, "green_light")
        put(px, x + 1, y + 1, "green_forest")
        put(px, x, y + 2, "green"); put(px, x + 2, y + 2, "green")
        put(px, x + 1, y + 2, "green_forest")
    put(px, 13, 7, "white_warm"); put(px, 13, 8, "pink")  # one clover blossom
    put(px, 6, 7, "green_pale")
    return t


def grass_flowers_b(seed=104):
    t = grass_base(seed)
    px = t.load()
    for (x, y, petal) in ((3, 3, "yellow"), (11, 6, "yellow"), (6, 12, "yellow_pale"),
                          (14, 13, "yellow")):
        put(px, x, y, petal); put(px, x + 1, y, petal)
        put(px, x, y + 1, petal); put(px, x + 1, y + 1, "orange")
        put(px, x, y + 2, "green_forest")
    put(px, 8, 9, "white_warm"); put(px, 8, 10, "green_forest")
    put(px, 1, 8, "white_warm"); put(px, 1, 9, "green_forest")
    return t


def dirt(seed=11, pebbles=2, big=0, root=False):
    t = tile_fill("brown_mid")
    px = t.load()
    r = random.Random(seed)
    for _ in range(16):
        put(px, r.randrange(T), r.randrange(T), "brown")
    for _ in range(10):
        x, y = r.randrange(T), r.randrange(T)
        put(px, x, y, "brown_light")
    for _ in range(3):  # soft clumps: light top, dark under
        x, y = r.randrange(T), r.randrange(T)
        put(px, x, y, "brown_light"); put(px, x + 1, y, "brown_light")
        put(px, x, y + 1, "brown"); put(px, x + 1, y + 1, "brown")
    spots = [(3, 4), (11, 2), (7, 11), (13, 13), (1, 9)]
    r.shuffle(spots)
    for i in range(pebbles):
        x, y = spots[i]
        put(px, x, y, "stone_light"); put(px, x, y + 1, "brown")
    for i in range(big):
        x, y = spots[pebbles + i]
        pebble(px, x, y, big=True)
    if root:  # little twig
        for i, (x, y) in enumerate(((4, 7), (5, 7), (6, 8), (7, 8), (8, 8), (9, 9))):
            put(px, x, y, "brown_dark")
        put(px, 6, 7, "tan")
    return t


def j_at(jit, x):
    return jit[x % T]


def furrows(ridge_hi, ridge, base, groove, deep, speck, seed, sheen=None, puddle=None):
    """Horizontal furrow rows, period 4px (seamless). Ridge top light, groove dark."""
    t = tile_fill(base)
    px = t.load()
    r = random.Random(seed)
    # per-column 0/1 jitter keeps rows hand-made looking; wraps cleanly (same jitter set per row)
    for row in range(4):
        y0 = row * 4
        jit = [0] * T
        for k in range(r.randrange(2, 4)):
            s = r.randrange(T)
            for d in range(r.randrange(2, 5)):
                jit[(s + d) % T] = 1
        for x in range(T):
            j = jit[x]
            put(px, x, y0 + j, ridge_hi)
            put(px, x, y0 + 1 + j, ridge)
            put(px, x, y0 + 3, groove)
            if j:
                put(px, x, y0, ridge)
        # clod breaks along the ridge
        for _ in range(2):
            x = r.randrange(T)
            put(px, x, y0 + 1, groove); put(px, x + 1, y0 + 1, base)
        for _ in range(3):
            put(px, r.randrange(T), y0 + 3, deep)
        for _ in range(2):
            put(px, r.randrange(T), y0, speck)
        if sheen:  # wet glint on the ridge: dark-cool streak with one bright pixel
            x = r.randrange(T)
            put(px, x, y0 + j_at(jit, x), sheen[0]); put(px, x + 1, y0 + j_at(jit, x + 1), sheen[1])
            put(px, x + 2, y0 + j_at(jit, x + 2), sheen[0])
        if puddle:
            x = r.randrange(T)
            for d in range(r.randrange(2, 4)):
                put(px, x + d, y0 + 3, puddle)
    return t


def tilled():
    # dry: warm mid-brown, sunlit ridge tops with tan dust
    return furrows("brown_light", "brown_mid", "brown_mid", "brown", "brown_dark", "tan", 21)


def watered():
    # wet: much darker, cool sheen on ridges, puddles in grooves; same furrow layout (seed 21)
    return furrows("brown", "soil_wet", "soil_wet", "soil_dark", "outline", "brown", 21,
                   sheen=("stone_dark", "stone"), puddle="blue_dark")


# --------------------------------------------------------------------------
# Fence autotile (16 tiles, overlay layer)
# --------------------------------------------------------------------------

def fence_tile(mask):
    t = new(T, T)
    rh = m1.RAIL_H
    if mask & W:
        blit_map(t, [row[:8] + "." * 8 for row in rh], m1.WOOD)
    if mask & E:
        blit_map(t, ["." * 8 + row[8:] for row in rh], m1.WOOD)
    rv = m1.RAIL_V
    if mask & N:
        blit_map(t, rv[:8] + ["." * 16] * 8, m1.WOOD)
    if mask & S:
        blit_map(t, ["." * 16] * 8 + rv[8:], m1.WOOD)
    post = list(m1.POST)
    if mask in (N | S,):
        # straight vertical run: slimmer cap so the run reads as one fence line
        post[1] = ".....oooooo....."
    blit_map(t, post, m1.WOOD)
    return t


# --------------------------------------------------------------------------
# Path autotile (16 tiles, overlay layer on grass; interior = tile 7 texture)
# --------------------------------------------------------------------------

def path_inside_fn(mask):
    lo, hi = 2, 13

    def inside(x, y):
        x = min(max(x, 0), T - 1)  # outside the tile: continue the edge pixel
        y = min(max(y, 0), T - 1)
        inx, iny = lo <= x <= hi, lo <= y <= hi
        if inx and iny:
            # round convex corners of the center pad
            cx = x == lo and not mask & W or x == hi and not mask & E
            cy = y == lo and not mask & N or y == hi and not mask & S
            return not (cx and cy)
        if iny:
            return (x < lo and mask & W) or (x > hi and mask & E)
        if inx:
            return (y < lo and mask & N) or (y > hi and mask & S)
        # tile corners: only if both adjacent sides connect
        ns = N if y < lo else S
        we = W if x < lo else E
        return bool(mask & ns and mask & we)
    return inside


def path_tile(mask, interior):
    t = new(T, T)
    px = t.load()
    ip = interior.load()
    inside = path_inside_fn(mask)
    for y in range(T):
        for x in range(T):
            if inside(x, y):
                nb = [inside(x + dx, y + dy) for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0))]
                if not nb[0]:
                    px[x, y] = c("sand")             # sunlit top lip
                elif not nb[2]:
                    px[x, y] = c("brown_light")      # shaded bottom lip
                elif not nb[1] or not nb[3]:
                    px[x, y] = c("brown_light")
                else:
                    px[x, y] = ip[x, y]
            else:
                adj = [inside(x + dx, y + dy) for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0))]
                if any(adj):
                    # dark grass rim hugging the path (sits on grass ground)
                    px[x, y] = c("green" if (x + y) % 3 else "green_forest")
    # grass blades overhanging the lips
    r = random.Random(500 + mask)
    edge_px = [(x, y) for y in range(T) for x in range(T)
               if inside(x, y) and not all(inside(x + dx, y + dy) for dx, dy in
                                            ((0, -1), (1, 0), (0, 1), (-1, 0)))]
    for x, y in r.sample(edge_px, min(3, len(edge_px))):
        px[x, y] = c("green_grass")
    return t


# --------------------------------------------------------------------------
# Tileset
# --------------------------------------------------------------------------

TILE_NAMES = {
    0: "grass_a", 1: "grass_b", 2: "grass_flowers", 3: "dirt", 4: "tilled_soil",
    5: "watered_soil", 6: "path_stone", 7: "path_packed", 8: "fence_post", 9: "fence_rail_h",
    10: "fence_rail_v", 11: "fence_post_rail_h", 12: "fence_post_rail_v",
    13: "grass_tufts", 14: "grass_stones", 15: "grass_clover", 16: "grass_flowers_yellow",
    17: "dirt_pebbles", 18: "dirt_stones_twig",
}


def build_tileset():
    tiles = {}
    tiles[0], tiles[1], tiles[2] = m1.grass(1), m1.grass(2), m1.grass(3, flowers=2)
    tiles[3] = dirt(11, pebbles=2)
    tiles[4], tiles[5] = tilled(), watered()
    tiles[6], tiles[7] = m1.stone_path(), m1.packed_path()
    tiles[8], tiles[9], tiles[10] = m1.wood(m1.POST), m1.wood(m1.RAIL_H), m1.wood(m1.RAIL_V)
    tiles[11] = m1.stack(m1.wood(m1.RAIL_H), m1.wood(m1.POST))
    tiles[12] = m1.stack(m1.wood(m1.RAIL_V), m1.wood(m1.POST))
    tiles[13], tiles[14], tiles[15], tiles[16] = grass_tufts(), grass_stones(), grass_clover(), grass_flowers_b()
    tiles[17] = dirt(12, pebbles=4, big=1)
    tiles[18] = dirt(13, pebbles=2, big=1, root=True)
    for m in range(16):
        tiles[FENCE_BASE + m] = fence_tile(m)
        tiles[PATH_BASE + m] = path_tile(m, tiles[7])
    cols = 8
    rows = (max(tiles) + cols) // cols
    sheet = new(cols * T, rows * T)
    for i, t in tiles.items():
        sheet.alpha_composite(t, ((i % cols) * T, (i // cols) * T))
    return sheet


# --------------------------------------------------------------------------
# Bed (16x32)
# --------------------------------------------------------------------------

BED_C = {"o": "outline", "D": "brown_dark", "d": "brown", "m": "brown_mid", "l": "brown_light",
         "h": "tan", "W": "white_warm", "w": "cream", "s": "stone_pale", "S": "stone_light",
         "R": "red_dark", "r": "red", "p": "pink", "y": "yellow_pale", "Y": "yellow",
         "b": "blue", "B": "blue_dark"}
BED = [
    ".oooooooooooooo.",  # 0 headboard
    "ohhhhhhhhhhhhhho",
    "olllllllllllllmo",
    "olmmdmmmmmmdmmmo",
    "olmmdmmmmmmdmmdo",
    "oDDDDDDDDDDDDDDo",  # 5
    "oDoooooooooooooD",
    "oDowwwwwwwwwwsoD",
    "oDoWWWWWWWWWwsoD",
    "oDoWWwWWWWWWwsoD",  # 9 pillow
    "oDoWWWWWWWWwwsoD",
    "oDosswwwwwwsssoD",
    "oDoooooooooooooD",
    "oDRRRRRRRRRRRRRD",  # 13 quilt fold (turned-down sheet)
    "oDywwwwwwwwwwwyD",
    "oDRRRRRRRRRRRRRD",
    "oRrrrrRppRrrrrrR",  # 16 quilt body, patchwork
    "oRrprrRrrRrrprrR",
    "oRrrrrRrrRrrrrrR",
    "oRRRRRRRRRRRRRRR",
    "oRppRrrrrRppRrrR",  # 20
    "oRprRrprrRprRrpR",
    "oRppRrrrrRppRrrR",
    "oRRRRRRRRRRRRRRR",
    "oRrrrrRppRrrrrrR",  # 24
    "oRrprrRrrRrrprrR",
    "oRrrrrRrrRrrrrRR",
    "oDRRRRRRRRRRRRRD",
    "olllllllllllllmo",  # 28 footboard
    "olmmdmmmmmmdmmdo",
    "oDDDDDDDDDDDDDDo",
    ".oooooooooooooo.",
]


def build_bed():
    assert len(BED) == 32 and all(len(r) == 16 for r in BED)
    img = new(16, 32)
    blit_map(img, BED, BED_C)
    return img


# --------------------------------------------------------------------------
# Tool icons (16x16)
# --------------------------------------------------------------------------

ICON_C = {"o": "outline", "D": "brown_dark", "d": "brown", "m": "brown_mid", "l": "brown_light",
          "h": "tan", "K": "stone_dark", "k": "stone", "s": "stone_light", "S": "stone_pale",
          "W": "white_warm", "R": "red_dark", "r": "red", "B": "blue_dark", "b": "blue",
          "L": "blue_light", "y": "yellow", "g": "green", "G": "green_dark"}

PICKAXE = [
    "................",
    "...oooooo.......",
    "..oSsssskoo.....",
    ".oSkoooosskoo...",
    ".oko....ookKko..",
    ".oo.....omookKo.",
    "........omlo.oKo",
    ".......omlo..oko",
    "......omlo....o.",
    ".....omlo.......",
    "....omlo........",
    "...omlo.........",
    "..omlo..........",
    ".oDdo...........",
    ".ooo............",
    "................",
]
def icon(rows, name):
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), name
    img = new(16, 16)
    blit_map(img, rows, ICON_C)
    return img


# ---- geometric icon helpers (fill first, then auto outline) ----

def outline_img(img, col="outline"):
    px = img.load()
    w, h = img.size
    add = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                X, Y = x + dx, y + dy
                if 0 <= X < w and 0 <= Y < h and px[X, Y][3] and px[X, Y] != c(col):
                    add.append((x, y))
                    break
    for x, y in add:
        px[x, y] = c(col)
    return img


def icon_pulaski():
    """Pulaski: axe blade (top-left) and adze/hoe blade (bottom-right) on one red head."""
    img = new(16, 16)
    px = img.load()
    for y in range(16):
        for x in range(16):
            u, v = x + (y - 1), x - (y - 1)   # u along the head axis, v across it (1px lower)
            col = None
            # handle along x + y = 16/17, from the head eye down-left to the grip
            if u in (15, 16) and 3 <= x <= 10 and y <= 14:
                col = "brown_light" if u == 15 else "brown_mid"
                if x <= 4:
                    col = "brown" if u == 15 else "brown_dark"   # grip wrap
            # head (painted red), 3px thick
            if 3 <= v <= 5 and 9 <= u <= 20:
                col = {3: "red", 4: "red", 5: "red_dark"}[v]
                if u in (15, 16):
                    col = "stone_dark" if v == 5 else "stone"      # eye / wedge
            # axe blade at the up-left end, widening to a long edge
            if 4 <= u <= 9:
                half = {4: 4, 5: 4, 6: 3.5, 7: 3, 8: 2.5, 9: 2}[u]
                if 4 - half <= v <= 4 + half:
                    col = {4: "stone_pale", 5: "stone_light", 6: "stone_light",
                           7: "stone", 8: "stone", 9: "stone_dark"}[u]
            # adze (hoe) blade at the down-right end: narrow neck, flared edge
            if 21 <= u <= 25:
                lo, hi = {21: (3, 5), 22: (3, 5), 23: (2, 6), 24: (2, 7), 25: (3, 7)}[u]
                if lo <= v <= hi:
                    col = {21: "stone_dark", 22: "stone", 23: "stone", 24: "stone_light",
                           25: "stone_pale"}[u]
            if col and 1 <= x <= 14 and 1 <= y <= 14:
                px[x, y] = c(col)
    return outline_img(img)


def icon_sickle():
    img = new(16, 16)
    px = img.load()
    cx, cy = 8.5, 8.0
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            rr = math.hypot(dx, dy)
            ang = math.degrees(math.atan2(-dy, dx)) % 360   # 0 = right, 90 = up
            # blade runs from the handle (lower-left, ~215 deg) over the top to the tip (~-30 deg)
            t = None
            if 215 >= ang >= 0 or ang >= 330:
                a = ang if ang <= 215 else ang - 360           # 215 .. -30
                t = (215 - a) / 245.0                            # 0 at handle, 1 at tip
            if t is not None:
                outer = 6.4
                inner = 6.4 - (3.0 * (1 - t) + 0.8 * t)
                if inner <= rr <= outer:
                    if rr < inner + 1.0:
                        col = "stone_pale"      # honed inner edge
                    elif rr > outer - 1.0:
                        col = "stone"
                    else:
                        col = "stone_light"
                    px[x, y] = c(col)
    # handle: down-left from the blade heel
    for i, (x, y) in enumerate(((4, 11), (3, 12), (3, 13), (2, 14))):
        px[x, y] = c("brown_light"); px[x + 1, y] = c("brown_mid")
    px[2, 14] = c("brown"); px[3, 14] = c("brown_dark")
    px[4, 10] = c("stone_dark"); px[5, 10] = c("stone_dark")    # ferrule
    return outline_img(img)


def icon_watering_can():
    rows = [
        "................",
        "................",
        "....KkkkK.......",   # handle arc
        "...K.....K......",
        "...K.....K...SS.",
        "..LLLLLLLLb.Ssk.",
        "..LbbbbbbbbBbk..",
        "..LbLbbbbbbbBk..",   # body with spout rising right
        "..LbbbbbbbBBk...",
        "..LbLbbbbbbB....",
        "..LbbbbbbbbB....",
        "..LbbbbbbbbB....",
        "..BBBBBBBBBB....",
        "................",
        "................",
        "................",
    ]
    img = new(16, 16)
    blit_map(img, rows, ICON_C)
    return outline_img(img)


# --------------------------------------------------------------------------
# Trees (32x48 frames, bottom-center anchor (16, 48))
# --------------------------------------------------------------------------

TW, TH = 32, 48


def disc_union(blobs):
    pts = set()
    for (cx, cy, rad) in blobs:
        for y in range(int(cy - rad) - 1, int(cy + rad) + 2):
            for x in range(int(cx - rad) - 1, int(cx + rad) + 2):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= rad * rad:
                    pts.add((x, y))
    return pts


def shade_canopy(img, pts, blobs, seed, outline="green_dark"):
    """Light from top-left. Per-blob shading so clumps read; colored outline."""
    px = img.load()
    r = random.Random(seed)
    for (x, y) in pts:
        if not (0 <= x < img.width and 0 <= y < img.height):
            continue
        # nearest blob decides local normal
        best = min(blobs, key=lambda b: ((x + .5 - b[0]) ** 2 + (y + .5 - b[1]) ** 2) / (b[2] ** 2))
        dx, dy = (x + .5 - best[0]) / best[2], (y + .5 - best[1]) / best[2]
        lit = -(dx * 0.6 + dy * 0.8)  # >0 faces the light
        if lit > 0.55:
            col = "green_light"
        elif lit > 0.1:
            col = "green_grass"
        elif lit > -0.45:
            col = "green"
        else:
            col = "green_forest"
        px[x, y] = c(col)
    # sparkle highlights + leaf-texture darks
    lst = sorted(pts)
    for (x, y) in r.sample(lst, len(lst) // 14):
        if px[x, y] == c("green_grass"):
            px[x, y] = c("green_light")
        elif px[x, y] == c("green"):
            px[x, y] = c("green_forest")
    for (x, y) in r.sample(lst, len(lst) // 40):
        if px[x, y] == c("green_light"):
            px[x, y] = c("green_pale")
    # outline: transparent pixels 4-adjacent to canopy
    out = set()
    for (x, y) in pts:
        for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + ddx, y + ddy)
            if q not in pts:
                out.add(q)
    for (x, y) in out:
        if 0 <= x < img.width and 0 <= y < img.height and px[x, y][3] == 0:
            px[x, y] = c(outline)


TRUNK_C = {"o": "outline", "D": "brown_dark", "d": "brown", "m": "brown_mid", "l": "brown_light",
           "h": "tan", "g": "green_forest", "G": "green", "L": "green_grass", "M": "green_light",
           "s": "stone_light", "w": "cream", "e": "green_dark"}


def tree_seed():
    f = new(TW, TH)
    blit_map(f, [
        "......oooo......",
        ".....odhmmo.....",   # acorn-ish seed peeking out of a dirt mound
        "....oodmmmoo....",
        "...odmmllmmdo...",
        "....ooooooo.....",
    ], TRUNK_C, 8, 43)
    return f


def tree_seedling():
    f = new(TW, TH)
    blit_map(f, [
        "..ee......ee....",
        ".eMLe....eLMe...",
        ".eLMLe..eLMLe...",
        "..eLLGeeGLLe....",
        "...eeGGgGee.....",
        ".....eeGge......",
        "......eGge......",
        "......eGge......",
        "....oodggdoo....",
        "...odmmmmmmdo...",
        "....oooooooo....",
    ], TRUNK_C, 8, 37)
    return f


def tree_sapling():
    f = new(TW, TH)
    blobs = [(16, 25, 5.2), (12.5, 28, 3.6), (19.5, 28, 3.6), (16, 21, 3.5)]
    pts = disc_union(blobs)
    trunk = ["......omlo......"] * 10 + [
        "......omdo......",
        "....eoomloo.e...",
        "...eoDmmlmDoe...",
        "....oooooooo....",
    ]
    blit_map(f, trunk, TRUNK_C, 8, 34)   # trunk first (y 34..47), canopy drawn over its top
    shade_canopy(f, pts, blobs, 7)
    return f


def tree_grown():
    f = new(TW, TH)
    trunk = [
        "..........omllmmdo..............",
        "..........omllmmdo..............",
        "..........omlmmmdo..............",
        "..........omhlmmdo..............",
        "..........omllmddo..............",
        "..........omlmmmdo..............",
        "..........omllmmdo..............",
        ".........oomlmmmdoo.............",
        "........odmmlmmmmddo............",
        ".......odmmdoomldoDdo...........",
        "........ooo.....oooo............",
    ]
    # shift so trunk is centered on x 15/16
    trunk = ["." * 3 + r[:-3] for r in trunk]
    blit_map(f, trunk, TRUNK_C, 0, 37)
    blobs = [(16, 17, 10.5), (8.5, 23, 6.8), (23.5, 23, 6.8), (11, 11, 6.5), (21, 10.5, 6.5),
             (16, 7, 6), (16, 27, 7)]
    pts = disc_union(blobs)
    pts = {p for p in pts if 1 <= p[0] <= 30 and 1 <= p[1] <= 38}
    shade_canopy(f, pts, blobs, 11)
    return f


def tree_stump():
    f = new(TW, TH)
    blit_map(f, [
        "......oooooo......",
        ".....ohwwwwho.....",
        "....odhwhhwhdo....",
        "....omhwwwwhmo....",
        "....omllmmmldo....",
        "...odmlmmmdmddo...",
        "..odmmdoomldoDdo..",
        "...ooo.....oooo...",
    ], TRUNK_C, 7, 40)
    return f


def build_trees():
    frames = [tree_seed(), tree_seedling(), tree_sapling(), tree_grown(), tree_stump()]
    sheet = new(TW * len(frames), TH)
    for i, fr in enumerate(frames):
        sheet.alpha_composite(fr, (i * TW, 0))
    return sheet


# --------------------------------------------------------------------------
# UI (wood + parchment). 9-slice sources; edges are uniform along their length
# so both stretch and tile modes are safe.
# --------------------------------------------------------------------------

def frame9(size, margin, ring, fill, corner_px=None, fill_fn=None):
    """ring: list of colors from outside in (one per px). fill: center color."""
    w, h = size
    img = new(w, h)
    px = img.load()
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d < len(ring):
                col = ring[d]
                if isinstance(col, tuple):  # (top-left color, bottom-right color) bevel
                    tl = (x == d or y == d) and not (x == w - 1 - d or y == h - 1 - d)
                    col = col[0] if tl else col[1]
                px[x, y] = c(col)
            else:
                px[x, y] = c(fill_fn(x, y) if fill_fn else fill)
    # rounded outer corners
    for (x, y) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        px[x, y] = TRANSPARENT
    for (x, y) in ((1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2)):
        px[x, y] = c("outline")
    if corner_px:
        for (x, y) in ((corner_px, corner_px), (w - 1 - corner_px, corner_px),
                       (corner_px, h - 1 - corner_px), (w - 1 - corner_px, h - 1 - corner_px)):
            px[x, y] = c("stone_pale")      # brass-ish nail head
            px[x + (1 if x < w // 2 else -1), y + (1 if y < h // 2 else -1)] = c("stone")
    return img


WOOD_RING = ["outline", ("tan", "brown"), ("brown_light", "brown_mid"), "brown_mid",
             ("brown", "brown_light"), "brown_dark"]


def toolbar_frame():
    # 18x18, margins 6 on every side; center = dark recessed wood behind slots
    return frame9((18, 18), 6, WOOD_RING, "brown", corner_px=3)


def hud_panel():
    # 18x18, margins 6; center = parchment
    return frame9((18, 18), 6, WOOD_RING, "sand", corner_px=3)


def slot(selected=False):
    """20x20: 2px frame around a 16x16 item area at (2,2)."""
    img = new(20, 20)
    px = img.load()
    for y in range(20):
        for x in range(20):
            d = min(x, y, 19 - x, 19 - y)
            if selected:
                col = ["red", "yellow"][d] if d < 2 else None
                if d == 1 and (x in (1, 18) or y in (1, 18)) and (x + y) % 4 == 0:
                    col = "yellow_pale"
            else:
                col = ["brown_dark", None][d] if d < 1 else None
                if d == 1:
                    col = "brown" if (x == 1 or y == 1) and not (x == 18 or y == 18) else "tan"
            if col is None:
                # item well: parchment, slightly shaded at top-left (inset look)
                col = "tan" if (x == 2 or y == 2) else "sand"
            px[x, y] = c(col)
    if selected:
        for (x, y) in ((0, 0), (19, 0), (0, 19), (19, 19)):
            px[x, y] = TRANSPARENT
    return img


def bar_frame():
    """32x10 horizontal bar frame (9-slice: margins L3 R3 T3 B3). Inner 26x4 is the trough."""
    img = frame9((32, 10), 3, ["outline", ("brown_light", "brown"), "brown_dark"], "outline")
    return img


def bar_fill(top, mid, low):
    """4x4 fill texture (stretch/tile horizontally) for the 4px-tall trough."""
    img = new(4, 4)
    px = img.load()
    for x in range(4):
        px[x, 0] = c(top); px[x, 1] = c(mid); px[x, 2] = c(mid); px[x, 3] = c(low)
    return img


HUD_ICON_C = {"o": "outline", "r": "red", "R": "red_dark", "p": "pink", "W": "white_warm",
              "y": "yellow", "Y": "yellow_pale", "O": "orange", "d": "brown_dark",
              "g": "green_light", "G": "green", "F": "green_forest"}
HUD_ICONS = [
    [  # health heart
        ".oo.oo..",
        "orWorro.",
        "orprrRo.",
        "orrrrRo.",
        ".orrRo..",
        "..oRo...",
        "...o....",
        "........",
    ],
    [  # stamina bolt (Stardew uses E; a bolt reads at 8px)
        "...oooo.",
        "..oYyo..",
        ".oYyo...",
        "oYyyyoo.",
        "oooyyo..",
        "..oyo...",
        ".oOo....",
        ".oo.....",
    ],
    [  # gold coin
        "..oooo..",
        ".oYyyyo.",
        "oYyOOyOo",
        "oyyOyyOo",
        "oyyOOyOo",
        "oyyyyyOo",
        ".oOOOOo.",
        "..oooo..",
    ],
    [  # bond heart (pink, for monster bond)
        ".oo.oo..",
        "opWoppo.",
        "oppppRo.",
        "opppRRo.",
        ".opRRo..",
        "..oRo...",
        "...o....",
        "........",
    ],
]


def build_hud_icons():
    sheet = new(8 * len(HUD_ICONS), 8)
    for i, rows in enumerate(HUD_ICONS):
        assert len(rows) == 8 and all(len(r) == 8 for r in rows), i
        blit_map(sheet, rows, HUD_ICON_C, i * 8, 0)
    return sheet


# --------------------------------------------------------------------------

def outputs():
    return {
        "assets/tilesets/farm_tiles.png": build_tileset(),
        "assets/sprites/bed.png": build_bed(),
        "assets/sprites/item_pulaski.png": icon_pulaski(),
        "assets/sprites/item_sickle.png": icon_sickle(),
        "assets/sprites/item_pickaxe.png": icon(PICKAXE, "pickaxe"),
        "assets/sprites/item_watering_can.png": icon_watering_can(),
        "assets/sprites/tree_stages.png": build_trees(),
        "assets/ui/toolbar_frame.png": toolbar_frame(),
        "assets/ui/toolbar_slot.png": slot(False),
        "assets/ui/toolbar_slot_selected.png": slot(True),
        "assets/ui/hud_panel.png": hud_panel(),
        "assets/ui/bar_frame.png": bar_frame(),
        "assets/ui/bar_fill_stamina.png": bar_fill("green_pale", "green_light", "green"),
        "assets/ui/bar_fill_health.png": bar_fill("pink", "red", "red_dark"),
        "assets/ui/hud_icons.png": build_hud_icons(),
    }


def validate(name, img):
    pal = set(RGBA)
    for p in (img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()):
        if p[3] == 0:
            continue
        assert p[3] == 255, (name, p)
        assert p in pal, (name, p)


def main():
    outs = outputs()
    for rel, img in outs.items():
        validate(rel, img)
        p = ROOT / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        img.save(p)
        print("wrote", rel, img.size)
    if "--preview" in sys.argv:
        import preview_m1b
        extra = {"crop": m1.build_crops(), "player": m1.build_player()}
        preview_m1b.preview(sys.argv[sys.argv.index("--preview") + 1], outs, extra)


if __name__ == "__main__":
    main()
