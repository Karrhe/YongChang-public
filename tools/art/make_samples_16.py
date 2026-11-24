"""Baseline B (ART-002 §11): 16x16 samples drawn as character grids, DB16 only.
Wang Cheng, a sea raider, and the stone wall in three states (intact / cracked / ruin).
Usage: python make_samples_16.py OUTDIR
Writes each sprite at native 16x16 and a x8 preview sheet."""
import sys
from pathlib import Path
from PIL import Image

DB16 = {
    "K": "140c1c", "P": "442434", "N": "30346d", "G": "4e4a4e", "B": "854c30", "D": "346524",
    "R": "d04648", "O": "757161", "L": "597dce", "A": "d27d2c", "S": "8595a1", "g": "6daa2c",
    "s": "d2aa99", "C": "6dc2ca", "y": "dad45e", "W": "deeed6",
}

WANG = [  # straw hat, long spear, short tunic, rolled trousers, sandals
    "..............S.",
    ".....KKKKK...KWK",
    "....KyyAyyK..KSK",
    "...KyAAAAAyK..B.",
    ".KKAAAAAAAAAKKB.",
    "..KKKKKKKKKKK.B.",
    "....KssssssK..B.",
    "....KsKssKsK..B.",
    "....KssssssK..B.",
    "...KKOKssKOKK.B.",
    "..KOOOOOOOOOOKsK",
    "..KsKOOOOOOKKKB.",
    "..KsKBBBBBBK..B.",
    "...K.KLLLLK...B.",
    "....KssK.KssK.B.",
    "...KBBK...KBBK..",
]

RAIDER = [  # red head wrap, ragged dark tunic, short blade, barefoot
    "................",
    ".....KKKKKK.....",
    "....KRRRRRRK....",
    "...KRRPRRRRRK...",
    "....KssssssK....",
    "....KsKssKsK....",
    "....KsPPPPsK....",
    ".....KPPPPK.....",
    "...KKPPGGPPKK...",
    "..KsKPPPPPPKsK..",
    "..KsKGBBBBGKsKK.",
    "...KKPPPPPPK.KSK",
    "....KPPKKPPK..KS",
    "....KPPK.KPPK...",
    "....KssK..KssK..",
    "...KssK....KssK.",
]


def wall(state):
    """Stone wall tile: top cap (rows 0-3) + front face of diagonally laid stones."""
    g = [["." for _ in range(16)] for _ in range(16)]
    for y in range(16):
        for x in range(16):
            if y <= 3:
                g[y][x] = "W" if y == 0 else ("S" if y < 3 else "G")
                if y == 0 and x % 4 == 3:
                    g[y][x] = "S"
            else:
                joint = (x + y) % 4 == 0
                band = ((x - y) // 4) % 2
                g[y][x] = "G" if joint else ("S" if band else "O")
                if y == 15:
                    g[y][x] = "K"
    if state in ("cracked", "ruin"):
        for x, y in [(9, 1), (8, 2), (8, 3), (7, 4), (7, 5), (8, 6), (8, 7), (7, 8), (6, 9), (6, 10), (7, 11)]:
            g[y][x] = "K"
        for x, y in [(2, 0), (3, 0), (13, 0), (14, 0), (14, 1)]:
            g[y][x] = "."
    if state == "ruin":
        # wall knocked down: only rubble and the stump of the lower courses remain
        rubble = [
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "................",
            "......KK........",
            "..KK.KSOK...KK..",
            ".KSOKKOOGK.KSOK.",
            "KSOOGSOGOOKSOOGK",
            "KOGOOOGOOGOOGOOK",
            "GOOGOOGOOOGOOGOG",
            "OGOOGOOGOOGOOGOO",
            "KKKKKKKKKKKKKKKK",
        ]
        g = [list(r) for r in rubble]
    return ["".join(r) for r in g]


def to_img(rows):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == 16, (y, row)
        for x, ch in enumerate(row):
            if ch != ".":
                h = DB16[ch]
                img.putpixel((x, y), (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255))
    return img


def main(outdir):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    sprites = {
        "unit_wang_cheng": WANG, "unit_raider": RAIDER,
        "tile_stone_wall_intact": wall("intact"), "tile_stone_wall_cracked": wall("cracked"),
        "tile_stone_wall_ruin": wall("ruin"),
    }
    scale, gap = 8, 8
    sheet = Image.new("RGBA", (len(sprites) * (16 * scale + gap) + gap, 16 * scale + 2 * gap), (96, 112, 88, 255))
    for i, (name, rows) in enumerate(sprites.items()):
        img = to_img(rows)
        img.save(out / f"{name}.png")
        sheet.alpha_composite(img.resize((16 * scale, 16 * scale), Image.NEAREST), (gap + i * (16 * scale + gap), gap))
    sheet.convert("RGB").save(out / "B_samples_16_preview_x8.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
