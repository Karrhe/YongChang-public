"""Snap an AI-generated image to a DB16 pixel grid.
Usage: python to_db16.py SRC OUT W H [--crop x,y,w,h] [--key] [--preview N]
  --crop     crop the source first (pixels of the source image)
  --key      treat magenta (#ff00ff-ish) as transparent
  --preview  also write OUT with _preview_xN, enlarged with nearest neighbour
Downsamples with a box filter, then maps every pixel to the nearest DB16 color."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image

DB16 = ["140c1c", "442434", "30346d", "4e4a4e", "854c30", "346524", "d04648", "757161",
        "597dce", "d27d2c", "8595a1", "6daa2c", "d2aa99", "6dc2ca", "dad45e", "deeed6"]
PAL = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in DB16], dtype=np.float32)

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("out"); ap.add_argument("w", type=int); ap.add_argument("h", type=int)
ap.add_argument("--crop"); ap.add_argument("--key", action="store_true"); ap.add_argument("--preview", type=int, default=0)
ap.add_argument("--mode", action="store_true", help="majority color per block (cleaner faces; no --key)")
a = ap.parse_args()

img = Image.open(a.src).convert("RGB")
if a.crop:
    x, y, w, h = map(int, a.crop.split(","))
    img = img.crop((x, y, x + w, y + h))
rgb = np.asarray(img).astype(np.float32)
alpha = np.full(rgb.shape[:2], 255.0, dtype=np.float32)
if a.key:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    alpha[(r > 150) & (b > 150) & (g < 110)] = 0
if a.mode:
    # snap every source pixel to DB16 first, then give each output pixel the most common color in its block
    big = np.asarray(Image.fromarray(rgb.astype(np.uint8)).resize((a.w * 8, a.h * 8), Image.LANCZOS)).astype(np.float32)
    idx = ((big[..., None, :] - PAL[None, None]) ** 2).sum(-1).argmin(-1)
    blocks = idx.reshape(a.h, 8, a.w, 8).transpose(0, 2, 1, 3).reshape(a.h, a.w, 64)
    counts = np.stack([(blocks == k).sum(-1) for k in range(16)], -1)
    q = PAL[counts.argmax(-1)].astype(np.uint8)
    sa = np.full((a.h, a.w), 255.0)
else:
    pm = np.dstack([rgb * (alpha[..., None] / 255.0), alpha]).astype(np.uint8)
    small = np.asarray(Image.fromarray(pm, "RGBA").resize((a.w, a.h), Image.BOX)).astype(np.float32)
    sa = small[..., 3]
    col = small[..., :3] / np.maximum(sa[..., None] / 255.0, 1e-3)
    q = PAL[((col[..., None, :] - PAL[None, None]) ** 2).sum(-1).argmin(-1)].astype(np.uint8)
out = Image.fromarray(np.dstack([q, np.where(sa >= 128, 255, 0).astype(np.uint8)]), "RGBA")
out.save(a.out)
if a.preview:
    p = Path(a.out)
    out.resize((a.w * a.preview, a.h * a.preview), Image.NEAREST).save(p.with_name(f"{p.stem}_preview_x{a.preview}.png"))
print(a.out, out.size)
