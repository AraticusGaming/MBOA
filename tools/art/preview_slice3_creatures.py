"""Preview renders for gen_slice3_creatures.py (written OUTSIDE the repo; nothing here ships).
8x nearest-neighbor sheets and portraits, a line-up next to the Cinderkin for scale, the
creatures in the Woodland room, and slice3_p2_all.png."""
from pathlib import Path

from PIL import Image

S = 8
BG = (58, 50, 60, 255)
ROOT = Path(__file__).resolve().parent.parent.parent
NAMES = ("moss_bun", "blue_jay", "bramble_cub")


def up(img, s=S, bg=BG):
    u = img.resize((img.width * s, img.height * s), Image.NEAREST)
    flat = Image.new("RGBA", u.size, bg)
    flat.alpha_composite(u)
    return flat


def frame(sheet, r, c):
    return sheet.crop((c * 32, r * 32, c * 32 + 32, r * 32 + 32))


def preview(outdir, outs):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    cind = Image.open(ROOT / "assets/sprites/cinderkin.png").convert("RGBA")
    cpor = Image.open(ROOT / "assets/portraits/cinderkin_portrait.png").convert("RGBA")
    sheets = {n: outs[f"assets/sprites/{n}.png"] for n in NAMES}
    ports = {n: outs[f"assets/portraits/{n}_portrait.png"] for n in NAMES}
    tiles = []
    for n in NAMES:
        a = up(sheets[n]); a.save(out / f"slice3_creatures_{n}.png")
        p = up(ports[n]); p.save(out / f"slice3_creatures_{n}_portrait.png")
        tiles += [a, p]
    # scale line-up: Cinderkin + the three, idle down / left frame on the floor, 1 tile grid
    room = ROOT / "assets/backgrounds/woodland_room.png"
    ts = Image.open(ROOT / "assets/tilesets/woodland_tiles.png").convert("RGBA")
    line = Image.new("RGBA", (176, 80))
    for ty in range(5):
        for tx in range(11):
            i = (0, 1, 0, 0, 2)[(tx * 3 + ty * 2) % 5]
            line.alpha_composite(ts.crop((i * 16, 0, i * 16 + 16, 16)), (tx * 16, ty * 16))
    allsh = [cind] + [sheets[n] for n in NAMES]
    for k, sh in enumerate(allsh):
        line.alpha_composite(frame(sh, 0, 0), (4 + k * 42, 4))
        line.alpha_composite(frame(sh, 1, 4), (4 + k * 42, 42))
    ln = up(line); ln.save(out / "slice3_creatures_lineup.png")
    # portraits side by side with Cinderkin
    pr = Image.new("RGBA", (4 * 68, 64), BG)
    for k, p in enumerate([cpor] + [ports[n] for n in NAMES]):
        pr.alpha_composite(p, (k * 68, 0))
    pu = up(pr, 4); pu.save(out / "slice3_creatures_portraits.png")
    # in-room mock at 3x
    full = Image.open(room).convert("RGBA").crop((160, 128, 160 + 320, 128 + 180))
    spots = [(cind, 0, 40, 60), (sheets["moss_bun"], 8, 110, 40), (sheets["blue_jay"], 20, 190, 70),
             (sheets["bramble_cub"], 12, 250, 110), (sheets["moss_bun"], 0, 80, 120),
             (sheets["blue_jay"], 29, 150, 120)]
    trap = ROOT / "assets/sprites/trap_basic.png"
    if trap.exists():
        t = Image.open(trap).convert("RGBA")
        full.alpha_composite(t.crop((16, 0, 32, 16)), (210, 130))
    for sh, idx, x, y in spots:
        full.alpha_composite(frame(sh, idx // 8, idx % 8), (x, y))
    mu = up(full, 3); mu.save(out / "slice3_creatures_room.png")
    # combined
    parts = tiles + [ln, pu, mu]
    W = max(p.width for p in parts) + 16
    H = sum(p.height + 16 for p in parts) + 16
    allimg = Image.new("RGBA", (W, H), (30, 26, 32, 255))
    y = 16
    for p in parts:
        allimg.alpha_composite(p, (8, y)); y += p.height + 16
    allimg.save(out / "slice3_p2_all.png")
