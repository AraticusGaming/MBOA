"""Slice 3 Woodland creatures (procedural, pixel-level, reproducible).

Outputs (relative to repo root), all in the Cinderkin layout:
  assets/sprites/moss_bun.png                 Critter  32x32 frames, 8 cols x 4 rows (256x128)
  assets/sprites/blue_jay.png                 Bird     32x32 frames, 8 cols x 4 rows (256x128)
  assets/sprites/bramble_cub.png              Beast    32x32 frames, 8 cols x 4 rows (256x128)
  assets/portraits/<name>_portrait.png        64x64 bust portraits, transparent background

Rows: 0 down, 1 left, 2 right (mirror of left), 3 up. Cols 0-3 idle, 4-7 walk/move.
Feet on y = 31 when grounded; pivot bottom-center (16, 32).
Every opaque pixel comes from tools/art/palette.py (indices 0-41, nothing added); alpha is 0/255.
Usage:  python3 tools/art/gen_slice3_creatures.py [--preview DIR]
"""
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from palette import RGBA, TRANSPARENT  # noqa: E402
from gen_cinderkin import Canvas, depth, shaded, banded  # noqa: E402

DIRS = ("down", "left", "right", "up")
IDLE_BOB = [0, 0, 1, 1]


def lifted(cv, lift):
    """Render a canvas and move it up by `lift` px (whole body leaves the ground: hops)."""
    img = cv.image()
    if not lift:
        return img
    assert all(y >= lift for (_, y) in cv.px), "hop clips the frame top"
    out = Image.new("RGBA", img.size, TRANSPARENT)
    out.alpha_composite(img, (0, -lift))
    return out


def bead_eye(cv, x, y, h=3, blink=False, col="outline", hl="white_warm"):
    """Small glossy bead eye (2px wide): reads as Stardew-like, unlike Cinderkin's big amber eyes."""
    if blink:
        cv.put(x, y + h - 1, col); cv.put(x + 1, y + h - 1, col)
        return
    for yy in range(y, y + h):
        cv.put(x, yy, col); cv.put(x + 1, yy, col)
    cv.put(x, y, hl)


def build_sheet(front, side, idle, walk):
    """front(phase, b, pose, back) / side(phase, b, pose) -> Canvas; idle/walk: [(b, pose, lift)]."""
    sheet = Image.new("RGBA", (256, 128), TRANSPARENT)
    for r, d in enumerate(DIRS):
        frames = []
        for i, (b, pose, lift) in enumerate(list(idle) + list(walk)):
            ph = i % 4
            if d in ("down", "up"):
                cv = front(ph, b, pose, d == "up")
            else:
                cv = side(ph, b, pose)
            img = lifted(cv, lift)
            if d == "right":
                img = img.transpose(Image.FLIP_LEFT_RIGHT)
            frames.append(img)
        for i, f in enumerate(frames):
            sheet.alpha_composite(f, (i * 32, r * 32))
    return sheet


# ==========================================================================
# Moss Bun (Critter): lop-eared forest rabbit with a moss cap and a sprout
# ==========================================================================
BUN = ("tan", "sand", "brown_light")          # fur base, light, dark
BELLY = ("cream", "sand")
MOSS = ("moss", "green_light", "green_forest")


def moss_fill(mask, seed=0):
    def f(x, y):
        if (x, y + 1) not in mask:
            return MOSS[2]
        if (x, y - 1) not in mask or (x * 7 + y * 3 + seed) % 11 == 0:
            return MOSS[1]
        return MOSS[0]
    return f


def sprout(cv, x, y, sway=0):
    """Two-leaf sprout growing out of the moss cap, stem base at (x, y)."""
    cv.put(x, y, "green_forest"); cv.put(x, y - 1, "green_forest")
    lx = x + sway
    for p, col in (((lx - 1, y - 2), "green_grass"), ((lx - 2, y - 3), "green_light"),
                   ((lx - 1, y - 3), "green_grass"), ((lx + 1, y - 2), "green_grass"),
                   ((lx + 1, y - 3), "green_light"), ((lx + 2, y - 3), "green_light"),
                   ((lx, y - 2), "green_forest")):
        cv.put(*p, col)
    for p in ((lx - 3, y - 3), (lx - 2, y - 4), (lx - 1, y - 4), (lx + 1, y - 4), (lx + 2, y - 4),
              (lx + 3, y - 3), (lx - 2, y - 2), (lx + 2, y - 2)):
        if p not in cv.px:
            cv.put(*p, "green_dark")


