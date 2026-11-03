"""Woodland trees: seasonal sprite sheets for Oak, Pine, Birch and Maple (procedural, Pillow).

Writes assets/sprites/tree_<species>.png (240x320) for species oak, pine, birch, maple.
  * cell 48x80, anchor bottom-center (24, 80); trunk base on the 16px tile column x 16-31,
    feet on y = 79.
  * columns = TreeData.Stage: 0 seed, 1 seedling, 2 sapling, 3 grown, 4 stump.
  * rows = GameClock.Season: 0 spring, 1 summer, 2 fall, 3 winter.
Small stages are drawn at their natural size, bottom-centered (seed/seedling 16x16, sapling
16x32, stump up to 16x24); the rest of the cell is transparent.

How the grown trees are built (all seeded, so output is byte-identical run to run):
  1. bark: trunk + limbs as a mask (gnarled polylines with tapering width), then a shading pass
     (lit left/top edge, shadowed right/bottom), vertical ridges, knots, root flare.
  2. canopy: a species envelope is filled with a dark back mass (inner shadow pockets), then
     many seeded leaf clumps of varied size are layered on it; each clump is lit from the
     top-left (local normal + whole-crown gradient) with a rim highlight and casts a shadow on
     the clumps under it. Maple clumps have pointed, jagged leaf tips. Holes are carved so
     limbs / sky show through, loose leaves are scattered at the edge, then a colored outline.
  3. winter: species-specific bare structures (oak: heavy twisting wide limbs; maple: upright
     vase of fine ascending twigs; birch: weeping twigs) with snow on upward surfaces.

Palette colors only (tools/art/palette.py; trees use 42-51), alpha 0/255, one pixel scale.
Run: python3 tools/art/gen_woodland_trees.py [--preview DIR]
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
# Ramps: (outline, deep, dark, mid, light, highlight)
# --------------------------------------------------------------------------
G_SUMMER_DEEP = ("canopy_deep", "green_dark", "green_forest", "green", "green_grass", "green_light")
G_SPRING = ("green_dark", "green_forest", "green", "green_grass", "green_light", "green_pale")
G_BRIGHT = ("green_dark", "green_forest", "green", "green_grass", "green_light", "green_pale")
G_PALE = ("green_forest", "green", "green_grass", "green_light", "green_pale", "yellow_pale")
OAK_FALL = [("brown_dark", "brown", "rust", "orange", "tan", "sand"),
            ("brown_dark", "brown", "rust", "orange", "ember_amber", "gold"),
            ("brown_dark", "rust", "orange", "ember_amber", "gold", "yellow_pale"),
            ("brown_dark", "green_forest", "moss", "gold_dark", "tan", "sand")]
MAPLE_FALL = [("outline", "red_dark", "crimson", "ember_deep", "ember_orange", "ember_amber"),
              ("outline", "red_dark", "ember_deep", "ember_orange", "ember_amber", "ember_yellow"),
              ("outline", "rust", "orange", "ember_amber", "gold", "ember_yellow"),
              ("outline", "gold_dark", "gold", "yellow", "ember_yellow", "yellow_pale")]
BIRCH_FALL = [("brown", "brown_mid", "gold_dark", "gold", "yellow", "yellow_pale"),
              ("brown", "gold_dark", "gold", "yellow", "yellow_pale", "ember_cream"),
              ("brown", "green_forest", "moss", "gold_dark", "yellow", "yellow_pale")]
PINE = ("canopy_deep", "canopy_deep", "green_dark", "pine", "pine_light", "green")
PINE_SPRING = ("canopy_deep", "canopy_deep", "green_dark", "pine", "pine_light", "green_light")
PINE_FALL = ("canopy_deep", "canopy_deep", "green_dark", "green_forest", "moss", "green_light")

# bark ramps: (outline, deep, dark, mid, light, highlight)
BARK = {
    "oak": ("outline", "soil_dark", "brown_dark", "brown", "brown_mid", "brown_light"),
    "pine": ("outline", "soil_dark", "brown_dark", "red_dark", "brown", "brown_mid"),
    "birch": ("stone_dark", "stone", "stone_light", "stone_pale", "white_warm", "white_warm"),
    "maple": ("outline", "brown_dark", "bark_grey", "bark_grey", "bark_grey_light", "stone_light"),
}

SUMMER_LEAF = {"oak": G_SUMMER_DEEP, "birch": G_BRIGHT, "maple": G_BRIGHT, "pine": PINE}
SPRING_LEAF = {"oak": G_SPRING, "birch": G_PALE, "maple": G_PALE, "pine": PINE_SPRING}


def leaf_ramp(sp, season, k=0):
    if sp == "pine":
        return {"spring": PINE_SPRING, "fall": PINE_FALL}.get(season, PINE)
    if season == "spring":
        return SPRING_LEAF[sp]
    if season == "fall":
        return {"oak": OAK_FALL, "birch": BIRCH_FALL, "maple": MAPLE_FALL}[sp][k]
    return SUMMER_LEAF[sp]


class Noise:
    """Deterministic 2-D value noise (bilinear) for organic variation."""

    def __init__(self, seed, cell=6):
        self.r = random.Random(seed)
        self.cell = cell
        self.g = {}

    def _v(self, i, j):
        if (i, j) not in self.g:
            self.g[(i, j)] = self.r.random()
        return self.g[(i, j)]

    def __call__(self, x, y):
        fx, fy = x / self.cell, y / self.cell
        i, j = math.floor(fx), math.floor(fy)
        u, v = fx - i, fy - j
        u, v = u * u * (3 - 2 * u), v * v * (3 - 2 * v)
        a = self._v(i, j) * (1 - u) + self._v(i + 1, j) * u
        b = self._v(i, j + 1) * (1 - u) + self._v(i + 1, j + 1) * u
        return a * (1 - v) + b * v


# --------------------------------------------------------------------------
# Generic pixel layer
# --------------------------------------------------------------------------
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


class Layer(dict):
    def __init__(self, w=CW, h=CH):
        super().__init__()
        self.w, self.h = w, h

    def ok(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def set(self, x, y, v):
        if self.ok(x, y):
            self[(x, y)] = v

    def outline(self, col, lit_col=None, clip_bottom=None):
        """Colored outline on empty 4-neighbours. lit_col (optional) is used where the outline
        sits on the top/left (lit) side of the shape."""
        add = {}
        for (x, y) in self:
            for dx, dy in N4:
                q = (x + dx, y + dy)
                if q in self or not self.ok(*q):
                    continue
                if clip_bottom is not None and q[1] > clip_bottom:
                    continue
                lit = lit_col is not None and (dx == -1 or dy == -1)
                if q in add and add[q] == col:
                    continue
                add[q] = lit_col if lit else col
        for q, v in add.items():
            self[q] = v
        return set(add)

    def paste(self, img, ox=0, oy=0):
        px = img.load()
        for (x, y), col in self.items():
            X, Y = x + ox, y + oy
            if 0 <= X < img.width and 0 <= Y < img.height:
                px[X, Y] = c(col)


# --------------------------------------------------------------------------
# Bark: masks, shading, texture
# --------------------------------------------------------------------------

def disc(mask, x, y, r, tag=1):
    if r < 0.75:
        mask.set(round(x - .5), round(y - .5), tag)
        return
    for yy in range(int(math.floor(y - r)), int(math.ceil(y + r)) + 1):
        for xx in range(int(math.floor(x - r)), int(math.ceil(x + r)) + 1):
            if (xx + .5 - x) ** 2 + (yy + .5 - y) ** 2 <= r * r:
                mask.set(xx, yy, tag)


def limb(mask, x, y, ang, length, w0, w1, r, gnarl=0.0, up=0.0, tag=1, stop=None):
    """Polyline limb from (x, y). ang: radians, 0 = straight up, + = right. up pulls the
    direction toward vertical (ascending twigs). Returns the end point and direction."""
    steps = max(1, int(length))
    for i in range(steps):
        t = i / steps
        if i % 3 == 0 and gnarl:
            ang += r.uniform(-gnarl, gnarl)
        ang -= ang * up * 0.08
        nx, ny = x + math.sin(ang), y - math.cos(ang)
        if stop and stop(nx, ny):
            break
        x, y = nx, ny
        disc(mask, x, y, (w0 + (w1 - w0) * t) / 2, tag)
    return x, y, ang


def shade_bark(mask, ramp, seed, ridges=True, horiz_marks=False):
    """Mask (pixel -> tag) to colors: lit on the left (vertical runs) or top (flat runs)."""
    o, deep, dark, mid, light, hi = ramp
    n = Noise(seed, 3)
    out = Layer(mask.w, mask.h)
    for (x, y) in mask:
        l = 0
        while (x - l - 1, y) in mask:
            l += 1
        rr = 0
        while (x + rr + 1, y) in mask:
            rr += 1
        t = 0
        while (x, y - t - 1) in mask and t < 8:
            t += 1
        b = 0
        while (x, y + b + 1) in mask and b < 8:
            b += 1
        wh, wv = l + rr + 1, t + b + 1
        if wh <= wv:      # vertical-ish
            u = l / max(wh - 1, 1) if wh > 1 else 0.4
        else:             # flat limb: lit from the top
            u = t / max(wv - 1, 1) if wv > 1 else 0.4
        width = min(wh, wv)
        if width <= 2:
            col = light if u < 0.5 else dark
        elif u < 0.18:
            col = hi if width >= 5 else light
        elif u < 0.42:
            col = light
        elif u < 0.72:
            col = mid
        elif u < 0.9:
            col = dark
        else:
            col = deep
        # vertical ridges (wavy), only on wide vertical parts
        if ridges and wh <= wv and wh >= 5 and 0.1 < u < 0.92:
            wav = math.sin(y * 0.45 + x * 1.7) * 0.8 + (n(x * 3, y) - .5) * 1.6
            if (x + round(wav)) % 3 == 0:
                col = {hi: light, light: mid, mid: dark, dark: deep}.get(col, col)
        out[(x, y)] = col
    return out


def knot(lay, x, y, ramp, big=False):
    o, deep, dark, mid, light, hi = ramp
    if big:
        for (dx, dy, cl) in ((-1, -1, light), (0, -1, light), (1, -1, mid), (-1, 0, dark), (0, 0, deep),
                             (1, 0, deep), (-1, 1, mid), (0, 1, dark), (1, 1, dark)):
            if (x + dx, y + dy) in lay:
                lay[(x + dx, y + dy)] = cl
    else:
        for (dx, dy, cl) in ((0, -1, light), (0, 0, deep), (1, 0, dark)):
            if (x + dx, y + dy) in lay:
                lay[(x + dx, y + dy)] = cl


def trunk_mask(mask, top, bot, cx_fn, w_fn, roots=(), tag=1):
    """Vertical trunk; cx_fn(y) center (float), w_fn(y) width. roots: (dir, length) root
    tendrils spreading from the base."""
    for y in range(top, bot + 1):
        cx, w = cx_fn(y), w_fn(y)
        x0 = round(cx - w / 2)
        for x in range(x0, x0 + max(1, round(w))):
            mask.set(x, y, tag)


def clamp_base(m):
    """Keep the bottom fill row (y = 78) inside the trunk tile so the outline row y = 79 stays
    on x 16-31 (anchor contract)."""
    for q in list(m):
        if q[1] >= 78 and not (16 <= q[0] <= 31):
            del m[q]
        elif q[1] >= 79:
            del m[q]


def snow_cap(img, ok_cols, seed, prob=0.85, thick=2, min_run=2, pile=0.6):
    """Snow on upward-facing surfaces of pixels whose color is in ok_cols (fill colors),
    placed on/above the outline so the branch keeps its shape."""
    px = img.load()
    w, h = img.size
    r = random.Random(seed)
    okc = {c(o) for o in ok_cols}
    for x in range(w):
        for y in range(2, h - 1):
            if px[x, y] not in okc:
                continue
            # find the outline above
            if px[x, y - 1][3] and px[x, y - 1] not in okc and px[x, y - 2][3] == 0:
                # run length to the left/right of upward surfaces
                run = 1
                for d in (1, -1):
                    k = 1
                    while 0 <= x + d * k < w and px[x + d * k, y][3] and px[x + d * k, y - 1][3] and \
                            px[x + d * k, y - 2][3] == 0 and k < 4:
                        run += 1
                        k += 1
                if run < min_run or r.random() > prob:
                    continue
                px[x, y - 1] = c("snow")
                if thick >= 2 and run >= 3 and r.random() < pile:
                    px[x, y - 2] = c("snow")
                if r.random() < 0.45:
                    px[x, y] = c("snow_shade")


# --------------------------------------------------------------------------
# Canopy
# --------------------------------------------------------------------------

def place_clumps(r, inside, bbox, rmin, rmax, tries, sep=0.62, keep_inside=0.55):
    x0, y0, x1, y1 = bbox
    out = []
    for _ in range(tries):
        rad = r.uniform(rmin, rmax)
        x, y = r.uniform(x0, x1), r.uniform(y0, y1)
        # center must be inside the envelope shrunk by part of the radius
        if not inside(x, y, rad * keep_inside):
            continue
        if any(math.hypot(x - a, y - b) < sep * (rad + q) for a, b, q in out):
            continue
        out.append((x, y, rad))
    return out


def rim_clumps(r, inside, bbox, rmin, rmax, tries, sep=0.8):
    """Small clumps whose centers sit just inside the silhouette, to scallop it."""
    x0, y0, x1, y1 = bbox
    out = []
    for _ in range(tries):
        rad = r.uniform(rmin, rmax)
        x, y = r.uniform(x0, x1), r.uniform(y0, y1)
        if not inside(x, y, 0.3) or inside(x, y, rad * 0.9 + 1):
            continue
        if any(math.hypot(x - a, y - b) < sep * (rad + q) for a, b, q in out):
            continue
        out.append((x, y, rad))
    return out


def canopy(clumps, ramps, env_inside, seed, bbox, spiky=False, holes=(), ramp_of=None,
           edge_leaves=40, center=None, back=True, shadow=2, w=CW, h=CH, texture=1.0,
           glyph=None, edge=(), bias=0.0, droop=False):
    """Render a leafy crown. Returns (Layer of colors, set of canopy pixels).
    clumps: big leaf masses (cx, cy, r); edge: small clumps that scallop the silhouette
    (drawn behind the masses). ramps: list of ramps; ramp_of(cx, cy, k) -> ramp index.
    Tones per ramp: 1 deep, 2 dark, 3 mid, 4 light, 5 highlight."""
    r = random.Random(seed)
    n = Noise(seed + 1, 9)
    x0, y0, x1, y1 = bbox
    gcx = center[0] if center else (x0 + x1) / 2
    gcy = center[1] if center else (y0 + y1) / 2
    hw, hh = (x1 - x0) / 2, (y1 - y0) / 2
    tone = {}          # (x, y) -> (ramp idx, tone 1..5)
    owner = {}

    def glob(x, y):
        gx, gy = (x - gcx) / hw, (y - gcy) / hh
        return -(0.5 * gx + 0.8 * gy)

    if back:
        for y in range(h):
            for x in range(w):
                if env_inside(x + .5, y + .5, 2.5):
                    ri = ramp_of(x, y, -1) if ramp_of else 0
                    tone[(x, y)] = (ri, 2 if glob(x + .5, y + .5) > 0.2 else 1)

    def shape_pts(cx, cy, rad, spk):
        phase = r.uniform(0, 2 * math.pi)
        tilt = r.uniform(-0.25, 0.25)
        lobes = r.choice((7, 8, 9)) if spk else r.choice((4, 5, 6))
        squash = r.uniform(1.15, 1.35) if droop else r.uniform(0.85, 1.0)
        pts = []
        for y in range(int(cy - rad) - 2, int(cy + rad) + 3):
            for x in range(int(cx - rad) - 2, int(cx + rad) + 3):
                dx, dy = x + .5 - cx, (y + .5 - cy) / squash
                d = math.hypot(dx, dy)
                th = math.atan2(dy, dx)
                if spk:
                    # maple leaf cluster: rounded top, 3 sharp points hanging down and a
                    # point to each side (reads as pointed, jagged foliage, not a blob)
                    tips = ((math.pi / 2 + tilt, 0.55), (math.pi / 2 + tilt - 0.75, 0.42),
                            (math.pi / 2 + tilt + 0.75, 0.42), (-0.15 + tilt, 0.3),
                            (math.pi + 0.15 + tilt, 0.3))
                    bump = 0.0
                    for (tk, amp) in tips:
                        dth = abs((th - tk + math.pi) % (2 * math.pi) - math.pi)
                        bump = max(bump, amp * max(0.0, 1 - dth / 0.32))
                    lim = rad * ((0.92 if dy < 0 else 0.74) + bump)
                elif droop:
                    # teardrop hanging cluster: longer and narrower toward the bottom
                    lim = rad * (0.9 + 0.25 * math.sin(th) + 0.06 * math.sin(lobes * th + phase))
                else:
                    lim = rad * (0.94 + 0.07 * math.sin(lobes * th + phase))
                if d <= lim:
                    pts.append((x, y, dx / rad, dy / rad, d / lim))
        return pts

    allc = [(q, True) for q in edge] + [(q, False) for q in sorted(clumps, key=lambda q: -q[1])]
    for k, ((cx, cy, rad), is_edge) in enumerate(allc):
        ri = ramp_of(cx, cy, k) if ramp_of else 0
        pts = shape_pts(cx, cy, rad, spiky)
        own = {(x, y) for (x, y, *_ ) in pts}
        if shadow and not is_edge:
            for (x, y, nx, ny, dd) in pts:
                if ny > 0.25 and dd > 0.6:
                    for sdy in range(1, shadow + 1):
                        q = (x + (1 if nx > 0.4 else 0), y + sdy)
                        if q in tone and q not in own:
                            rq, tq = tone[q]
                            tone[q] = (rq, max(1, tq - (2 if sdy == 1 else 1)))
        for (x, y, nx, ny, dd) in pts:
            loc = -(0.55 * nx + 0.85 * ny)
            v = 0.75 * loc + 0.45 * glob(x + .5, y + .5) + (n(x, y) - .5) * (0.05 if spiky else 0.12) + bias
            if v > 0.7:
                t = 4
            elif v > 0.25:
                t = 3
            elif v > -0.25:
                t = 2
            else:
                t = 1
            if dd > 0.8 and loc > 0.5 and v > 0.35:
                t = 5                                  # rim light, top-left edge
            elif dd > 0.86 and loc < -0.3:
                t = 1                                  # dark lower rim
            tone[(x, y)] = (ri, t)
            owner[(x, y)] = k
        # leaf texture: small sub-clump crescents (light top-left arc, dark lower-right arc)
        if not is_edge and texture:
            for _ in range(int(rad * 1.3 * texture)):
                a = r.uniform(0, 2 * math.pi)
                dd = r.uniform(0.15, 0.7) * rad
                sx, sy = cx + math.cos(a) * dd, cy + math.sin(a) * dd
                rs = r.uniform(1.6, 2.6)
                if glyph:
                    gx, gy = round(sx), round(sy)
                    for (ddx, ddy, dt) in glyph:
                        q = (gx + ddx, gy + ddy)
                        if owner.get(q) == k:
                            rq, tq = tone[q]
                            tone[q] = (rq, max(1, min(5 if tq >= 3 else 4, tq + dt)))
                    continue
                for y in range(int(sy - rs) - 1, int(sy + rs) + 2):
                    for x in range(int(sx - rs) - 1, int(sx + rs) + 2):
                        q = (x, y)
                        if owner.get(q) != k:
                            continue
                        ddx, ddy = x + .5 - sx, y + .5 - sy
                        d = math.hypot(ddx, ddy)
                        if rs - 1.0 < d <= rs:
                            rq, tq = tone[q]
                            if ddx + ddy < -0.6 * rs:
                                tone[q] = (rq, min(5 if tq >= 3 else 4, tq + 1))
                            elif ddx + ddy > 0.6 * rs:
                                tone[q] = (rq, max(1, tq - 1))
    for (hx, hy, hr) in holes:
        for y in range(int(hy - hr) - 1, int(hy + hr) + 2):
            for x in range(int(hx - hr) - 1, int(hx + hr) + 2):
                if (x + .5 - hx) ** 2 + ((y + .5 - hy) * 1.3) ** 2 <= hr * hr:
                    tone.pop((x, y), None)
    edgep = sorted({(x, y) for (x, y) in tone for dx, dy in N4 if (x + dx, y + dy) not in tone})
    for _ in range(edge_leaves):
        if not edgep:
            break
        x, y = r.choice(edgep)
        dx, dy = (x + .5 - gcx), (y + .5 - gcy)
        L = math.hypot(dx, dy) or 1
        ox, oy = round(dx / L * r.uniform(1.6, 2.8)), round(dy / L * r.uniform(1.6, 2.8))
        rq, tq = tone[(x, y)]
        shape = r.choice(((0, 0), (0, 0, 1, 0), (0, 0, 0, 1), (0, 0, 1, 1, 1, 0)))
        for i in range(0, len(shape), 2):
            q = (x + ox + shape[i], y + oy + shape[i + 1])
            if q not in tone:
                tone[q] = (rq, min(4, max(2, tq)))
    tone = {q: v for q, v in tone.items() if 1 <= q[0] < w - 1 and 1 <= q[1] < h - 1}
    lay = Layer(w, h)
    for q, (ri, t) in tone.items():
        lay[q] = ramps[ri][t]
    return lay, set(tone)


def outline_canopy(lay, pts, col, lit_col=None):
    add = {}
    for (x, y) in pts:
        for dx, dy in N4:
            q = (x + dx, y + dy)
            if q in pts or not lay.ok(*q):
                continue
            lit = lit_col is not None and (dx == -1 or dy == -1)
            if q not in add or not lit:
                add[q] = lit_col if lit else col
    for q, v in add.items():
        lay[q] = v


def ellipse_env(cx, cy, rx, ry, noise=None, amp=0.0, top_taper=0.0, flat_bottom=None):
    def inside(x, y, m=0.0):
        if flat_bottom is not None and y > flat_bottom - m * 0.6:
            return False
        dy = (y - cy) / ry
        rxx = rx
        if top_taper and dy < 0:
            rxx = rx * (1 - top_taper * (-dy) ** 1.4)
        a = math.atan2(y - cy, x - cx)
        k = 1 + (amp * (noise(math.cos(a) * 9 + 20, math.sin(a) * 9 + 20) - .5) * 2 if noise else 0)
        ex, ey = (x - cx) / max(rxx * k - m, 0.5), (y - cy) / max(ry * k - m, 0.5)
        return ex * ex + ey * ey <= 1
    return inside


# --------------------------------------------------------------------------
# Accents
# --------------------------------------------------------------------------

def scatter_on(img, pts, cols, n, seed, cond=None, shape=((0, 0),)):
    px = img.load()
    r = random.Random(seed)
    cand = sorted(p for p in pts if cond is None or cond(p, px))
    r.shuffle(cand)
    used = []
    for (x, y) in cand:
        if len(used) >= n:
            break
        if any(abs(x - u) + abs(y - v) < 5 for u, v in used):
            continue
        used.append((x, y))
        for i, (dx, dy) in enumerate(shape):
            X, Y = x + dx, y + dy
            if 0 <= X < img.width and 0 <= Y < img.height:
                px[X, Y] = c(cols[i % len(cols)])
    return used


def ground_leaves(img, cols, n, seed, y0=72, y1=78, x0=3, x1=44):
    px = img.load()
    r = random.Random(seed)
    for _ in range(n):
        x, y = r.randint(x0, x1), r.randint(y0, y1)
        if px[x, y][3] or (16 <= x <= 31 and y > 74):
            continue
        col = r.choice(cols)
        px[x, y] = c(col)
        if r.random() < 0.5 and x + 1 < CW and px[x + 1, y][3] == 0:
            px[x + 1, y] = c(col)
        if y + 1 <= 78 and px[x, y + 1][3] == 0 and r.random() < 0.6:
            px[x, y + 1] = c("brown_dark")


def lit_cols(ramp):
    return lambda p, px: px[p] in (c(ramp[3]), c(ramp[4]), c(ramp[5]))


# --------------------------------------------------------------------------
# Oak
# --------------------------------------------------------------------------

def oak_bark(season):
    r = random.Random(101)
    m = Layer()
    # thick, gnarled trunk that widens to the roots
    trunk_mask(m, 46 if season != "winter" else 40, 78, lambda y: 24 + math.sin(y * 0.21) * 1.0,
               lambda y: 10 + (y - 46) * 0.05 + max(0, y - 72) * 0.7 + (1 if 60 < y < 65 else 0))
    for sx, ang, ln in ((18.5, -2.2, 4), (29.5, 2.2, 4), (21, -2.8, 3), (27, 2.7, 3)):
        limb(m, sx, 75.5, ang, ln, 3, 2, r)
    twigs = Layer()
    if season == "winter":
        # heavy, twisting, WIDE limbs: low and almost horizontal, crooked elbows, then a
        # broad dome of crooked twigs (maple, by contrast, is a narrow upright vase)
        stop = lambda x, y: not (1.5 <= x <= 46.5 and 3 <= y)
        main = ((19, 52, -1.15, 11, 6.5, -1.6, 11), (29, 51, 1.2, 11, 6.5, 1.6, 11),
                (21, 45, -0.5, 12, 5.5, -0.85, 12), (27, 44, 0.52, 12, 5.5, 0.9, 12))
        fans = []
        for (sx, sy, ang, ln, w0, ang2, ln2) in main:
            ex, ey, ea = limb(m, sx, sy, ang, ln, w0, 4, r, gnarl=0.12, stop=stop)
            # crooked elbow: turn outward, then taper
            ex, ey, ea = limb(m, ex, ey, ang2 + r.uniform(-0.12, 0.12), ln2, 3.6, 1.6, r,
                              gnarl=0.22, stop=stop)
            fans.append((ex, ey, ea))
            # secondary limbs from the elbow, rising
            for t in (0.3, 0.6):
                bx, by = sx + (ex - sx) * t, sy + (ey - sy) * t - 1.5
                fa = ea * 0.3 + (-0.2 if ea < 0 else 0.2)
                fx, fy, fa = limb(m, bx, by, fa, r.uniform(8, 11), 2.6, 1.2, r, gnarl=0.35, stop=stop)
                fans.append((fx, fy, fa))
        ex, ey, ea = limb(m, 24, 42, 0.08, 16, 4.5, 2.4, r, gnarl=0.25, stop=stop)
        for sgn in (-1, 1):
            fx, fy, fa = limb(m, ex, ey, sgn * 0.5, 11, 2.4, 1.2, r, gnarl=0.35, stop=stop)
            fans.append((fx, fy, fa))
        fans.append((ex, ey, ea))
        # crooked twig fans at every limb end (two levels)
        for (fx, fy, fa) in fans:
            for sgn in (-1, 1):
                gx, gy, ga = limb(twigs, fx, fy, fa * 0.45 + sgn * r.uniform(0.4, 0.75), r.uniform(4, 6),
                                  1, 1, r, gnarl=0.4, stop=stop)
                if r.random() < 0.6:
                    limb(twigs, gx, gy, ga + sgn * r.uniform(0.6, 1.0), r.uniform(2, 3), 1, 1, r,
                         gnarl=0.4, stop=stop)
        for q in list(m):
            if not (1 <= q[0] <= 46 and 3 <= q[1]):
                del m[q]
        for q in list(twigs):
            if not (1 <= q[0] <= 46 and 2 <= q[1]) or q in m:
                del twigs[q]
    else:
        for (sx, sy, ang, ln, w0) in ((20, 52, -1.0, 15, 5), (28, 51, 1.05, 15, 5),
                                      (22, 47, -0.35, 13, 4), (26, 47, 0.4, 13, 4)):
            ex, ey, ea = limb(m, sx, sy, ang, ln, w0, 2, r, gnarl=0.2)
            limb(m, ex, ey, ea * 0.3, 6, 2, 1, r, gnarl=0.3)
    clamp_base(m)
    bark = BARK["oak"]
    lay = shade_bark(m, bark, 102)
    for (x, y, big) in ((21, 64, True), (27, 56, False), (22, 71, False), (27, 69, True)):
        knot(lay, x, y, bark, big)
    lay.outline("outline", clip_bottom=79)
    for q in twigs:
        if q not in lay:
            lay[q] = "brown_dark" if (q[0] + q[1]) % 3 else "brown"
    return lay


def oak_tree(season):
    img = new()
    bark = oak_bark(season)
    bark.paste(img)
    if season == "winter":
        snow_cap(img, BARK["oak"][2:], 103, prob=0.97, min_run=2, pile=0.9)
        return img
    n = Noise(104, 5)
    env = ellipse_env(24, 30, 22.5, 26, noise=n, amp=0.12, flat_bottom=58)
    r = random.Random(105)
    cl = place_clumps(r, env, (2, 2, 46, 58), 6.5, 9.5, 1500, sep=0.72, keep_inside=0.75)
    edge = rim_clumps(r, env, (0, 0, 48, 60), 2.8, 4.2, 1500, sep=0.75)
    ramps = OAK_FALL if season == "fall" else [leaf_ramp("oak", season)]
    nh = Noise(106, 14)

    def ramp_of(x, y, k):
        if season != "fall" or k == -1:
            return 0
        v = nh(x, y) * 0.9 + (1 - y / 58) * 0.45
        return 2 if v > 0.95 else 0 if v > 0.6 else 1 if v > 0.42 else 3

    holes = [(12, 51, 3.0), (35, 50, 3.2), (21, 45, 2.0), (41, 30, 1.6), (7, 33, 1.6)]
    lay, pts = canopy(cl, ramps, env, 107, (1, 2, 47, 58), holes=holes, ramp_of=ramp_of,
                      edge_leaves=40, edge=edge)
    outline_canopy(lay, pts, ramps[0][0])
    lay.paste(img)
    if season == "spring":
        # catkins dangling from the lower edges of clumps + a few pale blossoms
        scatter_on(img, pts, ("gold", "yellow_pale"), 12, 108,
                   cond=lambda p, px: p[1] + 3 < CH and px[p] == c(ramps[0][1])
                   and px[p[0], p[1] + 1] == c(ramps[0][0]) and p[1] > 14,
                   shape=((0, 1), (0, 2)))
        scatter_on(img, pts, ("yellow_pale",), 8, 109, cond=lambda p, px: px[p] == c(ramps[0][4]),
                   shape=((0, 0),))
    if season in ("summer", "fall"):
        # acorn hints: cap + nut
        scatter_on(img, pts, ("brown_dark", "tan" if season == "summer" else "brown_light"), 7, 110,
                   cond=lambda p, px: 16 < p[1] < 52 and px[p] == c(ramps[0][3]),
                   shape=((0, 0), (0, 1)))
    if season == "fall":
        ground_leaves(img, ("orange", "rust", "gold_dark", "brown_light"), 20, 111)
    return img


# --------------------------------------------------------------------------
# Maple
# --------------------------------------------------------------------------

def maple_bark(season):
    r = random.Random(201)
    m = Layer()
    trunk_mask(m, 50 if season != "winter" else 53, 78, lambda y: 24,
               lambda y: 8 + max(0, y - 73) * 0.7 - (max(0, 58 - y) * 0.9 if season == "winter" else 0))
    for sx, ang, ln in ((20, -2.1, 3), (27, 2.1, 3)):
        limb(m, sx, 77, ang, ln, 3, 2, r)
    twigs = Layer()
    if season == "winter":
        # upright vase / oval: straight leaders fork repeatedly into thin ASCENDING twigs,
        # clipped to a narrow oval crown (oak, by contrast, is low, wide and crooked)
        env = ellipse_env(24, 28, 18, 26)
        stop = lambda x, y: (y < 48 and not env(x, y)) or y < 2
        leaders = ((22.5, 55, -0.3, 13, 3.2), (25.5, 55, 0.3, 15, 3.2), (24, 54, 0.03, 21, 2.8),
                   (21.5, 58, -0.66, 8, 2.4), (26.5, 58, 0.68, 8, 2.4))
        tips = []
        for (sx, sy, ang, ln, w0) in leaders:
            ex, ey, ea = limb(m, sx, sy, ang, ln, w0, 1.4, r, gnarl=0.05, stop=stop)
            tips.append((ex, ey, ea, 0))
        while tips:
            x, y, a, d = tips.pop(0)
            if d >= 3:
                continue
            for sgn in (-1, 1):
                na = max(-0.85, min(0.85, a * 0.8 + sgn * r.uniform(0.28, 0.45)))
                ln = (r.uniform(9, 11), r.uniform(7, 9), r.uniform(5, 7))[d]
                tgt = m if d == 0 else twigs
                ex, ey, ea = limb(tgt, x, y, na, ln, 1.2 if d == 0 else 1, 0.8, r, gnarl=0.06,
                                  up=0.12, stop=stop)
                if math.hypot(ex - x, ey - y) > 0.7 * ln:      # only fork twigs that grew
                    tips.append((ex, ey, ea, d + 1))
            if d == 1:     # short spur from the fork
                limb(twigs, x, y, a * 0.5, r.uniform(2, 4), 1, 1, r, up=0.6, stop=stop)
        for q in list(twigs):
            if q in m:
                del twigs[q]
    else:
        for (sx, sy, ang, ln, w0) in ((22, 53, -0.5, 13, 4), (26, 53, 0.5, 13, 4), (24, 51, 0.0, 12, 3)):
            limb(m, sx, sy, ang, ln, w0, 2, r, gnarl=0.05)
    clamp_base(m)
    bark = BARK["maple"]
    lay = shade_bark(m, bark, 202)
    # maple bark: fine vertical furrows and a couple of small knots
    for (x, y) in ((22, 66, ), (26, 60)):
        knot(lay, x, y, bark)
    lay.outline("outline", clip_bottom=79)
    for q in twigs:
        if q not in lay:
            lay[q] = "bark_grey"
    return lay


# tiny five-pointed maple leaf used as canopy texture: (dx, dy, tone change)
MAPLE_GLYPH = ((0, -2, 1), (-2, -1, 1), (0, -1, 1), (2, -1, 1), (-1, 0, 1), (0, 0, 1), (1, 0, 1),
               (0, 1, -1), (-1, 1, -1), (1, 1, -1))


def maple_tree(season):
    img = new()
    bark = maple_bark(season)
    bark.paste(img)
    if season == "winter":
        snow_cap(img, BARK["maple"][2:], 203, prob=0.6, min_run=2)
        # a few snow dabs on fork tips
        return img
    n = Noise(204, 6)
    # oval / rounded-triangular crown: broad below, narrowing toward a rounded top
    env = ellipse_env(24, 30, 22.5, 27, noise=n, amp=0.08, top_taper=0.38, flat_bottom=57)
    r = random.Random(205)
    cl = place_clumps(r, env, (2, 2, 46, 58), 5.0, 7.5, 1500, sep=0.7, keep_inside=0.7)
    edge = rim_clumps(r, env, (0, 0, 48, 60), 3.4, 4.6, 1500, sep=0.8)
    nh = Noise(206, 10)
    ramps = MAPLE_FALL if season == "fall" else [leaf_ramp("maple", season)]

    def ramp_of(x, y, k):
        if season != "fall":
            return 0
        if k == -1:
            return 0
        v = (1 - y / 58) * 1.1 + (nh(x, y) - .5) * 0.9      # gold at the top, red below
        return 3 if v > 0.95 else 2 if v > 0.65 else 1 if v > 0.35 else 0

    holes = [(14, 52, 3.0), (34, 52, 3.0)]
    lay, pts = canopy(cl, ramps, env, 207, (1, 2, 47, 58), spiky=True, holes=holes,
                      ramp_of=ramp_of, edge_leaves=30, edge=edge, texture=0.6,
                      bias=0.12)
    outline_canopy(lay, pts, ramps[0][0])
    lay.paste(img)
    if season == "spring":
        # maple flowers / red new leaves in small clusters
        scatter_on(img, pts, ("crimson", "red"), 10, 208, cond=lit_cols(ramps[0]),
                   shape=((0, 0), (1, 0), (0, 1)))
    if season == "summer":
        # samara bunches
        scatter_on(img, pts, ("green_pale", "tan"), 6, 209,
                   cond=lambda p, px: p[1] > 25 and px[p] == c(ramps[0][3]), shape=((0, 0), (1, 1)))
    if season == "fall":
        ground_leaves(img, ("ember_deep", "ember_orange", "gold", "crimson", "ember_amber"), 30, 210)
    return img


# --------------------------------------------------------------------------
# Birch
# --------------------------------------------------------------------------

def birch_cx(y):
    return 23.0 + (78 - y) * 0.09 + math.sin(y * 0.09) * 0.6     # slender, leaning right


BIRCH_BRANCHES = ((52, -1, 15, 0.85), (47, 1, 17, 0.85), (42, -1, 18, 0.8), (37, 1, 17, 0.75),
                  (32, -1, 16, 0.7), (28, 1, 14, 0.65), (23, -1, 12, 0.55), (19, 1, 10, 0.5),
                  (15, -1, 7, 0.4), (13, 1, 6, 0.35))


def birch_bark(season):
    r = random.Random(301)
    m = Layer()
    trunk_mask(m, 10, 78, birch_cx, lambda y: 3.2 + (y - 10) * 0.028 + max(0, y - 74) * 0.8)
    for sx, ang, ln in ((20.5, -2.3, 3), (26, 2.3, 3)):
        limb(m, sx, 77, ang, ln, 2, 1.5, r)
    br = Layer()          # branches (white near the trunk, darker toward the tips)
    twigs = Layer()
    tips = []
    for (sy, side, ln, ang) in BIRCH_BRANCHES:
        sx = birch_cx(sy) + side * 1.2
        pts = []
        x, y, a = sx, sy, side * ang
        steps = int(ln * (1.0 if season == "winter" else 0.9))
        for i in range(steps):
            a += r.uniform(-0.06, 0.06) + side * 0.075       # arch: rise, then bow outward/down
            x, y = x + math.sin(a), y - math.cos(a)
            if not (2 <= x <= 45 and 3 <= y):
                break
            pts.append((x, y))
            disc(br, x, y, 0.9 if i < steps * 0.35 else 0.5, 1 if i < steps * 0.55 else 2)
        tips.append((x, y, a, pts, side))
    if season == "winter":
        # weeping fine twigs: hang from points along every branch like curtains
        for (x, y, a, pts, side) in tips:
            for k, (px_, py_) in enumerate(pts):
                if k < 2 or k % 2:
                    continue
                ox = px_ + side * r.uniform(0.5, 1.5)
                ln = r.uniform(4, 9) * (0.6 + 0.4 * k / len(pts))
                limb(twigs, ox, py_, side * r.uniform(2.5, 2.9), ln, 1, 1, r, gnarl=0.08)
            limb(twigs, x, y, side * 2.2, r.uniform(5, 8), 1, 1, r, gnarl=0.1)
        for q in list(twigs):
            if not (1 <= q[0] <= 46 and 2 <= q[1] <= 66) or q in m or q in br:
                del twigs[q]
    clamp_base(m)
    bark = BARK["birch"]
    lay = shade_bark(m, bark, 302, ridges=False)
    # dark lenticel dashes of varied length, a few chevron scars and black knots
    y = 12
    while y < 73:
        cx = birch_cx(y)
        wd = 3.2 + (y - 10) * 0.028
        ln = r.choice((1, 2, 2, 3, 3, 4))
        x0 = round(cx - wd / 2) + r.randint(0, max(0, round(wd) - ln))
        for i in range(ln):
            q = (x0 + i, y)
            if q in lay:
                lay[q] = "outline" if ln <= 2 or i in (0, ln - 1) else "stone_dark"
        if r.random() < 0.3:
            q = (x0 + r.randint(0, ln - 1), y + 1)
            if q in lay:
                lay[q] = "stone"
        y += r.choice((2, 3, 3, 4, 5))
    for (sy, side, ln, ang) in BIRCH_BRANCHES[:6]:
        cx = round(birch_cx(sy) - .5)
        # chevron scar below each branch
        for (dx, dy, col) in ((0, 1, "outline"), (-1, 2, "stone_dark"), (1, 2, "stone_dark"),
                              (side, 0, "outline")):
            q = (cx + dx, sy + dy)
            if q in lay:
                lay[q] = col
    # rough dark base
    for y in range(70, 79):
        for x in range(14, 34):
            if (x, y) in lay and r.random() < (y - 68) / 11:
                lay[(x, y)] = r.choice(("stone_dark", "stone", "outline", "bark_grey"))
    lay.outline("stone_dark", clip_bottom=79)
    for q, t in br.items():
        if q not in lay:
            lay[q] = "white_warm" if t == 1 and q[1] % 3 else "stone_light" if t == 1 else "bark_grey"
    # outline branches from below so they read on pale grass
    for q, t in list(br.items()):
        b2 = (q[0], q[1] + 1)
        if b2 not in lay and b2 not in br and t == 1:
            lay[b2] = "stone_dark"
    for q in twigs:
        if q not in lay:
            lay[q] = "bark_grey" if r.random() < 0.6 else "brown"
    return lay, tips


def birch_tree(season):
    img = new()
    bark, tips = birch_bark(season)
    bark.paste(img)
    if season == "winter":
        snow_cap(img, ("stone_light", "stone_pale", "white_warm", "stone", "bark_grey"), 303,
                 prob=0.7, min_run=2, thick=1)
        return img
    # airy, weeping crown: teardrop clusters hanging under each arching branch, gaps between
    r = random.Random(305)
    cl = []
    for (x, y, a, pts, side) in tips:
        for k, (px_, py_) in enumerate(pts):
            if k < 1 or k % 3:
                continue
            cl.append((px_ + r.uniform(-1, 1), py_ + r.uniform(1.0, 3.0), r.uniform(2.8, 3.8)))
        cl.append((x + side * 0.5, y + 2.5, r.uniform(3.0, 3.8)))
    for yy in (24, 38, 50):
        cl.append((birch_cx(yy) + r.uniform(-1, 1), yy, 2.6))
    cl.append((birch_cx(9), 8, 3.4))
    cl.append((birch_cx(13) - 2, 13, 3.0))
    cl.append((birch_cx(13) + 3, 12, 3.0))
    cl = [q for q in cl if 3 <= q[0] <= 45 and 3 <= q[1] <= 60]
    ramps = BIRCH_FALL if season == "fall" else [leaf_ramp("birch", season)]
    nh = Noise(307, 8)

    def ramp_of(x, y, k):
        if season != "fall" or k == -1:
            return 0
        v = nh(x, y) + (1 - y / 56) * 0.3
        return 1 if v > 0.75 else 0 if v > 0.15 else 2

    lay, pts = canopy(cl, ramps, None, 308, (4, 2, 46, 60), back=False, ramp_of=ramp_of,
                      edge_leaves=26, shadow=1, droop=True, texture=0.6, bias=0.1)
    # drooping leaf tassels below clusters
    rr = random.Random(309)
    for (x, y) in sorted(pts):
        if (x, y + 1) not in pts and rr.random() < 0.18 and y < 60:
            for k in range(1, rr.randint(2, 4)):
                if (x, y + k) not in pts and (x, y + k) not in bark:
                    lay[(x, y + k)] = ramps[0][3 if k == 1 else 2]
                    pts.add((x, y + k))
    outline_canopy(lay, pts, ramps[0][0])
    lay.paste(img)
    if season == "spring":
        scatter_on(img, pts, ("gold", "tan"), 10, 310,
                   cond=lambda p, px: p[1] + 3 < 62 and px[p] == c(ramps[0][0])
                   and px[p[0], p[1] + 1][3] == 0, shape=((0, 1), (0, 2)))
    if season == "fall":
        ground_leaves(img, ("yellow", "gold", "yellow_pale"), 16, 311)
    return img


# --------------------------------------------------------------------------
# Pine
# --------------------------------------------------------------------------

def pine_crown(tiers, ramp, seed, w=CW, h=CH, cx=AX, notch=3, cone_n=5, needle=True):
    """Layered drooping tiers. Each tier is drawn behind the one above it. Returns
    (layer, owner map (x, y) -> tier, list of tier bottom-edge points)."""
    o, deep, dark, mid, light, hi = ramp
    r = random.Random(seed)
    lay = Layer(w, h)
    owner = {}
    n = len(tiers)
    for k in range(n - 1, -1, -1):
        top, bot, hw = tiers[k]
        off = r.uniform(-0.8, 0.8)
        wl, wr = hw * r.uniform(0.92, 1.05), hw * r.uniform(0.92, 1.05)
        ph = r.randint(0, 3)
        for y in range(top, bot + 4):
            for x in range(w):
                dx = x + .5 - (cx + off)
                half = wl if dx < 0 else wr
                ad = abs(dx) / max(half, 1)
                if ad > 1:
                    continue
                # upper edge: concave slope up to the apex
                ytop = top + (bot - top) * (ad ** 1.25) * 0.9
                # lower edge: boughs droop toward the tips, needle tufts, notch at the centre
                tuft = (0, 1, 2, 1)[(int(abs(dx)) + ph) % 4]
                ybot = bot + ad ** 2 * 3 - tuft
                if notch and abs(dx) < 3.5:
                    ybot -= notch * (1 - abs(dx) / 3.5)
                if not (ytop <= y <= ybot):
                    continue
                v = (y - ytop) / max(ybot - ytop, 1)
                u = dx / max(half, 1)
                lit = -0.7 * u + 0.45 - 0.9 * v
                if y >= ybot - 1:
                    col = deep if ad > 0.15 else dark
                elif y <= ytop + 1 and u < 0.1:
                    col = hi if u < -0.25 else light          # lit upper rim of the bough
                elif lit > 0.35:
                    col = light
                elif lit > -0.12:
                    col = mid
                elif lit > -0.6:
                    col = dark
                else:
                    col = deep
                lay.set(x, y, col)
                owner[(x, y)] = k
    # shadow just under each upper tier's fringe
    for (x, y), k in list(owner.items()):
        for dy in (1, 2):
            q = (x, y + dy)
            if q in owner and owner[q] > k:
                lay[q] = deep if dy == 1 else (dark if lay[q] in (mid, light) else deep)
    # windows near the trunk under the lower tiers, so the trunk shows between them
    windows = []
    for k in ():       # (disabled: gaps read as odd shapes at this scale)
        ub = tiers[k - 1][1]
        for y in range(ub - notch, ub + 4):
            for x in range(int(cx - 3), int(cx + 3)):
                if owner.get((x, y)) == k and abs(x + .5 - cx) < 3.0 - max(0, y - ub) * 0.6:
                    del lay[(x, y)]
                    del owner[(x, y)]
                    windows.append((x, y))
    lay.windows = windows
    if needle:
        pts = sorted(lay)
        for (x, y) in r.sample(pts, len(pts) // 6):
            col = lay[(x, y)]
            up = {deep: dark, dark: mid, mid: light, light: hi}.get(col)
            if up is None:
                continue
            s = 1 if x + .5 > cx else -1
            lay[(x, y)] = up if col != light or r.random() < .35 else col
            for i in (1, 2):
                q = (x + s * i, y + i)
                if q in lay and lay[q] == col and r.random() < .7:
                    lay[q] = up
    return lay, owner


def pine_tree(season):
    img = new()
    r = random.Random(401)
    m = Layer()
    trunk_mask(m, 10, 78, lambda y: 24, lambda y: 5 + (78 - y < 14) * 1 + max(0, y - 74) * 0.8)
    for sx, ang, ln in ((20, -2.1, 3), (28, 2.1, 3)):
        limb(m, sx, 77, ang, ln, 3, 2, r)
    clamp_base(m)
    bark = shade_bark(m, BARK["pine"], 402)
    knot(bark, 23, 70, BARK["pine"])
    bark.outline("outline", clip_bottom=79)
    bark.paste(img)
    ramp = leaf_ramp("pine", season)
    tiers = [(0, 11, 6), (5, 20, 9.5), (11, 30, 13), (18, 40, 16.5), (26, 51, 19.5),
             (35, 62, 22.5)]
    lay, owner = pine_crown(tiers, ramp, 403)
    pts = set(lay)
    if season == "spring":
        # light new-growth tips on the bough ends
        for (x, y), k in owner.items():
            if (x, y + 1) not in owner and abs(x + .5 - AX) > 4 and r.random() < 0.35:
                lay[(x, y)] = "green_light"
    lay.outline(ramp[0])
    lay.paste(img)
    px = img.load()
    # trunk seen through the gaps is in deep shade
    for (x, y) in lay.windows:
        if px[x, y][3] and (x, y) not in lay:
            px[x, y] = c("soil_dark" if x + .5 > AX - 1 else "red_dark")
    # cones hanging under the boughs
    rc = random.Random(404)
    cones = []
    cand = sorted(q for q in owner if (q[0], q[1] + 1) not in owner and 5 < abs(q[0] + .5 - AX) < 15
                  and 18 < q[1] < 62)
    rc.shuffle(cand)
    for (x, y) in cand:
        if len(cones) >= (6 if season != "winter" else 3):
            break
        if any(abs(x - a) + abs(y - b) < 8 for a, b in cones):
            continue
        cones.append((x, y))
        # 2 x 3 hanging cone: lit scales on the left, dark tip
        for (dx, dy, col) in ((0, 1, "brown_light"), (1, 1, "brown"), (0, 2, "brown_mid"),
                              (1, 2, "brown_dark"), (0, 3, "brown_dark"), (1, 3, "outline")):
            if 0 <= x + dx < CW and y + dy < CH:
                px[x + dx, y + dy] = c(col)
    if season == "winter":
        pine_snow(img, owner, 405)
    return img


def pine_snow(img, owner, seed, cx=AX, heavy=True):
    px = img.load()
    r = random.Random(seed)
    for (x, y), k in sorted(owner.items()):
        above = (x, y - 1)
        if above in owner and owner[above] == k:
            continue
        # exposed top of tier k at column x: lay a snow band 2-3 px thick, heavier on the left
        dx = x + .5 - cx
        th = 2 + (1 if heavy and dx < 2 and r.random() < 0.6 else 0)
        if r.random() < 0.08:
            continue
        for t in range(th):
            q = (x, y + t)
            if q in owner and owner[q] == k:
                px[q] = c("snow" if t < th - 1 or dx < -3 else "snow_shade")
        # snow pillow on the outline above
        if y - 1 >= 0 and px[x, y - 1][3] and r.random() < 0.5:
            px[x, y - 1] = c("snow")
    # snow clumps on bough tips
    for (x, y), k in sorted(owner.items()):
        if (x, y + 1) not in owner and abs(x + .5 - cx) > 8 and r.random() < 0.12:
            px[x, y] = c("snow_shade")


GROWN = {"oak": oak_tree, "pine": pine_tree, "birch": birch_tree, "maple": maple_tree}


# --------------------------------------------------------------------------
# Small stages
# --------------------------------------------------------------------------
MOUND_ROWS = [
    "....oooooooo....",
    "...oDdmmlmdDo...",
    "..odmmllmmmmdo..",
    "...oooooooooo...",
]


def keymap(sp, season):
    leaf = leaf_ramp(sp, season, 0 if season != "fall" else 0)
    bark = BARK[sp]
    return {
        "o": "outline", "D": "brown_dark", "d": "brown", "m": "brown_mid", "l": "brown_light",
        "h": "tan", "w": "cream",
        "O": leaf[0], "1": leaf[2], "2": leaf[3], "3": leaf[4], "4": leaf[5],
        "b": bark[0], "B": bark[2], "c": bark[3], "e": bark[4], "f": bark[5],
        "s": "snow", "S": "snow_shade", "r": "red", "R": "red_dark", "y": "yellow", "g": "gold_dark",
        "k": "stone_dark", "t": "rust", "q": "orange", "G": "green", "F": "green_forest",
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
    "oak": [              # acorn: textured cap + glossy nut
        "......ooo.......",
        ".....oDdDo......",
        "....oDmdmDo.....",
        "....odDdDdo.....",
        "....ooooooo.....",
        ".....olhwmo.....",
        ".....ohlmmo.....",
        ".....olmmdo.....",
        "......odDo......",
        ".......o........",
    ],
    "pine": [             # pine cone lying on its side, scales
        "....oooooo......",
        "..oomdmdmdoo....",
        ".odlhlmlmmdDo.o.",
        "oDmlmhmlmmddooDo",
        ".odmdmdmdmdDo.o.",
        "..oooooooooo....",
    ],
    "birch": [            # catkin cone of seeds with two winged nutlets beside it
        ".......o........",
        "......omo.......",
        ".....omhmo......",
        ".....odmdo......",
        ".....omhmo......",
        ".....odmdo..o.o.",
        ".....omhmo.ohoho",
        "......odo...oDo.",
    ],
    "maple": [            # samara pair (helicopter seeds), veined wings
        ".oo........oo...",
        "ohho......ohho..",
        "ohwho....ohwho..",
        ".ohllo..ollho...",
        "..ollmoomllo....",
        "...oomDDmoo.....",
        ".....oDDo.......",
        "......oo........",
    ],
}

SEEDLINGS = {
    "oak": [               # two lobed oak leaves on a sturdy stem
        "..OO.......OO...",
        ".O34O.....O43O..",
        "O3443O...O3432O.",
        "O3232OO.OO2323O.",
        ".O2221O.O1222O..",
        "..OO11OOO11OO...",
        "....OOGFOOO.....",
        "......GF........",
        "......GF........",
        "......GF........",
    ],
    "pine": [              # whorl of needles
        ".......O........",
        "...O..O3O..O....",
        "..O3O.O3O.O3O...",
        "...O3OO2OO3O....",
        ".OO.O32123O.OO..",
        "O332O21112O233O.",
        ".OOO221G122OOO..",
        "....OOOGFOO.....",
        "......GF........",
        "......GF........",
    ],
    "birch": [             # small serrated oval leaves on a thin red-brown stem
        ".......OO.......",
        "......O34O......",
        "..OO..O23O......",
        ".O34O..O2O..OO..",
        "O3432O.dm..O43O.",
        ".O221OdD..O3322O",
        "..OOO.dm.OO11O..",
        "......dmdD.OO...",
        "......dm........",
        "......dm........",
    ],
    "maple": [             # two pointed, toothed maple leaves
        "...O.......O....",
        "..O3O.O.O.O3O...",
        ".O343O3OO3O343O.",
        "O32333OOOO33323O",
        ".O32221OO12223O.",
        "..O2O21OO12O2O..",
        "...O.OOGFOO.O...",
        "......GF........",
        "......GF........",
        "......GF........",
    ],
}


def stage_seed(sp, season):
    img = new(16, 16)
    km = keymap(sp, "summer")
    rows = SEEDS[sp]
    draw_rows(img, MOUND_ROWS, km, 0, 12)
    if season == "winter":
        px = img.load()
        for x in range(4, 12):
            px[x, 12] = c("snow")
        for x in (3, 4, 5, 10, 11, 12):
            px[x, 13] = c("snow_shade")
    draw_rows(img, rows, km, 1, 14 - len(rows))
    if season == "spring":
        draw_rows(img, [".O.", "O3O", "OGO", ".G."], keymap("oak", "spring"), 12, 9)
    if season == "fall":
        leaf_dab(img, sp, 11, 10)
    if season == "winter":
        px = img.load()
        top = min(y for y in range(16) for x in range(16) if px[x, y][3])
        xs = [x for x in range(16) if px[x, top][3]]
        for x in xs[:2]:
            px[x, top] = c("snow")
    return img


def leaf_dab(img, sp, x, y):
    km = keymap(sp, "fall")
    draw_rows(img, ["OO.", "O32O"[:3], ".OO"], km, x, y)


def hash_seed(sp, k):
    return SPECIES.index(sp) * 100 + k + 5000


def stage_seedling(sp, season):
    img = new(16, 16)
    km = keymap(sp, season)
    rows = SEEDLINGS[sp]
    if season == "winter" and sp != "pine":
        rows = [r_.replace("O", ".").replace("1", ".").replace("2", ".").replace("3", ".")
                .replace("4", ".") for r_ in rows]
        km["G"], km["F"] = "brown_mid", "brown"
        km["d"], km["m"] = "brown", "brown_mid"
    draw_rows(img, MOUND_ROWS, km, 0, 12)
    draw_rows(img, rows, km, 1, 14 - len(rows))
    px = img.load()
    if season == "winter":
        if sp != "pine":
            # bare twig: outline it, add a bud and a snow dab on the tip
            lay = Layer(16, 16)
            for y in range(12):
                for x in range(16):
                    if px[x, y][3]:
                        lay[(x, y)] = 1
            for q in lay.outline(1):
                if px[q][3] == 0 and q[1] < 12:
                    px[q] = c("outline")
            top = min(y for y in range(16) for x in range(16) if px[x, y][3])
            for x in range(16):
                if px[x, top][3]:
                    px[x, top] = c("snow")
        else:
            for x in range(16):
                for y in range(1, 12):
                    if px[x, y][3] and px[x, y - 1][3] and px[x, y - 1] == c(km["O"]) and \
                            (x + y) % 3 == 0:
                        px[x, y - 1] = c("snow")
        for x in range(4, 12):
            px[x, 12] = c("snow")
    return img


# leaf stamps for saplings: rows of '1'(dark) '2'(mid) '3'(light) '4'(hi), outlined later
LEAF_STAMPS = {
    "oak": [[".33.", "3432", "2322", ".22."], [".3.", "342", "232", ".2."], ["33.", "3422", ".221"]],
    "maple": [[".3.3.", "33432", ".232.", "..1.."], ["3.3", "343", ".2."], [".3.", "342", "3.2"]],
    "birch": [[".3", "34", "32", "2."], ["3.", "43", "22"], [".3.", "342", ".2."]],
}


def sapling(sp, season):
    """Young tree, 24 x 40: a real little crown of species-specific foliage on a thin trunk."""
    W, H, cx = 24, 40, 12
    img = new(W, H)
    r = random.Random(hash_seed(sp, 3))
    bark = BARK[sp]
    m = Layer(W, H)
    twigs = Layer(W, H)
    lean = {"birch": 0.07, "oak": 0.0, "maple": 0.0, "pine": 0.0}[sp]
    cxf = lambda y: cx + (38 - y) * lean + (math.sin(y * 0.3) * 0.5 if sp == "oak" else 0)
    top = {"oak": 14, "maple": 10, "birch": 8, "pine": 12}[sp]
    trunk_mask(m, top, 38, cxf, lambda y: {"oak": 3, "maple": 2.6, "birch": 2.2, "pine": 2.6}[sp]
               + (y > 36) * 1)
    tips = []
    # branches: (start y, angle, length)
    spec = {"oak": ((24, -1.15, 7), (21, 1.1, 7), (17, -0.6, 6), (16, 0.7, 6)),
            "maple": ((22, -0.45, 8), (21, 0.45, 8), (15, -0.3, 6), (14, 0.35, 6)),
            "birch": ((27, -1.0, 6), (23, 1.0, 7), (18, -0.9, 6), (14, 0.8, 5), (11, -0.6, 4)),
            "pine": ()}[sp]
    for (sy, a, ln) in spec:
        sx = cxf(sy) + (0.6 if a > 0 else -0.6)
        tgt = m if sp == "oak" and season == "winter" else twigs
        ex, ey, ea = limb(tgt, sx, sy, a, ln * (1.15 if season == "winter" else 1), 1.4 if sp == "oak" else 1,
                          1, r, gnarl=0.25 if sp == "oak" else 0.06, up=0.5 if sp == "maple" else 0)
        tips.append((ex, ey, ea))
        if season == "winter":
            for sgn in (-1, 1):
                if sp == "birch":
                    limb(twigs, ex, ey, (2.6 if ea > 0 else -2.6), r.uniform(2, 5), 1, 1, r)
                else:
                    limb(twigs, ex, ey, ea * (0.5 if sp == "maple" else 1) + sgn * r.uniform(0.3, 0.6),
                         r.uniform(2, 4), 1, 1, r, gnarl=0.3 if sp == "oak" else 0.05,
                         up=0.5 if sp == "maple" else 0)
    tips.append((cxf(top), top - 1, 0.0))
    if sp != "pine" and season == "winter":
        limb(twigs, cxf(top), top, 0.0, 4, 1, 1, r, up=0.5)
    for q in list(twigs):
        if not (1 <= q[0] < W - 1 and 1 <= q[1]) or q in m:
            del twigs[q]
    lay = shade_bark(m, bark, hash_seed(sp, 4), ridges=False)
    if sp == "birch":
        for y in range(top + 2, 37, 3):
            q = (round(cxf(y) - .5) - (y % 2), y)
            if q in lay:
                lay[q] = "outline"
    lay.outline(bark[0] if sp != "birch" else "stone_dark", clip_bottom=H - 1)
    for q in twigs:
        if q not in lay:
            lay[q] = {"birch": "brown", "maple": "brown_dark", "oak": "brown_dark",
                      "pine": "brown_dark"}[sp]
    lay.paste(img)
    if sp == "pine":
        ramp = leaf_ramp("pine", season)
        can, owner = pine_crown([(1, 8, 3.5), (4, 14, 5.5), (8, 20, 7.5), (13, 26, 9), (18, 32, 10.5)],
                                ramp, hash_seed(sp, 5), w=W, h=H, cx=cx, notch=1)
        if season == "spring":
            for (x, y), k in owner.items():
                if (x, y + 1) not in owner and abs(x + .5 - cx) > 3 and r.random() < 0.4:
                    can[(x, y)] = "green_light"
        can.outline(ramp[0])
        can.paste(img)
        if season == "winter":
            pine_snow(img, owner, hash_seed(sp, 6), cx=cx, heavy=False)
        return img
    if season == "winter":
        px = img.load()
        for (x, y, a) in tips:
            X, Y = round(x - .5), round(y - .5)
            if 0 <= X < W and 0 <= Y < H and not px[X, Y][3]:
                px[X, Y] = c("brown_mid")             # buds
        snow_cap(img, bark[2:] + ("brown_dark", "bark_grey"), hash_seed(sp, 7), prob=0.8, min_run=1,
                 thick=1)
        return img
    ramps = [leaf_ramp(sp, season, 0)]
    if season == "fall":
        ramps = {"oak": OAK_FALL, "maple": MAPLE_FALL, "birch": BIRCH_FALL}[sp]
    if sp == "oak":
        cl = [(12, 12, 5.0), (6.5, 17, 4.0), (17.5, 16, 4.2), (9, 8, 3.6), (15.5, 8.5, 3.6),
              (12, 19, 3.4)]
        kw = dict(spiky=False)
    elif sp == "maple":
        cl = [(12, 7, 4.0), (8, 13, 4.2), (16, 12.5, 4.2), (12, 15, 4.0), (7, 19, 3.4), (17, 19, 3.4)]
        kw = dict(spiky=True)
    else:
        cl = [(x + (1 if a > 0 else -1), y + 2, 2.6) for (x, y, a) in tips]
        cl += [(cxf(y) + r.uniform(-1, 1), y + 1.5, 2.4) for (_, y, _a) in tips[:3]]
        cl.append((cxf(top) , top + 1, 3.0))
        kw = dict(droop=True)
    nh = Noise(hash_seed(sp, 11), 6)

    def ramp_of(x, y, k):
        if season != "fall" or k == -1:
            return 0
        if sp == "maple":
            v = (1 - y / 22) * 1.1 + (nh(x, y) - .5) * 0.8
            return 3 if v > 0.95 else 2 if v > 0.65 else 1 if v > 0.35 else 0
        return (k * 7 + 3) % (2 if sp == "birch" else len(ramps)) if (k % 3) else 0

    can, pts = canopy(cl, ramps, None, hash_seed(sp, 12), (1, 1, 23, 24), back=False,
                      ramp_of=ramp_of, edge_leaves=10, shadow=1, w=W, h=H, texture=0.5,
                      bias=0.1, **kw)
    outline_canopy(can, pts, ramps[0][0])
    can.paste(img)
    if sp == "oak" and season == "spring":
        scatter_on(img, pts, ("gold", "yellow_pale"), 3, hash_seed(sp, 8),
                   cond=lambda p, px: p[1] + 2 < H and px[p] == c(ramps[0][0]) and px[p[0], p[1] + 1][3] == 0
                   and p[1] > 10, shape=((0, 1), (0, 2)))
    if sp == "maple" and season == "spring":
        scatter_on(img, pts, ("crimson",), 4, hash_seed(sp, 8), cond=lit_cols(ramps[0]))
    if sp == "oak" and season in ("summer", "fall"):
        scatter_on(img, pts, ("brown_dark", "tan"), 2, hash_seed(sp, 9),
                   cond=lambda p, px: px[p] == c(ramps[0][3]), shape=((0, 0), (0, 1)))
    return img


def stump(sp, season):
    """Cut stump, 24 x 24: ringed top face with a crack, splintered rim, ridged bark sides and
    flared roots."""
    W, H = 24, 24
    img = new(W, H)
    r = random.Random(hash_seed(sp, 9))
    bark = BARK[sp]
    wid = {"oak": 15, "pine": 12, "birch": 9, "maple": 12}[sp]
    hgt = {"oak": 9, "pine": 9, "birch": 10, "maple": 8}[sp]
    cx = 12
    top = 22 - hgt
    m = Layer(W, H)
    for y in range(top + 1, 23):
        extra = max(0, y - 19) * 0.8
        x0 = round(cx - wid / 2 - extra)
        for x in range(x0, round(cx + wid / 2 + extra)):
            m.set(x, y, 1)
    for (sx, ang, ln) in ((cx - wid / 2, -2.0, 3), (cx + wid / 2, 2.0, 3), (cx - 2, -2.8, 2),
                          (cx + 2.5, 2.7, 2)):
        limb(m, sx, 20.5, ang, ln, 2.2, 1.4, r)
    # splinters left on the back rim (oak / pine)
    if sp in ("oak", "pine"):
        for (dx, hh) in ((-3, 2), (-2, 3), (2, 1), (4, 2)):
            for k in range(hh):
                m.set(cx + dx, top - 1 - k + 1, 1)
    for q in list(m):
        if q[1] >= 22 and not (4 <= q[0] <= 19):
            del m[q]
        elif q[1] >= 23:
            del m[q]
    lay = shade_bark(m, bark, hash_seed(sp, 10), ridges=(sp != "birch"))
    if sp == "birch":
        for (y, x, ln) in ((top + 4, cx - 4, 6), (top + 7, cx + 1, 3)):
            for i in range(ln):
                if (x + i, y) in lay:
                    lay[(x + i, y)] = "outline" if i in (0, ln - 1) else "stone_dark"
        for y in range(19, 23):
            for x in range(W):
                if (x, y) in lay and r.random() < (y - 17) / 7:
                    lay[(x, y)] = r.choice(("stone_dark", "bark_grey", "stone"))
    else:
        knot(lay, round(cx - wid / 4), top + 5, bark)
    # top face: ellipse with concentric rings, pith and a radial crack
    ecx, ecy, rx, ry = cx, top + 1.0, wid / 2, max(2.2, wid / 5)
    ring_a, ring_b = ("cream", "tan") if sp != "pine" else ("sand", "tan")
    if sp == "birch":
        ring_a, ring_b = "cream", "sand"
    for y in range(top - 3, top + 5):
        for x in range(W):
            dx, dy = (x + .5 - ecx) / rx, (y + .5 - ecy) / ry
            d = math.hypot(dx, dy)
            if d > 1:
                continue
            if d > 0.8:
                col = bark[4] if dy < 0 else bark[2]           # bark rim, lit at the back
            else:
                col = ring_a if int(d * 6) % 2 == 0 else ring_b
                if dx + dy > 0.6 and col == ring_a:
                    col = "sand" if sp != "pine" else "tan"     # top face shading lower-right
                if d < 0.14:
                    col = "brown_mid"
            lay[(x, y)] = col
    # crack from the pith to the front edge
    for k in range(1, round(rx * 0.75)):
        q = (round(ecx) + k, round(ecy) + (1 if k > 2 else 0))
        if q in lay:
            lay[q] = "brown_light" if k < 3 else "brown_mid"
    if sp == "pine":
        for q, col in (((round(cx - wid / 2) + 2, top + 3), "yellow"), ((round(cx - wid / 2) + 2, top + 4), "gold_dark")):
            lay[q] = col                                  # resin drip
    lay.outline(bark[0] if sp != "birch" else "stone_dark", clip_bottom=H - 1)
    lay.paste(img)
    px = img.load()
    if season == "winter":
        for (x, y) in sorted(lay):
            if lay[(x, y)] in (ring_a, ring_b, "sand", "brown_mid", "brown_light") and y <= ecy + 0.5:
                px[x, y] = c("snow")
            elif lay[(x, y)] in (ring_a, ring_b, "sand", "brown_light", "brown_mid"):
                px[x, y] = c("snow_shade" if r.random() < 0.7 else "snow")
        # a snow pillow rising above the rim
        for x in range(round(ecx - rx * 0.6), round(ecx + rx * 0.6)):
            y = round(ecy - ry * 0.9) - 1
            if 0 <= y < H and not px[x, y][3]:
                px[x, y] = c("snow")
        for x in range(W):            # snow drifted against the roots
            if px[x, 21][3] and r.random() < 0.4 and not (x, 20) in lay:
                pass
    if season == "fall":
        km = keymap({"pine": "maple"}.get(sp, sp), "fall")
        draw_rows(img, ["OO.", "O32"], km, 18, 21)
        draw_rows(img, ["O3", ".O"], km, 2, 21)
        draw_rows(img, ["O2"], km, round(ecx) - 1, round(ecy))     # a leaf on the cut
    if season == "spring":
        # a new shoot from the stump side and a moss patch
        draw_rows(img, [".O.", "O3O", "O2O", ".O."], keymap("oak", "spring"), round(cx + wid / 2) - 2, top - 3)
        for x in range(round(cx - wid / 2) - 1, round(cx - wid / 2) + 4):
            for y in (20, 21):
                if (x, y) in lay and r.random() < 0.7:
                    px[x, y] = c("moss" if y == 21 else "green_grass")
    if season == "summer" and sp in ("oak", "maple"):
        # little mushrooms at the foot
        for (x, y, cap) in ((round(cx + wid / 2), 20, "red"), (round(cx + wid / 2) + 1, 21, "red")):
            pass
        X = round(cx + wid / 2) + 1
        if X + 1 < W:
            px[X, 20] = c("red" if sp == "oak" else "tan")
            px[X + 1, 20] = c("red_dark" if sp == "oak" else "brown_mid")
            px[X, 21] = c("cream")
    return img


# --------------------------------------------------------------------------
# Sheet assembly
# --------------------------------------------------------------------------

def place(cell, img):
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
