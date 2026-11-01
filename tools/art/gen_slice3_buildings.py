"""Slice 3 farm buildings (procedural, pixel-level, reproducible).

Outputs (relative to repo root):
  assets/tilesets/pasture_tiles.png          128x48, 8 cols of 16x16
      0-15  pasture fence autotile, tile = 0 + mask (N=1, E=2, S=4, W=8)
      16 gate_h_closed  17 gate_h_open  18 gate_v_closed  19 gate_v_open
      20 water_trough   21 hay_bale     22 feed_trough    23 (empty)
  assets/sprites/habitat_woodland.png        64x64 Woodland habitat plot (ground + objects)
  assets/sprites/habitat_woodland_ground.png 64x64 opaque ground layer (draw under actors)
  assets/sprites/habitat_woodland_objects.png 64x64 fence/trees/rocks/log only (y-sort / overlay)
  assets/sprites/barn_stages.png             400x80, 5 frames of 80x80, frame = barn_upgrades (0-4)

Every opaque pixel comes from tools/art/palette.py (indices 0-41, nothing added); alpha is 0/255.
Usage:  python3 tools/art/gen_slice3_buildings.py [--preview DIR]
"""
import random
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from palette import RGBA, TRANSPARENT, c  # noqa: E402
from gen_cinderkin import Canvas, shaded  # noqa: E402
import gen_slice3_woodland as wl  # noqa: E402

T = 16


def new(w, h):
    return Image.new("RGBA", (w, h), TRANSPARENT)


def blit(img, rows, cmap, ox=0, oy=0):
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != "." and 0 <= ox + x < img.width and 0 <= oy + y < img.height:
                px[ox + x, oy + y] = c(cmap[ch])


# ==========================================================================
# (a) Pasture fence: white-washed, taller (rails rows 2-11 vs the farm fence's 4-12),
#     pointed post caps, cool stone_dark outline instead of the farm fence's brown.
# ==========================================================================

PF = {"o": "stone_dark", "w": "white_warm", "p": "stone_pale", "s": "stone_light",
      "k": "outline", "y": "yellow", "b": "brown_mid", "d": "brown"}

P_RAIL_H = [
    "................",
    "................",
    "oooooooooooooooo",
    "wwwwwwwwwwwwwwww",
    "pppppppsppppppps",
    "oooooooooooooooo",
    "................",
    "................",
    "oooooooooooooooo",
    "wwwwwwwwwwwwwwww",
    "pppsppppppppsppp",
    "oooooooooooooooo",
    "................",
    "................",
    "................",
    "................",
]
P_RAIL_V = ["......owpo......"] * 16
P_RAIL_V[3] = "......owso......"
P_RAIL_V[10] = "......opso......"
P_POST = [
    ".......oo.......",
    "......owwo......",
    ".....owwwpo.....",
    ".....owwwpo.....",
    ".....owwppo.....",
    ".....owwwpo.....",
    ".....owwwpo.....",
    ".....owwpso.....",
    ".....owwwpo.....",
    ".....owwwpo.....",
    ".....owpwpo.....",
    ".....owwwpo.....",
    ".....owwwso.....",
    ".....ospsso.....",
    ".....oooooo.....",
    "................",
]


def pasture_fence(mask):
    t = new(T, T)
    def half(rows, a, b):
        return ["." * a + r[a:b] + "." * (16 - b) for r in rows]
    if mask & 8:
        blit(t, half(P_RAIL_H, 0, 8), PF)
    if mask & 2:
        blit(t, half(P_RAIL_H, 8, 16), PF)
    if mask & 1:
        blit(t, P_RAIL_V[:8], PF)
    if mask & 4:
        blit(t, P_RAIL_V[8:], PF, 0, 8)
    post = list(P_POST)
    if mask == 5:  # straight vertical run: the rail passes through, cap reads as one line
        post[0] = "......owwo......"
    blit(t, post, PF)
    return t