def bun_front(phase, b, pose, back):
    cv = Canvas(32, 32)
    tuck = pose == "tuck"
    stretch = pose == "stretch"
    ear_sw = [0, 0, 1, 1][phase] if pose is None else (-1 if stretch else 1)
    # hind feet
    if not back:
        for fx in (8, 19):
            fm = cv.ellipse(fx, 28 - tuck, fx + 4, 31 - tuck)
            cv.part(fm, lambda x, y: BELLY[1] if y >= 30 - tuck else BELLY[0], outer="outline", inner="outline")
    # body
    body = cv.ellipse(9, 17 + b, 22, 31 - (2 if tuck else 0))
    cv.part(body, shaded(body, *BUN), outer="outline", inner="outline")
    if not back:
        bl = cv.ellipse(12, 20 + b, 19, 30 - (2 if tuck else 0)) & body
        cv.part(bl, lambda x, y: BELLY[1] if (x, y + 1) not in bl else BELLY[0], outer=None)
        for px in (12, 18):   # front paws tucked against the chest
            cv.put(px, 24 + b, BELLY[0]); cv.put(px + 1, 24 + b, BELLY[0])
            cv.put(px, 25 + b, "brown_light"); cv.put(px + 1, 25 + b, "brown_light")
    else:
        moss = cv.ellipse(11, 18 + b, 20, 25 + b) & body
        cv.part(moss, moss_fill(moss, 1), outer=None)
        tail = cv.ellipse(13, 24 + b, 18, 29 + b)
        cv.part(tail, lambda x, y: "white_warm" if y < 27 + b else "cream", outer="outline", inner="stone_pale")
        for fx in (9, 19):
            fm = cv.ellipse(fx, 29 - tuck, fx + 3, 31 - tuck)
            cv.part(fm, BELLY[1], outer="outline", inner="outline")
    # head
    head = cv.ellipse(7, 6 + b, 24, 21 + b)
    cv.part(head, shaded(head, *BUN), outer="outline", inner=BUN[2])
    if not back:
        mz = cv.ellipse(11, 14 + b, 20, 21 + b) & head
        cv.part(mz, lambda x, y: BELLY[1] if (x, y + 1) not in mz else BELLY[0], outer=None)
        bead_eye(cv, 10, 12 + b, 3, blink=phase == 3 and pose is None)
        bead_eye(cv, 20, 12 + b, 3, blink=phase == 3 and pose is None)
        nose = 16 + b + (1 if phase == 1 and pose is None else 0)   # nose twitch
        cv.put(15, nose, "pink"); cv.put(16, nose, "pink")
        cv.put(15, nose + 1, "brown_mid"); cv.put(16, nose + 1, "brown_mid")
        cv.put(14, nose + 2, "brown_mid"); cv.put(17, nose + 2, "brown_mid")
        cv.put(9, 16 + b, "pink"); cv.put(22, 16 + b, "pink")
    # lop ears hanging down both sides of the face, moss tips
    for s in (0, 1):
        def X(x):
            return x if s == 0 else 31 - x
        sw = ear_sw if s == 0 else -ear_sw
        e = cv.stroke([(X(10), 8 + b), (X(6.5 - sw * 0.5), 12 + b), (X(5.5 - sw), 19 + b)], 2.6, 2.1)
        tip = {p for p in e if p[1] >= 18 + b}
        cv.part(e, lambda x, y: MOSS[0] if (x, y) in tip and (x, y + 1) in e else
                (MOSS[2] if (x, y) in tip else shaded(e, *BUN)(x, y)), outer="outline", inner="outline")
        if not back:
            for yy in range(12 + b, 17 + b):   # inner ear line
                cv.put(X(6), yy, "skin_shadow")
    # moss cap on the crown + sprout
    cap = cv.ellipse(10, 5 + b, 21, 10 + b)
    cv.part(cap, moss_fill(cap), outer="green_dark", inner="green_dark")
    sprout(cv, 15, 5 + b, [0, 0, 1, 0][phase] if pose is None else (1 if stretch else -1 if tuck else 0))
    return cv


def bun_side(phase, b, pose):
    cv = Canvas(32, 32)
    tuck = pose == "tuck"
    stretch = pose == "stretch"
    # cottontail (behind body, right)
    tail = cv.ellipse(22, 19 + b, 27, 24 + b)
    cv.part(tail, lambda x, y: "white_warm" if y < 22 + b else "cream", outer="outline")
    # far feet
    if not tuck:
        fm = cv.ellipse(5 if not stretch else 3, 29, 8 if not stretch else 6, 31)
        cv.part(fm, BELLY[1], outer="outline")
    # body
    body = cv.ellipse(9, 17 + b, 25, 31 - (2 if tuck else 0))
    cv.part(body, shaded(body, *BUN), outer="outline", inner="outline")
    moss = cv.ellipse(14, 16 + b, 23, 21 + b) & body
    cv.part(moss, moss_fill(moss, 2), outer=None)
    bl = cv.ellipse(9, 23 + b, 15, 30) & body
    cv.part(bl, BELLY[0], outer=None)
    # big hind foot (stretched back on take-off, tucked in the air)
    if stretch:
        hf = cv.ellipse(20, 28, 28, 31)
    elif tuck:
        hf = cv.ellipse(15, 26, 22, 29)
    else:
        hf = cv.ellipse(15, 28, 23, 31)
    cv.part(hf, lambda x, y: BELLY[1] if (x, y + 1) not in hf else BELLY[0], outer="outline", inner="outline")
    # front paw
    fp = cv.ellipse(9 if not stretch else 6, 28 - tuck * 2, 12 if not stretch else 9, 31 - tuck * 2)
    cv.part(fp, BELLY[0], outer="outline", inner="outline")
    # head
    head = cv.ellipse(3, 7 + b, 18, 21 + b)
    cv.part(head, shaded(head, *BUN), outer="outline", inner="outline")
    mz = cv.ellipse(2, 14 + b, 10, 21 + b) & head
    cv.part(mz, lambda x, y: BELLY[1] if (x, y + 1) not in mz else BELLY[0], outer=None)
    bead_eye(cv, 6, 12 + b, 3, blink=phase == 3 and pose is None)
    ny = 16 + b + (1 if phase == 1 and pose is None else 0)
    cv.put(3, ny, "pink"); cv.put(3, ny + 1, "brown_mid"); cv.put(4, ny + 2, "brown_mid")
    cv.put(9, 17 + b, "pink")
    # lop ear hanging down behind the cheek
    sw = [0, 0, 1, 1][phase] if pose is None else (2 if stretch else -1)
    e = cv.stroke([(11, 8 + b), (14 + sw * 0.5, 12 + b), (15 + sw, 19 + b)], 2.7, 2.2)
    tip = {p for p in e if p[1] >= 18 + b}
    cv.part(e, lambda x, y: MOSS[0] if (x, y) in tip and (x, y + 1) in e else
            (MOSS[2] if (x, y) in tip else shaded(e, *BUN)(x, y)), outer="outline", inner="outline")
    cap = cv.ellipse(6, 5 + b, 15, 10 + b)
    cv.part(cap, moss_fill(cap), outer="green_dark", inner="green_dark")
    sprout(cv, 10, 5 + b, [0, 0, 1, 0][phase] if pose is None else (1 if stretch else 0))
    return cv


