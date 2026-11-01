"""Cinderkin creature art generator (procedural, pixel-level, reproducible).

Outputs (relative to repo root):
  assets/sprites/cinderkin.png              32x32 frames, 8 cols x 4 rows (down, left, right, up)
  assets/portraits/cinderkin_portrait.png   64x64 bust portrait, transparent background
  assets/sprites/item_wet_waxweed.png       16x16 item icon (Wet Waxweed)

Every opaque pixel comes from tools/art/palette.py; alpha is only 0 or 255.
Shapes are rasterised with aliased (hard-edged) Pillow primitives into masks, then
shaded and outlined per part, so nothing is ever anti-aliased or resampled.
Usage:  python3 tools/art/gen_cinderkin.py [--preview DIR]
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from palette import RGBA, TRANSPARENT, c  # noqa: E402

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


# --------------------------------------------------------------------------
# Tiny mask + canvas engine
# --------------------------------------------------------------------------

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}  # (x, y) -> palette name

    # ---- mask builders (sets of (x, y)) ----
    def _draw(self, fn):
        m = Image.new("1", (self.w, self.h), 0)
        fn(ImageDraw.Draw(m))
        d = m.load()
        return {(x, y) for y in range(self.h) for x in range(self.w) if d[x, y]}

    def ellipse(self, x0, y0, x1, y1):
        return self._draw(lambda d: d.ellipse((x0, y0, x1, y1), fill=1))

    def poly(self, pts):
        return self._draw(lambda d: d.polygon([tuple(p) for p in pts], fill=1))

    def rect(self, x0, y0, x1, y1):
        return self._draw(lambda d: d.rectangle((x0, y0, x1, y1), fill=1))

    def stroke(self, pts, r0, r1):
        """Tapered stroke: discs along a polyline, radius r0 -> r1."""
        out = set()
        segs = list(zip(pts, pts[1:]))
        total = sum(math.dist(a, b) for a, b in segs) or 1
        acc = 0.0
        for a, b in segs:
            L = math.dist(a, b)
            n = max(1, int(L * 2))
            for i in range(n + 1):
                t = i / n
                x = a[0] + (b[0] - a[0]) * t
                y = a[1] + (b[1] - a[1]) * t
                r = r0 + (r1 - r0) * ((acc + L * t) / total)
                if r < 0.5:
                    out.add((round(x), round(y)))
                else:
                    out |= self.ellipse(x - r, y - r, x + r - 0.01, y + r - 0.01)
            acc += L
        return {p for p in out if 0 <= p[0] < self.w and 0 <= p[1] < self.h}

    # ---- painting ----
    def part(self, mask, fill, outer="outline", inner=None):
        """Paint a part: 1px ring (outer over empty, inner over existing pixels), then fill.
        fill is a palette name or fn(x, y) -> name/None."""
        if outer or inner:
            ring = set()
            for (x, y) in mask:
                for dx, dy in N4:
                    q = (x + dx, y + dy)
                    if q not in mask and 0 <= q[0] < self.w and 0 <= q[1] < self.h:
                        ring.add(q)
            for q in ring:
                col = inner if q in self.px else outer
                if col:
                    self.px[q] = col
        for p in mask:
            col = fill(*p) if callable(fill) else fill
            if col:
                self.px[p] = col

    def put(self, x, y, name):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = name

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), TRANSPARENT)
        d = img.load()
        for (x, y), n in self.px.items():
            d[x, y] = c(n)
        return img


def depth(mask):
    """4-neighbour distance from the mask edge (edge pixels = 0)."""
    dist, frontier, rest = {}, set(), set(mask)
    for p in mask:
        if any((p[0] + dx, p[1] + dy) not in mask for dx, dy in N4):
            frontier.add(p)
    k = 0
    while frontier:
        for p in frontier:
            dist[p] = k
        rest -= frontier
        frontier = {p for p in rest if any((p[0] + dx, p[1] + dy) in dist for dx, dy in N4)}
        k += 1
    return dist


def shaded(mask, base, light, dark):
    """Light from the top-left: 1px highlight on top edges, 1px shadow on bottom/right edges."""
    def f(x, y):
        if (x, y + 1) not in mask or (x + 1, y + 1) not in mask and (x + 1, y) not in mask:
            return dark
        if light and (x, y - 1) not in mask:
            return light
        return base
    return f


FLAME = ["ember_deep", "ember_orange", "ember_amber", "ember_yellow", "ember_cream"]


def flame_fill(mask, hot=0):
    """Colour bands by depth: deep edge -> orange -> amber -> yellow -> cream core."""
    d = depth(mask)

    def f(x, y):
        return FLAME[min(len(FLAME) - 1, d[(x, y)] + hot)]
    return f


def flame(cv, mask, hot=0, outline="red_dark"):
    mask = {(x, y) for x, y in mask if 1 <= x <= cv.w - 2 and 1 <= y <= cv.h - 1}
    cv.part(mask, flame_fill(mask, hot), outer=outline, inner=None)


def flame_tail(cv, path, r0, r1, tongues, phase):
    """Fluffy fire tail: a tapered core stroke plus tongues licking outward/upward.
    tongues: (segment_index, t, dx, dy, radius); tips sway with the flicker phase."""
    m = cv.stroke(path, r0, r1)
    for k, (si, t, dx, dy, r) in enumerate(tongues):
        a, b = path[si], path[si + 1]
        x0, y0 = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        sway = [0, 1, 0, -1][(phase + k) % 4]
        grow = [0, 0.5, 1, 0.5][(phase + k * 2) % 4]
        tip = (x0 + dx + sway * 0.7, y0 + dy - grow)
        mid = (x0 + dx * 0.45, y0 + dy * 0.6)
        m |= cv.stroke([(x0, y0), mid, tip], r, 0.3)
    return m


# --------------------------------------------------------------------------
# Cinderkin overworld (32x32 frames). Feet on y = 31, pivot bottom-centre (16, 32).
# --------------------------------------------------------------------------

FUR, FUR_L, FUR_D = "stone_light", "stone_pale", "stone"
CHEST, CHEST_D = "cream", "sand"
MEMB, MEMB_L = "ember_glow", "ember_amber"


def flick(phase, a=1.0):
    """Small deterministic flame wobble per idle/walk phase (0-3)."""
    return [0, 1, 0, -1][phase % 4] * a


def membrane(cv, pts, dy=0):
    m = cv.poly([(x, y + dy) for x, y in pts])
    d = depth(m)

    def f(x, y):
        # bright lit rim on the outer/lower edge, glowing body, fur-brown near the arm
        if d[(x, y)] == 0 and ((x, y + 1) not in m or (x - 1, y) not in m and (x + 1, y) not in m):
            return MEMB_L
        return MEMB if d[(x, y)] < 2 else "ember_orange"
    cv.part(m, f, outer="red_dark", inner="red_dark")


def eye(cv, x0, y0, w=4, h=5, look=0):
    m = cv.ellipse(x0, y0, x0 + w - 1, y0 + h - 1)
    cv.part(m, lambda x, y: "ember_amber" if y < y0 + h - 2 else "ember_orange",
            outer="outline", inner="outline")
    cx = x0 + w // 2 + look
    for y in range(y0 + 1, y0 + h - 1):
        cv.put(cx - 1 + (1 if look > 0 else 0), y, "outline")
    cv.put(x0 + (1 if look >= 0 else w - 2), y0 + 1, "white_warm")
    cv.put(cx + (0 if look > 0 else 0), y0 + h - 2, "ember_yellow")


def front(phase=0, bob=0, step=None, flap=0, back=False):
    """Down-facing (back=False) or up-facing (back=True) Cinderkin."""
    cv = Canvas(32, 32)
    b = bob
    # tail: plume curling up on the right behind the body (in front when seen from behind)
    w = flick(phase)
    tail_pts = [(17, 27 + b), (23, 27 + b), (27, 23 + b), (28 + w * 0.5, 18 + b), (26 + w, 13 + b)]

    def draw_tail():
        t = flame_tail(cv, tail_pts, 3.8, 1.0,
                       [(1, 0.6, 3, -3, 1.6), (2, 0.5, 3, -2, 1.4), (3, 0.3, 2, -3, 1.2),
                        (0, 0.7, 1, 3, 1.2), (2, 0.9, -3, -1, 1.2)], phase)
        flame(cv, t, hot=0)

    if not back:
        draw_tail()
    # membranes (spread a little, lit edges)
    fy = -flap
    wing = [(12, 17), (5, 17 + fy), (1, 20 + fy * 2), (3, 23 + fy), (5, 22 + fy), (7, 25),
            (9, 24), (12, 27)]
    membrane(cv, wing, b)
    membrane(cv, [(31 - x, y) for x, y in wing], b)
    # ears: big pointed, glowing inside
    for side in (0, 1):
        def X(x):
            return x if side == 0 else 31 - x
        e = cv.poly([(X(1), 1 + b), (X(13), 7 + b), (X(5), 14 + b)])
        cv.part(e, shaded(e, FUR, FUR_L, FUR_D), outer="outline")
        if not back:
            ie = cv.poly([(X(3), 3 + b), (X(11.5), 7.5 + b), (X(6), 12.5 + b)])
            ie_d = depth(ie)
            cv.part(ie, lambda x, y: "ember_glow" if ie_d[(x, y)] == 0 else
                    ("ember_amber" if phase % 2 == 0 or ie_d[(x, y)] > 1 else "ember_yellow"),
                    outer=None)
        else:
            rim = cv.poly([(X(1.5), 1.5 + b), (X(3), 2.5 + b), (X(5.5), 13 + b), (X(5), 14 + b)])
            cv.part(rim, "ember_glow", outer=None)
    # body
    body = cv.ellipse(10, 17 + b, 21, 30)
    cv.part(body, shaded(body, FUR, FUR_L, FUR_D), outer="outline", inner="outline")
    if not back:
        ch = cv.ellipse(12, 19 + b, 19, 29)
        cv.part(ch, lambda x, y: CHEST_D if (x, y + 1) not in ch else CHEST, outer=None)
    # feet
    for fx, lift in ((10, step == "L"), (18, step == "R")):
        fm = cv.ellipse(fx, 28 - lift, fx + 3, 31 - lift)
        cv.part(fm, lambda x, y: "sand" if y < 31 - lift else "tan", outer="outline", inner="outline")
        cv.put(fx + 1, 30 - lift, "skin_shadow")
        cv.put(fx + 2, 30 - lift, "skin_shadow")
    # front paws
    if not back:
        for px in (12, 18):
            pm = cv.ellipse(px, 22 + b, px + 1, 24 + b)
            cv.part(pm, "sand", outer=None, inner=None)
            cv.put(px, 25 + b, "outline"); cv.put(px + 1, 25 + b, "outline")
    # head
    head = cv.ellipse(6, 6 + b, 25, 21 + b)
    cv.part(head, shaded(head, FUR, FUR_L, FUR_D), outer="outline", inner=FUR_D)
    if not back:
        mz = cv.ellipse(9, 13 + b, 22, 21 + b) & head
        mz = {p for p in mz if p[1] >= 15 + b or 11 <= p[0] <= 20} - {p for p in head if p[1] >= 21 + b}
        cv.part(mz, lambda x, y: CHEST_D if (x, y + 1) not in mz else CHEST, outer=None)
        # forehead stripe (concept: darker V mark under the crest)
        for y in range(8, 11):
            cv.put(15, y + b, FUR_D); cv.put(16, y + b, FUR_D)
        eye(cv, 8, 10 + b, 5, 6)
        eye(cv, 19, 10 + b, 5, 6)
        cv.put(15, 16 + b, "pink"); cv.put(16, 16 + b, "pink")
        cv.put(15, 17 + b, "skin_shadow"); cv.put(16, 17 + b, "skin_shadow")
        for x, y in ((14, 18), (15, 19), (16, 19), (17, 18)):
            cv.put(x, y + b, "brown_mid")
        cv.put(10, 17 + b, "pink"); cv.put(21, 17 + b, "pink")  # blush
    else:
        # darker back-of-head stripe under the crest, lighter nape tufts
        for y in range(8, 15):
            cv.put(15, y + b, FUR_D); cv.put(16, y + b, FUR_D)
        for x, y in ((11, 17), (12, 18), (19, 18), (20, 17), (13, 19), (18, 19)):
            cv.put(x, y + b, "stone_pale")
    # flame crest on the forehead
    cw = flick(phase + 1)
    cr = cv.stroke([(15.5, 8 + b), (15.5 + cw * 0.5, 5 + b), (16.5 + cw, 2 + b)], 2.0, 0.4)
    cr |= cv.stroke([(14, 7 + b), (13.5 - cw * 0.5, 4 + b)], 1.0, 0.3)
    flame(cv, cr, hot=1)
    if back:
        draw_tail()
    return cv


def side(phase=0, bob=0, step=0, flap=0):
    """Left-facing Cinderkin (right is a mirror). step: 0 stand, 1/2 opposite strides."""
    cv = Canvas(32, 32)
    b = bob
    w = flick(phase)
    # big flame tail curling up behind (right side)
    tail = flame_tail(cv, [(17, 26 + b), (23, 26 + b), (26, 22 + b), (26 + w * 0.5, 16 + b),
                           (24 + w, 11 + b), (21 + w, 9 + b)], 3.8, 0.8,
                      [(1, 0.7, 3, -2, 1.4), (2, 0.6, 4, -3, 1.4), (3, 0.5, 4, -3, 1.3),
                       (4, 0.4, 3, -4, 1.2), (4, 0.9, 1, -4, 1.1), (3, 0.9, -3, -2, 1.0),
                       (0, 0.8, 2, 3, 1.0)], phase)
    flame(cv, tail)
    # far ear (behind head), peeking out with a glowing edge
    fe = cv.poly([(12, 10 + b), (20, 2 + b), (18, 13 + b)])
    cv.part(fe, lambda x, y: "ember_glow" if (x + 1, y) not in fe else FUR, outer="outline")
    # far legs
    lx = {0: (0, 0), 1: (-2, 2), 2: (2, -2)}[step]
    for fx in (8 + lx[1], 16 + lx[0]):
        fm = cv.ellipse(fx, 28, fx + 3, 31)
        cv.part(fm, "tan", outer="outline", inner="outline")
    # body
    body = cv.ellipse(7, 18 + b, 21, 30)
    cv.part(body, shaded(body, FUR, FUR_L, FUR_D), outer="outline", inner="outline")
    ch = cv.ellipse(6, 20 + b, 13, 30) & body
    cv.part(ch, lambda x, y: CHEST_D if (x, y + 1) not in ch else CHEST, outer=None)
    # membrane: stretched between front and back leg along the flank, scalloped edge
    fy = -flap
    membrane(cv, [(10, 21), (19, 20 + fy * 2), (22, 23 + fy), (20, 26), (18, 25), (16, 27),
                  (14, 26), (11, 27)], b)
    # near legs
    for fx in (10 + lx[0], 18 + lx[1]):
        fm = cv.ellipse(fx, 28, fx + 3, 31)
        cv.part(fm, lambda x, y: "sand" if y < 31 else "tan", outer="outline", inner="outline")
    # head
    head = cv.ellipse(2, 7 + b, 18, 21 + b)
    cv.part(head, shaded(head, FUR, FUR_L, FUR_D), outer="outline", inner="outline")
    mz = cv.ellipse(1, 13 + b, 12, 21 + b) & head
    cv.part(mz, lambda x, y: CHEST_D if (x, y + 1) not in mz else CHEST, outer=None)
    # near ear (big, pointing up and back)
    e = cv.poly([(10, 9 + b), (15, 1 + b), (17.5, 12 + b)])
    cv.part(e, shaded(e, FUR, FUR_L, FUR_D), outer="outline", inner=FUR_D)
    ie = cv.poly([(11.5, 9 + b), (14.8, 3.2 + b), (16.5, 11 + b)])
    cv.part(ie, "ember_amber" if phase % 2 == 0 else "ember_yellow", outer=None, inner=None)
    for p in ie:
        if (p[0] - 1, p[1]) not in ie or (p[0], p[1] - 1) not in ie:
            cv.put(*p, "ember_glow")
    eye(cv, 3, 10 + b, 5, 6, look=0)
    cv.put(1, 16 + b, "pink"); cv.put(1, 17 + b, "skin_shadow")
    cv.put(3, 19 + b, "brown_mid"); cv.put(4, 19 + b, "brown_mid")
    cv.put(7, 17 + b, "pink")
    # crest
    cw = flick(phase + 1)
    cr = cv.stroke([(6, 8 + b), (6 + cw * 0.5, 5 + b), (7 + cw, 2 + b)], 1.8, 0.4)
    cr |= cv.stroke([(4.5, 8 + b), (3.5 - cw * 0.5, 6 + b)], 0.9, 0.3)
    flame(cv, cr, hot=1)
    return cv


IDLE_BOB = [0, 0, 1, 1]


def creature_row(direction):
    frames = []
    if direction in ("down", "up"):
        bk = direction == "up"
        for i in range(4):
            frames.append(front(i, IDLE_BOB[i], back=bk).image())
        for i, (st, bb, fl) in enumerate(((("R"), 1, 1), (None, 0, 2), ("L", 1, 1), (None, 0, 0))):
            frames.append(front(i, bb, step=st, flap=fl, back=bk).image())
    else:
        for i in range(4):
            frames.append(side(i, IDLE_BOB[i]).image())
        for i, (st, bb, fl) in enumerate(((1, 1, 1), (0, 0, 2), (2, 1, 1), (0, 0, 0))):
            frames.append(side(i, bb, st, fl).image())
        if direction == "right":
            frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]
    return frames


def build_sheet():
    sheet = Image.new("RGBA", (32 * 8, 32 * 4), TRANSPARENT)
    for r, d in enumerate(("down", "left", "right", "up")):
        for i, f in enumerate(creature_row(d)):
            sheet.alpha_composite(f, (i * 32, r * 32))
    return sheet


# --------------------------------------------------------------------------
# Portrait (64x64 bust, transparent background)
# --------------------------------------------------------------------------

def banded(mask, light, base, dark, deep=None, k=0.35):
    """Soft-looking but hard-edged form shading: bands by position toward the top-left light."""
    xs = [p[0] for p in mask]; ys = [p[1] for p in mask]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    rx, ry = max(1, (max(xs) - min(xs)) / 2), max(1, (max(ys) - min(ys)) / 2)

    def f(x, y):
        v = (x - cx) / rx * 0.6 + (y - cy) / ry * 0.8
        if deep and v > 0.95:
            return deep
        if v > k + 0.2:
            return dark
        if v < -0.75:
            return light
        return base
    return f


def tufts(cv, mask, pts, col):
    for x, y in pts:
        if (x, y) in mask:
            cv.put(x, y, col)


def build_portrait():
    cv = Canvas(64, 64)
    # shoulders / body with membranes peeking out
    for side in (0, 1):
        def X(x):
            return x if side == 0 else 63 - x
        wing = cv.poly([(X(14), 48), (X(4), 50), (X(0.5), 55), (X(3), 58), (X(5), 57), (X(7), 61),
                        (X(10), 60), (X(12), 63.5), (X(18), 63.5)])
        d = depth(wing)
        cv.part(wing, lambda x, y: "ember_amber" if d[(x, y)] == 0 and (x, y + 1) not in wing
                else ("ember_glow" if d[(x, y)] < 2 else "ember_orange"),
                outer="red_dark", inner="red_dark")
    body = cv.ellipse(10, 44, 53, 80)
    cv.part(body, banded(body, FUR_L, FUR, FUR_D), outer="outline", inner="outline")
    chest = cv.poly([(20, 48), (44, 48), (42, 63.5), (22, 63.5)])
    chest |= cv.ellipse(18, 46, 45, 70)
    chest &= body
    cv.part(chest, lambda x, y: CHEST_D if x > 38 and y > 52 else CHEST, outer=None)
    for x in range(20, 44, 4):  # fluffy tuft edge where chest meets fur
        cv.put(x, 47, CHEST); cv.put(x + 1, 46, CHEST)
    for x, y in ((26, 56), (27, 57), (36, 55), (37, 56), (31, 60), (32, 61), (24, 61), (40, 60)):
        cv.put(x, y, CHEST_D)
    # ears
    for side in (0, 1):
        def X(x):
            return x if side == 0 else 63 - x
        e = cv.poly([(X(1), 1), (X(26), 15), (X(13), 33)])
        cv.part(e, banded(e, FUR_L, FUR, FUR_D), outer="outline", inner="outline")
        ie = cv.poly([(X(4.5), 5), (X(22.5), 16), (X(13.5), 29)])
        d = depth(ie)
        cv.part(ie, lambda x, y: ["ember_glow", "ember_glow", "ember_orange", "ember_amber",
                                  "ember_yellow", "ember_cream"][min(5, d[(x, y)])], outer=None)
        # fur tufts along the inner ear rim
        for t in range(3):
            tx, ty = X(13 + t * 2), 27 - t
            cv.put(tx, ty, FUR_L); cv.put(tx, ty - 1, FUR_L)
    # head
    head = cv.ellipse(11, 13, 52, 51)
    cv.part(head, banded(head, FUR_L, FUR, FUR_D), outer="outline", inner=CHEST_D)
    # cheek fluff + muzzle (cream), jagged fluffy outer edge
    mz = cv.ellipse(20, 34, 43, 52) & head
    mz |= (cv.ellipse(13, 40, 25, 52) | cv.ellipse(38, 40, 50, 52)) & head  # cheek fluff
    mz |= cv.poly([(14, 46), (10, 48), (17, 49)]) | cv.poly([(49, 46), (53, 48), (46, 49)])
    cv.part(mz, lambda x, y: CHEST_D if y > 48 or x > 44 else CHEST, outer=None)
    tufts(cv, head, [(14, 40), (13, 42), (49, 40), (50, 42), (31, 14), (33, 15), (29, 16)], FUR_L)
    # forehead dark mark under the crest
    for y in range(17, 24):
        for x in (30, 31, 32, 33):
            if abs(x - 31.5) < (24 - y) * 0.35 + 0.6:
                cv.put(x, y, FUR_D)
    # eyes: big, round, glowing amber
    for ex in (16, 37):
        em = cv.ellipse(ex, 23, ex + 10, 35)
        cv.part(em, lambda x, y: "ember_amber" if y < 28 else ("ember_orange" if y < 33 else "ember_deep"),
                outer="outline", inner="outline")
        pm = cv.ellipse(ex + 3, 26, ex + 7, 33)
        cv.part(pm, "outline", outer=None)
        for x in range(ex + 3, ex + 8):  # warm glow at the bottom of the pupil
            if (x, 33) in em and (x, 34) in em:
                cv.put(x, 34, "ember_yellow")
        hl = cv.ellipse(ex + 2, 25, ex + 4, 27)
        cv.part(hl, "white_warm", outer=None)
        cv.put(ex + 7, 31, "white_warm")
    # nose + mouth + blush
    for x, y in ((30, 38), (31, 38), (32, 38), (33, 38), (31, 39), (32, 39)):
        cv.put(x, y, "pink")
    cv.put(31, 38, "white_warm")
    for x, y in ((31, 40), (32, 40), (31, 41), (32, 41), (30, 42), (29, 42), (28, 41),
                 (33, 42), (34, 42), (35, 41)):
        cv.put(x, y, "brown_mid")
    for x, y in ((18, 40), (19, 40), (20, 40), (43, 40), (44, 40), (45, 40)):
        cv.put(x, y, "pink")
    # whiskers (soft, short)
    for x, y in ((12, 38), (11, 38), (13, 41), (12, 42)):
        cv.put(x, y, FUR_D); cv.put(63 - x, y, FUR_D)
    # flame crest
    cr = cv.stroke([(31.5, 18), (31, 12), (33, 7), (35, 2)], 3.2, 0.5)
    cr |= cv.stroke([(29, 16), (27, 11), (26.5, 8)], 1.8, 0.4)
    cr |= cv.stroke([(34, 16), (36.5, 12), (38, 10)], 1.4, 0.3)
    flame(cv, cr, hot=0)
    # a few drifting embers
    for x, y, col in ((5, 40, "ember_amber"), (57, 36, "ember_yellow"), (59, 44, "ember_orange"),
                      (3, 30, "ember_yellow"), (44, 4, "ember_amber"), (20, 6, "ember_orange")):
        cv.put(x, y, col)
    return cv.image()


# --------------------------------------------------------------------------
# Item icon: Wet Waxweed (16x16). Damp green moss clump with a water sheen.
# --------------------------------------------------------------------------

WW = {
    "o": "green_dark", "f": "green_forest", "g": "green", "G": "green_grass",
    "l": "green_light", "p": "green_pale", "b": "blue_light", "B": "blue",
    "w": "white_warm", "d": "blue_dark",
}
WAXWEED = [
    "................",
    "...........B....",
    "..........BbB...",
    ".....ooo..Bwb...",
    "...oolGlo..BB...",
    "..olpGGGlooo....",
    ".olGGgGwbGlGo...",
    ".oGGgGGGGlGGgoo.",
    "oGlGwbGgGGGGGglo",
    "oGGgGGGGgGpGgGGo",
    "ofGGlGgGGGwbGgfo",
    "ofgGGbgfGGgGgffo",
    ".ofgfGgfgffgffo.",
    "..offfgffbfffo..",
    "...ooooooBoooo..",
    ".........b......",
]


def build_waxweed():
    assert len(WAXWEED) == 16 and all(len(r) == 16 for r in WAXWEED)
    img = Image.new("RGBA", (16, 16), TRANSPARENT)
    px = img.load()
    for y, row in enumerate(WAXWEED):
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = c(WW[ch])
    return img


# --------------------------------------------------------------------------

def validate(name, img, size):
    assert img.size == size, (name, img.size)
    pal = set(RGBA)
    d = img.load()
    for px in (d[x, y] for y in range(img.height) for x in range(img.width)):
        assert px[3] in (0, 255), (name, "partial alpha", px)
        assert px[3] == 0 or px in pal, (name, "off-palette", px)


def preview(outdir, outputs):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    S = 8
    bg = (58, 50, 60, 255)  # preview-only backdrop, not shipped
    ups = []
    for name, img in outputs.items():
        up = img.resize((img.width * S, img.height * S), Image.NEAREST)
        flat = Image.new("RGBA", up.size, bg)
        flat.alpha_composite(up)
        stem = name if name.startswith("cinderkin") else f"cinderkin_{name}"
        flat.save(outdir / f"{stem}_8x.png")
        ups.append(flat)
    # in-context check: idle-down frame + icon on grass and dirt tiles at 1:1 scale
    ts = ROOT / "assets/tilesets/farm_tiles.png"
    if ts.exists():
        tiles = Image.open(ts).convert("RGBA")
        scene = Image.new("RGBA", (96, 48))
        for y in range(3):
            for x in range(6):
                i = 7 if y == 2 else (x + y) % 2
                scene.paste(tiles.crop((i * 16, 0, i * 16 + 16, 16)), (x * 16, y * 16))
        sh = outputs["cinderkin"]
        scene.alpha_composite(sh.crop((0, 0, 32, 32)), (8, 8))
        scene.alpha_composite(sh.crop((32 * 4, 32, 32 * 5, 64)), (48, 8))
        scene.alpha_composite(outputs["item_wet_waxweed"], (72, 32))
        up = scene.resize((96 * S, 48 * S), Image.NEAREST)
        up.save(outdir / "cinderkin_scene_8x.png")
        ups.append(up)
    W = max(u.width for u in ups) + 16
    H = sum(u.height + 16 for u in ups) + 16
    allimg = Image.new("RGBA", (W, H), (30, 26, 32, 255))
    y = 16
    for u in ups:
        allimg.alpha_composite(u, (8, y))
        y += u.height + 16
    allimg.save(outdir / "cinderkin_all.png")


def main():
    outputs = {
        "cinderkin": build_sheet(),
        "cinderkin_portrait": build_portrait(),
        "item_wet_waxweed": build_waxweed(),
    }
    paths = {
        "cinderkin": (ROOT / "assets/sprites/cinderkin.png", (256, 128)),
        "cinderkin_portrait": (ROOT / "assets/portraits/cinderkin_portrait.png", (64, 64)),
        "item_wet_waxweed": (ROOT / "assets/sprites/item_wet_waxweed.png", (16, 16)),
    }
    for k, img in outputs.items():
        path, size = paths[k]
        validate(k, img, size)
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
        print("wrote", path.relative_to(ROOT), img.size)
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], outputs)


if __name__ == "__main__":
    main()
