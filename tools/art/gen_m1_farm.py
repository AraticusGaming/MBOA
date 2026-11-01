"""Milestone 1 farm art generator (procedural, pixel-level, reproducible).

Outputs (relative to repo root):
  assets/tilesets/farm_tiles.png   8-column grid of 16x16 tiles
  assets/sprites/player_base.png   16x32 frames, 8 cols x 4 rows (down, left, right, up)
  assets/sprites/crop_basic.png    16x16 frames, 1 row (seed, stage 1, stage 2, harvest)
  tools/art/palette.png            palette swatch

Every opaque pixel comes from tools/art/palette.py; alpha is only 0 or 255.
Usage:  python3 tools/art/gen_m1_farm.py [--preview DIR]
"""
import random
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from palette import RGBA, TRANSPARENT, c, write_swatch  # noqa: E402

T = 16  # tile size


def new(w, h):
    return Image.new("RGBA", (w, h), TRANSPARENT)


def blit_map(img, rows, cmap, ox=0, oy=0):
    """Draw ASCII rows onto img; '.' is transparent (skipped)."""
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            X, Y = ox + x, oy + y
            if 0 <= X < img.width and 0 <= Y < img.height:
                px[X, Y] = c(cmap[ch])


# --------------------------------------------------------------------------
# Tiles (repeating tiles wrap mod 16 so they are seamless)
# --------------------------------------------------------------------------

def tile_fill(name):
    t = new(T, T)
    px = t.load()
    for y in range(T):
        for x in range(T):
            px[x, y] = c(name)
    return t


def put(px, x, y, name):
    px[x % T, y % T] = c(name)


def grass(seed, flowers=0):
    t = tile_fill("green_grass")
    px = t.load()
    r = random.Random(seed)
    # darker clumps
    for _ in range(10):
        x, y = r.randrange(T), r.randrange(T)
        put(px, x, y, "green")
    # little blades: light tip over darker base
    for _ in range(9):
        x, y = r.randrange(T), r.randrange(T)
        put(px, x, y, "green_light")
        put(px, x, y + 1, "green")
    # occasional V tufts
    for _ in range(3):
        x, y = r.randrange(T), r.randrange(T)
        put(px, x, y, "green_light")
        put(px, x + 2, y, "green_light")
        put(px, x + 1, y + 1, "green")
        put(px, x, y + 1, "green")
        put(px, x + 2, y + 1, "green")
    for i in range(flowers):
        x, y = r.randrange(T), r.randrange(T)
        petal = "white_warm" if i % 2 == 0 else "pink"
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            put(px, x + dx, y + dy, petal)
        put(px, x, y, "yellow")
        put(px, x, y + 2, "green")
    return t


def dirt(seed=11):
    t = tile_fill("brown_mid")
    px = t.load()
    r = random.Random(seed)
    for _ in range(18):
        put(px, r.randrange(T), r.randrange(T), "brown")
    for _ in range(10):
        put(px, r.randrange(T), r.randrange(T), "brown_light")
    for _ in range(3):  # pebbles
        x, y = r.randrange(T), r.randrange(T)
        put(px, x, y, "stone_light")
        put(px, x, y + 1, "brown")
    return t


def clods(base, mid, light, shadow, seed):
    """Tilled earth: rows of soft clods on a jittered grid (wraps mod 16)."""
    t = tile_fill(base)
    px = t.load()
    r = random.Random(seed)
    for gy in range(4):
        for gx in range(4):
            x = gx * 4 + (2 if gy % 2 else 0) + r.choice((0, 0, 1))
            y = gy * 4 + r.choice((0, 1))
            #   .mm.      clod: 4x2 body, light top-left, shadow underneath
            #   mmmm
            #   .ss.
            put(px, x + 1, y, mid); put(px, x + 2, y, light)
            for dx in range(4):
                put(px, x + dx, y + 1, mid)
            put(px, x + 1, y + 1, light)
            put(px, x + 1, y + 2, shadow); put(px, x + 2, y + 2, shadow)
            put(px, x + 3, y + 2, shadow)
    return t


def tilled():
    return clods("brown", "brown_mid", "brown_light", "soil_dark", 21)