BUN_IDLE = [(b, None, 0) for b in IDLE_BOB]
# hop: crouch -> push off (stretched, 2 px up) -> airborne (tucked, 3 px up) -> land
BUN_WALK = [(1, None, 0), (1, "stretch", 2), (2, "tuck", 3), (1, None, 1)]


# ==========================================================================
# Blue Jay (Bird): round crested songbird, blue back, white face, black necklace
# ==========================================================================
JAY = ("blue", "blue_light", "blue_dark")
WHITE = ("white_warm", "stone_pale")


def wing_bars(cv, mask, step=3, x0=0):
    """Black bars + white tips on jay wing/tail feathers."""
    ys = sorted({y for _, y in mask})
    for y in ys[1::step]:
        for x in range(32):
            if (x, y) in mask and (x - 1, y) in mask and (x + 1, y) in mask:
                cv.put(x, y, "outline")


JAY_DROP = 4   # the jay is drawn 4 px lower than the full frame: smaller bird, room to hop


def jay_front(phase, b0, pose, back):
    cv = Canvas(32, 32)
    b = b0 + JAY_DROP
    flap = {None: 0, "up": 2, "out": 1}.get(pose, 0)
    # tail fan below / behind
    tl = cv.poly([(13, 22 + b), (18, 22 + b), (20, 31), (11, 31)])
    if back:
        cv.part(tl, lambda x, y: JAY[2] if y % 3 == 0 else JAY[0], outer="outline")
        for x in range(12, 20):
            cv.put(x, 30, "white_warm")
    # legs
    if pose is None:
        for lx in (13, 18):
            cv.put(lx, 29, "stone_dark"); cv.put(lx, 30, "stone_dark")
            cv.put(lx - 1, 31, "stone_dark"); cv.put(lx, 31, "stone_dark"); cv.put(lx + 1, 31, "stone_dark")
    else:
        for lx in (13, 18):   # tucked legs while hopping
            cv.put(lx, 29, "stone_dark"); cv.put(lx + (1 if lx < 16 else -1), 30, "stone_dark")
    # wings (raised and spread when fluttering)
    for s in (0, 1):
        def X(x):
            return x if s == 0 else 31 - x
        if flap == 0:
            pts = [(X(10), 14 + b), (X(7), 17 + b), (X(7), 25 + b), (X(10), 27 + b)]
        elif flap == 1:
            pts = [(X(10), 14 + b), (X(3), 15 + b), (X(1), 21 + b), (X(5), 23 + b), (X(10), 25 + b)]
        else:
            pts = [(X(10), 16 + b), (X(4), 10 + b), (X(0), 7 + b), (X(2), 14 + b), (X(6), 20 + b), (X(10), 23 + b)]
        wg = cv.poly(pts)
        cv.part(wg, shaded(wg, *JAY), outer="outline", inner="outline")
        wing_bars(cv, wg, 3)
        tips = sorted(wg, key=lambda p: (-p[1], p[0]))[:3]
        for p in tips:
            cv.put(*p, "white_warm")
    # body
    body = cv.ellipse(9, 13 + b, 22, 29)
    cv.part(body, shaded(body, *JAY), outer="outline", inner="outline")
    if not back:
        bl = cv.ellipse(11, 17 + b, 20, 29) & body
        cv.part(bl, lambda x, y: WHITE[1] if (x, y + 1) not in bl or x >= 19 else WHITE[0], outer=None)
    # crest: a pointed tuft rising from behind the crown, sways in idle
    cs = [0, 0, 1, 1][phase] if pose is None else (-1 if flap == 2 else 0)
    cr = cv.poly([(13, 8 + b), (16 + cs, 0 + b + (1 if b0 else 0)), (17 + cs, 0 + b + (1 if b0 else 0)),
                  (19, 8 + b)])
    cv.part(cr, lambda x, y: JAY[1] if x <= 15 + cs else JAY[0], outer="outline", inner=JAY[2])
    # head
    head = cv.ellipse(9, 5 + b, 22, 18 + b)
    cv.part(head, shaded(head, *JAY), outer="outline", inner=JAY[2])
    if not back:
        face = cv.ellipse(11, 10 + b, 20, 18 + b) & head
        cv.part(face, WHITE[0], outer=None)
        # black necklace curving under the face, eye lines
        for x, y in ((10, 15), (11, 17), (12, 18), (13, 19), (14, 19), (15, 19), (16, 19), (17, 19),
                     (18, 19), (19, 18), (20, 17), (21, 15), (10, 16), (21, 16)):
            cv.put(x, y + b, "outline")
        bead_eye(cv, 12, 11 + b, 2, blink=phase == 2 and pose is None)
        bead_eye(cv, 18, 11 + b, 2, blink=phase == 2 and pose is None)
        cv.put(11, 11 + b, "outline"); cv.put(20, 11 + b, "outline")
        # bill
        cv.put(15, 13 + b, "stone_dark"); cv.put(16, 13 + b, "stone_dark")
        cv.put(15, 14 + b, "outline"); cv.put(16, 14 + b, "stone")
        cv.put(13, 15 + b, "pink"); cv.put(18, 15 + b, "pink")
    else:
        for y in (9, 12):
            for x in range(13, 19):
                if (x, y + b) in head:
                    cv.put(x, y + b, JAY[2])
        for x in range(12, 20):   # wing tips cross over the back
            if (x, 25 + b) in body:
                cv.put(x, 25 + b, "outline")
    return cv


