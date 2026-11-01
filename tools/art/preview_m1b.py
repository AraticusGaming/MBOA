"""Preview renders for gen_m1b_polish.py (written OUTSIDE the repo, nothing here ships).
8x nearest-neighbor sheets, a mock farm scene and a mock HUD, plus m1b_all.png."""
import random
from pathlib import Path

from PIL import Image

import gen_m1b_polish as g
from palette import c

S = 8
BG = (58, 50, 60, 255)  # preview backdrop only


def up(img, s=S, bg=BG):
    u = img.resize((img.width * s, img.height * s), Image.NEAREST)
    flat = Image.new("RGBA", u.size, bg)
    flat.alpha_composite(u)
    return flat


def tile(ts, i):
    x, y = (i % 8) * 16, (i // 8) * 16
    return ts.crop((x, y, x + 16, y + 16))


def nine(src, w, h, m):
    """Stretch a 9-slice source (equal margins m) to w x h (nearest)."""
    sw, sh = src.size
    out = Image.new("RGBA", (w, h))
    xs = [(0, m, 0, m), (m, sw - m, m, w - m), (sw - m, sw, w - m, w)]
    ys = [(0, m, 0, m), (m, sh - m, m, h - m), (sh - m, sh, h - m, h)]
    for (sx0, sx1, dx0, dx1) in xs:
        for (sy0, sy1, dy0, dy1) in ys:
            part = src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.alpha_composite(part, (dx0, dy0))
    return out


FONT = {  # 3x5 preview-only glyphs
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
    "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001010010010",
    "8": "111101111101111", "9": "111101111001111", ":": "000010000010000", "A": "010101111101101",
    "M": "101111111101101", "P": "110101110100100", "D": "110101101101110", "Y": "101101010010010",
    "S": "111100111001111", "R": "110101110101101", "I": "111010010010111", "N": "110101101101101",
    "G": "111100101101111", "U": "101101101101111", " ": "000000000000000", "F": "111100110100100",
    "E": "111100110100111", "L": "100100100100111", "W": "101101111111101", "T": "111010010010010",
    "H": "101101111101101", "O": "111101101101111", "C": "111100100100111", "B": "110101110101110",
}


def text(img, x, y, s, col="brown_dark"):
    px = img.load()
    for ch in s:
        gph = FONT[ch]
        for i, b in enumerate(gph):
            if b == "1":
                px[x + i % 3, y + i // 3] = c(col)
        x += 4


def mock_scene(o):
    ts = o["assets/tilesets/farm_tiles.png"]
    W, H = 22, 14
    img = Image.new("RGBA", (W * 16, H * 16))
    r = random.Random(7)
    grass = [0] * 12 + [1] * 8 + [13] * 3 + [14, 15, 15, 2, 16]
    for y in range(H):
        for x in range(W):
            img.paste(tile(ts, r.choice(grass)), (x * 16, y * 16))
    # field (dirt) inside the fence
    fx0, fy0, fx1, fy1 = 1, 1, 12, 9
    for y in range(fy0 + 1, fy1):
        for x in range(fx0 + 1, fx1):
            img.paste(tile(ts, r.choice([3, 3, 3, 17, 18])), (x * 16, y * 16))
    crop = o.get("crop")
    for y, kind in ((3, 4), (4, 5), (6, 5), (7, 4)):
        for x in range(3, 11):
            k = kind if not (y == 6 and x > 8) else 4
            img.paste(tile(ts, k), (x * 16, y * 16))
    # fence ring with a gate gap at bottom (6,9)
    fence = set()
    for x in range(fx0, fx1 + 1):
        fence.add((x, fy0)); fence.add((x, fy1))
    for y in range(fy0, fy1 + 1):
        fence.add((fx0, y)); fence.add((fx1, y))
    fence.discard((6, fy1)); fence.discard((7, fy1))
    fence |= {(fx1 + 1, 4), (fx1 + 2, 4)}  # a T-junction spur
    # path: from the gate down and right to a crossroads
    path = {(6, y) for y in range(9, 14)} | {(7, 9)} | {(x, 12) for x in range(6, 22)} | \
           {(16, y) for y in range(2, 12)} | {(17, 2), (18, 2)} | {(x, 13) for x in range(12, 15)}
    path |= {(13, 12), (13, 11), (14, 11), (14, 12)}  # a 2x2 plaza to show filled corners

    def mask(cells, p):
        x, y = p
        return ((g.N if (x, y - 1) in cells else 0) | (g.E if (x + 1, y) in cells else 0) |
                (g.S if (x, y + 1) in cells else 0) | (g.W if (x - 1, y) in cells else 0))
    for p in path:
        if 0 <= p[0] < W and 0 <= p[1] < H:
            img.alpha_composite(tile(ts, g.PATH_BASE + mask(path, p)), (p[0] * 16, p[1] * 16))
    for p in sorted(fence, key=lambda q: q[1]):
        img.alpha_composite(tile(ts, g.FENCE_BASE + mask(fence, p)), (p[0] * 16, p[1] * 16))
    lone = (19, 9)
    img.alpha_composite(tile(ts, g.FENCE_BASE + 0), (lone[0] * 16, lone[1] * 16))
    if crop is not None:
        for i, x in enumerate(range(3, 11)):
            f = (i // 2) % 4
            img.alpha_composite(crop.crop((f * 16, 0, f * 16 + 16, 16)), (x * 16, 4 * 16))
            img.alpha_composite(crop.crop((0, 0, 16, 16)), (x * 16, 3 * 16)) if i % 3 == 0 else None
    # trees: bottom-center anchor (16,48) at the bottom-center of their cell
    tr = o["assets/sprites/tree_stages.png"]
    for k, (cx, cy) in enumerate(((18, 4), (19, 5), (20, 7), (19, 11), (14, 6), (20, 3))):
        f = [0, 1, 2, 3, 4, 3][k]
        fr = tr.crop((f * 32, 0, f * 32 + 32, 48))
        img.alpha_composite(fr, (cx * 16 + 8 - 16, cy * 16 + 16 - 48))
    # player + bed
    pl = o.get("player")
    bed = o["assets/sprites/bed.png"]
    img.alpha_composite(bed, (14 * 16, 8 * 16))
    if pl is not None:
        img.alpha_composite(pl.crop((0, 0, 16, 32)), (6 * 16, 10 * 16 - 8))
    return img


def mock_hud(o):
    ts = o["assets/tilesets/farm_tiles.png"]
    W, H = 240, 136
    img = Image.new("RGBA", (W, H))
    for y in range(0, H, 16):
        for x in range(0, W, 16):
            img.paste(tile(ts, [0, 1, 0, 13][(x // 16 + y // 16) % 4]), (x, y))
    # HUD panel top-right: date / clock / gold
    panel = nine(o["assets/ui/hud_panel.png"], 64, 44, 6)
    img.alpha_composite(panel, (W - 68, 4))
    px0, py0 = W - 68 + 7, 4 + 7
    text(img, px0, py0, "SPR 1")
    text(img, px0, py0 + 8, "6:00 AM")
    icons = o["assets/ui/hud_icons.png"]
    img.alpha_composite(icons.crop((16, 0, 24, 8)), (px0, py0 + 16))
    text(img, px0 + 10, py0 + 18, "500")
    # bars (stamina partial)
    bf = o["assets/ui/bar_frame.png"]
    for i, (ico, fill, frac) in enumerate(((0, "assets/ui/bar_fill_health.png", 1.0),
                                          (1, "assets/ui/bar_fill_stamina.png", 0.62))):
        y = 4 + i * 12
        img.alpha_composite(icons.crop((ico * 8, 0, ico * 8 + 8, 8)), (4, y + 1))
        fr = nine(bf, 56, 10, 3)
        img.alpha_composite(fr, (14, y))
        inner_w = int((56 - 6) * frac)
        img.alpha_composite(o[fill].resize((inner_w, 4), Image.NEAREST), (14 + 3, y + 3))
    # toolbar bottom-center
    n = 8
    tw = 12 + n * 20 + (n - 1)
    tb = nine(o["assets/ui/toolbar_frame.png"], tw, 32, 6)
    tx, ty = (W - tw) // 2, H - 34
    img.alpha_composite(tb, (tx, ty))
    items = ["assets/sprites/item_pulaski.png", "assets/sprites/item_sickle.png",
             "assets/sprites/item_pickaxe.png", "assets/sprites/item_watering_can.png"]
    for i in range(n):
        sx = tx + 6 + i * 21
        sl = o["assets/ui/toolbar_slot_selected.png" if i == 0 else "assets/ui/toolbar_slot.png"]
        img.alpha_composite(sl, (sx, ty + 6))
        if i < len(items):
            img.alpha_composite(o[items[i]], (sx + 2, ty + 8))
    # bond hearts row
    for i in range(3):
        img.alpha_composite(icons.crop((24, 0, 32, 8)), (4 + i * 9, 30))
    return img


def preview(outdir, outs, extra=None):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    o = dict(outs)
    if extra:
        o.update(extra)
    ups = []
    for rel, img in outs.items():
        name = "m1b_" + Path(rel).stem
        s = S if img.width * S <= 1400 else 4
        u = up(img, s)
        u.save(outdir / f"{name}_{s}x.png")
        ups.append(u)
    sc = mock_scene(o)
    u = up(sc, 4); u.save(outdir / "m1b_scene_4x.png"); ups.append(u)
    up(sc, 8).save(outdir / "m1b_scene_8x.png")
    hd = mock_hud(o)
    u = up(hd, 4); u.save(outdir / "m1b_hud_4x.png"); ups.append(u)
    # tiling check for the seamless ground tiles
    ts = outs["assets/tilesets/farm_tiles.png"]
    ids = [3, 4, 5, 13, 14, 15, 16, 17, 18]
    rep = Image.new("RGBA", (len(ids) * 48, 48))
    for k, i in enumerate(ids):
        for yy in range(3):
            for xx in range(3):
                rep.paste(tile(ts, i), (k * 48 + xx * 16, yy * 16))
    u = up(rep, 4); u.save(outdir / "m1b_tiling_4x.png"); ups.append(u)
    Wd = max(x.width for x in ups) + 16
    Ht = sum(x.height + 16 for x in ups) + 16
    allimg = Image.new("RGBA", (Wd, Ht), (30, 26, 32, 255))
    y = 16
    for x in ups:
        allimg.alpha_composite(x, (8, y))
        y += x.height + 16
    allimg.save(outdir / "m1b_all.png")
    print("previews in", outdir)