def watered():
    return clods("soil_wet", "brown", "brown_mid", "soil_dark", 21)


def stone_path():
    # toroidal Voronoi cobbles -> seamless by construction
    seeds = [(2, 3), (9, 1), (14, 6), (5, 9), (11, 11), (1, 14), (8, 6)]

    def cell(x, y):
        best, bi = 1e9, 0
        for i, (sx, sy) in enumerate(seeds):
            dx = min(abs(x - sx), T - abs(x - sx))
            dy = min(abs(y - sy), T - abs(y - sy))
            d = dx * dx + dy * dy * 1.3
            if d < best:
                best, bi = d, i
        return bi

    cells = [[cell(x, y) for x in range(T)] for y in range(T)]
    gap = [[False] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            k = cells[y][x]
            if cells[y][(x + 1) % T] != k or cells[(y + 1) % T][x] != k:
                gap[y][x] = True
    t = new(T, T)
    px = t.load()
    for y in range(T):
        for x in range(T):
            if gap[y][x]:
                px[x, y] = c("brown")
            elif gap[(y - 1) % T][x] or gap[y][(x - 1) % T]:
                px[x, y] = c("stone_pale")
            elif gap[(y + 1) % T][x]:
                px[x, y] = c("stone")
            else:
                px[x, y] = c("stone_light")
    return t


def packed_path(seed=41):
    t = tile_fill("tan")
    px = t.load()
    r = random.Random(seed)
    for _ in range(14):
        put(px, r.randrange(T), r.randrange(T), "sand")
    for _ in range(12):
        put(px, r.randrange(T), r.randrange(T), "brown_light")
    for _ in range(3):
        x, y = r.randrange(T), r.randrange(T)
        put(px, x, y, "stone_pale")
        put(px, x, y + 1, "brown_light")
    return t


WOOD = {"o": "brown_dark", "h": "tan", "l": "brown_light", "m": "brown_mid", "d": "brown"}

RAIL_H = [
    "................",
    "................",
    "................",
    "................",
    "oooooooooooooooo",
    "llllhllllllllhll",
    "mmmmmmmdmmmmmmmm",
    "oooooooooooooooo",
    "................",
    "oooooooooooooooo",
    "llhllllllllhllll",
    "mmmmmmmmmmmdmmmm",
    "oooooooooooooooo",
    "................",
    "................",
    "................",
]
RAIL_V = ["......olmo......"] * 16
RAIL_V[4] = "......ohmo......"
RAIL_V[11] = "......oldo......"
POST = [
    "................",
    ".....oooooo.....",
    ".....ohhhho.....",
    ".....ohllho.....",
    ".....oooooo.....",
    ".....olmmdo.....",
    ".....olmmdo.....",
    ".....olmddo.....",
    ".....olmmdo.....",
    ".....olmmdo.....",
    ".....oldmdo.....",
    ".....olmmdo.....",
    ".....olmmdo.....",
    ".....oddddo.....",
    ".....oooooo.....",
    "................",
]


def wood(rows):
    t = new(T, T)
    blit_map(t, rows, WOOD)
    return t


def stack(*tiles):
    t = new(T, T)
    for s in tiles:
        t.alpha_composite(s)
    return t


def build_tileset():
    tiles = [
        grass(1), grass(2), grass(3, flowers=2),        # 0-2
        dirt(), tilled(), watered(),                     # 3-5
        stone_path(), packed_path(),                     # 6-7
        wood(POST), wood(RAIL_H), wood(RAIL_V),          # 8-10
        stack(wood(RAIL_H), wood(POST)),                 # 11
        stack(wood(RAIL_V), wood(POST)),                 # 12
    ]
    cols = 8
    rows = (len(tiles) + cols - 1) // cols
    sheet = new(cols * T, rows * T)
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t, ((i % cols) * T, (i // cols) * T))
    return sheet


# --------------------------------------------------------------------------
# Player (16x32)
# --------------------------------------------------------------------------

PC = {
    "o": "outline", "H": "yellow", "y": "yellow_pale", "h": "tan", "B": "green_forest",
    "r": "brown", "R": "brown_dark", "n": "brown_mid", "s": "skin", "S": "skin_shadow", "p": "pink",
    "c": "red", "C": "red_dark", "v": "blue", "V": "blue_dark", "l": "blue_light",
    "u": "yellow", "b": "brown", "k": "brown_dark", "w": "white_warm",
}

HAT = [
    "......oooo......",
    ".....oyHHHo.....",
    "....oyHHHHHo....",
    "....oBBBBBBo....",
    "..ooyHHHHHHHoo..",
    ".oyHhhhhhhhhHHo.",
]  # rows 5-10

FRONT_UP = HAT + [
    "..oorRssssRroo..",
    "...orssssssro...",
    "...ossossosso...",
    "...ospsssspso...",
    "....oSssssSo....",
    ".....oSSSSo.....",
    "...occcSSccco...",
    "..oCcvccccvcCo..",
    ".oCoVvvvvvvVoCo.",
    ".oCoVvuvvuvVoCo.",
    ".oCoVvvvvvvVoCo.",
    ".osoVvvvvvvVoso.",
    ".oooVvvvvvvVooo.",
    "...oVvvvvvvVo...",
]  # rows 5-24

BACK_UP = HAT + [
    "..oonrnnnnrnoo..",
    "...onrnnnnrno...",
    "...onnrnnrnno...",
    "...ornnnnnnro...",
    "....orrrrrro....",
    ".....oSSSSo.....",
    "...occcccccco...",
    "..oCcvccccvcCo..",
    ".oCocvccccvcoCo.",
    ".oCoccvccvccoCo.",
    ".oCoVvvvvvvVoCo.",
    ".osoVvvvvvvVoso.",
    ".oooVvvvvvvVooo.",
    "...oVvvvvvvVo...",
]

SIDE_UP = HAT + [
    "...ossssrRRro...",
    "..osssssRrrro...",
    "...osossSRrro...",
    "...ospssSrRro...",
    "....oSsssRRo....",
    ".....oSSSo......",
    "....occcccco....",
    "...ovvcccccco...",
    "...ovvccccvVo...",
    "...ovuvvvvvVo...",
    "...ovvvvvvvVo...",
    "...ovvvvvvvVo...",
    "...oVvvvvvvVo...",
    "...oVvvvvvvVo...",
]

LEGS_FRONT = [
    "...oVvvVVvvVo...",
    "...oVvvoovvVo...",
    "...oVvvoovvVo...",
    "...oVvvoovvVo...",
    "...obbboobbbo...",
    "...okbboobbko...",
    "....ooo..ooo....",
]  # rows 25-31

LEGS_SIDE_STAND = [
    "....oVvvvvVo....",
    "....oVvvvvVo....",
    "....oVvvvvVo....",
    "....oVvvvvVo....",
    "...obbbbbbo.....",
    "...okbbbbko.....",
    "....oooooo......",
]
LEGS_SIDE_STEP_A = [
    "....oVvvvvVo....",
    "...oVvvooVvvo...",
    "..oVvvo..oVvvo..",
    "..oVvo....oVvo..",
    ".obbbo....obbbo.",
    ".okbbo....okbbo.",
    "..ooo......ooo..",
]
LEGS_SIDE_STEP_B = [
    "....oVvvvvVo....",
    "...oVVVooVvvo...",
    "..oVVVo..oVvvo..",
    "..oVVo....oVvo..",
    ".okkko....obbbo.",
    ".okkko....okbbo.",
    "..ooo......ooo..",
]

# side arm overlay, relative to (ax, 18)
ARM = [
    "cCo",
    "CCo",
    "CCo",
    "CCo",
    "sso",
    "oo.",
]


def lift(legs, cols):
    """Raise the boot/leg in the given columns by 1px (walking step)."""
    out = [list(r) for r in legs]
    for x in cols:
        col = [legs[y][x] for y in range(len(legs))]
        new_col = col[:1] + col[2:] + ["."]
        for y in range(len(legs)):
            out[y][x] = new_col[y]
    return ["".join(r) for r in out]


def frame(upper, legs, dy=0, arm_x=None, arm_dy=0):
    f = new(16, 32)
    blit_map(f, legs, PC, 0, 25)
    blit_map(f, upper, PC, 0, 5 + dy)
    if arm_x is not None:
        blit_map(f, ARM, PC, arm_x, 18 + dy + arm_dy)
    return f


IDLE_DY = [0, 0, 1, 1]  # slow breathing bob (upper body sinks 1px)


def player_row(direction):
    frames = []
    if direction in ("down", "up"):
        upper = FRONT_UP if direction == "down" else BACK_UP
        for dy in IDLE_DY:
            frames.append(frame(upper, LEGS_FRONT, dy))
        left_cols, right_cols = range(3, 8), range(8, 13)
        walk = [
            (lift(LEGS_FRONT, right_cols), 1),
            (LEGS_FRONT, 0),
            (lift(LEGS_FRONT, left_cols), 1),
            (LEGS_FRONT, 0),
        ]
        for legs, dy in walk:
            frames.append(frame(upper, legs, dy))
    else:  # draw facing left; right is a mirror
        for dy in IDLE_DY:
            frames.append(frame(SIDE_UP, LEGS_SIDE_STAND, dy, arm_x=7))
        walk = [
            (LEGS_SIDE_STEP_A, 1, 5),
            (LEGS_SIDE_STAND, 0, 7),
            (LEGS_SIDE_STEP_B, 1, 8),
            (LEGS_SIDE_STAND, 0, 7),
        ]
        for legs, dy, ax in walk:
            frames.append(frame(SIDE_UP, legs, dy, arm_x=ax))
        if direction == "right":
            frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]
    return frames


def _check(rows, h, name):
    assert len(rows) == h and all(len(r) == 16 for r in rows), name


for _n, _r, _h in (("FRONT_UP", FRONT_UP, 20), ("BACK_UP", BACK_UP, 20), ("SIDE_UP", SIDE_UP, 20),
                   ("LEGS_FRONT", LEGS_FRONT, 7), ("LEGS_SIDE_STAND", LEGS_SIDE_STAND, 7),
                   ("LEGS_SIDE_STEP_A", LEGS_SIDE_STEP_A, 7), ("LEGS_SIDE_STEP_B", LEGS_SIDE_STEP_B, 7)):
    _check(_r, _h, _n)


def build_player():
    sheet = new(16 * 8, 32 * 4)
    for r, d in enumerate(("down", "left", "right", "up")):
        for i, f in enumerate(player_row(d)):
            sheet.alpha_composite(f, (i * 16, r * 32))
    return sheet


# --------------------------------------------------------------------------
# Crops (16x16, transparent; sit on tilled/watered soil)
# --------------------------------------------------------------------------

CC = {
    "g": "green_dark", "f": "green_forest", "G": "green", "L": "green_grass",
    "l": "green_light", "d": "brown_dark", "M": "brown_mid", "m": "brown",
    "t": "tan", "w": "cream", "W": "white_warm", "k": "pink", "R": "red_dark",
}
E = "................"
MOUND = [
    "....ddMMMMdd....",
    "...dMMMMMMMMd...",
    "....dddddddd....",
]
CROP_SEED = [E] * 12 + [
    "......dddd......",
    "....ddMwMMdd....",
    "...dMMtMMwMMd...",
    "....dddddddd....",
]
CROP_1 = [E] * 7 + [
    "...gg......gg...",
    "..glLg....gLlg..",
    "..gllLg..gLllg..",
    "...gLLLggLLLg...",
    "....gggLLggg....",
    ".......gG.......",
    "....ddMgGMdd....",
    "...dMMMMMMMMd...",
    "....dddddddd....",
]
CROP_2 = [E] * 3 + [
    ".......gg.......",
    "......glLg......",
    "..gg..glLg..gg..",
    ".glLg.gLLg.gLlg.",
    ".gllLggLLggLllg.",
    "..gLLLgLLgLLLg..",
    "...ggLLLLLLgg...",
    ".gglLggLLggLlgg.",
    "gllLLLgLLgLLLllg",
    ".gggggdGGdggggg.",
    "....ddMfGMdd....",
    "...dMMMMMMMMd...",
    "....dddddddd....",
]
CROP_HARVEST = [E] + [
    "....gg....gg....",
    "...glLg..gLlg...",
    "...gllLggLllg...",
    "..gg.gLLLLg.gg..",
    ".glLg.gLLg.gLlg.",
    ".gllLggLLggLllg.",
    "..gLLLgLLgLLLg..",
    "...ggggfGgggg...",
    "....RkkkkkkR....",
    "...RkWkkkkkkR...",
    "...RkWkkkkkkR...",
    "...RwWwwwwwtR...",
    "..dRwwwwwwwtRd..",
    ".dMMRtwwwwtRMMd.",
    "..dddRRRRRRddd..",
]


def build_crops():
    sheet = new(16 * 4, 16)
    for i, rows in enumerate((CROP_SEED, CROP_1, CROP_2, CROP_HARVEST)):
        assert len(rows) == 16 and all(len(r) == 16 for r in rows), i
        f = new(16, 16)
        blit_map(f, rows, CC)
        sheet.alpha_composite(f, (i * 16, 0))
    return sheet


# --------------------------------------------------------------------------

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
        flat.save(outdir / f"{name}_8x.png")
        ups.append(flat)
    # seamless check: 3x3 repeats of each repeating tile
    ts = outputs["farm_tiles"]
    rep = Image.new("RGBA", (8 * 48 * 4, 48 * 4), bg)
    for i in range(8):
        tile = ts.crop((i * 16, 0, i * 16 + 16, 16))
        block = Image.new("RGBA", (48, 48))
        for yy in range(3):
            for xx in range(3):
                block.paste(tile, (xx * 16, yy * 16))
        rep.alpha_composite(block.resize((192, 192), Image.NEAREST), (i * 192, 0))
    rep.save(outdir / "farm_tiles_tiling_4x.png")
    # crops on soil, player on grass scene
    scene = Image.new("RGBA", (128, 64))
    tiles = [ts.crop(((i % 8) * 16, (i // 8) * 16, (i % 8) * 16 + 16, (i // 8) * 16 + 16)) for i in range(13)]
    for y in range(4):
        for x in range(8):
            scene.paste(tiles[(x + y) % 2], (x * 16, y * 16))
    for x in range(1, 4):
        scene.paste(tiles[4], (x * 16, 16)); scene.paste(tiles[5], (x * 16, 32))
    for x in range(8):
        scene.paste(tiles[7], (x * 16, 48))
    scene.alpha_composite(tiles[11], (80, 0)); scene.alpha_composite(tiles[9], (96, 0)); scene.alpha_composite(tiles[11], (112, 0))
    cr = outputs["crop_basic"]
    for i in range(3):
        scene.alpha_composite(cr.crop(((i + 1) * 16, 0, (i + 2) * 16, 16)), ((i + 1) * 16, 32))
        scene.alpha_composite(cr.crop((i * 16, 0, (i + 1) * 16, 16)), ((i + 1) * 16, 16))
    pl = outputs["player_base"]
    scene.alpha_composite(pl.crop((0, 0, 16, 32)), (72, 22))
    scene.alpha_composite(pl.crop((80, 64, 96, 96)), (96, 22))
    scene_up = scene.resize((128 * S, 64 * S), Image.NEAREST)
    scene_up.save(outdir / "m1_scene_8x.png")
    ups.append(scene_up)
    W = max(u.width for u in ups) + 16
    H = sum(u.height + 16 for u in ups) + 16
    allimg = Image.new("RGBA", (W, H), (30, 26, 32, 255))
    y = 16
    for u in ups:
        allimg.alpha_composite(u, (8, y))
        y += u.height + 16
    allimg.save(outdir / "m1_all.png")


def main():
    outputs = {
        "farm_tiles": build_tileset(),
        "player_base": build_player(),
        "crop_basic": build_crops(),
    }
    paths = {
        "farm_tiles": ROOT / "assets/tilesets/farm_tiles.png",
        "player_base": ROOT / "assets/sprites/player_base.png",
        "crop_basic": ROOT / "assets/sprites/crop_basic.png",
    }
    for k, img in outputs.items():
        img.save(paths[k])
        print("wrote", paths[k].relative_to(ROOT), img.size)
    write_swatch(HERE / "palette.png")
    print("wrote tools/art/palette.png")
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], outputs)


if __name__ == "__main__":
    main()
