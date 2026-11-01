"""Preview renders for gen_slice3_woodland.py (written OUTSIDE the repo; nothing here ships).
8x nearest-neighbor sheets, a tiling test, a mock Woodland room with traps, bait, player and
Cinderkin for scale, and slice3_p1_all.png."""
from pathlib import Path

from PIL import Image

import gen_slice3_woodland as w

S = 8
BG = (58, 50, 60, 255)


def up(img, s=S, bg=BG):
    u = img.resize((img.width * s, img.height * s), Image.NEAREST)
    flat = Image.new("RGBA", u.size, bg)
    flat.alpha_composite(u)
    return flat


def tiling_test(tiles):
    """3x3 repeats of each opaque tile, every ground pairing, and wall runs."""
    ground = [0, 1, 2, 3, 4, 5, 6, 7]
    img = Image.new("RGBA", (16 * 24, 16 * 14), BG)
    for k, i in enumerate(ground):
        for y in range(3):
            for x in range(3):
                img.alpha_composite(tiles[i], ((k % 8) * 48 + x * 16, (k // 8) * 48 + y * 16))
    # random mix of all ground variants
    import random
    r = random.Random(5)
    for y in range(5):
        for x in range(24):
            img.alpha_composite(tiles[r.choice(ground)], (x * 16, 48 + y * 16))
    # wall run: canopy block rows, bottom fringe + trunks, then the near wall rim + fill
    for x in range(24):
        g0 = r.choice(ground)
        for y in (9, 10, 11):
            img.alpha_composite(tiles[r.choice(ground)], (x * 16, y * 16))
        img.alpha_composite(tiles[w.canopy(x, 7)], (x * 16, 7 * 16))
        img.alpha_composite(tiles[28 + x % 2], (x * 16, 8 * 16))
        img.alpha_composite(tiles[30 + x % 2], (x * 16, 9 * 16))
        img.alpha_composite(tiles[36 + x % 2], (x * 16, 11 * 16))
        img.alpha_composite(tiles[w.canopy(x, 12)], (x * 16, 12 * 16))
        img.alpha_composite(tiles[w.canopy(x, 13)], (x * 16, 13 * 16))
    return img


def preview(outdir, outs):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    ts = outs["assets/tilesets/woodland_tiles.png"]
    room = outs["assets/backgrounds/woodland_room.png"]
    trap = outs["assets/sprites/trap_basic.png"]
    bait = outs["assets/sprites/item_bait.png"]
    up(ts).save(out / "slice3_woodland_tiles.png")
    up(trap).save(out / "slice3_trap_basic.png")
    up(bait).save(out / "slice3_item_bait.png")
    up(room, 2).save(out / "slice3_woodland_room.png")
    tiles = w.build_tiles()
    up(tiling_test(tiles), 3).save(out / "slice3_tiling_test.png")
    # mock scene
    root = w.ROOT
    player = Image.open(root / "assets/sprites/player_base.png").convert("RGBA")
    cind = Image.open(root / "assets/sprites/cinderkin.png").convert("RGBA")
    p = player.crop((0, 0, 16, 32))
    ck = cind.crop((0, 0, 32, 32))
    ckl = cind.crop((32 * 8, 0, 32 * 9, 32)) if cind.width > 256 else cind.crop((0, 32, 32, 64))
    fr = [trap.crop((16 * i, 0, 16 * i + 16, 16)) for i in range(4)]
    extra = [
        (fr[0], 290, 288), (p, 312, 272), (bait, 330, 286),
        (fr[1], 200, 160), (ck, 214, 140),
        (fr[2], 420, 220), (fr[3], 120, 250), (ckl, 470, 120),
    ]
    scene = w.compose_room(tiles, extra)
    up(scene, 3).save(out / "slice3_mock_room.png")
    crop = scene.crop((80, 120, 400, 300))
    up(crop, 4).save(out / "slice3_mock_room_zoom.png")
    # combined
    parts = [up(ts, 4), up(trap, 8), up(bait, 8), up(scene, 2)]
    wd = max(pp.width for pp in parts[:3]) + 0
    W_ = max(parts[0].width + parts[1].width + 16, parts[3].width)
    H_ = parts[0].height + parts[3].height + 16
    allimg = Image.new("RGBA", (W_, H_), BG)
    allimg.alpha_composite(parts[0], (0, 0))
    allimg.alpha_composite(parts[1], (parts[0].width + 16, 0))
    allimg.alpha_composite(parts[2], (parts[0].width + 16, parts[1].height + 16))
    allimg.alpha_composite(parts[3], (0, parts[0].height + 16))
    allimg.save(out / "slice3_p1_all.png")
    print("previews in", out)
