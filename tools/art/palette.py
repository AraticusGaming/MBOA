"""MBOA master palette (32 base colors + 6 ember colors + 4 woodland colors, 42 total). All game art must use ONLY these colors
(plus fully transparent pixels). Warm, slightly desaturated, cozy 16-bit look.

Run directly to regenerate tools/art/palette.png (8-column grid of 16x16 swatches,
index order left-to-right, top-to-bottom)."""
from pathlib import Path

PALETTE = [
    # idx  name             hex
    ("outline",      "#2b1d24"),  # 0  dark plum-brown, default outline (never pure black)
    ("brown_dark",   "#4a2f2a"),  # 1
    ("brown",        "#6e4433"),  # 2
    ("brown_mid",    "#8f5f3f"),  # 3
    ("brown_light",  "#b07d4f"),  # 4
    ("tan",          "#d4a46a"),  # 5
    ("sand",         "#e8c88e"),  # 6
    ("cream",        "#f6e7c1"),  # 7
    ("green_dark",   "#24452f"),  # 8
    ("green_forest", "#36643a"),  # 9
    ("green",        "#4f8a3c"),  # 10
    ("green_grass",  "#6fa640"),  # 11
    ("green_light",  "#9cc44f"),  # 12
    ("green_pale",   "#c9de78"),  # 13
    ("soil_dark",    "#3d2622"),  # 14
    ("soil_wet",     "#5a3a30"),  # 15
    ("stone_dark",   "#4d4a55"),  # 16
    ("stone",        "#7a7472"),  # 17
    ("stone_light",  "#a8a094"),  # 18
    ("stone_pale",   "#cfc6b4"),  # 19
    ("red_dark",     "#7a2e2e"),  # 20
    ("red",          "#b8443a"),  # 21
    ("orange",       "#e07a3c"),  # 22
    ("yellow",       "#f2c14e"),  # 23
    ("yellow_pale",  "#f9e79f"),  # 24
    ("skin_shadow",  "#c27c5a"),  # 25
    ("skin",         "#eab08a"),  # 26
    ("blue_dark",    "#2f3e66"),  # 27
    ("blue",         "#4a6aa5"),  # 28
    ("blue_light",   "#7fa8d4"),  # 29
    ("pink",         "#d97c8e"),  # 30
    ("white_warm",   "#fffaf0"),  # 31
    # --- ember extension (Cinderkin, appended; indices 0-31 never change) ---
    ("ember_deep",   "#c23b22"),  # 32 deep red-orange, flame edges
    ("ember_orange", "#f26b2a"),  # 33 hot orange, flame body
    ("ember_amber",  "#ffa23a"),  # 34 amber, flame mid / eyes
    ("ember_yellow", "#ffd25a"),  # 35 bright yellow, flame core
    ("ember_cream",  "#fff2c2"),  # 36 pale yellow-cream, hottest highlight
    ("ember_glow",   "#e8894e"),  # 37 soft glow orange, ear interiors / membranes
    # --- woodland extension (slice 3 Woodland room, appended; indices 0-37 never change) ---
    ("loam",         "#5b4a31"),  # 38 olive-brown forest floor
    ("loam_dark",    "#3f3427"),  # 39 forest floor shade, shadows under the canopy
    ("moss",         "#85963d"),  # 40 muted olive moss
    ("canopy_deep",  "#1a3126"),  # 41 deepest canopy shadow (gaps in the tree wall)
]

def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

RGB = [_rgb(h) for _, h in PALETTE]
RGBA = [c + (255,) for c in RGB]
IDX = {name: i for i, (name, _) in enumerate(PALETTE)}
TRANSPARENT = (0, 0, 0, 0)

def c(name_or_idx):
    """RGBA tuple for a palette name or index."""
    i = IDX[name_or_idx] if isinstance(name_or_idx, str) else name_or_idx
    return RGBA[i]

def write_swatch(path, cell=16, cols=8):
    from PIL import Image
    rows = (len(RGB) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell, rows * cell), TRANSPARENT)
    px = img.load()
    for i, col in enumerate(RGBA):
        x0, y0 = (i % cols) * cell, (i // cols) * cell
        for y in range(cell):
            for x in range(cell):
                px[x0 + x, y0 + y] = col
    img.save(path)

if __name__ == "__main__":
    out = Path(__file__).with_name("palette.png")
    write_swatch(out)
    print("wrote", out)