def jay_side(phase, b0, pose):
    cv = Canvas(32, 32)
    b = b0 + JAY_DROP
    flap = {None: 0, "up": 2, "out": 1}.get(pose, 0)
    tf = [0, 0, -1, 0][phase] if pose is None else (1 if flap == 2 else 0)   # tail flick
    tail = cv.poly([(19, 21 + b), (30, 17 + b + tf), (31, 20 + b + tf), (21, 26 + b)])
    cv.part(tail, lambda x, y: JAY[2] if (x, y + 1) not in tail else JAY[0], outer="outline")
    for x in range(23, 31, 3):
        for y in range(14, 28):
            if (x, y) in tail:
                cv.put(x, y, "outline")
    cv.put(30, 18 + b + tf, "white_warm"); cv.put(30, 19 + b + tf, "white_warm")
    # legs
    for lx in (13, 16):
        if pose is None:
            cv.put(lx, 28, "stone_dark"); cv.put(lx, 29, "stone_dark"); cv.put(lx, 30, "stone_dark")
            cv.put(lx - 1, 31, "stone_dark"); cv.put(lx, 31, "stone_dark"); cv.put(lx - 2, 31, "stone_dark")
        else:
            cv.put(lx, 28, "stone_dark"); cv.put(lx + 1, 29, "stone_dark")
    body = cv.ellipse(7, 13 + b, 23, 28)
    cv.part(body, shaded(body, *JAY), outer="outline", inner="outline")
    bl = cv.ellipse(6, 18 + b, 15, 28) & body
    cv.part(bl, lambda x, y: WHITE[1] if (x, y + 1) not in bl else WHITE[0], outer=None)
    # wing
    if flap == 0:
        pts = [(11, 16 + b), (20, 16 + b), (25, 22 + b), (18, 25 + b), (12, 22 + b)]
    elif flap == 1:
        pts = [(11, 16 + b), (18, 11 + b), (25, 12 + b), (22, 18 + b), (14, 21 + b)]
    else:
        pts = [(11, 16 + b), (14, 7 + b), (20, 3 + b), (21, 9 + b), (16, 18 + b)]
    wg = cv.poly(pts)
    cv.part(wg, shaded(wg, *JAY), outer="outline", inner="outline")
    wing_bars(cv, wg, 3)
    tips = sorted(wg, key=lambda p: (p[1] if flap == 2 else -p[0], p[0]))[:2]
    for p in tips:
        cv.put(*p, "white_warm")
    # crest swept up and back from behind the crown
    cs = [0, 0, 1, 1][phase] if pose is None else (1 if flap else 0)
    cr = cv.poly([(8, 8 + b), (15 + cs, 0 + b + (1 if b0 else 0)), (16 + cs, 2 + b), (15, 9 + b)])
    cv.part(cr, shaded(cr, *JAY), outer="outline", inner=JAY[2])
    # head
    head = cv.ellipse(4, 5 + b, 17, 18 + b)
    cv.part(head, shaded(head, *JAY), outer="outline", inner="outline")
    face = cv.ellipse(3, 10 + b, 12, 18 + b) & head
    cv.part(face, WHITE[0], outer=None)
    for x, y in ((3, 15), (4, 17), (5, 18), (6, 19), (7, 19), (8, 19), (9, 18), (10, 17), (11, 15),
                 (11, 16), (12, 14)):
        cv.put(x, y + b, "outline")
    bead_eye(cv, 6, 10 + b, 2, blink=phase == 2 and pose is None)
    cv.put(8, 10 + b, "outline"); cv.put(9, 10 + b, "outline")
    # bill pointing left
    for x, y, col in ((3, 12, "stone_dark"), (2, 12, "stone_dark"), (1, 13, "outline"),
                      (2, 13, "stone"), (3, 13, "stone_dark")):
        cv.put(x, y + b, col)
    cv.put(8, 15 + b, "pink")
    return cv


JAY_IDLE = [(b, None, 0) for b in IDLE_BOB]
# hop-flutter: crouch -> wings out, 2 px up -> wings high, 3 px up -> wings out, landing
JAY_WALK = [(1, None, 0), (0, "out", 2), (0, "up", 3), (0, "out", 1)]


# ==========================================================================
# Bramble Cub (Beast): chunky bear cub, cream chest crescent, bramble crown
# ==========================================================================
CUB = ("brown_mid", "brown_light", "brown")
CUB_D = "brown_dark"
MUZ = ("tan", "sand", "brown_light")


