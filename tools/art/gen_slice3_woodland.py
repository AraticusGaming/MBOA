"""Slice 3, part 1: Woodland Assessment room art (procedural, Pillow, reproducible).

Writes:
  assets/tilesets/woodland_tiles.png   128x128, 16x16 tiles, 8 columns (see ART_NOTES.md)
  assets/backgrounds/woodland_room.png 640x360, the Assessment room composed only from the tiles
  assets/sprites/trap_basic.png        64x16, 4 frames: idle, set, shaking, knocked_over
  assets/sprites/item_bait.png         16x16 bait pouch icon

Palette colors only (tools/art/palette.py; this batch appends 38-41), alpha 0/255, one pixel
scale. Run: python3 tools/art/gen_slice3_woodland.py [--preview DIR]
"""
import random
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from palette import RGBA, c  # noqa: E402
import gen_m1_farm as m1  # noqa: E402
import gen_m1b_polish as g  # noqa: E402

T = 16
new, blit_map, put, tile_fill = m1.new, m1.blit_map, m1.put, m1.tile_fill
N, E, S, W = 1, 2, 4, 8
PATH_BASE = 48  # tiles 48..63 = path mask 0..15
COLS = 8


def stamp(px, x, y, rows, cmap):
    """ASCII stamp that must stay inside the tile (no wrap) so variants stay seamless."""
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            X, Y = x + i, y + j
            assert 0 <= X < T and 0 <= Y < T, (X, Y)
            px[X, Y] = c(cmap[ch])


# --------------------------------------------------------------------------
# Ground (opaque, seamless). Multi-pixel details never cross the tile edge, and the
# single-pixel speckle has no structure, so every ground tile joins every other one.
# --------------------------------------------------------------------------

LEAF_C = {"o": "orange", "y": "yellow", "r": "red", "R": "red_dark", "l": "brown_light",
          "t": "tan", "m": "brown_mid", "d": "brown", "D": "brown_dark", "g": "green_forest",
          "G": "green", "M": "moss", "L": "green_grass", "k": "loam_dark", "s": "stone_light",
          "S": "stone", "p": "stone_pale", "w": "white_warm", "x": "stone_dark"}

LEAVES = [  # small fallen leaves (3x3 / 3x2), lit from top-left, shade bottom-right
    [".t.", "tlm", ".m."],
    ["lt.", ".lm"],
    [".l.", "lmd", ".d."],
    ["yo.", ".oR"],
    ["tl.", ".ld"],
]


def floor_base(seed):
    t = tile_fill("loam")
    px = t.load()
    r = random.Random(seed)
    for _ in range(12):
        put(px, r.randrange(T), r.randrange(T), "loam_dark")
    for _ in range(5):  # short soft dashes (wrap; single-row so they never form seams)
        x, y = r.randrange(T), r.randrange(T)
        put(px, x, y, "loam_dark"); put(px, x + 1, y, "loam_dark")
    for _ in range(5):
        put(px, r.randrange(T), r.randrange(T), "brown")
    for _ in range(3):
        put(px, r.randrange(T), r.randrange(T), "brown_mid")
    for _ in range(2):
        put(px, r.randrange(T), r.randrange(T), "moss")
    return t


def scatter(px, seed, sprites, n, margin=0):
    """Place n small sprites fully inside the tile, not overlapping each other."""
    r = random.Random(seed)
    used = set()
    placed = 0
    tries = 0
    while placed < n and tries < 400:
        tries += 1
        spr = r.choice(sprites)
        h, w = len(spr), len(spr[0])
        x = r.randrange(margin, T - w - margin + 1)
        y = r.randrange(margin, T - h - margin + 1)
        cells = {(x + i, y + j) for j in range(-1, h + 1) for i in range(-1, w + 1)}
        if cells & used:
            continue
        used |= cells
        stamp(px, x, y, spr, LEAF_C)
        placed += 1


def floor_a():
    t = floor_base(201)
    scatter(t.load(), 2011, LEAVES[1:2], 1)
    return t


def floor_b():
    t = floor_base(202)
    px = t.load()
    scatter(px, 2021, [["M"], ["s"]], 3)
    return t


def leaf_litter(seed, n):
    t = floor_base(seed)
    scatter(t.load(), seed * 7, LEAVES, n)
    return t


def floor_twigs():
    t = floor_base(204)
    px = t.load()
    stamp(px, 2, 4, [
        "Dd.......",
        ".Dld.....",
        "..DlldDd.",
        "....DDlld",
        "......DDd",
    ], LEAF_C)
    scatter_px = [["yo.", "ooR", ".R."]]
    stamp(px, 10, 11, scatter_px[0], LEAF_C)
    stamp(px, 3, 12, ["ps", "SS"], LEAF_C)
    return t


def floor_pebbles():
    t = floor_base(205)
    px = t.load()
    stamp(px, 3, 3, [".ps.", "pssS", "kSSk"], LEAF_C)
    stamp(px, 11, 9, ["ps", "Sk"], LEAF_C)
    stamp(px, 6, 12, ["s", "k"], LEAF_C)
    stamp(px, 12, 2, ["ps", "kk"], LEAF_C)
    return t


def floor_mossy():
    """Forest floor half grown over with moss; moss stays off the edge pixels so it blends."""
    t = floor_base(206)
    px = t.load()
    pts = blob_pts(5, 5, 4.2, 3.4, 2061) | blob_pts(11, 10.5, 4.4, 3.8, 2062) | blob_pts(4, 12, 2.6, 2, 2063)
    pts = {(x, y) for (x, y) in pts if 1 <= x <= 14 and 1 <= y <= 14}
    r = random.Random(2064)
    for (x, y) in sorted(pts):
        edge = any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            if r.random() < 0.6:
                px[x, y] = c("green_forest" if (x + y) % 2 else "moss")
        else:
            px[x, y] = c(r.choice(("moss", "moss", "moss", "green_grass", "green")))
    return t