def gate_h_closed():
    t = new(T, T)
    cv = Canvas(T, T)
    # rails (full width, joins the neighbouring fence rails)
    for y, col in ((2, "o"), (3, "w"), (4, "p"), (5, "o"), (8, "o"), (9, "w"), (10, "p"), (11, "o")):
        for x in range(T):
            cv.put(x, y, PF[col])
    # stiles at both ends, rows 1-12
    for x0 in (0, 13):
        for y in range(1, 13):
            cv.put(x0, y, "stone_dark")
            cv.put(x0 + 1, y, "white_warm")
            cv.put(x0 + 2, y, "stone_pale")
        cv.put(x0 + 1, 1, "stone_dark")
        cv.put(x0 + 1, 12, "stone_dark")
        cv.put(x0 + 2, 12, "stone_dark")
    # diagonal brace, hinge foot (3,10) -> latch head (12,3)
    for i in range(10):
        x = 3 + i
        y = 10 - round(i * 7 / 9)
        cv.put(x, y, "white_warm")
        cv.put(x, y + 1, "stone_light")
    # latch
    cv.put(14, 6, "yellow")
    cv.put(14, 7, "brown_mid")
    cv.put(15, 6, "outline")
    cv.put(15, 7, "outline")
    # hinges
    cv.put(1, 3, "stone_dark")
    cv.put(1, 9, "stone_dark")
    t.alpha_composite(cv.image())
    return t


def gate_h_open():
    """Swung open toward the viewer on its west hinge: a foreshortened panel down the left edge."""
    cv = Canvas(T, T)
    # stub of the top rail ends at the hinge so the neighbour reads as a gate post
    for x in range(0, 5):
        for y in range(1, 15):
            cv.put(x, y, "stone_dark" if x in (0, 4) or y in (1, 14) else
                   ("white_warm" if x in (1, 3) and y % 6 != 4 else
                    ("stone_pale" if x == 2 else "stone_light")))
    for y in (4, 9):  # rails seen end-on as cross boards
        for x in range(1, 4):
            cv.put(x, y, "stone_light")
    cv.put(2, 6, "yellow")  # latch, now at the far (bottom) end
    cv.put(2, 12, "yellow")
    # shadow cast on the ground to the right of the panel
    for y in range(5, 15):
        cv.put(5, y, "green_forest")
    cv.put(6, 14, "green_forest")
    return cv.image()


def gate_v_closed():
    """Gate in a north-south fence run, seen edge-on: a wider plank column with cross boards."""
    cv = Canvas(T, T)
    for y in range(T):
        for x in range(5, 11):
            edge = x in (5, 10)
            cv.put(x, y, "stone_dark" if edge else ("white_warm" if x in (6, 7) else
                                                   ("stone_pale" if x == 8 else "stone_light")))
    for y in (0, 7, 14):  # cross boards
        for x in range(4, 12):
            cv.put(x, y, "stone_dark")
        for x in range(5, 11):
            cv.put(x, y + 1, "white_warm" if x < 9 else "stone_pale")
        cv.put(4, y + 1, "stone_dark")
        cv.put(11, y + 1, "stone_dark")
        cv.put(4, y + 2 if y + 2 < T else y, "stone_dark")
        cv.put(11, y + 2 if y + 2 < T else y, "stone_dark")
        for x in range(5, 11):
            if y + 2 < T:
                cv.put(x, y + 2, "stone_dark")
    cv.put(9, 11, "yellow")
    cv.put(9, 12, "brown_mid")
    return cv.image()


def gate_v_open():
    """North-south gate swung east on its north hinge: the panel lies along the top of the tile."""
    t = new(T, T)
    t.alpha_composite(gate_h_closed().crop((0, 0, 16, 13)).crop((0, 0, 11, 13)), (5, 0))
    cv = Canvas(T, T)
    # hinge stub of the vertical rail at the top, nothing in the passage below
    for x in range(6, 16):
        cv.put(x, 13, "green_forest")
    sh = cv.image()
    sh.alpha_composite(t)
    return sh


def water_trough():
    rows = [
        "................",
        "................",
        "................",
        "................",
        "................",
        ".oooooooooooooo.",
        "obbbbbbbbbbbbbbo",
        "obooooooooooooko",
        "obwlLLlLLLlLLwko",
        "obwLLLLlLLLLLwko",
        "obwwwwwwwwwwwwko",
        "obbbbbbbbbbbbbko",
        "odddddddddddddko",
        ".oooooooooooooo.",
        "..o..........o..",
        "................",
    ]
    t = new(T, T)
    blit(t, rows, {"o": "outline", "b": "brown_mid", "d": "brown", "k": "brown_dark",
                   "w": "blue", "l": "white_warm", "L": "blue_light"})
    return t


