"""Previews for gen_woodland_trees.py (8x nearest-neighbor; written outside the repo)."""
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from palette import c  # noqa: E402

CW, CH = 48, 80
BG = (92, 132, 70, 255)


def up(img, k=8):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def on_bg(img, col=BG):
    bg = Image.new("RGBA", img.size, col)
    bg.alpha_composite(img)
    return bg


def preview(outdir, outs):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    sheets = {Path(k).stem.replace("tree_", ""): v for k, v in outs.items()}
    for sp, sh in sheets.items():
        # sheet with a faint cell grid
        g = on_bg(sh, (150, 170, 130, 255))
        d = ImageDraw.Draw(g)
        for x in range(0, sh.width, CW):
            d.line([(x, 0), (x, sh.height)], fill=(120, 140, 100, 255))
        for y in range(0, sh.height, CH):
            d.line([(0, y), (sh.width, y)], fill=(120, 140, 100, 255))
        up(g, 4).save(out / f"trees_{sp}_4x.png")
        up(on_bg(sh), 8).save(out / f"trees_{sp}_8x.png")
    # all: rows = species, cols = 4 seasons grown, then stages (summer) seed..stump
    pad = 4
    names = list(sheets)
    W = (CW + pad) * 9 + pad
    H = (CH + pad) * len(names) + pad
    allimg = Image.new("RGBA", (W, H), BG)
    for r, sp in enumerate(names):
        sh = sheets[sp]
        for s in range(4):
            cell = sh.crop((3 * CW, s * CH, 4 * CW, (s + 1) * CH))
            allimg.alpha_composite(cell, (pad + s * (CW + pad), pad + r * (CH + pad)))
        for st in (0, 1, 2, 4):
            cell = sh.crop((st * CW, 1 * CH, (st + 1) * CW, 2 * CH))
            k = 4 + [0, 1, 2, 4].index(st)
            allimg.alpha_composite(cell, (pad + k * (CW + pad), pad + r * (CH + pad)))
        # winter stump
        cell = sh.crop((4 * CW, 3 * CH, 5 * CW, 4 * CH))
        allimg.alpha_composite(cell, (pad + 8 * (CW + pad), pad + r * (CH + pad)))
    up(allimg, 4).save(out / "trees_all.png")
    # stage x season grid of small stages, per species, to check seasonal variants
    for sp, sh in sheets.items():
        small = Image.new("RGBA", (4 * 18 + 2, 4 * 34 + 2), BG)
        for s in range(4):
            for st in range(3):
                cell = sh.crop((st * CW + 16, s * CH + 48, st * CW + 32, s * CH + 80))
                small.alpha_composite(cell, (2 + st * 18, 2 + s * 34))
            cell = sh.crop((4 * CW + 16, s * CH + 48, 4 * CW + 32, s * CH + 80))
            small.alpha_composite(cell, (2 + 3 * 18, 2 + s * 34))
        up(small, 8).save(out / f"trees_{sp}_small_8x.png")
    scene(out, sheets)


def scene(out, sheets):
    tiles = Image.open(ROOT / "assets/tilesets/woodland_tiles.png").convert("RGBA")
    player = Image.open(ROOT / "assets/sprites/player_base.png").convert("RGBA").crop((0, 0, 16, 32))

    def tile(i):
        return tiles.crop(((i % 8) * 16, (i // 8) * 16, (i % 8) * 16 + 16, (i // 8) * 16 + 16))

    for season in range(4):
        pass
    W, H = 16 * 24, 16 * 14
    r = random.Random(5)
    base = Image.new("RGBA", (W, H))
    for ty in range(H // 16):
        for tx in range(W // 16):
            base.alpha_composite(tile(r.choice([0, 1, 2, 3, 4, 5, 6, 7])), (tx * 16, ty * 16))
    # objects: (species, stage, cell x, cell y) -> trunk tile (cx, cy) bottom-center
    objs = [("oak", 3, 3, 6), ("pine", 3, 8, 5), ("birch", 3, 12, 7), ("maple", 3, 17, 6),
            ("pine", 3, 21, 8), ("oak", 2, 6, 10), ("maple", 1, 9, 11), ("birch", 2, 15, 12),
            ("pine", 0, 19, 12), ("oak", 4, 2, 12), ("maple", 4, 22, 13), ("birch", 3, 5, 13),
            ("pine", 2, 13, 10)]
    rows = []
    for season in range(4):
        img = base.copy()
        items = [(cy, "tree", sp, st, cx) for sp, st, cx, cy in objs]
        items.append((10, "player", None, None, 11))
        for cy, kind, sp, st, cx in sorted(items):
            bx, by = cx * 16 + 8, cy * 16 + 16   # cell bottom-center
            if kind == "player":
                img.alpha_composite(player, (bx - 8, by - 32))
            else:
                cell = sheets[sp].crop((st * CW, season * CH, (st + 1) * CW, (season + 1) * CH))
                img.alpha_composite(cell, (bx - 24, by - 80))
        rows.append(img)
    sc = Image.new("RGBA", (W * 2 + 4, H * 2 + 4), (0, 0, 0, 255))
    for i, im in enumerate(rows):
        sc.alpha_composite(im, ((i % 2) * (W + 4), (i // 2) * (H + 4)))
    up(sc, 3).save(out / "trees_scene.png")
    up(rows[1], 4).save(out / "trees_scene_summer_4x.png")