def bramble(cv, pts, berries, sway=0):
    """Leafy bramble sprig: leaves (green) + red berries, along given points."""
    for i, (x, y) in enumerate(pts):
        lf = cv.ellipse(x - 1, y - 1, x + 1, y + 1)
        cv.part(lf, lambda xx, yy: "green_grass" if yy < y else "green", outer="green_dark", inner="green_dark")
    for (x, y) in berries:
        x += sway
        cv.put(x, y, "red"); cv.put(x + 1, y, "red"); cv.put(x, y + 1, "red_dark"); cv.put(x + 1, y + 1, "red_dark")
        cv.put(x, y, "pink")


def cub_front(phase, b, pose, back):
    cv = Canvas(32, 32)
    step = pose  # None, "L", "R"
    # back paws peeking out under the belly
    if not back:
        for fx in (6, 22):
            pm = cv.ellipse(fx, 27, fx + 4, 31)
            cv.part(pm, CUB[2], outer="outline")
    body = cv.ellipse(4, 15 + b, 27, 31)
    cv.part(body, shaded(body, CUB[0], CUB[1], CUB[2]), outer="outline", inner="outline")
    if back:
        tl = cv.ellipse(14, 25 + b, 17, 28 + b)
        cv.part(tl, CUB[1], outer="outline", inner="outline")
        for fx in (6, 21):
            pm = cv.ellipse(fx, 28, fx + 5, 31)
            cv.part(pm, CUB[2], outer="outline", inner="outline")
            cv.put(fx + 1, 31, MUZ[0]); cv.put(fx + 4, 31, MUZ[0])
    else:
        # cream crescent on the chest
        for x, y in ((11, 21), (12, 22), (13, 22), (14, 23), (15, 23), (16, 23), (17, 23), (18, 22),
                     (19, 22), (20, 21), (13, 23), (18, 23)):
            cv.put(x, y + b, "cream")
        # front paws (step lifts one)
        for fx, side in ((8, "L"), (19, "R")):
            lift = 2 if step == side else 0
            pm = cv.ellipse(fx, 26 - lift, fx + 5, 31 - lift)
            cv.part(pm, shaded(pm, CUB[0], CUB[1], CUB[2]), outer="outline", inner="outline")
            for k in (1, 3):   # claws/toe lines
                cv.put(fx + k + (1 if k == 3 else 0), 31 - lift, CUB_D)
            cv.put(fx + 2, 31 - lift, MUZ[0]); cv.put(fx + 3, 31 - lift, MUZ[0])
    # ears
    ef = [0, 0, 0, 1][phase] if step is None else 0
    for s in (0, 1):
        def X(x):
            return x if s == 0 else 31 - x
        x0, x1 = sorted((X(2), X(10)))
        em = cv.ellipse(x0, 1 + b + (ef if s == 1 else 0), x1, 9 + b)
        cv.part(em, shaded(em, CUB[0], CUB[1], CUB[2]), outer="outline", inner="outline")
        if not back:
            i0, i1 = sorted((X(4), X(8)))
            im = cv.ellipse(i0, 3 + b + (ef if s == 1 else 0), i1, 8 + b)
            cv.part(im, MUZ[0], outer=None)
    head = cv.ellipse(4, 3 + b, 27, 23 + b)
    cv.part(head, shaded(head, CUB[0], CUB[1], CUB[2]), outer="outline", inner=CUB[2])
    if not back:
        mz = cv.ellipse(10, 13 + b, 21, 22 + b)
        cv.part(mz, lambda x, y: MUZ[2] if (x, y + 1) not in mz else (MUZ[1] if y < 15 + b else MUZ[0]),
                outer=CUB[2], inner=CUB[2])
        for x, y in ((14, 15), (15, 15), (16, 15), (17, 15), (15, 16), (16, 16)):
            cv.put(x, y + b, "outline")
        cv.put(15, 15 + b, "stone")
        for x, y in ((15, 17), (16, 17), (14, 18), (17, 18), (15, 19), (16, 19)):
            cv.put(x, y + b, CUB_D if y < 19 else "pink")
        bl = phase == 3 and step is None
        bead_eye(cv, 9, 11 + b, 3, blink=bl)
        bead_eye(cv, 21, 11 + b, 3, blink=bl)
        cv.put(7, 16 + b, "pink"); cv.put(8, 16 + b, "pink"); cv.put(23, 16 + b, "pink"); cv.put(24, 16 + b, "pink")
    # bramble crown across the top of the head
    sw = [0, 0, 0, 0][phase]
    bramble(cv, [(9, 5 + b), (13, 3 + b), (18, 3 + b), (22, 5 + b)], [(15, 2 + b), (11, 4 + b)], sw)
    return cv


