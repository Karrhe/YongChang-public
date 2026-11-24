"""Hand-fix for the hall background (ART-002 §10 step 4): whitewashed walls were snapped to pink skin
(#d2aa99) and floor shadows to bright blue (#597dce). Above the floor line pink -> wall white
(#deeed6); straw mats on the floor pink -> straw (#d27d2c is too strong, use #dad45e only on edges)
-> keep mats as #d2aa99; blue -> stone gray (#8595a1 / #4e4a4e). Usage: python fix_hall.py IN OUT"""
import sys
from PIL import Image
PINK, WHITE = (210, 170, 153), (222, 238, 214)
BLUE, NAVY, GRAY, DARK = (89, 125, 206), (48, 52, 109), (133, 149, 161), (78, 74, 78)
im = Image.open(sys.argv[1]).convert("RGB")
w, h = im.size
floor = int(h * 0.70)  # floor line (pixels below this are floor)
px = im.load()
for y in range(h):
    for x in range(w):
        c = px[x, y]
        if c == PINK and y < floor:
            px[x, y] = WHITE
        elif c == BLUE:
            px[x, y] = GRAY if y < floor else DARK
        elif c == NAVY and y >= floor:
            px[x, y] = DARK
im.save(sys.argv[2])
