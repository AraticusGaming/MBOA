"""Woodland trees: seasonal sprite sheets for Oak, Pine, Birch and Maple (procedural, Pillow).

Writes assets/sprites/tree_<species>.png (240x320) for species oak, pine, birch, maple.
  * cell 48x80, anchor bottom-center (24, 80); trunk base on the 16px tile column x 16-31,
    feet on y = 79.
  * columns = TreeData.Stage: 0 seed, 1 seedling, 2 sapling, 3 grown, 4 stump.
  * rows = GameClock.Season: 0 spring, 1 summer, 2 fall, 3 winter.
Small stages are drawn at their natural size, bottom-centered (seed/seedling 16x16, sapling
16x32, stump up to 16x24); the rest of the cell is transparent.

Palette colors only (tools/art/palette.py; this batch appends 42-47), alpha 0/255, one pixel
scale, colored outlines. Deterministic (fixed seeds). Run:
  python3 tools/art/gen_woodland_trees.py [--preview DIR]
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

CW, CH = 48, 80                  # cell
AX = 24                          # anchor x (trunk centre between x 23 and 24)
SPECIES = ["oak", "pine", "birch", "maple"]
SEASONS = ["spring", "summer", "fall", "winter"]   # GameClock.Season order
STAGES = ["seed", "seedling", "sapling", "grown", "stump"]  # TreeData.Stage order


def new(w=CW, h=CH):
    return Image.new("RGBA", (w, h), TRANSPARENT)


# --------------------------------------------------------------------------
# Color ramps. Leaf ramp = (outline, dark, mid, light, highlight)
# --------------------------------------------------------------------------
LEAF = {
    ("oak", "spring"): ("green_dark", "green_forest", "green", "green_grass", "green_light"),
    ("oak", "summer"): ("canopy_deep", "green_dark", "green_forest", "green", "green_grass"),
    ("oak", "fall"): ("brown_dark", "brown", "rust", "orange", "tan"),
    ("pine", "spring"): ("canopy_deep", "green_dark", "pine", "pine_light", "green"),
    ("pine", "summer"): ("canopy_deep", "green_dark", "pine", "pine_light", "green"),
    ("pine", "fall"): ("canopy_deep", "green_dark", "green_forest", "green", "moss"),
    ("pine", "winter"): ("canopy_deep", "green_dark", "pine", "pine_light", "green"),
    ("birch", "spring"): ("green_forest", "green", "green_grass", "green_light", "green_pale"),
    ("birch", "summer"): ("green_dark", "green_forest", "green", "green_grass", "green_light"),
    ("birch", "fall"): ("brown", "brown_mid", "gold_dark", "yellow", "yellow_pale"),
    ("maple", "spring"): ("green_dark", "green", "green_grass", "green_light", "green_pale"),
    ("maple", "summer"): ("green_dark", "green_forest", "green", "green_grass", "green_light"),
    ("maple", "fall"): ("outline", "red_dark", "ember_deep", "ember_orange", "ember_amber"),
}
# Bark ramp = (outline, dark, mid, light, highlight)
BARK = {
    "oak": ("outline", "brown_dark", "brown", "brown_mid", "brown_light"),
    "pine": ("outline", "brown_dark", "red_dark", "brown", "brown_mid"),
    "birch": ("stone_dark", "stone", "stone_light", "stone_pale", "white_warm"),
    "maple": ("outline", "brown_dark", "brown", "brown_mid", "tan"),
}
TWIG = {"oak": "brown", "pine": "brown", "birch": "brown", "maple": "brown"}
MOUND = ("outline", "brown_dark", "brown", "brown_mid", "brown_light")


class Layer:
    """A drawing layer of palette names with an ownership map used for shading tricks."""

    def __init__(self, w=CW, h=CH):
        self.w, self.h = w, h
        self.p = {}
        self.twig = None   # optional layer for 1px twigs (drawn after outlining)

    def set(self, x, y, col):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[(x, y)] = col

    def outline(self, col, diag=False):
        add = set()
        nb = ((1, 0), (-1, 0), (0, 1), (0, -1))
        if diag:
            nb += ((1, 1), (-1, 1), (1, -1), (-1, -1))
        for (x, y) in self.p:
            for dx, dy in nb:
                q = (x + dx, y + dy)
                if q not in self.p and 0 <= q[0] < self.w and 0 <= q[1] < self.h:
                    add.add(q)
        for q in add:
            self.p[q] = col
        return add

    def paste(self, img, ox=0, oy=0):
        px = img.load()
        for (x, y), col in self.p.items():
            X, Y = x + ox, y + oy
            if 0 <= X < img.width and 0 <= Y < img.height:
                px[X, Y] = c(col)


# --------------------------------------------------------------------------
# Canopy: union of shaded clumps (later clumps on top), lit from the top-left
# --------------------------------------------------------------------------

def clump_canopy(clumps, ramp, seed, w=CW, h=CH, rim=True, tex=1.0, bounds=None):
    o, d0, d1, d2, hi = ramp
    lay = Layer(w, h)
    owner = {}
    for k, (cx, cy, rx, ry) in enumerate(clumps):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx, ny = (x + .5 - cx) / rx, (y + .5 - cy) / ry
                dd = nx * nx + ny * ny
                if dd > 1:
                    continue
                if bounds and not (bounds[0] <= x <= bounds[2] and bounds[1] <= y <= bounds[3]):
                    continue
                lit = -(nx * 0.55 + ny * 0.85)
                edge = math.sqrt(dd) > 1 - 1.2 / min(rx, ry)
                if rim and edge and lit < 0.05:
                    col = d0
                elif lit > 0.55 and dd > 0.08:
                    col = d2
                elif lit > 0.05:
                    col = d1
                elif lit > -0.4:
                    col = d1
                else:
                    col = d0
                lay.set(x, y, col)
                owner[(x, y)] = k
    # occlusion: pixel just below a different (earlier, higher) clump's area gets dark
    r = random.Random(seed)
    pts = sorted(lay.p)
    for (x, y) in r.sample(pts, int(len(pts) * 0.10 * tex)):
        col = lay.p[(x, y)]
        if col == d2:
            lay.p[(x, y)] = hi
            if (x + 1, y) in lay.p and lay.p[(x + 1, y)] == d2 and r.random() < .5:
                lay.p[(x + 1, y)] = hi
        elif col == d1:
            lay.p[(x, y)] = d2 if r.random() < .55 else d0
        elif col == d0 and r.random() < .4:
            lay.p[(x, y)] = d1
    return lay, owner


def add_blossoms(lay, ramp, seed, n, cols=("pink", "white_warm")):
    r = random.Random(seed)
    lit = [p for p, col in lay.p.items() if col in (ramp[3], ramp[4], ramp[2])]
    for (x, y) in r.sample(sorted(lit), min(n, len(lit))):
        lay.p[(x, y)] = cols[r.randrange(len(cols))]


# --------------------------------------------------------------------------
# Trunk and branches
# --------------------------------------------------------------------------

def trunk(lay, bark, top, bot, x0, x1, flare=3, marks=None, seed=0):
    """Vertical trunk x0..x1 (inclusive) from top to bot (bot = last fill row), lit from left."""
    o, d0, d1, d2, hi = bark
    r = random.Random(seed)
    for y in range(top, bot + 1):
        f = max(0, flare - (bot - y)) if flare else 0   # root flare on the bottom rows
        f = min(f, flare)
        a, b = x0 - f, x1 + f
        wdt = b - a + 1
        for x in range(a, b + 1):
            u = (x - a) / max(wdt - 1, 1)
            if u < 0.2:
                col = d2
            elif u < 0.45:
                col = hi if bark[0] == "stone_dark" else d2
            elif u < 0.75:
                col = d1
            else:
                col = d0
            lay.set(x, y, col)
    # bark streaks
    if marks == "birch":
        y = top + 1
        while y < bot - 2:
            ln = r.randint(2, 4)
            x = r.randint(x0, max(x0, x1 - ln + 1))
            for i in range(ln):
                if x0 <= x + i <= x1:
                    lay.set(x + i, y, "outline" if i in (0, ln - 1) else "stone_dark")
            y += r.randint(3, 6)
    else:
        for x in range(x0 + 1, x1):
            if r.random() < 0.5:
                y = r.randint(top, bot - 2)
                for k in range(r.randint(2, 5)):
                    if (x, y + k) in lay.p and lay.p[(x, y + k)] != d0:
                        lay.set(x, y + k, d0 if lay.p[(x, y + k)] in (d1, d2) else d1)


def line_pts(x0, y0, x1, y1):
    pts = []
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(n, 1)
        pts.append((round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)))
    return pts


def branch(lay, x, y, ang, length, width, depth, r, cols, spread=0.5, shrink=0.72,
           droop=0.0, tips=None):
    """Recursive branch. ang in radians, 0 = up, positive = right."""
    x1 = x + math.sin(ang) * length
    y1 = y - math.cos(ang) * length + droop * length
    tgt = lay.twig if (width == 1 and lay.twig is not None) else lay
    for (px_, py_) in line_pts(x, y, x1, y1):
        if tgt is not lay:
            if (px_, py_) not in lay.p:
                tgt.set(px_, py_, "brown_dark")
            continue
        for k in range(width):
            col = cols[0] if k == 0 and width > 1 else cols[min(1, len(cols) - 1)]
            lay.set(px_ + k, py_, col)
    if depth <= 0 or length < 2:
        if tips is not None:
            tips.append((round(x1), round(y1)))
        return
    nw = max(1, width - 1)
    for s in (-1, 1):
        branch(lay, x1, y1, ang + s * spread * r.uniform(0.7, 1.2), length * shrink * r.uniform(.85, 1.1),
               nw, depth - 1, r, cols, spread, shrink, droop, tips)
    if r.random() < 0.35:
        branch(lay, x1, y1, ang + r.uniform(-.15, .15), length * shrink * .8, nw, depth - 1, r, cols,
               spread, shrink, droop, tips)


def snow_on(img, prob=1.0, seed=0, deep=1, skip=(), only=None):
    """Put snow on upward-facing surfaces: the first fill pixel(s) under a top outline become
    snow, or (thin twigs) the outline pixel itself."""
    r = random.Random(seed)
    px = img.load()
    w, h = img.size
    tops = []
    for y in range(1, h):
        for x in range(w):
            p = px[x, y]
            if p[3] == 0 or px[x, y - 1][3] != 0:
                continue
            tops.append((x, y))
    for (x, y) in tops:
        if r.random() > prob or (x, y) in skip:
            continue
        if only is not None and px[x, y] not in [c(o) for o in only]:
            continue
        # (x,y) is an outline (top edge). Make it snow and the pixel under it snow/shade.
        px[x, y] = c("snow")
        if y + 1 < h and px[x, y + 1][3] and deep:
            px[x, y + 1] = c("snow_shade") if r.random() < .5 else c("snow")
    # outline the snow on top so it does not float
    add = []
    for (x, y) in tops:
        if px[x, y] == c("snow") and y - 1 >= 0 and px[x, y - 1][3] == 0 and r.random() < 0.0:
            add.append((x, y - 1))
    return img


# --------------------------------------------------------------------------
# Stage 3: grown trees
# --------------------------------------------------------------------------

def grown_oak(season):
    img = new()
    bark = BARK["oak"]
    tl = Layer()
    trunk(tl, bark, 44, 78, 19, 28, flare=2, seed=11)
    r = random.Random(12)
    br = Layer()
    tips = []
    if season == "winter":
        cols = ("brown_mid", "brown")
        br.twig = Layer()
        for sx, ang, ln, wd in ((20, -1.0, 13, 3), (26, 1.0, 13, 3), (21, -0.38, 18, 3),
                                (25, 0.38, 18, 3), (23, 0.05, 17, 2)):
            branch(br, sx, 47, ang, ln, wd, 3, r, cols, spread=0.5, shrink=0.66, tips=tips)
        for (x, y) in list(br.p):
            if not (2 <= x <= 45 and 3 <= y <= 70):
                del br.p[(x, y)]
        trunk(tl, bark, 46, 78, 19, 28, flare=2, seed=11)
    for (x, y), col in br.p.items():
        tl.p[(x, y)] = col
    tl.outline(bark[0])
    # keep the outline row on y = 79 inside the trunk tile column
    tl.paste(img)
    if br.twig is not None:
        br.twig.paste(img)
    if season == "winter":
        snow_on(img, 0.75, seed=13, deep=1, only=("outline",))
        return img
    ramp = LEAF[("oak", season)]
    clumps = [(24, 32, 19, 17), (20, 13, 10, 9), (31, 14, 10, 9), (11, 25, 9, 9), (37, 25, 9, 9),
              (25, 8, 8, 6), (8, 39, 7, 7), (40, 39, 7, 7), (16, 45, 9, 8), (32, 45, 9, 8),
              (24, 49, 9, 7)]
    can, _ = clump_canopy(clumps, ramp, 14, bounds=(1, 2, 46, 60))
    can.outline(ramp[0])
    can.paste(img)
    if season == "spring":
        blooms(img, ramp, 15, 7)
    return img


def add_blossoms_img(img, ramp, seed, n, cols):
    px = img.load()
    r = random.Random(seed)
    cand = [(x, y) for y in range(CH) for x in range(CW)
            if px[x, y] in (c(ramp[2]), c(ramp[3])) and px[x + 1, y] in (c(ramp[2]), c(ramp[3]))]
    for (x, y) in r.sample(cand, min(n, len(cand))):
        col = cols[r.randrange(len(cols))]
        px[x, y] = c(col)


def pine_tiers(tiers, ramp, seed, w=CW, h=CH, cx=AX, tooth=4):
    """Stacked drooping tiers. Lower tiers drawn first; each upper tier overlaps the next."""
    o, d0, d1, d2, hi = ramp
    lay = Layer(w, h)
    owner = {}
    r = random.Random(seed)
    n = len(tiers)
    for k in range(n - 1, -1, -1):
        top, bot, hw = tiers[k]
        for y in range(top, bot + 1):
            for x in range(w):
                dx = x + .5 - cx
                v = (y - top) / max(bot - top, 1)
                half = hw * (0.15 + 0.85 * v) if v < 1 else hw
                if abs(dx) > half:
                    continue
                # jagged bottom edge: needle tufts
                t = int(abs(dx)) % tooth
                lift = [0, 1, 2, 1, 0, 1][t % 6] if tooth else 0
                edge_y = bot - lift + int(abs(dx) / hw * 2.5)
                if y > edge_y:
                    continue
                u = dx / max(half, 1)
                lit = -0.75 * u + 0.35 - 0.55 * v
                if y >= edge_y - 1:
                    col = d0
                elif lit > 0.45:
                    col = d2
                elif lit > -0.1:
                    col = d1
                else:
                    col = d0
                lay.set(x, y, col)
                owner[(x, y)] = k
    # occlusion shadow just under each upper tier's fringe
    for (x, y), k in list(owner.items()):
        for dy in (1, 2):
            q = (x, y + dy)
            if q in owner and owner[q] > k and lay.p[q] != d0:
                lay.p[q] = d0 if dy == 1 else (d0 if lay.p[q] == d1 else d1)
    # needle texture: short down-out diagonal strokes
    pts = sorted(lay.p)
    for (x, y) in r.sample(pts, len(pts) // 9):
        col = lay.p[(x, y)]
        s = 1 if x + .5 > cx else -1
        up = {d0: d1, d1: d2, d2: hi}.get(col)
        if up is None:
            continue
        lay.p[(x, y)] = up if col != d2 or r.random() < .5 else col
        q = (x + s, y + 1)
        if q in lay.p and lay.p[q] == col and r.random() < .6:
            lay.p[q] = up
    return lay, owner


def grown_pine(season):
    img = new()
    bark = BARK["pine"]
    tl = Layer()
    trunk(tl, bark, 60, 78, 21, 26, flare=3, seed=21)
    tl.outline(bark[0])
    tl.paste(img)
    ramp = LEAF[("pine", season)]
    tiers = [(1, 16, 7), (8, 28, 11), (17, 40, 15), (27, 53, 19), (38, 66, 22)]
    can, owner = pine_tiers(tiers, ramp, 22)
    can.outline(ramp[0])
    can.paste(img)
    if season == "winter":
        snow_tiers(img, owner, seed=23)
    return img


def snow_tiers(img, owner, seed, cx=AX):
    """Snow lies on the upper face of each tier (top two rows of its exposed area) plus dabs."""
    px = img.load()
    r = random.Random(seed)
    for (x, y), k in owner.items():
        above = (x, y - 1)
        exposed = above not in owner or owner[above] != k
        if not exposed:
            continue
        # this pixel is the top of a run belonging to tier k
        if r.random() < 0.85:
            px[x, y] = c("snow")
            if (x, y + 1) in owner and owner[(x, y + 1)] == k and r.random() < 0.7:
                px[x, y + 1] = c("snow" if x + .5 < cx else "snow_shade")
            if (x, y + 2) in owner and owner[(x, y + 2)] == k and r.random() < 0.25:
                px[x, y + 2] = c("snow_shade")
    for _ in range(18):
        x, y = r.choice(sorted(owner))
        if px[x, y] not in (c("snow"), c("snow_shade")):
            px[x, y] = c("snow_shade") if r.random() < .5 else c("snow")


def grown_birch(season):
    img = new()
    bark = BARK["birch"]
    tl = Layer()
    trunk(tl, bark, 22, 78, 21, 26, flare=2, marks="birch", seed=31)
    r = random.Random(32)
    br = Layer()
    tips = []
    if season == "winter":
        cols = ("brown_mid", "brown")
        br.twig = Layer()
        for (sx, sy, ang, ln) in ((20, 40, -0.9, 9), (27, 36, 0.9, 9), (20, 30, -0.7, 8),
                                   (27, 27, 0.7, 8), (22, 22, -0.25, 8), (25, 22, 0.25, 8),
                                   (20, 48, -1.0, 7), (27, 46, 1.0, 7)):
            branch(br, sx, sy, ang, ln, 2, 3, r, ("brown_mid", "brown"), spread=0.45, shrink=0.75,
                   droop=0.15, tips=tips)
        for (x, y) in list(br.p):
            if not (1 <= x <= 46 and 1 <= y <= 66):
                del br.p[(x, y)]
    else:
        for (sx, sy, ang, ln) in ((21, 40, -0.9, 8), (26, 34, 0.9, 8), (22, 26, -0.6, 7),
                                   (25, 24, 0.6, 7)):
            branch(br, sx, sy, ang, ln, 1, 1, r, ("brown",), spread=0.5, tips=tips)
    for (x, y), col in br.p.items():
        if (x, y) not in tl.p:
            tl.p[(x, y)] = col
    tl.outline(bark[0] if season != "winter" else "outline")
    # trunk outline is stone_dark (soft grey); twigs keep a plum outline
    tl.paste(img)
    if br.twig is not None:
        br.twig.paste(img)
    if season == "winter":
        # catkins hanging from a few tips and snow dabs on branches
        px = img.load()
        for (x, y) in tips[::3]:
            for k in range(1, 3):
                if 0 <= x < CW and 0 <= y + k < CH and px[x, y + k][3] == 0:
                    px[x, y + k] = c("brown_mid")
        snow_on(img, 0.75, seed=33, deep=1, only=("outline",))
        return img
    ramp = LEAF[("birch", season)]
    clumps = [(24, 7, 5, 4), (18, 12, 6, 4), (30, 11, 6, 4), (13, 19, 6, 4), (35, 18, 6, 4),
              (23, 17, 6, 4), (9, 27, 5, 4), (39, 26, 5, 4), (19, 25, 7, 4), (30, 26, 6, 4),
              (14, 33, 6, 4), (34, 34, 6, 4), (24, 32, 5, 4), (9, 40, 5, 4), (39, 41, 5, 4),
              (19, 40, 5, 4), (30, 42, 5, 4), (13, 47, 4, 3), (35, 49, 4, 3)]
    can, _ = clump_canopy(clumps, ramp, 34, bounds=(1, 1, 46, 56), rim=False)
    # airy: knock out small holes so branches/sky show through
    r = random.Random(35)
    for (hx, hy) in ((24, 37), (19, 30), (29, 31), (25, 22), (14, 41), (35, 45), (12, 24)):
        for y in range(hy - 1, hy + 2):
            for x in range(hx - 1, hx + 1 + (r.random() < .5)):
                can.p.pop((x, y), None)
    can.outline(ramp[0])
    can.paste(img)
    if season == "spring":
        add_blossoms_img(img, ramp, 36, 10, ("yellow_pale", "green_pale"))   # catkins / new leaves
    if season == "fall":
        add_blossoms_img(img, ramp, 37, 8, ("tan", "yellow_pale"))
    return img


def grown_maple(season):
    img = new()
    bark = BARK["maple"]
    tl = Layer()
    trunk(tl, bark, 50, 78, 20, 27, flare=3, seed=41)
    r = random.Random(42)
    br = Layer()
    if season == "winter":
        cols = ("brown_mid", "brown")
        br.twig = Layer()
        for ang, ln, wd in ((-0.4, 17, 3), (0.4, 17, 3), (-0.85, 12, 2), (0.85, 12, 2), (0.0, 18, 2)):
            branch(br, 23 + (1 if ang > 0 else -1 if ang < 0 else 0), 52, ang, ln, wd, 3, r, cols,
                   spread=0.3, shrink=0.74)
        for (x, y) in list(br.p):
            if not (1 <= x <= 46 and 1 <= y <= 70):
                del br.p[(x, y)]
    for (x, y), col in br.p.items():
        tl.p[(x, y)] = col
    tl.outline(bark[0])
    tl.paste(img)
    if br.twig is not None:
        br.twig.paste(img)
    if season == "winter":
        snow_on(img, 0.75, seed=43, deep=1, only=("outline",))
        return img
    ramp = LEAF[("maple", season)]
    # rounded star: a dome plus five pointed lobes
    clumps = maple_clumps(24, 29, 24)
    can, _ = clump_canopy(clumps, ramp, 44, bounds=(1, 2, 46, 58))
    can.outline(ramp[0])
    can.paste(img)
    return img


def maple_clumps(cx, cy, R):
    """Rounded star: a dome plus five broad lobes (one up, two out, two down-out), each ending in
    a small pointed tip; the notches between lobes stay visible."""
    out = [(cx, cy, R * 0.6, R * 0.56)]
    for k, ang in enumerate((0, 68, -68, 140, -140)):
        a = math.radians(ang)
        sx, sy = math.sin(a), -math.cos(a)
        rr = R * (0.40 if k == 0 else 0.42)
        out.append((cx + sx * R * 0.56, cy + sy * R * 0.56, rr, rr * 0.95))
        out.append((cx + sx * R * 0.88, cy + sy * R * 0.88, R * 0.17, R * 0.17))
    for ang in (34, -34):   # two small shoulder fillers keep the top round, not spiky
        a = math.radians(ang)
        out.append((cx + math.sin(a) * R * 0.62, cy - math.cos(a) * R * 0.62, R * 0.2, R * 0.2))
    return sorted(out, key=lambda t: t[1])


def blooms(img, ramp, seed, n):
    """Small 2x2 blossoms (pink with a white lit corner) on lit leaves."""
    px = img.load()
    r = random.Random(seed)
    ok = (c(ramp[2]), c(ramp[3]), c(ramp[4]))
    cand = [(x, y) for y in range(CH - 1) for x in range(CW - 1)
            if all(px[x + i, y + j] in ok for i in (0, 1) for j in (0, 1))]
    used = []
    for (x, y) in r.sample(cand, len(cand)):
        if len(used) >= n:
            break
        if any(abs(x - u) < 7 and abs(y - v) < 7 for u, v in used):
            continue
        used.append((x, y))
        px[x, y] = c("white_warm")
        px[x + 1, y] = c("pink")
        px[x, y + 1] = c("pink")
        px[x + 1, y + 1] = c("red") if r.random() < .3 else c("pink")


GROWN = {"oak": grown_oak, "pine": grown_pine, "birch": grown_birch, "maple": grown_maple}


# --------------------------------------------------------------------------
# Stages 0-2 and the stump, drawn in small boxes and placed bottom-center
# --------------------------------------------------------------------------
MOUND_ROWS = [
    "....oooooooo....",
    "...oDdmmlmdDo...",
    "..odmmllmmmmdo..",
    "...oooooooooo...",
]


def keymap(sp, season):
    leaf = LEAF.get((sp, season), LEAF[(sp, "summer")])
    bark = BARK[sp]
    return {
        "o": "outline", "D": "brown_dark", "d": "brown", "m": "brown_mid", "l": "brown_light",
        "h": "tan", "w": "cream",
        "O": leaf[0], "1": leaf[1], "2": leaf[2], "3": leaf[3], "4": leaf[4],
        "b": bark[0], "B": bark[1], "c": bark[2], "e": bark[3], "f": bark[4],
        "s": "snow", "S": "snow_shade", "r": "red", "R": "red_dark", "y": "yellow", "g": "gold_dark",
        "k": "stone_dark", "t": "rust", "q": "orange",
    }


def draw_rows(img, rows, km, ox, oy):
    px = img.load()
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            X, Y = ox + i, oy + j
            if 0 <= X < img.width and 0 <= Y < img.height:
                px[X, Y] = c(km[ch])


SEEDS = {
    "oak": [              # acorn: cap + nut on the mound
        "......ooo.......",
        ".....oDdDo......",
        "....oDmdmDo.....",
        "....ooooooo.....",
        ".....olhmo......",
        ".....ohlmo......",
        "......odo.......",
    ],
    "pine": [             # pine cone lying on its side
        "...ooooooo......",
        "..odmdmdmdoo....",
        ".odlmlmlmmdDo...",
        "..odmdmdmdoo....",
        "...ooooooo......",
    ],
    "birch": [            # dangling catkin of seeds
        ".......o........",
        "......omo.......",
        ".....omhmo......",
        ".....odmdo......",
        ".....omhmo......",
        ".....odmdo......",
        ".....omhmo......",
        "......odo.......",
    ],
    "maple": [            # samara pair (helicopter seeds)
        ".oo.......oo....",
        "ohho.....ohho...",
        "ohllo...ollho...",
        ".ollmooomllo....",
        "..ooomDmooo.....",
        ".....oDo........",
    ],
}

# season-independent leaf shapes for seedlings: '1..4' leaf ramp, 'c/e' stem
SEEDLINGS = {
    "oak": [
        "..OO......OO....",
        ".O34O....O43O...",
        "O3432O..O2343O..",
        "O2322O..O2232O..",
        ".O221OOOO122O...",
        "..OO1OeBO1OO....",
        "....OOeBOO......",
        "......eB........",
        "......eB........",
    ],
    "pine": [
        ".....O..O.......",
        "..O.O3OO3O.O....",
        ".O3O.O32O.O3O...",
        "..O33O22O33O....",
        "...OO2112OO.....",
        ".O3322112233O...",
        "..OOO1eB1OOO....",
        "......eB........",
        "......eB........",
    ],
    "birch": [
        ".......OO.......",
        "......O34O......",
        "..OO..O23O......",
        ".O34O..O2O..OO..",
        ".O232O.eB..O43O.",
        "..O21OeB...O32O.",
        "...OO.eB.OO12O..",
        "......eBeB.OO...",
        "......eB........",
        "......eB........",
    ],
    "maple": [
        "...O........O...",
        "..O3O.O..O.O3O..",
        ".O343O3OO3O343O.",
        "..O2323OO3232O..",
        ".O32221OO12223O.",
        "..OOO11OO11OOO..",
        ".....OOeBOO.....",
        "......eB........",
        "......eB........",
    ],
}


def stage_seed(sp, season):
    img = new(16, 16)
    km = keymap(sp, season)
    rows = SEEDS[sp]
    draw_rows(img, MOUND_ROWS, km, 0, 12)
    if season == "winter":
        snow_on(img, 1.0, seed=hash_seed(sp, 1), deep=0)   # snowy mound, seed still visible
    draw_rows(img, rows, km, 1, 14 - len(rows))
    if season == "fall":
        leaf_dab(img, sp, 11, 10)
    if season == "winter":
        px = img.load()
        top = min(y for y in range(16) for x in range(16) if px[x, y][3])
        xs = [x for x in range(16) if px[x, top][3]]
        for x in xs[:2]:
            px[x, top] = c("snow")
    if season == "spring":
        draw_rows(img, [".O.", "O3O", ".O."], keymap("oak", "spring"), 12, 10)
    return img


def leaf_dab(img, sp, x, y):
    km = keymap(sp, "fall")
    draw_rows(img, ["OO.", "O32O"[:3], ".OO"], km, x, y)


def hash_seed(sp, k):
    return SPECIES.index(sp) * 100 + k


def stage_seedling(sp, season):
    img = new(16, 16)
    km = keymap(sp, season)
    km["e"], km["B"] = "green", "green_forest"
    if sp == "birch":
        km["e"], km["B"] = "brown_mid", "brown"
    rows = SEEDLINGS[sp]
    if season == "winter" and sp != "pine":
        # bare: only the stem remains, with two leaf buds
        rows = [r.replace("O", ".").replace("1", ".").replace("2", ".").replace("3", ".")
                .replace("4", ".") for r in rows]
        km["e"], km["B"] = "brown_mid", "brown"
    draw_rows(img, MOUND_ROWS, km, 0, 12)
    draw_rows(img, rows, km, 1, 13 - len(rows))
    if season == "winter" and sp != "pine":
        lay = Layer(16, 16)
        px = img.load()
        for y in range(16):
            for x in range(16):
                if px[x, y][3] and y < 12:
                    lay.set(x, y, "x")
        add = lay.outline("x")
        for (x, y) in add:
            if px[x, y][3] == 0 and y < 12:
                px[x, y] = c("outline")
        top = min(y for y in range(16) for x in range(16) if px[x, y][3])
        xs = [x for x in range(16) if px[x, top][3]]
        for x in xs:
            px[x, top] = c("snow")
    if season == "winter":
        snow_on(img, 0.8, seed=hash_seed(sp, 2), deep=0)
    return img


def sapling(sp, season):
    img = new(16, 32)
    bark = BARK[sp]
    tl = Layer(16, 32)
    w0, w1 = (7, 8)
    for y in range(12 if sp != "pine" else 22, 31):
        tl.set(w0, y, bark[3] if sp != "birch" else bark[4])
        tl.set(w1, y, bark[2] if sp != "birch" else bark[2])
    if sp == "birch":
        for y in (16, 20, 25):
            tl.set(w0 + (y % 2), y, "outline")
    tl.set(6, 30, bark[2])
    tl.set(9, 30, bark[1])
    tl.outline(bark[0])
    r = random.Random(hash_seed(sp, 3))
    if season == "winter" and sp != "pine":
        br = Layer(16, 32)
        cols = ("brown",)
        for (sx, sy, ang, ln) in {
            "oak": ((7, 14, -0.8, 5), (8, 13, 0.8, 5), (7, 10, -0.1, 5)),
            "birch": ((7, 16, -0.6, 4), (8, 14, 0.6, 4), (7, 11, 0.0, 5)),
            "maple": ((7, 14, -0.5, 5), (8, 14, 0.5, 5), (8, 11, 0.0, 4)),
        }[sp]:
            branch(br, sx, sy, ang, ln, 1, 2, r, cols, spread=0.5, shrink=0.65)
        for (x, y), col in br.p.items():
            if (x, y) not in tl.p and 1 <= x <= 14:
                tl.p[(x, y)] = col
        tl.outline("outline")
        tl.paste(img)
        snow_on(img, 0.45, seed=hash_seed(sp, 4), deep=0)
        draw_rows(img, ["sSss"], keymap(sp, season), 5, 30) if False else None
        return img
    tl.paste(img)
    ramp = LEAF.get((sp, season), LEAF[(sp, "summer")])
    if sp == "pine":
        can, owner = pine_tiers([(2, 11, 4), (6, 17, 6), (11, 24, 7)], ramp, hash_seed(sp, 5),
                                w=16, h=32, cx=8, tooth=3)
        can.outline(ramp[0])
        can.paste(img)
        if season == "winter":
            snow_tiers(img, owner, hash_seed(sp, 6), cx=8)
        return img
    clumps = {
        "oak": [(8, 11, 6.5, 6), (4.5, 14, 3.5, 3.5), (11.5, 14, 3.5, 3.5), (8, 6, 4, 3.5)],
        "birch": [(8, 5, 3, 3), (5, 10, 3.2, 3), (11, 9, 3.2, 3), (6, 15, 3, 2.6), (10.5, 15, 3, 2.6)],
        "maple": [(8, 11, 5.5, 5), (8, 4.5, 2.5, 2.5), (3, 9, 2.5, 2.5), (13, 9, 2.5, 2.5),
                  (4, 15, 2.5, 2.2), (12, 15, 2.5, 2.2)],
    }[sp]
    can, _ = clump_canopy(clumps, ramp, hash_seed(sp, 7), w=16, h=32, tex=0.7, bounds=(1, 1, 14, 22))
    can.outline(ramp[0])
    can.paste(img)
    if sp == "oak" and season == "spring":
        add_blossoms_img_box(img, ramp, hash_seed(sp, 8), 3, ("pink", "white_warm"))
    return img


def add_blossoms_img_box(img, ramp, seed, n, cols):
    px = img.load()
    r = random.Random(seed)
    w, h = img.size
    cand = [(x, y) for y in range(h) for x in range(w) if px[x, y] in (c(ramp[2]), c(ramp[3]))]
    for (x, y) in r.sample(cand, min(n, len(cand))):
        px[x, y] = c(cols[r.randrange(len(cols))])


STUMP_ROWS = {
    "oak": [
        "...oooooooooo...",
        "..ohwwwwwwwwho..",
        ".ohwwhhhhhhwwho.",
        ".ohwhwwwwwwhwho.",
        ".ohwwhhhhhhwwho.",
        ".oehhwwwwwwhhco.",
        ".oeeccBccBcccBo.",
        ".oefecBcecBccBo.",
        ".oeecBccBcccBBo.",
        ".oefcccBcecBBBo.",
        "ofeecBcccBccBBBo",
        "oeecBoooooocBBBo",
        ".ooo........ooo.",
    ],
    "pine": [
        "....oooooooo....",
        "...ohwwwwwwho...",
        "..ohwhhhhhhwho..",
        "..ohwhwwwwhwho..",
        "..oehhwwwwhhco..",
        "..oeecBccBccBo..",
        "..oefcBecBcBBo..",
        "..oecBcecBcBBo..",
        ".ofeecBccBccBBo.",
        ".oeeccoooooBBBo.",
        "..ooo......ooo..",
    ],
    "birch": [
        "....oooooooo....",
        "...ohwwwwwwho...",
        "..ohwhhhhhhwho..",
        "..ohwhwwwwhwho..",
        "..offeeeeeeccb..",
        "..bfffeeeecBBb..",
        "..bfoooeeeccBb..",
        "..bffeeeeeccBb..",
        ".bffeeeeeooocBb.",
        ".bfeeeeeeeccBBb.",
        "..bbb......bbb..",
    ],
    "maple": [
        "...oooooooooo...",
        "..ohwwwwwwwwho..",
        "..ohwhhhhhhwho..",
        "..ohwhwwwwhwho..",
        "..ohwwhhhhwwho..",
        "..oefhhwwwhhco..",
        "..oefecBccBcBo..",
        "..oeecBcecBcBo..",
        ".ofeecBccBccBBo.",
        ".oeefcBcecBcBBo.",
        "oeeecooooooBBBBo",
        ".ooo........ooo.",
    ],
}


def stump(sp, season):
    rows = STUMP_ROWS[sp]
    img = new(16, 24)
    km = keymap(sp, season)
    if sp == "birch":
        km["o"] = "outline"
    draw_rows(img, rows, km, 0, 24 - len(rows))
    if season == "winter":
        snow_on(img, 1.0, seed=hash_seed(sp, 9), deep=1)
    if season == "fall":
        draw_rows(img, ["OO.", "O32O"[:3]], keymap({"pine": "oak"}.get(sp, sp), "fall"), 12, 21)
        draw_rows(img, ["OO", "3O"], keymap({"pine": "maple"}.get(sp, sp), "fall"), 1, 22)
    if season == "spring":
        draw_rows(img, [".O.", "O3O", "O2O", ".O."], keymap("oak", "spring"), 12, 24 - len(rows) - 2)
    return img


# --------------------------------------------------------------------------
# Sheet assembly
# --------------------------------------------------------------------------

def place(cell, img):
    """Paste a small-stage image bottom-centered on the trunk tile column (x 16-31)."""
    x = AX - img.width // 2
    cell.alpha_composite(img, (x, CH - img.height))


def build_sheet(sp):
    sheet = new(CW * len(STAGES), CH * len(SEASONS))
    for row, season in enumerate(SEASONS):
        cells = [new() for _ in STAGES]
        place(cells[0], stage_seed(sp, season))
        place(cells[1], stage_seedling(sp, season))
        place(cells[2], sapling(sp, season))
        cells[3] = GROWN[sp](season)
        place(cells[4], stump(sp, season))
        for col, cell in enumerate(cells):
            sheet.alpha_composite(cell, (col * CW, row * CH))
    return sheet


def outputs():
    return {f"assets/sprites/tree_{sp}.png": build_sheet(sp) for sp in SPECIES}


def validate(name, img):
    pal = set(RGBA)
    for p in (img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()):
        if p[3] == 0:
            continue
        assert p[3] == 255, (name, p)
        assert p in pal, (name, p)
    assert img.size == (CW * 5, CH * 4), (name, img.size)
    for row in range(4):
        for col in range(5):
            cell = img.crop((col * CW, row * CH, col * CW + CW, row * CH + CH))
            bb = cell.getbbox()
            assert bb and bb[3] == CH, (name, row, col, bb)
            base = [x for x in range(CW) if cell.getpixel((x, CH - 1))[3]]
            assert base and min(base) >= 16 and max(base) <= 31, (name, row, col, base)


def main():
    outs = outputs()
    for rel, img in outs.items():
        validate(rel, img)
        p = ROOT / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        img.save(p)
        print("wrote", rel, img.size)
    if "--preview" in sys.argv:
        import preview_woodland_trees
        preview_woodland_trees.preview(sys.argv[sys.argv.index("--preview") + 1], outs)


if __name__ == "__main__":
    main()