def cub_side(phase, b, pose):
    cv = Canvas(32, 32)
    step = pose  # None, 1, 2 opposite strides
    lx = {None: (0, 0), 1: (-2, 2), 2: (2, -2)}[step]
    # far legs (darker)
    for fx in (8 + lx[1], 21 + lx[0]):
        lm = cv.rect(fx, 24, fx + 4, 31)
        cv.part(lm, CUB[2], outer="outline")
        cv.put(fx + 1, 31, CUB_D); cv.put(fx + 3, 31, CUB_D)
    # stubby tail
    tl = cv.ellipse(26, 14 + b, 30, 18 + b)
    cv.part(tl, CUB[1], outer="outline")
    body = cv.ellipse(6, 11 + b, 29, 28 + b)
    cv.part(body, shaded(body, CUB[0], CUB[1], CUB[2]), outer="outline", inner="outline")
    # shoulder hump highlight + fur tufts
    for x, y in ((14, 12), (15, 12), (16, 12), (20, 12), (21, 12)):
        if (x, y + b) in body:
            cv.put(x, y + b, CUB[1])
    # near legs
    for fx in (10 + lx[0], 22 + lx[1]):
        lm = cv.rect(fx, 23 + b, fx + 4, 31)
        lm |= cv.ellipse(fx - 1, 21 + b, fx + 5, 27 + b)
        cv.part(lm, shaded(lm, CUB[0], CUB[1], CUB[2]), outer="outline", inner="outline")
        cv.put(fx, 31, MUZ[0]); cv.put(fx + 1, 31, CUB_D); cv.put(fx + 2, 31, MUZ[0]); cv.put(fx + 3, 31, CUB_D)
    # head (big, low, leading)
    ear = cv.ellipse(9, 2 + b + ([0, 0, 0, 1][phase] if step is None else 0), 15, 8 + b)
    cv.part(ear, shaded(ear, CUB[0], CUB[1], CUB[2]), outer="outline", inner="outline")
    ie = cv.ellipse(11, 4 + b, 13, 7 + b)
    cv.part(ie, MUZ[0], outer=None)
    head = cv.ellipse(2, 4 + b, 19, 22 + b)
    cv.part(head, shaded(head, CUB[0], CUB[1], CUB[2]), outer="outline", inner="outline")
    mz = cv.ellipse(0, 12 + b, 9, 20 + b)
    cv.part(mz, lambda x, y: MUZ[2] if (x, y + 1) not in mz else (MUZ[1] if y < 14 + b else MUZ[0]),
            outer="outline", inner=CUB[2])
    cv.put(1, 13 + b, "outline"); cv.put(2, 13 + b, "outline"); cv.put(1, 14 + b, "outline")
    cv.put(2, 13 + b, "stone")
    for x, y in ((2, 17), (3, 18), (4, 18), (5, 17)):
        cv.put(x, y + b, CUB_D)
    bead_eye(cv, 8, 10 + b, 3, blink=phase == 3 and step is None)
    cv.put(10, 15 + b, "pink"); cv.put(11, 15 + b, "pink")
    # cream crescent peeking on the chest
    for x, y in ((7, 23), (8, 24), (9, 24)):
        if (x, y + b) in body:
            cv.put(x, y + b, "cream")
    bramble(cv, [(7, 5 + b), (11, 3 + b), (15, 4 + b)], [(9, 2 + b), (13, 2 + b)])
    return cv


CUB_IDLE = [(b, None, 0) for b in IDLE_BOB]
# lumbering walk: alternate strides with a heavy 1 px body dip on the passing frames
CUB_WALK_FRONT = ["R", None, "L", None]
CUB_WALK_SIDE = [1, None, 2, None]


def build_cub_sheet():
    def front(ph, b, pose, back):
        return cub_front(ph, b, pose, back)

    def side(ph, b, pose):
        return cub_side(ph, b, pose)
    sheet = Image.new("RGBA", (256, 128), TRANSPARENT)
    for r, d in enumerate(DIRS):
        for i in range(8):
            ph = i % 4
            if i < 4:
                b, pf, ps = IDLE_BOB[ph], None, None
            else:
                b, pf, ps = (0, 1, 0, 1)[ph], CUB_WALK_FRONT[ph], CUB_WALK_SIDE[ph]
            if d in ("down", "up"):
                img = cub_front(ph, b, pf, d == "up").image()
            else:
                img = cub_side(ph, b, ps).image()
                if d == "right":
                    img = img.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.alpha_composite(img, (i * 32, r * 32))
    return sheet


# ==========================================================================
# Portraits (64x64 busts, transparent background)
# ==========================================================================