def hay_bale():
    rows = [
        "................",
        "................",
        "................",
        "...oooooooooo...",
        "..oyyYyyyyYyyo..",
        ".oyYyyyhyyyyYyo.",
        ".ohhhhhhhhhhhho.",
        ".oyyhyyyyyYyyho.",
        ".oyYyyyhyyyyyho.",
        ".ohhhhhhhhhhhho.",
        ".obbbbbbbbbbbbo.",
        ".oyyYyyyhyyyyto.",
        ".otyttttttyttto.",
        "..oooooooooooo..",
        "................",
        "................",
    ]
    t = new(T, T)
    blit(t, rows, {"o": "brown_dark", "y": "yellow", "Y": "yellow_pale", "h": "tan",
                   "b": "brown_mid", "t": "sand"})
    return t


def feed_trough():
    rows = [
        "................",
        "................",
        "................",
        "................",
        "................",
        "......G.g.......",
        "...gG.gGgO...G..",
        ".ooooOoooOoooGo.",
        "obbbbbbbbbbbbbbo",
        "obrcrORtcROrtcko",
        "obbbbbbbbbbbbbko",
        "odddddddddddddko",
        ".oooooooooooooo.",
        "..o..........o..",
        "................",
        "................",
    ]
    t = new(T, T)
    blit(t, rows, {"o": "outline", "b": "brown_mid", "d": "brown", "k": "brown_dark",
                   "g": "green", "G": "green_dark", "O": "orange", "r": "red", "R": "red_dark",
                   "c": "tan", "t": "yellow"})
    return t


GATE_WOOD = {"stone_dark": "brown_dark", "white_warm": "tan", "stone_pale": "brown_light",
             "stone_light": "brown_mid"}


def wood_gate(img):
    """Gates are natural wood (tan/brown) so they read apart from the white-washed fence."""
    px = img.load()
    rev = {c(k): c(v) for k, v in GATE_WOOD.items()}
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y] in rev:
                px[x, y] = rev[px[x, y]]
    return img