def floor_sprouts():
    t = floor_base(207)
    px = t.load()
    for (x, y) in ((2, 3), (10, 5), (5, 10), (12, 12)):
        stamp(px, x, y, ["L.L", "GLG", ".g."], LEAF_C)
    return t


# --------------------------------------------------------------------------
# Small overlays (transparent background)
# --------------------------------------------------------------------------

def blob_pts(cx, cy, rx, ry, seed, jitter=0.18):
    r = random.Random(seed)
    pts = set()
    for y in range(T):
        for x in range(T):
            d = ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2
            if d <= 1 + r.uniform(-jitter, jitter):
                pts.add((x, y))
    return pts


def moss_patch(big):
    t = new(T, T)
    px = t.load()
    if big:
        pts = blob_pts(8, 8.5, 7, 5.6, 301) | blob_pts(4.5, 5, 3.4, 2.6, 302)
    else:
        pts = blob_pts(8, 9, 5, 3.6, 303)
    pts = {(x, y) for (x, y) in pts if 0 < x < T - 1 and 0 < y < T - 1}
    r = random.Random(304 + big)
    for (x, y) in pts:
        edge = any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            px[x, y] = c("green" if (x + y) % 2 else "green_forest")
        else:
            px[x, y] = c("moss")
    inner = sorted(p for p in pts if px[p] == c("moss"))
    for p in r.sample(inner, len(inner) // 4):
        px[p] = c("green_grass")
    for p in r.sample(inner, len(inner) // 10):
        px[p] = c("green_light")
    for p in r.sample(inner, len(inner) // 10):
        px[p] = c("green")
    return t


def rock_small():
    t = new(T, T)
    stamp(t.load(), 3, 5, [
        "...oooo...",
        "..opppso..",
        ".oppssSSo.",
        "opsssSSSxo",
        "osssSSSxxo",
        "oSSSSSxxxo",
        ".oxxxxxxo.",
        "..oooooo..",
        "..kkkkkk..",
    ], dict(LEAF_C, o="outline"))
    return t


def rock_pair():
    t = new(T, T)
    px = t.load()
    stamp(px, 1, 3, [
        "..ooo...",
        ".oppso..",
        "opssSSo.",
        "osSSSxo.",
        ".oxxxo..",
        "..ooo...",
        "..kkk...",
    ], dict(LEAF_C, o="outline"))
    stamp(px, 8, 8, [
        "..oooo.",
        ".oppsSo",
        "opssSSo",
        "osSSSxo",
        "oSSxxxo",
        ".ooooo.",
        ".kkkkk.",
    ], dict(LEAF_C, o="outline"))
    return t


def rock_mossy():
    t = rock_small()
    px = t.load()
    stamp(px, 5, 5, ["..LML.", ".LMGMM"], LEAF_C)
    stamp(px, 4, 7, ["G"], LEAF_C)
    stamp(px, 11, 7, ["G"], LEAF_C)
    return t


MUSH_C = dict(LEAF_C, o="outline", c="cream", w="white_warm", h="sand", a="tan")


def mushrooms_red():
    t = new(T, T)
    px = t.load()
    stamp(px, 2, 3, [
        "..oooo..",
        ".orrwro.",
        "orwrrrRo",
        "orrrrwRo",
        "oRRRRRRo",
        ".oooooo.",
        "..owco..",
        "..owco..",
        "..ocao..",
        "..oooo..",
    ], MUSH_C)
    stamp(px, 9, 8, [
        ".oooo.",
        "orwrRo",
        "oRRRRo",
        ".oooo.",
        ".owao.",
        ".oooo.",
    ], MUSH_C)
    return t


def mushrooms_brown():
    t = new(T, T)
    px = t.load()
    stamp(px, 1, 5, [
        "..oooo...",
        ".otllmo..",
        "otllmmdo.",
        "oddddddo.",
        ".oooooo..",
        "..owco...",
        "..owco...",
        "..oooo...",
    ], MUSH_C)
    stamp(px, 8, 3, [
        ".ooo...",
        "otlmo..",
        "oddddo.",
        ".oooo..",
        ".oco...",
        ".oco...",
        ".ooo...",
    ], MUSH_C)
    stamp(px, 10, 9, [
        "..ooo.",
        ".otlmo",
        "oddddo",
        ".oooo.",
        "..oco.",
        "..ooo.",
    ], MUSH_C)
    return t


FERN_C = {"e": "green_dark", "g": "green_forest", "G": "green", "L": "green_grass",
          "M": "green_light", "P": "green_pale", "k": "loam_dark"}


def fern():
    t = new(T, T)
    stamp(t.load(), 0, 1, [
        "......e.........",
        ".....eMe....e...",
        ".e...eLe...eMe..",
        "eMe..eLGe..eLe..",
        "eLGe.eLGe.eLGe..",
        ".eLGeeLGeeLGe.e.",
        "..eLGeLGeLGe.eMe",
        "e..eLGLGLGeeeLGe",
        "MLeeeLGGGeeLLGe.",
        ".eLLGGGgGGLGGe..",
        "..eeeGGgGGeee...",
        "....eeggge......",
        "......eke.......",
    ], FERN_C)
    return t


def fern_tall():
    t = new(T, T)
    stamp(t.load(), 1, 0, [
        "......ee......",
        ".....eMLe.....",
        "..e..eLGe..e..",
        ".eMe.eLGe.eMe.",
        ".eLGeeLGeeLGe.",
        "..eLGeLGeLGe..",
        "e..eLGLGLGe..e",
        "Me..eLGGGe..eM",
        "eLe.eLGGGe.eLe",
        ".eLGeLGgGeGLe.",
        "..eLGGGgGGLe..",
        "...eLGGgGGe...",
        "....eeGgGee...",
        "......egge....",
        ".......kk.....",
    ], FERN_C)
    return t


def bush(berries):
    t = new(T, T)
    blobs = [(8, 8.5, 5.6), (4.5, 10, 3.8), (11.5, 10, 3.8), (8, 5.5, 3.8)]
    pts = {p for p in g.disc_union(blobs) if 1 <= p[0] <= 14 and 1 <= p[1] <= 13}
    g.shade_canopy(t, pts, blobs, 410 + berries)
    px = t.load()
    for x in range(3, 13):  # ground shadow
        if px[x, 15][3] == 0:
            px[x, 15] = c("loam_dark")
    if berries:
        for (x, y) in ((5, 6), (9, 5), (11, 9), (6, 11), (8, 9)):
            px[x, y] = c("red")
            px[x + 1, y] = c("red_dark")
            px[x, y + 1] = c("red_dark")
            px[x + 1, y + 1] = c("red_dark")
            px[x, y] = c("pink")
    return t


WOOD_C = {"o": "outline", "D": "brown_dark", "d": "brown", "m": "brown_mid", "l": "brown_light",
          "h": "tan", "s": "sand", "w": "cream", "G": "green", "L": "green_grass", "M": "moss",
          "g": "green_forest", "k": "loam_dark"}

# horizontal log body rows (top to bottom), 10 px tall at y 4..13 + shadow row 14
LOG_ROWS = ["o", "l", "h", "m", "m", "d", "m", "d", "D", "o"]


def log_body(px, x0, x1, seed):
    for x in range(x0, x1):
        for j, col in enumerate(LOG_ROWS):
            px[x, 4 + j] = c(WOOD_C[col])
        px[x, 14] = c("loam_dark")
    r = random.Random(seed)
    # bark grain: short dark dashes inside, never on the tile edge columns
    for _ in range(4):
        x = r.randrange(max(x0, 1), min(x1, T - 1) - 2)
        y = r.choice((6, 7, 9, 10))
        for i in range(r.choice((2, 3))):
            if x + i < min(x1, T - 1):
                px[x + i, y] = c("brown" if y < 9 else "brown_dark")


def log_moss(px, xs):
    for x in xs:
        px[x, 4] = c("green")
        px[x, 5] = c("moss")
        px[x, 3] = c("green_dark")


def cut_face(px, x):
    """End grain (rings) on the left end of a log, x = leftmost column."""
    stamp(px, x, 4, [
        ".ooo",
        "ohso",
        "hswo",
        "shso",
        "sssl",
        "shsl",
        "hssl",
        "hhlo",
        "ohlo",
        ".oo.",
    ], WOOD_C)


def round_end(px, x):
    """Broken/rounded right end of a log, x = first column of the cap."""
    stamp(px, x, 4, [
        "o..",
        "lo.",
        "hdo",
        "mdo",
        "mdo",
        "ddo",
        "mDo",
        "dDo",
        "Do.",
        "o..",
    ], WOOD_C)


def log_left():
    t = new(T, T)
    px = t.load()
    log_body(px, 3, T, 501)
    cut_face(px, 1)
    px[1, 14] = px[2, 14] = c("loam_dark")
    log_moss(px, (9, 10, 11))
    return t


def log_mid():
    t = new(T, T)
    px = t.load()
    log_body(px, 0, T, 502)
    log_moss(px, (4, 5))
    return t


def log_right():
    t = new(T, T)
    px = t.load()
    log_body(px, 0, 12, 503)
    round_end(px, 12)
    px[12, 14] = px[13, 14] = c("loam_dark")
    return t


def log_short():
    t = new(T, T)
    px = t.load()
    log_body(px, 3, 12, 504)
    cut_face(px, 1)
    round_end(px, 12)
    px[1, 14] = px[2, 14] = px[12, 14] = c("loam_dark")
    log_moss(px, (7, 8))
    # a little sprout
    stamp(px, 9, 1, [".L", "LG", ".g"], WOOD_C)
    return t


def stump():
    t = new(T, T)
    stamp(t.load(), 1, 3, [
        "...oooooooo...",
        "..ohsswsshlo..",
        ".ohswhhhwslmo.",
        ".olshhwhhslmo.",
        ".ommlllllmmdo.",
        ".olmmdmmmdmdo.",
        ".olmdmmmdmmDo.",
        ".olGmmdmmmMDo.",
        "oolMLmmmdMLDoo",
        "odmMmdoomdmDdo",
        ".oooo.kk.oooo.",
        "......kk......",
    ], WOOD_C)
    return t


def leaf_pile():
    t = new(T, T)
    stamp(t.load(), 1, 5, [
        "....DyoD......",
        "..DyoorRlD....",
        ".DoyoRlttloD..",
        "DloorRltlmyoD.",
        "DlyoRmlorryoRD",
        "DRlmRRrlRRlmRD",
        ".DDDRDDDDRDDD.",
        "...kkkkkkkk...",
    ], LEAF_C)
    return t


def flowers():
    t = new(T, T)
    stamp(t.load(), 0, 2, [
        "..w.........B...",
        ".wyw.......BbB..",
        "..w.....w...b...",
        "..g....wyw..g...",
        "..g.....w...g...",
        "..G.....g..Gg...",
        "..g.L...g.......",
        ".LgG...GgL...w..",
        "...........LwyW.",
        "....B.......wg..",
        "...BbB......Lg..",
        "....bg.......gL.",
        "....gG..........",
    ], dict(LEAF_C, B="blue_light", b="blue", W="white_warm", y="yellow"))
    return t


def twig():
    t = new(T, T)
    stamp(t.load(), 1, 3, [
        "....o.........",
        "...olo........",
        "....olo.......",
        "o....olooo....",
        "oloooollllooo.",
        ".odddlddddddlo",
        "..ooooooooooo.",
        "..........kk..",
        "..ooo.........",
        ".oDmDo........",
        ".omDmo........",
        ".oDmDo........",
        "..ooo.........",
    ], dict(WOOD_C, l="brown_light", d="brown_mid", D="brown", m="tan"))
    return t


# --------------------------------------------------------------------------
# Boulder (2x2 tiles = 32x32)
# --------------------------------------------------------------------------

def boulder():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = img.load()
    cx, cy, rx, ry = 16, 16.5, 14.2, 12.3
    r = random.Random(601)
    pts = set()
    for y in range(32):
        for x in range(32):
            dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            # flatter bottom
            if dy > 0:
                dy *= 1.25
            if dx * dx + dy * dy <= 1:
                pts.add((x, y))
    for (x, y) in pts:
        dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
        lit = -(dx * 0.65 + dy * 0.75)
        # facets: a crack line splits the rock into two lumps
        if lit > 0.55:
            col = "stone_pale"
        elif lit > 0.15:
            col = "stone_light"
        elif lit > -0.35:
            col = "stone"
        else:
            col = "stone_dark"
        px[x, y] = c(col)
    for (x, y) in sorted(pts):
        if r.random() < 0.07 and px[x, y] in (c("stone_light"), c("stone")):
            px[x, y] = c("stone" if px[x, y] == c("stone_light") else "stone_dark")
    # crack
    for (x, y) in ((19, 6), (19, 7), (18, 8), (18, 9), (19, 10), (20, 11), (20, 12), (19, 13)):
        px[x, y] = c("stone_dark")
        px[x + 1, y] = c("stone_pale") if px[x + 1, y] in (c("stone_light"), c("stone_pale")) else px[x + 1, y]
    # moss cap on top
    moss = blob_pts(12, 7, 7.5, 3.2, 602)
    moss = {(x, y) for (x, y) in moss if (x, y) in pts}
    for (x, y) in moss:
        px[x, y] = c("moss" if (x * 3 + y) % 5 else "green_grass")
    for (x, y) in moss:
        if (x, y + 1) not in moss and (x, y + 1) in pts:
            px[x, y + 1] = c("green")
            if (x + y) % 3 == 0 and (x, y + 2) in pts:
                px[x, y + 2] = c("green_forest")
        if (x, y - 1) not in moss:
            px[x, y] = c("green_light")
    # outline
    out = []
    for y in range(32):
        for x in range(32):
            if (x, y) in pts:
                continue
            if any((x + dx, y + dy) in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.append((x, y))
    for (x, y) in out:
        px[x, y] = c("outline")
    # contact shadow on the ground
    for x in range(5, 27):
        if px[x, 31][3] == 0:
            px[x, 31] = c("loam_dark")
    return img


# --------------------------------------------------------------------------
# Tree wall. All canopy tiles are cut from ONE seamless 32x32 canopy block, so each canopy
# tile has a block position (bx, by): place it on a cell with (x % 2, y % 2) == (bx, by).
# --------------------------------------------------------------------------

B = 32  # canopy block size
CANOPY_CLUMPS = [  # (cx, cy, r) on a 32x32 torus, drawn back (top) to front (bottom)
    (9, 2, 8.5), (25, 4, 7.0), (2, 10, 6.0), (16, 11, 8.0), (29, 15, 6.5),
    (7, 19, 7.5), (21, 23, 8.5), (31, 27, 5.0), (11, 29, 6.0), (4, 31, 4.5),
    (13, 21, 3.5), (26, 12, 3.2),
]


def _tor(a, b, n=B):
    d = (a - b) % n
    return d - n if d > n / 2 else d


def canopy_block():
    import math
    img = Image.new("RGBA", (B, B), c("canopy_deep"))
    px = img.load()
    r = random.Random(700)
    for (cx, cy, rad) in sorted(CANOPY_CLUMPS, key=lambda b: b[1]):
        for y in range(B):
            for x in range(B):
                dx, dy = _tor(x + .5, cx), _tor(y + .5, cy)
                d = math.hypot(dx, dy)
                if d > rad:
                    continue
                nx, ny = dx / rad, dy / rad
                lit = -(nx * 0.55 + ny * 0.85)
                if d > rad - 1.1 and lit < 0.0:
                    col = "green_dark"      # shadowed rim: separates this clump from the next
                elif lit > 0.6 and d > rad * 0.35:
                    col = "green_grass"
                elif lit > 0.15:
                    col = "green"
                elif lit > -0.45:
                    col = "green_forest"
                else:
                    col = "green_dark"
                px[x, y] = c(col)
        # leaf texture: a few lit specks and dark notches inside each clump
        for _ in range(int(rad * 1.3)):
            a = r.uniform(0, 2 * math.pi)
            d = r.uniform(0.2, 0.8) * rad
            x, y = int(cx + math.cos(a) * d) % B, int(cy + math.sin(a) * d) % B
            p = px[x, y]
            if p == c("green_grass"):
                px[x, y] = c("green_light")
            elif p == c("green") and r.random() < 0.5:
                px[x, y] = c("green_grass")
            elif p == c("green_forest"):
                px[x, y] = c("green_dark")
    return img


def block_tile(bx, by):
    return canopy_block().crop((bx * T, by * T, bx * T + T, by * T + T))


# 32-long cyclic edge profiles; tile with block x/y = k uses [16k : 16k+16].
BOTTOM32 = [12, 13, 13, 14, 14, 14, 13, 12, 11, 11, 12, 13, 14, 14, 13, 12,
            11, 12, 13, 14, 14, 14, 14, 13, 12, 11, 10, 10, 11, 12, 12, 12]   # last foliage row
TOP32 = [3, 2, 2, 1, 1, 2, 3, 4, 4, 3, 2, 2, 2, 3, 4, 5,
         5, 4, 3, 2, 2, 2, 3, 3, 4, 5, 5, 4, 3, 3, 3, 3]                    # first foliage row
SIDE32 = [12, 13, 13, 14, 14, 13, 12, 11, 11, 12, 13, 13, 12, 11, 10, 10,
          11, 12, 13, 14, 14, 14, 13, 12, 11, 11, 12, 12, 11, 11, 11, 11]   # foliage depth from the wall
TRUNK_X = 5  # trunk column in canopy_bottom_a / trunk_base_a (b has no trunk: undergrowth)


def prof(p, k):
    return p[16 * k:16 * k + 16]


def cut(t, keep):
    """Clear pixels where keep(x,y) is False; give the cut edge a green_dark outline."""
    px = t.load()
    for y in range(T):
        for x in range(T):
            if not keep(x, y):
                px[x, y] = (0, 0, 0, 0)
    edge = []
    for y in range(T):
        for x in range(T):
            if px[x, y][3] and any(0 <= x + dx < T and 0 <= y + dy < T and not keep(x + dx, y + dy)
                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge.append((x, y))
    for (x, y) in edge:
        px[x, y] = c("green_dark")
    return t


def trunk_col(px, x0, y0, y1):
    cols = ["outline", "brown_light", "brown_mid", "brown_mid", "brown", "brown_dark", "outline"]
    for y in range(y0, y1):
        for i, col in enumerate(cols):
            px[x0 + i, y] = c(col)
        if (y * 3 + x0) % 7 == 0:
            px[x0 + 3, y] = c("brown")
        if (y * 5 + x0) % 11 == 0:
            px[x0 + 2, y] = c("brown_light")


def canopy_bottom(k):
    """Lower fringe of the top tree wall (block (k, 0)), trunk tops below it."""
    edge = prof(BOTTOM32, k)
    t = cut(block_tile(k, 0), lambda x, y: y <= edge[x])
    px = t.load()
    for x in range(T):  # underside of the fringe is in shade
        y = edge[x] - 1
        if px[x, y] in (c("green_grass"), c("green_light"), c("green")):
            px[x, y] = c("green_forest")
    for x in range(T):  # canopy shadow on the floor (dither)
        for y in range(edge[x] + 1, T):
            if y <= edge[x] + 1 or (x + y) % 2 == 0:
                px[x, y] = c("loam_dark")
    if k:
        return t
    tx = TRUNK_X
    top = max(edge[tx - 1:tx + 6]) + 1
    trunk_col(px, tx - 1, top - 2, T)
    for x in range(tx - 1, tx + 6):  # leaves hang over the trunk top
        px[x, top - 2] = c("green_dark")
        if x % 2:
            px[x, top - 1] = c("green_dark")
    return t


def trunk_base(k):
    t = new(T, T)
    px = t.load()
    for x in range(T):  # canopy shadow fading out
        for y in range(0, 4):
            if (x + y) % 2 == 0 and (y < 2 or (y == 2 and x % 4 == 0)):
                px[x, y] = c("loam_dark")
    if k:  # undergrowth between trunks: a low fern clump
        stamp(px, 3, 4, [
            "..e.......e.",
            ".eMe..e..eMe",
            ".eLGe.eeeLGe",
            "e.eLGeLGeGe.",
            "MeeeLGLGGee.",
            "eLLGGGgGGLLe",
            ".eeGGgggGee.",
            "...eeggge...",
            "....kkkk....",
        ], FERN_C)
        return t
    tx = TRUNK_X
    trunk_col(px, tx - 1, 0, 9)
    stamp(px, tx - 3, 8, [
        "..olmmmdDo...",
        ".olmmlmmdDo..",
        "olmdolmddDDo.",
        "ooooooooooooo",
        ".kkkkkkkkkkk.",
    ], dict(WOOD_C, l="brown_light"))
    px[tx, 6] = c("moss"); px[tx, 7] = c("moss"); px[tx + 1, 8] = c("green"); px[tx, 8] = c("green")
    return t


def canopy_top(k):
    """Upper rim of the near (bottom) tree wall, block (k, 1); fill (k, 0) goes below it."""
    edge = prof(TOP32, k)
    t = cut(block_tile(k, 1), lambda x, y: y >= edge[x])
    px = t.load()
    for x in range(T):  # sunlit rim
        y = edge[x] + 1
        if px[x, y] != c("green_dark") and px[x, y] != c("canopy_deep"):
            px[x, y] = c("green_light")
    return t


def canopy_side(left, k):
    """Left wall (block (1, k), foliage on the left) or right wall (block (0, k))."""
    prof_ = prof(SIDE32, k)
    if left:
        return cut(block_tile(1, k), lambda x, y: x <= prof_[y])
    return cut(block_tile(0, k), lambda x, y: x >= T - 1 - prof_[y])


def canopy_corner(top, left):
    bx = 1 if left else 0
    by = 0 if top else 1
    side, hor = prof(SIDE32, by), prof(BOTTOM32 if top else TOP32, bx)

    def keep(x, y):
        s = x <= side[y] if left else x >= T - 1 - side[y]
        h = y <= hor[x] if top else y >= hor[x]
        return s or h
    return cut(block_tile(bx, by), keep)


# --------------------------------------------------------------------------
# Forest path (opaque interior + 16-tile autotile overlay)
# --------------------------------------------------------------------------

def path_fill():
    t = tile_fill("brown_mid")
    px = t.load()
    r = random.Random(801)
    for _ in range(18):
        put(px, r.randrange(T), r.randrange(T), "brown")
    for _ in range(10):
        put(px, r.randrange(T), r.randrange(T), "brown_light")
    for _ in range(4):
        put(px, r.randrange(T), r.randrange(T), "stone_light")
    for _ in range(3):
        put(px, r.randrange(T), r.randrange(T), "loam")
    return t


def path_tile(mask, interior):
    t = new(T, T)
    px = t.load()
    ip = interior.load()
    inside = g.path_inside_fn(mask)
    nb4 = ((0, -1), (1, 0), (0, 1), (-1, 0))
    for y in range(T):
        for x in range(T):
            if inside(x, y):
                nb = [inside(x + dx, y + dy) for dx, dy in nb4]
                if not nb[0]:
                    px[x, y] = c("brown")           # top lip in the shade of the floor edge
                elif not nb[2]:
                    px[x, y] = c("brown_light")     # sunlit bottom lip
                elif not nb[1] or not nb[3]:
                    px[x, y] = c("brown")
                else:
                    px[x, y] = ip[x, y]
            elif any(inside(x + dx, y + dy) for dx, dy in nb4):
                px[x, y] = c("loam_dark")          # dark rim where floor meets path
    r = random.Random(900 + mask)  # a few leaves drifted onto the path edge
    edge_px = [(x, y) for y in range(T) for x in range(T)
               if inside(x, y) and not all(inside(x + dx, y + dy) for dx, dy in nb4)]
    for x, y in r.sample(edge_px, min(2, len(edge_px))):
        px[x, y] = c(r.choice(("orange", "tan", "moss")))
    return t


# --------------------------------------------------------------------------
# Tileset
# --------------------------------------------------------------------------

TILE_NAMES = {
    0: "floor_a", 1: "floor_b", 2: "leaf_litter_a", 3: "leaf_litter_b", 4: "floor_twigs",
    5: "floor_pebbles", 6: "floor_mossy", 7: "floor_sprouts",
    8: "moss_patch_small", 9: "moss_patch_large", 10: "rock_small", 11: "rock_pair",
    12: "rock_mossy", 13: "mushrooms_red", 14: "mushrooms_brown", 15: "fern",
    16: "bush", 17: "bush_berries", 18: "fern_tall", 19: "stump", 20: "log_left",
    21: "log_mid", 22: "log_right", 23: "log_short",
    24: "boulder_tl", 25: "boulder_tr", 26: "canopy_fill_00", 27: "canopy_fill_10",
    28: "canopy_bottom_a", 29: "canopy_bottom_b", 30: "trunk_base_a", 31: "trunk_base_b",
    32: "boulder_bl", 33: "boulder_br", 34: "canopy_fill_01", 35: "canopy_fill_11",
    36: "canopy_top_a", 37: "canopy_top_b", 38: "path_fill", 39: "leaf_pile",
    40: "canopy_left_0", 41: "canopy_left_1", 42: "canopy_right_0", 43: "canopy_right_1",
    44: "canopy_corner_tl", 45: "canopy_corner_tr", 46: "canopy_corner_bl", 47: "canopy_corner_br",
    64: "flowers", 65: "twig_pinecone",
}
for _m in range(16):
    TILE_NAMES[PATH_BASE + _m] = "path_mask_%d" % _m
OPAQUE = {0, 1, 2, 3, 4, 5, 6, 7, 26, 27, 34, 35, 38}
# canopy tile -> block position (bx, by): place on cells with (x % 2, y % 2) == (bx, by)
CANOPY_BLOCK = {26: (0, 0), 27: (1, 0), 34: (0, 1), 35: (1, 1), 28: (0, 0), 29: (1, 0),
                36: (0, 1), 37: (1, 1), 40: (1, 0), 41: (1, 1), 42: (0, 0), 43: (0, 1),
                44: (1, 0), 45: (0, 0), 46: (1, 1), 47: (0, 1)}


def build_tiles():
    t = {}
    t[0], t[1] = floor_a(), floor_b()
    t[2], t[3] = leaf_litter(203, 3), leaf_litter(213, 4)
    t[4], t[5], t[6], t[7] = floor_twigs(), floor_pebbles(), floor_mossy(), floor_sprouts()
    t[8], t[9] = moss_patch(False), moss_patch(True)
    t[10], t[11], t[12] = rock_small(), rock_pair(), rock_mossy()
    t[13], t[14], t[15] = mushrooms_red(), mushrooms_brown(), fern()
    t[16], t[17], t[18], t[19] = bush(False), bush(True), fern_tall(), stump()
    t[20], t[21], t[22], t[23] = log_left(), log_mid(), log_right(), log_short()
    b = boulder()
    t[24], t[25] = b.crop((0, 0, 16, 16)), b.crop((16, 0, 32, 16))
    t[32], t[33] = b.crop((0, 16, 16, 32)), b.crop((16, 16, 32, 32))
    t[26], t[27], t[34], t[35] = block_tile(0, 0), block_tile(1, 0), block_tile(0, 1), block_tile(1, 1)
    t[28], t[29] = canopy_bottom(0), canopy_bottom(1)
    t[30], t[31] = trunk_base(0), trunk_base(1)
    t[36], t[37] = canopy_top(0), canopy_top(1)
    t[38], t[39] = path_fill(), leaf_pile()
    t[40], t[41] = canopy_side(True, 0), canopy_side(True, 1)
    t[42], t[43] = canopy_side(False, 0), canopy_side(False, 1)
    t[44], t[45] = canopy_corner(True, True), canopy_corner(True, False)
    t[46], t[47] = canopy_corner(False, True), canopy_corner(False, False)
    for m in range(16):
        t[PATH_BASE + m] = path_tile(m, t[38])
    t[64], t[65] = flowers(), twig()
    return t


def build_tileset(tiles=None):
    tiles = tiles or build_tiles()
    rows = (max(tiles) + COLS) // COLS
    sheet = new(COLS * T, rows * T)
    for i, tl in tiles.items():
        sheet.alpha_composite(tl, ((i % COLS) * T, (i // COLS) * T))
    return sheet


# --------------------------------------------------------------------------
# Room background (640x360 = the Assessment room's full draw area; room_rect 24,56 592x280)
# --------------------------------------------------------------------------

ROOM_W, ROOM_H = 640, 360
RC, RR = 40, 23  # grid (last row is cut to 8 px)


def path_cells():
    """Exit (bottom-left, 48,320) to the spawn (320,300), a spur north-east, and the way out
    running under the near canopy at the bottom-left."""
    cells = set()
    for x in range(3, 21):
        cells.add((x, 20))
    for y in range(17, 20):
        cells.add((20, y))
    for x in range(21, 25):
        cells.add((x, 17))
    for y in range(14, 17):
        cells.add((24, y))
    cells |= {(3, 21), (3, 22)}
    return cells


def canopy(x, y):
    return {(0, 0): 26, (1, 0): 27, (0, 1): 34, (1, 1): 35}[(x % 2, y % 2)]


def room_layers(seed=1234):
    """Returns (ground, over): {(col,row): tile} and {(col,row): [tiles, drawn in order]}."""
    r = random.Random(seed)
    ground, over = {}, {}
    weights = [(0, 40), (1, 24), (2, 12), (3, 6), (4, 5), (5, 4), (6, 4), (7, 5)]
    tot = sum(w_ for _, w_ in weights)
    for y in range(RR):
        for x in range(RC):
            roll = r.uniform(0, tot)
            for gi, w_ in weights:
                roll -= w_
                if roll <= 0:
                    break
            ground[(x, y)] = gi
    paths = path_cells()

    def add(cell, i):
        over.setdefault(cell, []).append(i)

    # tree wall: solid canopy rows 0-1, left/right columns 0 and 39, bottom row 22
    for x in range(RC):
        for y in range(RR):
            if y <= 1 or y == 22 or x in (0, RC - 1):
                ground[(x, y)] = canopy(x, y)
    for x in range(2, RC - 2):
        add((x, 2), 28 + x % 2)
        add((x, 3), 30 + x % 2)
    add((1, 2), 44)
    add((RC - 2, 2), 45)
    for y in range(3, 21):
        add((1, y), 40 + y % 2)
        add((RC - 2, y), 42 + y % 2)
    add((1, 21), 46)
    add((RC - 2, 21), 47)
    for x in range(2, RC - 2):
        add((x, 21), 36 + x % 2)
    # path: dirt autotile on the floor; the way out continues under the near canopy
    for (x, y) in paths:
        if y == 22:
            continue
        m = 0
        for bit, (dx, dy) in ((N, (0, -1)), (E, (1, 0)), (S, (0, 1)), (W, (-1, 0))):
            if (x + dx, y + dy) in paths:
                m |= bit
        over.setdefault((x, y), []).insert(0, PATH_BASE + m)
    # props (decorative; the background has no collision). Kept to the edges of the play area.
    props = [
        ((31, 5), 20), ((32, 5), 21), ((33, 5), 22),
        ((6, 5), 23), ((28, 13), 19), ((12, 4), 17), ((36, 16), 16), ((3, 16), 16), ((2, 6), 16),
        ((27, 4), 18), ((2, 10), 15), ((37, 11), 15), ((22, 5), 13), ((9, 16), 14),
        ((17, 9), 8), ((31, 18), 9), ((14, 13), 10), ((33, 13), 11), ((6, 4), 12),
        ((19, 4), 39), ((29, 14), 64), ((11, 18), 65), ((35, 19), 14), ((4, 12), 64),
        ((16, 15), 8), ((37, 6), 13), ((15, 5), 9), ((26, 19), 39), ((8, 9), 9), ((25, 9), 8),
        ((36, 4), 18), ((10, 7), 64), ((21, 12), 65), ((7, 18), 15), ((32, 9), 9),
        ((2, 14), 18), ((37, 14), 17), ((2, 19), 15), ((37, 20), 18), ((12, 11), 9), ((30, 16), 8),
        ((19, 15), 39), ((23, 20), 15), ((14, 19), 8), ((34, 4), 15), ((9, 4), 15),
    ]
    for cell, i in props:
        assert cell not in paths, cell
        add(cell, i)
    for (dx, dy), i in (((0, 0), 24), ((1, 0), 25), ((0, 1), 32), ((1, 1), 33)):
        add((34 + dx, 8 + dy), i)
    return ground, over


def compose_room(tiles, extra=None):
    """Compose the 640x360 background purely from tiles. extra: list of (img, x, y) sprites
    pasted after the tiles (previews only)."""
    ground, over = room_layers()
    img = Image.new("RGBA", (RC * T, RR * T), (0, 0, 0, 0))
    for (x, y), i in ground.items():
        img.alpha_composite(tiles[i], (x * T, y * T))
    for y in range(RR):  # overlays row by row (top to bottom)
        for x in range(RC):
            for i in over.get((x, y), []):
                img.alpha_composite(tiles[i], (x * T, y * T))
    for (spr, x, y) in extra or []:
        img.alpha_composite(spr, (x, y))
    return img.crop((0, 0, ROOM_W, ROOM_H))


# --------------------------------------------------------------------------
# Trap (16x16 frames: idle, set, shaking, knocked_over) and bait icon
# --------------------------------------------------------------------------

TRAP_C = {"o": "outline", "D": "brown_dark", "d": "brown", "m": "brown_mid", "l": "brown_light",
          "h": "tan", "s": "sand", "k": "soil_dark", "r": "red", "R": "red_dark", "y": "yellow",
          "Y": "orange", "w": "cream", "a": "ember_amber", "p": "stone_pale", "c": "white_warm",
          "t": "tan", "x": "loam_dark", "g": "green", "G": "green_grass"}

TRAP_IDLE = [   # closed crate trap resting on the ground, prop stick lying in front
    "................",
    "................",
    "..oooooooooooo..",
    ".ohhhmhhhhmhhho.",
    ".olllmllllmlllo.",
    ".ommmDmmmmDmmmo.",
    ".oDDDDDDDDDDDDo.",
    ".olmkklmkklmkdo.",
    ".olmkklmkklmkdo.",
    ".olmkklmkklmkdo.",
    ".ommmmmmmmmmmdo.",
    ".oddddddddddddo.",
    ".oooooooooooooo.",
    "..ooooooooooxx..",
    ".othhhhhhhldo...",
    "..oooooooooo....",
]

TRAP_SET = [    # crate propped up on the stick, bait under it
    "..oooooooooooo..",
    ".ohhhmhhhhmhhho.",
    ".olllmllllmlllo.",
    ".ommmDmmmmDmmmo.",
    ".oDDDDDDDDDDDDo.",
    ".olmkklmkklmkdo.",
    ".olmkklmkklmkdo.",
    ".ommmmmmmmmmmdo.",
    ".oddddddddddddo.",
    "..ooooooooooooo.",
    "..xkkkkkkkkoho..",
    "..xkkkoook.oho..",
    "..xkorYro.kohox.",
    "...xoRrRo.xohox.",
    "....oooo...ooo..",
    "................",
]

TRAP_SHAKE = [  # snapped shut with a creature inside: eyes in the slats, jiggle marks
    "................",
    "................",
    "...oooooooooooo.",
    "..ohhhmhhhhmhhho",
    "..olllmllllmlllo",
    "..ommmDmmmmDmmmo",
    "p.oDDDDDDDDDDDDo",
    "p.olmkalmkalmkdo",
    "..olmkklmkklmkdo",
    "p.olmkklmkklmkdo",
    "p.ommmmmmmmmmmdo",
    "..oddddddddddddo",
    "...oooooooooooo.",
    "...xxxxxxxxxxxx.",
    "................",
    "................",
]

_KNOCKED_BOX = [  # tipped toward the viewer: slatted front now on top, open bottom facing us
    "oooooooooooooo",
    "olmkklmkklmkdo",
    "olmkklmkklmkdo",
    "oDDDDDDDDDDDDo",
    "ohookkkkkkkooo",
    "ohokkkkkkkkoDo",
    "ohokkkkkkkkoDo",
    "ohoooooooooolo",
    "olllllllllllDo",
    "oooooooooooooo",
]
_KNOCKED_SHIFT = [2, 2, 1, 1, 1, 1, 0, 0, 0, 0]  # leans: the box lies askew
TRAP_KNOCKED = ["................"] * 2 + [
    "." * (1 + sh) + row + "." * (1 - sh) if sh <= 1 else "." * (sh) + row
    for row, sh in zip(_KNOCKED_BOX, _KNOCKED_SHIFT)
] + [
    "p..xxxxxxxxxxx.p",
    ".p...ooooo...p..",
    "....othhldo.....",
    ".....ooooo......",
]
TRAP_KNOCKED = [r.ljust(16, ".")[:16] for r in TRAP_KNOCKED]


BAIT = [   # cloth bait pouch, berries peeking out, a little sparkle
    "............c...",
    "...........cyc..",
    "............c...",
    ".....ooooo......",
    "....orYrYro.....",
    "....owhwhwo.....",
    ".....oRrRo......",
    "....owsshho.....",
    "...owsshhhdo....",
    "..owsshhhhhdo...",
    "..oshhhhhhhdo...",
    "..oshhhhhhhdo...",
    "..ohhhhhhhddo...",
    "...oddhhhddo....",
    "....ooooooo.....",
    "................",
]


def ascii_frame(rows, cmap, name):
    assert len(rows) == 16 and all(len(rw) == 16 for rw in rows), name
    f = new(16, 16)
    blit_map(f, rows, cmap)
    return f


def build_trap():
    frames = [TRAP_IDLE, TRAP_SET, TRAP_SHAKE, TRAP_KNOCKED]
    sheet = new(16 * len(frames), 16)
    for i, rows in enumerate(frames):
        sheet.alpha_composite(ascii_frame(rows, TRAP_C, "trap%d" % i), (16 * i, 0))
    return sheet


def build_bait():
    return ascii_frame(BAIT, TRAP_C, "bait")


# --------------------------------------------------------------------------

def outputs():
    tiles = build_tiles()
    return {
        "assets/tilesets/woodland_tiles.png": build_tileset(tiles),
        "assets/backgrounds/woodland_room.png": compose_room(tiles),
        "assets/sprites/trap_basic.png": build_trap(),
        "assets/sprites/item_bait.png": build_bait(),
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
        import preview_slice3
        preview_slice3.preview(sys.argv[sys.argv.index("--preview") + 1], outs)


if __name__ == "__main__":
    main()