def portrait_bun():
    cv = Canvas(64, 64)
    body = cv.ellipse(12, 46, 51, 80)
    cv.part(body, banded(body, BUN[1], BUN[0], BUN[2]), outer="outline", inner="outline")
    chest = cv.ellipse(20, 48, 43, 76) & body
    cv.part(chest, lambda x, y: BELLY[1] if x > 37 and y > 54 else BELLY[0], outer=None)
    head = cv.ellipse(9, 10, 54, 52)
    cv.part(head, banded(head, BUN[1], BUN[0], BUN[2]), outer="outline", inner=BUN[2])
    mz = (cv.ellipse(19, 32, 44, 52) | cv.ellipse(12, 36, 26, 50) | cv.ellipse(37, 36, 51, 50)) & head
    cv.part(mz, lambda x, y: BELLY[1] if y > 48 or x > 45 else BELLY[0], outer=None)
    # eyes: big glossy dark beads
    for ex in (17, 38):
        em = cv.ellipse(ex, 22, ex + 8, 33)
        cv.part(em, lambda x, y: "brown_dark" if y > 29 else "outline", outer="outline", inner="outline")
        hl = cv.ellipse(ex + 1, 23, ex + 3, 26)
        cv.part(hl, "white_warm", outer=None)
        cv.put(ex + 6, 30, "white_warm")
    for x, y in ((29, 36), (30, 36), (31, 36), (32, 36), (33, 36), (34, 36), (30, 37), (31, 37), (32, 37), (33, 37)):
        cv.put(x, y, "pink")
    cv.put(30, 36, "white_warm")
    for x, y in ((31, 38), (32, 38), (31, 39), (32, 39), (30, 40), (29, 40), (33, 40), (34, 40)):
        cv.put(x, y, "brown_mid")
    for x, y in ((15, 39), (16, 39), (17, 39), (46, 39), (47, 39), (48, 39)):
        cv.put(x, y, "pink")
    # lop ears hanging down the sides, moss tips
    for s in (0, 1):
        def X(x):
            return x if s == 0 else 63 - x
        e = cv.stroke([(X(17), 13), (X(8), 22), (X(5), 38), (X(6), 52)], 6.5, 5.0)
        tip = {p for p in e if p[1] >= 46}
        bf = banded(e, BUN[1], BUN[0], BUN[2])
        cv.part(e, lambda x, y: moss_fill(tip, 3)(x, y) if (x, y) in tip else bf(x, y),
                outer="outline", inner="outline")
        for y in range(24, 44):
            cv.put(X(8), y, "skin_shadow")
            if y > 28:
                cv.put(X(9), y, "skin_shadow")
    cap = cv.ellipse(18, 6, 45, 18)
    cv.part(cap, moss_fill(cap), outer="green_dark", inner="green_dark")
    for x, y in ((24, 9), (30, 8), (37, 10), (27, 13), (41, 13), (34, 12)):
        cv.put(x, y, "green_pale")
    # sprout (2x scale)
    stem = cv.stroke([(32, 8), (32, 3)], 1.0, 0.8)
    cv.part(stem, "green_forest", outer=None)
    for pts in ([(31, 4), (25, 0.5), (22, 3), (27, 5)], [(33, 4), (39, 0.5), (42, 3), (37, 5)]):
        lf = cv.poly(pts)
        cv.part(lf, lambda x, y: "green_light" if y < 3 else "green_grass", outer="green_dark", inner="green_dark")
    return cv.image()


def portrait_jay():
    cv = Canvas(64, 64)
    for s in (0, 1):
        def X(x):
            return x if s == 0 else 63 - x
        wg = cv.poly([(X(16), 42), (X(3), 50), (X(1), 63.5), (X(20), 63.5)])
        cv.part(wg, banded(wg, JAY[1], JAY[0], JAY[2]), outer="outline", inner="outline")
        for y in (50, 54, 58, 62):
            for x in range(64):
                if (x, y) in wg and (x - 1, y) in wg and (x + 1, y) in wg:
                    cv.put(x, y, "outline")
        for x in range(64):
            if (x, 63) in wg:
                cv.put(x, 63, "white_warm")
    body = cv.ellipse(12, 40, 51, 84)
    cv.part(body, banded(body, JAY[1], JAY[0], JAY[2]), outer="outline", inner="outline")
    chest = cv.ellipse(20, 46, 43, 80) & body
    cv.part(chest, lambda x, y: WHITE[1] if x > 37 else WHITE[0], outer=None)
    # crest: tall tuft rising from behind the crown, leaning back
    cr = cv.poly([(24, 16), (33, 0.5), (37, 0.5), (41, 16)])
    cv.part(cr, banded(cr, JAY[1], JAY[0], JAY[2]), outer="outline", inner=JAY[2])
    for y in (6, 10, 14):
        for x in range(64):
            if (x, y) in cr and (x - 2, y) in cr and (x + 2, y) in cr and (x + y) % 3 == 0:
                cv.put(x, y, JAY[2])
    head = cv.ellipse(12, 10, 51, 50)
    cv.part(head, banded(head, JAY[1], JAY[0], JAY[2]), outer="outline", inner=JAY[2])
    face = cv.ellipse(17, 24, 46, 50) & head
    cv.part(face, lambda x, y: WHITE[1] if x > 41 or y > 47 else WHITE[0], outer=None)
    # black necklace and eye lines
    neck = cv.stroke([(14, 36), (18, 46), (26, 51), (37, 51), (45, 46), (49, 36)], 1.4, 1.4)
    cv.part(neck, "outline", outer=None)
    for ex in (18, 37):
        em = cv.ellipse(ex, 23, ex + 8, 31)
        cv.part(em, "outline", outer="outline", inner="outline")
        hl = cv.ellipse(ex + 2, 24, ex + 3, 26)
        cv.part(hl, "white_warm", outer=None)
        cv.put(ex + 6, 29, "stone")
    for x in range(14, 19):
        cv.put(x, 26, "outline")
    for x in range(45, 50):
        cv.put(x, 26, "outline")
    # bill
    bill = cv.poly([(28, 32), (36, 32), (32, 40)])
    cv.part(bill, lambda x, y: "stone" if y < 34 else "stone_dark", outer="outline", inner="outline")
    for x, y in ((21, 37), (22, 37), (23, 37), (40, 37), (41, 37), (42, 37)):
        cv.put(x, y, "pink")
    return cv.image()