def build_pasture():
    sheet = new(8 * T, 3 * T)
    tiles = {m: pasture_fence(m) for m in range(16)}
    tiles.update({16: wood_gate(gate_h_closed()), 17: wood_gate(gate_h_open()),
                  18: wood_gate(gate_v_closed()), 19: wood_gate(gate_v_open()),
                  20: water_trough(), 21: hay_bale(), 22: feed_trough()})
    for i, tl in tiles.items():
        sheet.alpha_composite(tl, ((i % 8) * T, (i // 8) * T))
    return sheet


# ==========================================================================
# (b) Woodland habitat plot, 64x64 (4x4 tiles). Top-left on a tile corner; gate opening
#     bottom-centre x 24-39 (interaction point (32, 64)).
# ==========================================================================

HW = 64
RUSTIC = {"o": "outline", "D": "brown_dark", "d": "brown", "m": "brown_mid", "l": "brown_light",
          "h": "tan", "M": "moss", "g": "green_forest"}


def habitat_ground(tiles):
    img = new(HW, HW)
    pick = [[0, 6, 2, 1], [3, 0, 4, 6], [1, 5, 0, 3], [6, 2, 7, 0]]
    for ty in range(4):
        for tx in range(4):
            img.alpha_composite(tiles[pick[ty][tx]], (tx * T, ty * T))
    # moss carpet patches
    img.alpha_composite(tiles[9], (2, 30))
    img.alpha_composite(tiles[8], (44, 46))
    # pond (water spot), right-middle
    cv = Canvas(HW, HW)
    rim = cv.ellipse(34, 26, 57, 41)
    water = cv.ellipse(36, 28, 55, 39)
    cv.part(rim, lambda x, y: "stone_light" if (x + y) % 5 else "stone", outer="outline")
    cv.part(water, shaded(water, "blue", "blue_dark", "blue_light"), outer=None)
    for (x, y) in water:  # top shore shadow, highlight ripples
        if (x, y - 1) not in water:
            cv.put(x, y, "blue_dark")
    for x, y in ((40, 33), (41, 33), (48, 35), (49, 35), (50, 35), (44, 31)):
        cv.put(x, y, "white_warm" if x != 44 else "blue_light")
    for x, y in ((50, 30), (51, 30), (52, 31), (50, 31), (51, 31)):  # lily pad
        cv.put(x, y, "green_light" if y == 30 else "green")
    cv.put(52, 30, "pink")
    for x, y in ((35, 33), (56, 34), (38, 39), (53, 39)):
        cv.put(x, y, "moss")
    img.alpha_composite(cv.image())
    return img


def rustic_fence(cv_img):
    """Mossy split-rail ring with a gate opening at the bottom centre."""
    img = cv_img
    px = img.load()

    def P(x, y, k):
        if 0 <= x < HW and 0 <= y < HW:
            px[x, y] = c(RUSTIC[k])

    def rail_h(x0, x1, y):
        for x in range(x0, x1 + 1):
            P(x, y, "o"); P(x, y + 3, "o")
            P(x, y + 1, "h" if x % 9 == 4 else "l")
            P(x, y + 2, "d" if x % 7 == 3 else "m")

    def rail_v(x, y0, y1):
        for y in range(y0, y1 + 1):
            P(x, y, "o"); P(x + 3, y, "o")
            P(x + 1, y, "l"); P(x + 2, y, "m" if y % 6 else "d")

    def post(x, y, moss=True):  # 6 wide x 10 tall, top-left (x, y)
        for yy in range(10):
            for xx in range(6):
                edge = xx in (0, 5) or yy in (0, 9)
                k = "o" if edge else ("h" if yy in (1, 2) else ("l" if xx == 1 else ("d" if xx == 4 else "m")))
                P(x + xx, y + yy, k)
        if moss:
            for xx in (1, 2, 3):
                P(x + xx, y + 1, "M")
            P(x + 2, y + 2, "g")
    return img, rail_h, rail_v, post


def tree_oak(cv, bx, by):
    """Small round oak, trunk base centre (bx, by)."""
    trunk = cv.rect(bx - 2, by - 12, bx + 1, by)
    cv.part(trunk, lambda x, y: "brown_light" if x == bx - 2 else ("brown_dark" if x == bx + 1 else "brown_mid"))
    for x in (bx - 3, bx + 2):
        cv.put(x, by, "brown_mid")
    cv.put(bx - 4, by, "outline"); cv.put(bx + 3, by, "outline")
    clumps = [(-11, -22, 8), (9, -21, 8), (-5, -27, 8), (5, -29, 7), (-1, -17, 9)]
    whole = set()
    for (dx, dy, r) in clumps:
        whole |= cv.ellipse(bx + dx - r, by + dy - r, bx + dx + r - 1, by + dy + r - 1)
    cv.part(whole, "green_forest", outer="outline")
    for (dx, dy, r) in clumps:  # each clump: lit top-left, dark rim bottom-right
        m = cv.ellipse(bx + dx - r, by + dy - r, bx + dx + r - 1, by + dy + r - 1)
        cx, cy = bx + dx, by + dy

        def f(x, y, m=m, cx=cx, cy=cy, r=r):
            d = ((x - cx + r * 0.35) ** 2 + (y - cy + r * 0.35) ** 2) ** 0.5
            if (x, y + 1) not in m or (x + 1, y + 1) not in m:
                return "green_dark"
            if d < r * 0.45:
                return "green_grass"
            if d < r * 0.95:
                return "green"
            return "green_forest"
        cv.part(m, f, outer=None, inner="green_dark")
    for (x, y) in ((bx - 13, by - 25), (bx + 3, by - 33), (bx + 7, by - 24), (bx - 6, by - 30)):
        cv.put(x, y, "green_light")
        cv.put(x + 1, y, "green_light")
    cv.px = {p: v for p, v in cv.px.items() if p in whole or v == "outline" or p[1] > by - 12}


def tree_pine(cv, bx, by):
    trunk = cv.rect(bx - 1, by - 4, bx, by)
    cv.part(trunk, lambda x, y: "brown_mid" if x == bx - 1 else "brown_dark")
    tiers = [(by - 4, 8, 7), (by - 9, 6, 6), (by - 14, 4, 6)]
    for (y0, hw, h) in tiers:
        m = cv.poly([(bx - hw - 1, y0), (bx + hw, y0), (bx, y0 - h - 3), (bx - 1, y0 - h - 3)])
        cv.part(m, lambda x, y, m=m, y0=y0: "canopy_deep" if y >= y0 - 1 else
                ("green_forest" if x >= bx else ("green" if (x + y) % 3 else "green_forest")),
                outer="outline")


def habitat_objects(tiles):
    cv = Canvas(HW, HW)
    img = new(HW, HW)
    img, rail_h, rail_v, post = rustic_fence(img)
    # back fence (behind everything)
    rail_h(2, 61, 3)
    for x in (0, 19, 39, 58):
        post(x, 0)
    # objects, back to front
    tree_pine(cv, 49, 22)
    img.alpha_composite(cv.image())
    oak = Canvas(HW, HW)
    tree_oak(oak, 16, 37)
    img.alpha_composite(oak.image())
    for t, (x, y) in ((12, (25, 17)), (14, (17, 27)), (13, (24, 30)), (23, (6, 37)),
                      (14, (55, 41)), (10, (40, 41)), (15, (20, 40))):
        img.alpha_composite(tiles[t], (x, y))
    # feeding spot: a little wooden bowl of berries near the gate
    bowl = ["..oooooo..", ".orRrrRro.", "oRrrRrRrRo", "olmmmmmmdo", ".oddddddo.", "..oooooo.."]
    blit(img, bowl, {"o": "outline", "r": "red", "R": "red_dark", "l": "brown_light",
                     "m": "brown_mid", "d": "brown"}, 42, 47)
    # side fences + front fence with the gate opening
    rail_v(1, 6, 56)
    rail_v(59, 6, 56)
    post(0, 26)
    post(58, 26)
    rail_h(2, 21, 56)
    rail_h(42, 61, 56)
    for x in (0, 58):
        post(x, 53)
    post(18, 52)   # gate posts (taller: start a px higher)
    post(40, 52)
    return img


def build_habitat():
    tiles = wl.build_tiles()
    ground = habitat_ground(tiles)
    objects = habitat_objects(tiles)
    full = ground.copy()
    full.alpha_composite(objects)
    return full, ground, objects


# ==========================================================================
# (c) Barn, 5 stages (barn_upgrades 0-4 -> 20/40/60/80/100 stalls), 80x80 frames.
#     Anchor bottom-centre (40, 80). Door always centred on x = 40 with its sill on the bottom
#     row, so the entrance cell is tile column 2 of the bottom tile row in every stage.
# ==========================================================================

BF = 80
STAGES = [
    #  w   wall  paint      roof     door  loft  wing  windows found silo vane
    dict(depth=14, w=40, wall=22, paint=0, roof=0, door=12, loft=0, wing=0, win=0, found=0, silo=0, vane=0),
    dict(depth=16, w=48, wall=26, paint=1, roof=1, door=16, loft=0, wing=0, win=0, found=0, silo=0, vane=0),
    dict(depth=16, w=48, wall=26, paint=1, roof=1, door=16, loft=1, wing=1, win=0, found=0, silo=0, vane=0),
    dict(depth=20, w=56, wall=28, paint=1, roof=2, door=16, loft=2, wing=1, win=1, found=1, silo=0, vane=0),
    dict(depth=20, w=56, wall=28, paint=2, roof=2, door=16, loft=2, wing=1, win=1, found=1, silo=1, vane=1),
]
ROOFS = [  # (lit-slope base, lit-slope course line, shaded-slope base, shaded line, ridge light)
    ("brown", "brown_dark", "brown_dark", "outline", "brown_mid"),          # weathered shingles
    ("brown_mid", "brown", "brown", "brown_dark", "brown_light"),          # new wood shingles
    ("stone_light", "stone", "stone", "stone_dark", "stone_pale")]         # slate


def wall_fill(st, x0, x1, top, bottom):
    def f(x, y):
        if st["paint"] == 0:  # weathered: faded red with a couple of bare patched planks
            plank = (x - x0) // 4
            base = "brown_mid" if plank in (2, 7) else "red_dark"
            if (x - x0) % 4 == 0:
                return "brown_dark"
            if y == top:
                return "brown_dark"
            if (x * 7 + y * 3) % 23 == 0:
                return "brown"
            return base
        if (x - x0) % 4 == 0:
            return "red_dark"
        if y == top:
            return "red_dark"
        if st["paint"] == 2 and (x - x0) % 4 == 1:
            return "ember_deep"
        return "red"
    return f


def shingles(st, roof, top):
    """Lean-to roof: lit-slope colours, courses every 3 px."""
    base, line = ROOFS[st["roof"]][:2]

    def f(x, y):
        if (x, y + 1) not in roof:
            return "outline"
        row, sub = divmod(y - top + x // 3, 3)
        if sub == 2:
            return line
        if sub == 1 and (x + row * 3) % 6 == 0:
            return line
        return base
    return f


def gable_box(cv, st, cx, w, wall, ground=79, trim=True):
    """Front-gabled block: wall rect + gable triangle + shingle roof; returns geometry."""
    x0, x1 = cx - w // 2, cx + w // 2 - 1
    wt = ground - wall + 1
    gh = w * 3 // 10
    apex = wt - gh
    body = cv.rect(x0, wt, x1, ground) | cv.poly([(x0, wt), (cx - 1, apex), (cx, apex), (x1, wt)])
    cv.part(body, wall_fill(st, x0, x1, wt, ground))
    D = st["depth"]
    ex0, ex1, et = x0 - 3, x1 + 3, wt + 2       # eave corners (front)
    at = apex - 3                               # front ridge point
    roof = cv.poly([(ex0, et), (ex0, et - D), (cx - 1, at - D), (cx, at - D), (ex1, et - D), (ex1, et),
                    (cx, at), (cx - 1, at)])
    roof -= body
    roof = {p for p in roof if p[1] <= et}
    lb, ll, rb, rl, rlight = ROOFS[st["roof"]]
    fascia = "white_warm" if st["paint"] else "brown_light"
    k = (at - et) / (cx - 1 - ex0)               # front edge slope (negative)

    def front_y(x):
        return et + k * (x - ex0) if x < cx else et + k * (ex1 - x)

    def f(x, y):
        d = front_y(x) - y                       # px above the front (gable) edge
        if d < 1.5 and (x, y + 1) not in roof:
            return "outline" if d < 0.5 else fascia
        if d < 2.5:
            return fascia
        if x == cx - 1:
            return rlight                        # ridge cap
        if x == cx:
            return rl
        left = x < cx
        base, line = (lb, ll) if left else (rb, rl)
        row, sub = divmod(int(d - 2.5), 3)
        if sub == 2:
            return line                          # shingle course
        if sub == 1 and (x + row * 3) % 6 == 0:
            return line                          # staggered butt joints
        return base
    cv.part(roof, f)
    inner = set()
    if trim and st["paint"]:
        for y in range(wt + 3, ground):  # white corner boards
            cv.put(x0 + 1, y, "white_warm")
            cv.put(x1 - 1, y, "stone_pale")
    return x0, x1, wt, apex


def barn_door(cv, st, cx, ground=79):
    dw = st["door"]
    dh = 14 if dw == 12 else 18
    x0, x1, y0 = cx - dw // 2, cx + dw // 2 - 1, ground - dh + 1
    frame = cv.rect(x0 - 1, y0 - 1, x1 + 1, ground)
    trim = "brown_dark" if not st["paint"] else "white_warm"
    cv.part(frame, trim)
    panel = cv.rect(x0, y0, x1, ground)
    cv.part(panel, lambda x, y: "brown_dark" if (x - x0) % 3 == 0 else "brown_mid", outer=None)
    if dw == 12:  # single plank door with a Z brace
        for x in range(x0, x1 + 1):
            cv.put(x, y0 + 2, "brown_light"); cv.put(x, ground - 2, "brown_light")
        for i in range(dh - 5):
            cv.put(x1 - (i * (dw - 1)) // (dh - 5), y0 + 3 + i, "brown_light")
        cv.put(x0 + 2, y0 + 7, "yellow")
    else:  # double doors, white X braces, centre seam, two handles
        half = [(x0, cx - 1), (cx, x1)]
        for (a, b) in half:
            n = b - a
            for i in range(dh):
                y = y0 + i
                xa = a + round(i * n / (dh - 1))
                xb = b - round(i * n / (dh - 1))
                for xx in (xa, xb):
                    cv.put(xx, y, "white_warm" if y < ground - 1 else "stone_pale")
            for x in range(a, b + 1):
                cv.put(x, y0, "white_warm")
                cv.put(x, ground, "stone_pale")
                cv.put(x, y0 + dh // 2, "white_warm")
        for y in range(y0, ground + 1):
            cv.put(cx - 1, y, "outline")
        cv.put(cx - 2, y0 + dh // 2 + 2, "yellow")
        cv.put(cx + 1, y0 + dh // 2 + 2, "yellow")
    return (x0, y0, dw, dh)


def loft_door(cv, st, cx, apex, wt):
    big = st["loft"] == 2
    w, h = (12, 9) if big else (10, 7)
    x0, y0 = cx - w // 2, apex + (6 if big else 5)
    cv.part(cv.rect(x0 - 1, y0 - 1, x0 + w, y0 + h), "white_warm")
    cv.part(cv.rect(x0, y0, x0 + w - 1, y0 + h - 1), lambda x, y: "brown_dark" if y < y0 + 2 else "outline",
            outer=None)
    for x in range(x0, x0 + w):  # hay spilling over the sill
        k = (x * 5) % 7
        cv.put(x, y0 + h - 1, "yellow" if k < 5 else "yellow_pale")
        if k < 3:
            cv.put(x, y0 + h - 2, "yellow")
        if k == 1:
            cv.put(x, y0 + h, "yellow_pale")
    if big:  # hay hoist beam with a pulley
        for x in range(cx - 1, cx + 1):
            for y in range(y0 - 4, y0 - 1):
                cv.put(x, y, "brown_mid")
            cv.put(x, y0 - 5, "outline")
        cv.put(cx - 2, y0 - 4, "outline"); cv.put(cx + 1, y0 - 4, "outline")
        cv.put(cx - 2, y0 - 3, "outline"); cv.put(cx + 1, y0 - 3, "outline")


def window(cv, x0, y0, box=False):
    cv.part(cv.rect(x0, y0, x0 + 6, y0 + 6), "white_warm")
    glass = cv.rect(x0 + 1, y0 + 1, x0 + 5, y0 + 5)
    cv.part(glass, lambda x, y: "white_warm" if x == x0 + 3 or y == y0 + 3 else
            ("blue_light" if (x, y) in ((x0 + 1, y0 + 1), (x0 + 4, y0 + 4)) else
             ("blue_dark" if y == y0 + 1 else "blue")), outer=None)
    if box:  # flower box
        cv.part(cv.rect(x0 - 1, y0 + 8, x0 + 7, y0 + 9), "brown_mid")
        for i, col in enumerate(("pink", "green", "yellow", "green", "pink", "green", "yellow", "green", "pink")):
            cv.put(x0 - 1 + i, y0 + 7, col)


def silo(cv):
    x0, x1, top, ground = 64, 78, 12, 79
    body = cv.rect(x0, top + 6, x1, ground)

    def f(x, y):
        if (y - top) % 10 == 0:
            return "stone_dark"
        k = (x - x0) / (x1 - x0)
        return "stone_pale" if k < 0.2 else ("stone_light" if k < 0.6 else ("stone" if k < 0.9 else "stone_dark"))
    cv.part(body, f)
    dome = cv.ellipse(x0 - 1, top, x1 + 1, top + 13)
    dome = {p for p in dome if p[1] <= top + 7}
    cv.part(dome, lambda x, y: "ember_deep" if (x < 70 and y < top + 4) else
            ("red_dark" if y >= top + 6 or x > 75 else "red"))
    cv.put(71, top - 1, "outline"); cv.put(71, top - 2, "stone_dark")
    for y in range(top + 12, ground - 2, 4):  # ladder
        cv.put(74, y, "outline"); cv.put(76, y, "outline"); cv.put(75, y, "stone_dark")


def weathervane(cv, cx, base):
    """Rooster vane standing on the ridge; pole foot at (cx, base)."""
    for y in range(base - 6, base + 1):
        cv.put(cx, y, "stone_dark")
    cv.put(cx - 1, base, "outline"); cv.put(cx + 1, base, "outline")
    for x in range(cx - 4, cx + 5):
        cv.put(x, base - 4, "stone_dark")
    cv.put(cx + 5, base - 4, "outline"); cv.put(cx + 4, base - 5, "outline"); cv.put(cx + 4, base - 3, "outline")
    cv.put(cx - 5, base - 5, "outline"); cv.put(cx - 5, base - 3, "outline")
    rooster = [".oo...", "oyro..", ".oyyoo", ".oyyyo", "..ooo."]
    for y, row in enumerate(rooster):
        for x, ch in enumerate(row):
            if ch != ".":
                cv.put(cx - 2 + x, base - 11 + y, {"o": "outline", "y": "yellow", "r": "red"}[ch])


def lean_to(cv, st, x0, x1, wall=16, ground=79):
    wt = ground - wall + 1
    body = cv.rect(x0, wt, x1, ground)
    cv.part(body, wall_fill(st, x0, x1, wt, ground))
    roof = cv.poly([(x0 - 2, wt + 1), (x1 + 2, wt - 6), (x1 + 2, wt - 3), (x0 - 2, wt + 3)])
    cv.part(roof, shingles(st, roof, wt - 6))
    window(cv, x0 + 3, wt + 4, box=st["vane"] == 1)


def foundation(cv, x0, x1, ground=79):
    for x in range(x0, x1 + 1):
        for y in (ground - 2, ground - 1, ground):
            mortar = (y == ground - 2 and x % 5 == 0) or (y == ground and (x + 2) % 5 == 0)
            cv.put(x, y, "stone_dark" if mortar or x in (x0, x1) else
                   ("stone_light" if y == ground - 2 else "stone"))


def barn_stage(i):
    st = STAGES[i]
    cv = Canvas(BF, BF)
    cx = BF // 2
    if st["silo"]:
        silo(cv)
    if st["wing"]:
        wx0 = 2 if st["w"] == 56 else 4
        lean_to(cv, st, wx0, cx - st["w"] // 2, wall=16 if st["w"] == 48 else 18)
    x0, x1, wt, apex = gable_box(cv, st, cx, st["w"], st["wall"])
    if st["found"]:
        foundation(cv, x0, x1)
    if st["loft"]:
        loft_door(cv, st, cx, apex, wt)
    if st["win"]:
        window(cv, x0 + 6, wt + 6, box=st["vane"] == 1)
        window(cv, x1 - 11, wt + 6, box=st["vane"] == 1)
    door = barn_door(cv, st, cx)
    if st["vane"]:
        weathervane(cv, cx, apex - 3 - st["depth"] + 5)
    if i == 0:  # a patched hole and a leaning plank on the old shed
        for x, y in ((x0 + 4, wt + 6), (x0 + 5, wt + 6), (x0 + 4, wt + 7)):
            cv.put(x, y, "outline")
    if i >= 1:  # lantern by the door
        cv.put(cx + 10, wt + 4, "outline"); cv.put(cx + 10, wt + 5, "ember_amber")
        cv.put(cx + 10, wt + 6, "outline")
    return cv.image(), dict(x0=x0, x1=x1, wall_top=wt, apex=apex, door=door)


def build_barn():
    sheet = new(BF * 5, BF)
    info = []
    for i in range(5):
        img, geo = barn_stage(i)
        sheet.alpha_composite(img, (i * BF, 0))
        info.append(geo)
    return sheet, info


# ==========================================================================

OUT = {
    "pasture_tiles": ("assets/tilesets/pasture_tiles.png", (128, 48)),
    "habitat_woodland": ("assets/sprites/habitat_woodland.png", (64, 64)),
    "habitat_woodland_ground": ("assets/sprites/habitat_woodland_ground.png", (64, 64)),
    "habitat_woodland_objects": ("assets/sprites/habitat_woodland_objects.png", (64, 64)),
    "barn_stages": ("assets/sprites/barn_stages.png", (400, 80)),
}


def validate(name, img, size):
    assert img.size == size, (name, img.size)
    pal = set(RGBA)
    d = img.load()
    for px in (d[x, y] for y in range(img.height) for x in range(img.width)):
        assert px[3] in (0, 255), (name, "partial alpha", px)
        assert px[3] == 0 or px in pal, (name, "off-palette", px)


def build_all():
    full, ground, objects = build_habitat()
    barn, _ = build_barn()
    return {"pasture_tiles": build_pasture(), "habitat_woodland": full,
            "habitat_woodland_ground": ground, "habitat_woodland_objects": objects,
            "barn_stages": barn}


def main():
    outputs = build_all()
    for k, img in outputs.items():
        rel, size = OUT[k]
        validate(k, img, size)
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
        print("wrote", rel, img.size)
    for i, g in enumerate(build_barn()[1]):
        print(f"barn stage {i}: walls x {g['x0']}-{g['x1']}, wall top y {g['wall_top']}, "
              f"door rect {g['door']}")
    if "--preview" in sys.argv:
        import preview_slice3_buildings
        preview_slice3_buildings.preview(sys.argv[sys.argv.index("--preview") + 1], outputs)


if __name__ == "__main__":
    main()
