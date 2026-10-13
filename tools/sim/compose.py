"""Renders stub snapshots (draw-call logs) to PNG using the game's tile tables.

    python3 compose.py <source>/images out.png snap1.log snap2.log ...
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

IMG = Path(sys.argv[1])  # source/images
tables = {s: Image.open(IMG / f"tiles{s}-table-{s}-{s}.png").convert("RGBA") for s in (8, 16, 32)}
FLIP = {"none": lambda t: t, "flipX": lambda t: t.transpose(Image.FLIP_LEFT_RIGHT),
        "flipY": lambda t: t.transpose(Image.FLIP_TOP_BOTTOM), "flipXY": lambda t: t.transpose(Image.ROTATE_180)}


def render(log):
    im = Image.new("RGBA", (400, 240), (0, 0, 0, 255))
    d = ImageDraw.Draw(im)
    for line in log.read_text().splitlines():
        p = line.split(" ")
        if p[0] == "T":
            s, idx, x, y, flip = int(p[1]), int(p[2]), int(p[3]), int(p[4]), p[5]
            t = tables[s]
            cols = t.width // s
            tile = t.crop(((idx % cols) * s, (idx // cols) * s, (idx % cols + 1) * s, (idx // cols + 1) * s))
            tile = FLIP[flip](tile)
            # ink is white; when drawn over a white fill it would vanish, so draw ink black on white boxes
            im.alpha_composite(tile, (x, y))
        elif p[0] in ("F", "R"):
            x, y, w, h, c = int(p[1]), int(p[2]), int(p[3]), int(p[4]), p[5]
            col = (255, 255, 255, 255) if c == "white" else (0, 0, 0, 255)
            if p[0] == "F":
                d.rectangle((x, y, x + w - 1, y + h - 1), fill=col)
            else:
                d.rectangle((x, y, x + w - 1, y + h - 1), outline=col)
        elif p[0] == "X":
            x, y, w = int(p[1]), int(p[2]), int(p[3])
            text = " ".join(p[4:])
            d.text((x, y), text, fill=(0, 0, 0, 255))
    return im


outs = [render(Path(a)) for a in sys.argv[3:]]
cols = min(3, len(outs))
rows = (len(outs) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * 404, rows * 244), (200, 30, 30, 255))
for i, im in enumerate(outs):
    sheet.paste(im, ((i % cols) * 404, (i // cols) * 244))
sheet.save(sys.argv[2])
