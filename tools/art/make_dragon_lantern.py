"""E6 ending illustration: the character-forming dragon lantern (拼字龙灯) spelling 天下太平.
320x180, DB16. Each stroke is a lantern body section (scale pattern, fringe below) held up on
red-and-white poles; one dragon color per character (red / yellow / green / blue), the black
dragon's head leads on the left and its tail closes on the right. Drawn by script so the
characters are exact. Usage: python make_dragon_lantern.py OUT.png"""
import sys
from PIL import Image, ImageDraw

DB = {"K": (20, 12, 28), "P": (68, 36, 52), "N": (48, 52, 109), "G": (78, 74, 78), "B": (133, 76, 48),
      "D": (52, 101, 36), "R": (208, 70, 72), "O": (117, 113, 97), "L": (89, 125, 206), "A": (210, 125, 44),
      "S": (133, 149, 161), "g": (109, 170, 44), "s": (210, 170, 153), "C": (109, 194, 202),
      "y": (218, 212, 94), "W": (222, 238, 214)}

W, H = 320, 180
im = Image.new("RGB", (W, H), DB["K"])
d = ImageDraw.Draw(im)

# night sky + far wall + ground
d.rectangle([0, 0, W, 120], fill=DB["K"])
for x in range(0, W, 7):
    if (x * 37) % 11 < 2:
        d.point((x, (x * 13) % 60), fill=DB["S"])
d.rectangle([0, 128, W, 140], fill=DB["P"])
for x in range(0, W, 12):
    d.rectangle([x, 124, x + 6, 128], fill=DB["P"])
d.rectangle([0, 141, W, H], fill=DB["G"])
for x in range(0, W, 16):
    d.line([x, 141, x + 8, H], fill=DB["K"])

# stroke layout per character on a 7x7 cell grid; strokes are (x0, y0, x1, y1) in cells
CHARS = {
    "天": [(1, 1, 5, 1), (0, 3, 6, 3), (3, 1, 3, 3), (3, 3, 0, 6), (3, 3, 6, 6)],
    "下": [(0, 1, 6, 1), (3, 1, 3, 6), (3, 3, 5, 4)],
    "太": [(0, 2, 6, 2), (3, 0, 3, 2), (3, 2, 0, 6), (3, 2, 6, 6), (2, 5, 3, 6)],
    "平": [(0, 1, 6, 1), (1, 2, 2, 3), (5, 2, 4, 3), (0, 4, 6, 4), (3, 1, 3, 6)],
}
COLORS = [("R", "y"), ("y", "A"), ("g", "D"), ("L", "N")]  # (body, scale shade) per character
CELL, TH = 8, 6  # cell size in px, stroke thickness
ORIGINS = [(30, 30), (100, 30), (170, 30), (240, 30)]


def seg(x0, y0, x1, y1, body, shade):
    """Draw one lantern section along a line, with outline, scales and a yellow fringe."""
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    pts = [(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps) for i in range(steps + 1)]
    for (px, py) in pts:
        d.rectangle([px - TH // 2 - 1, py - TH // 2 - 1, px + TH // 2 + 1, py + TH // 2 + 1], fill=DB["K"])
    for i, (px, py) in enumerate(pts):
        d.rectangle([px - TH // 2, py - TH // 2, px + TH // 2, py + TH // 2], fill=DB[body])
        if i % 3 == 0:
            d.rectangle([px - 1, py - 1, px, py], fill=DB[shade])
    if abs(y1 - y0) < abs(x1 - x0) * 0.3:  # mostly horizontal: fringe below
        for (px, py) in pts[::2]:
            d.point((px, py + TH // 2 + 2), fill=DB["y"])


poles = []
for char, (ox, oy), (body, shade) in zip(CHARS, ORIGINS, COLORS):
    for (a, b, c, e) in CHARS[char]:
        seg(ox + a * CELL, oy + b * CELL, ox + c * CELL, oy + e * CELL, body, shade)
    for (a, b, c, e) in CHARS[char]:  # one pole under each stroke's midpoint
        poles.append((ox + (a + c) * CELL // 2, oy + max(b, e) * CELL + TH, body))

# poles and bearers (bearers wear the dragon color)
for (px, py, body) in poles:
    for y in range(py, 132):
        d.point((px, y), fill=DB["R"] if (y // 3) % 2 else DB["W"])
for (px, py, body) in poles[::2]:
    d.rectangle([px - 2, 132, px + 2, 135], fill=DB["s"])  # head
    d.rectangle([px - 3, 136, px + 3, 146], fill=DB[body])  # body
    d.rectangle([px - 3, 147, px - 1, 152], fill=DB["K"])
    d.rectangle([px + 1, 147, px + 3, 152], fill=DB["K"])

# black dragon: head on the left, tail on the right
head = ["....KKKK....", "..KKGWGGKK..", ".KGGRGGGGGK.", "KGyGGGGGGGGK", "KGGGGGGGRRK.",
        "KGGGGGGKKK..", ".KGGGGK.....", "..KyKyK....."]
for y, r in enumerate(head):
    for x, c in enumerate(r):
        if c != ".":
            d.point((6 + x, 54 + y), fill=DB[c])
tail = ["....KK", "..KKGK", ".KGGK.", "KGGGK.", ".KGGGK", "..KKGGK", "....KK."]
for y, r in enumerate(tail):
    for x, c in enumerate(r):
        if c != ".":
            d.point((302 + x, 56 + y), fill=DB[c])
for x in range(18, 30):
    d.point((x, 58), fill=DB["G"])
for x in range(292, 302):
    d.point((x, 60), fill=DB["G"])

# a red lead lantern on a bamboo pole
d.line([12, 132, 12, 88], fill=DB["B"])
d.line([12, 88, 22, 82], fill=DB["B"])
d.rectangle([20, 84, 26, 92], fill=DB["R"])
d.point((23, 93), fill=DB["y"])

im.save(sys.argv[1] if len(sys.argv) > 1 else "dragon_lantern.png")
