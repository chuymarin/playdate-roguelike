"""Builds the game's tile image tables, and checks source/config/kits.json.

Run from the repo root:  python3 tools/build_kits.py

Kenney's 1-Bit Pack sheet (16x16 tiles, light ink on a transparent
background) becomes three Playdate image tables with white ink on a
transparent background, one per drawing size:

- images/tiles8   (1/2)  the 4x4 map screen; a pixel is ink when at least
                         2 of the 4 source pixels it covers are
- images/tiles16  (1x)   the HUD
- images/tiles32  (2x)   rooms

All three keep the sheet's order, so a tile's sheet index n (row * columns +
col, from 0) is image n + 1 in every table. source/config/kits.json names which
tiles each area kind uses; the game reads it at startup (tiles/kits.lua), so
editing it only needs a rebuild with pdc. This script is only needed when the
sheet changes; it also checks kits.json lists real tiles.
"""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
KITS = ROOT / "source/config/kits.json"
IMAGES = ROOT / "source/images"
SIZES = (8, 16, 32)  # drawn tile sizes, one image table each
INK_THRESHOLD = 128  # sheet pixels brighter (and opaque) than this are ink
HALF_MIN_INK = 2     # of the 4 pixels a half-size pixel covers


def ink_mask(sheet):
    """[y][x] True where the sheet has ink."""
    w, h = sheet.size
    px = sheet.load()
    return [[px[x, y][3] > 0 and px[x, y][0] > INK_THRESHOLD for x in range(w)] for y in range(h)]


def ink_image(mask):
    h, w = len(mask), len(mask[0])
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = out.load()
    for y in range(h):
        for x in range(w):
            if mask[y][x]:
                px[x, y] = (255, 255, 255, 255)
    return out


def half(mask):
    h, w = len(mask) // 2, len(mask[0]) // 2
    return [
        [mask[2 * y][2 * x] + mask[2 * y][2 * x + 1] + mask[2 * y + 1][2 * x] + mask[2 * y + 1][2 * x + 1] >= HALF_MIN_INK for x in range(w)]
        for y in range(h)
    ]


def build_tables(config):
    sheet = Image.open(ROOT / config["sheet"]).convert("RGBA")
    size, cols = config["tileSize"], config["columns"]
    rows = sheet.height // size
    mask = ink_mask(sheet)
    IMAGES.mkdir(parents=True, exist_ok=True)
    for px in SIZES:
        for old in IMAGES.glob(f"tiles{px}-table-*.png"):
            old.unlink()
        if px < size:
            image = ink_image(half(mask))
        else:
            image = ink_image(mask).resize((cols * px, rows * px), Image.NEAREST)
        image.save(IMAGES / f"tiles{px}-table-{px}-{px}.png")
        print(f"images/tiles{px}: {cols * rows} tiles of {px}px")


def check_kits(config, count):
    """Every tile in kits.json is on the sheet."""
    bad = []
    for group in ("kits", "walls"):
        for kind, slots in config.get(group, {}).items():
            for slot, tiles in slots.items():
                bad += [f"{group}.{kind}.{slot}: {t}" for t in tiles if not 0 <= t < count]
    if bad:
        raise SystemExit("kits.json names tiles that aren't on the sheet:\n  " + "\n  ".join(bad))


def main():
    config = json.loads(KITS.read_text())
    build_tables(config)
    sheet = Image.open(ROOT / config["sheet"])
    check_kits(config, (sheet.width // config["tileSize"]) * (sheet.height // config["tileSize"]))
    print("kits.json: ok")


if __name__ == "__main__":
    main()