def portrait_cub():
    cv = Canvas(64, 64)
    body = cv.ellipse(5, 44, 58, 90)
    cv.part(body, banded(body, CUB[1], CUB[0], CUB[2]), outer="outline", inner="outline")
    cres = cv.stroke([(17, 54), (24, 59), (32, 60), (40, 59), (47, 54)], 2.4, 2.4) & body
    cv.part(cres, lambda x, y: "sand" if y > 60 else "cream", outer=None)
    for s in (0, 1):
        def X(x):
            return x if s == 0 else 63 - x
        x0, x1 = sorted((X(3), X(21)))
        em = cv.ellipse(x0, 2, x1, 20)
        cv.part(em, banded(em, CUB[1], CUB[0], CUB[2]), outer="outline", inner="outline")
        i0, i1 = sorted((X(7), X(17)))
        im = cv.ellipse(i0, 6, i1, 17)
        cv.part(im, lambda x, y: MUZ[0] if y < 13 else MUZ[2], outer=None)
    head = cv.ellipse(5, 7, 58, 54)
    cv.part(head, banded(head, CUB[1], CUB[0], CUB[2]), outer="outline", inner=CUB[2])
    mz = cv.ellipse(19, 29, 44, 50)
    cv.part(mz, lambda x, y: MUZ[1] if y < 35 else (MUZ[0] if y < 47 else MUZ[2]), outer=CUB[2], inner=CUB[2])
    nose = cv.ellipse(26, 32, 37, 38)
    cv.part(nose, lambda x, y: "stone_dark" if y < 34 and x < 31 else "outline", outer="outline", inner="outline")
    cv.put(28, 33, "stone_light")
    for x, y in ((31, 39), (32, 39), (31, 40), (32, 40), (31, 41), (32, 41), (30, 42), (29, 42), (28, 41),
                 (33, 42), (34, 42), (35, 41)):
        cv.put(x, y, CUB_D)
    for x, y in ((30, 43), (31, 43), (32, 43), (33, 43)):
        cv.put(x, y, "pink")
    for ex in (16, 41):
        em = cv.ellipse(ex, 23, ex + 6, 30)
        cv.part(em, lambda x, y: "brown_dark" if y > 27 else "outline", outer="outline", inner="outline")
        cv.put(ex + 1, 24, "white_warm"); cv.put(ex + 2, 24, "white_warm"); cv.put(ex + 1, 25, "white_warm")
        cv.put(ex + 5, 28, "stone")
    for x, y in ((12, 36), (13, 36), (14, 36), (15, 36), (48, 36), (49, 36), (50, 36), (51, 36)):
        cv.put(x, y, "pink")
    tufts = [(30, 9), (32, 8), (34, 9), (8, 30), (55, 30)]
    for p in tufts:
        if p in head:
            cv.put(*p, CUB[1])
    # bramble crown: leaves + berries across the head top
    vine = cv.stroke([(13, 16), (20, 10), (32, 7), (44, 10), (51, 16)], 1.0, 1.0)
    cv.part(vine, "brown", outer=None)
    for (x, y) in ((15, 13), (22, 8), (30, 6), (38, 7), (46, 10), (50, 15)):
        lf = cv.ellipse(x - 2, y - 2, x + 2, y + 2)
        cv.part(lf, lambda xx, yy, y=y: "green_grass" if yy < y else "green", outer="green_dark", inner="green_dark")
        cv.put(x - 1, y - 1, "green_light")
    for (x, y) in ((18, 11), (26, 6), (34, 5), (42, 7)):
        bm = cv.ellipse(x - 1, y - 1, x + 2, y + 2)
        cv.part(bm, lambda xx, yy, y=y: "red" if yy <= y else "red_dark", outer="outline", inner="outline")
        cv.put(x, y - 1 + 1, "pink")
    return cv.image()


# ==========================================================================

CREATURES = {
    "moss_bun": lambda: build_sheet(bun_front, bun_side, BUN_IDLE, BUN_WALK),
    "blue_jay": lambda: build_sheet(jay_front, jay_side, JAY_IDLE, JAY_WALK),
    "bramble_cub": build_cub_sheet,
}
PORTRAITS = {"moss_bun": portrait_bun, "blue_jay": portrait_jay, "bramble_cub": portrait_cub}


def outputs():
    out = {}
    for name, fn in CREATURES.items():
        out[f"assets/sprites/{name}.png"] = fn()
    for name, fn in PORTRAITS.items():
        out[f"assets/portraits/{name}_portrait.png"] = fn()
    return out


def validate(rel, img):
    exp = (64, 64) if "portraits" in rel else (256, 128)
    assert img.size == exp, (rel, img.size)
    pal = set(RGBA)
    data = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
    for px in data:
        assert px[3] in (0, 255), (rel, "partial alpha", px)
        assert px[3] == 0 or px in pal, (rel, "off-palette", px)
    if "sprites" in rel:
        for r in range(4):
            for col in range(8):
                f = img.crop((col * 32, r * 32, col * 32 + 32, r * 32 + 32))
                assert f.getbbox(), (rel, r, col, "empty frame")
        left = img.crop((0, 32, 256, 64))
        right = img.crop((0, 64, 256, 96))
        for col in range(8):
            a = left.crop((col * 32, 0, col * 32 + 32, 32)).transpose(Image.FLIP_LEFT_RIGHT)
            assert a.tobytes() == right.crop((col * 32, 0, col * 32 + 32, 32)).tobytes(), (rel, "mirror")


def main():
    outs = outputs()
    for rel, img in outs.items():
        validate(rel, img)
        p = ROOT / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        img.save(p)
        print("wrote", rel, img.size)
    if "--preview" in sys.argv:
        import preview_slice3_creatures
        preview_slice3_creatures.preview(sys.argv[sys.argv.index("--preview") + 1], outs)


if __name__ == "__main__":
    main()
