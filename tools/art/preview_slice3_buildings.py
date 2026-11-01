"""Previews for gen_slice3_buildings (preview-only, nothing here ships)."""
import sys
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))

T = 16
BG = (58, 50, 60, 255)


def tile(sheet, i, cols=8):
    return sheet.crop(((i % cols) * T, (i // cols) * T, (i % cols) * T + T, (i // cols) * T + T))


def grass_field(w, h):
    farm = Image.open(ROOT / "assets/tilesets/farm_tiles.png").convert("RGBA")
    img = Image.new("RGBA", (w, h))
    for y in range(0, h, T):
        for x in range(0, w, T):
            k = (x * 7 + y * 13) // T % 11
            img.paste(tile(farm, (0, 1, 13, 0, 1, 15, 0, 1, 14, 0, 1)[k]), (x, y))
    return img, farm


def up(img, s=8):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)


def on_bg(img, bg=BG):
    flat = Image.new("RGBA", img.size, bg)
    flat.alpha_composite(img)
    return flat


def fence_ring(sheet, cells, gates):
    """Place pasture autotiles for a set of cells; gates = {cell: tile index}."""
    out = []
    for (x, y) in sorted(cells, key=lambda p: (p[1], p[0])):
        if (x, y) in gates:
            i = gates[(x, y)]
        else:
            i = sum(b for b, (dx, dy) in ((1, (0, -1)), (2, (1, 0)), (4, (0, 1)), (8, (-1, 0)))
                    if (x + dx, y + dy) in cells)
        out.append(((x, y), tile(sheet, i)))
    return out


def rect_cells(x0, y0, w, h):
    cells = set()
    for x in range(x0, x0 + w):
        cells |= {(x, y0), (x, y0 + h - 1)}
    for y in range(y0, y0 + h):
        cells |= {(x0, y), (x0 + w - 1, y)}
    return cells


def farm_mock(outputs):
    W, H = 30 * T, 15 * T
    scene, farm = grass_field(W, H)
    past = outputs["pasture_tiles"]
    # dirt path from barn door to the bottom edge
    for y in range(6, 15):
        scene.paste(tile(farm, 7), (5 * T, y * T))
    for x in range(5, 27):
        scene.paste(tile(farm, 7), (x * T, 12 * T))
    sprites = []  # (sort_y, x, y, img)
    barn = outputs["barn_stages"]
    sprites.append((6 * T, 3 * T, 1 * T, barn.crop((320, 0, 400, 80))))      # stage 4 at cells (3..7, 1..5)
    # pasture 8x6 cells, gate in the bottom side above the path
    cells = rect_cells(10, 4, 8, 7)
    gates = {(13, 10): 17, (17, 7): 18}
    for (x, y), t in fence_ring(past, cells, gates):
        sprites.append(((y + 1) * T - 1, x * T, y * T, t))
    for i, (cx, cy) in ((20, (11, 5)), (21, (15, 5)), (22, (12, 5)), (21, (16, 8))):
        sprites.append(((cy + 1) * T - 2, cx * T, cy * T, tile(past, i)))
    # habitat 4x4 at cells (21..24, 7..10), gate opening faces the path
    scene.alpha_composite(outputs["habitat_woodland_ground"], (21 * T, 7 * T))
    sprites.append((11 * T - 1, 21 * T, 7 * T, outputs["habitat_woodland_objects"]))
    # actors: player at the barn door + creatures
    pl = Image.open(ROOT / "assets/sprites/player_base.png").convert("RGBA").crop((0, 0, 16, 32))
    sprites.append((7 * T + 15, 5 * T, 6 * T - 16 + 16, pl))
    for name, (x, y) in (("moss_bun", (12 * T, 7 * T)), ("cinderkin", (14 * T + 8, 8 * T)),
                         ("blue_jay", (22 * T, 8 * T + 4)), ("bramble_cub", (24 * T - 12, 8 * T + 12))):
        p = ROOT / f"assets/sprites/{name}.png"
        if p.exists():
            sprites.append((y + 31, x, y, Image.open(p).convert("RGBA").crop((0, 0, 32, 32))))
    for _, x, y, im in sorted(sprites, key=lambda s: s[0]):
        scene.alpha_composite(im, (x, y))
    return scene


def preview(outdir, outputs):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    ups = []
    # 1 pasture tileset on grass + labelled usage ring
    past = outputs["pasture_tiles"]
    g, _ = grass_field(past.width, past.height)
    g.alpha_composite(past)
    im = up(g)
    im.save(outdir / "slice3_buildings_pasture_8x.png")
    ups.append(im)
    ring, _ = grass_field(9 * T, 6 * T)
    cells = rect_cells(1, 1, 7, 4)
    for (x, y), t in fence_ring(past, cells, {(4, 4): 16, (4, 1): 17, (1, 2): 18, (7, 2): 19}):
        ring.alpha_composite(t, (x * T, y * T))
    im = up(ring, 6)
    im.save(outdir / "slice3_buildings_pasture_ring_6x.png")
    ups.append(im)
    # 2 habitat: full / ground / objects
    hab, _ = grass_field(3 * 80 + 16, 96)
    for i, k in enumerate(("habitat_woodland", "habitat_woodland_ground", "habitat_woodland_objects")):
        hab.alpha_composite(outputs[k], (16 + i * 80, 16))
    im = up(hab)
    im.save(outdir / "slice3_buildings_habitat_8x.png")
    ups.append(im)
    # 3 barn stages on grass with a tile grid hint (1px dark on the grass behind, preview only)
    barn = outputs["barn_stages"]
    bg, _ = grass_field(barn.width, barn.height + 16)
    bg.alpha_composite(barn)
    im = up(bg, 4)
    im.save(outdir / "slice3_buildings_barn_4x.png")
    up(bg).save(outdir / "slice3_buildings_barn_8x.png")
    ups.append(im)
    # 4 mock farm
    mock = farm_mock(outputs)
    mock.save(outdir / "slice3_buildings_farm_mock_1x.png")
    im = up(mock, 3)
    im.save(outdir / "slice3_buildings_farm_mock_3x.png")
    ups.append(im)
    Wd = max(u.width for u in ups) + 16
    Hd = sum(u.height + 16 for u in ups) + 16
    allimg = Image.new("RGBA", (Wd, Hd), (30, 26, 32, 255))
    y = 16
    for u in ups:
        allimg.alpha_composite(u, (8, y))
        y += u.height + 16
    allimg.save(outdir / "slice3_p3_all.png")
