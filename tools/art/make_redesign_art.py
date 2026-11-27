"""Draw ART-2 sprites in DB16. Run with --check to verify existing PNGs."""
import argparse
from pathlib import Path

from PIL import Image

from make_battle_art import DB16, img, rgb

ART_DIR = Path(__file__).resolve().parents[2] / "assets" / "art"

# The lowered head sits forward of the shoulders. The far leg trails the cane.
VILLAGER = (
    "................",
    "................",
    "................",
    "......GGG.......",
    ".....GSSSG......",
    "....DGSSsSG.....",
    "...DgGssKsG.....",
    "..DggDGGssG.....",
    "..DgDgDGGG......",
    "..DDDggDsssAB...",
    "...DODDD...B....",
    "...GOOG....B....",
    "..GOOGG....B....",
    "..GO..GO...B....",
    "..KGG.KGG..A....",
    "................",
)

# Each stone is a full-cell swatch. The puzzle defines the overall piece
# footprint by repeating the swatch over its occupied cells.
STONES = {
    # The diagonal facet wraps around both axes when repeated.
    "stone_wedge": tuple(
        "".join(
            "W" if (x, y) in {(5, 1), (4, 2)}
            else "G" if (x, y) in {(8, 6), (7, 7)}
            else "O" if (x + y) % 16 >= 11
            else "S"
            for x in range(16)
        )
        for y in range(16)
    ),
    "stone_bar": (
        "SSSSSSSSSSSSSSSS",
        "SSSSWWWSSSSSSSSS",
        "SSSSSSSSSSSSSSSS",
        "OOOOOOOOOOOOOOOO",
        "OOOOOOOOOOOOOOOO",
        "GGGGGGGGGGGGGGGG",
        "OOOOOOOOOOOOOOOO",
        "SSSSSSSSSSSSSSSS",
        "SSSSSSSSWWSSSSSS",
        "SSSSSSSSSSSSSSSS",
        "SSSSSSSSSSSSSSSS",
        "OOOOOOOOOOOOOOOO",
        "OOOOOOOOOOOOOOOO",
        "GGGGGGGGGGGGGGGG",
        "OOOOOOOOOOOOOOOO",
        "SSSSSSSSSSSSSSSS",
    ),
    "stone_corner": (
        "OOOOOOOOOOOOOOOO",
        "OOOOOOOOOOOOOOOO",
        "OOSSSSSSSSSSSSOO",
        "OOSWWWWWWWSSSSOO",
        "OOSWOOOOOOOOOOOO",
        "OOSWOOOOOOOOOOOO",
        "OOSWOOGGGGGGGGOO",
        "OOSWOOGOOOOOOOOO",
        "OOSWOOGOOOOOOOOO",
        "OOSSOOGOOOSSOOOO",
        "OOSSOOGOOOOOOOOO",
        "OOSSOOGOOOOOOOOO",
        "OOSSOOGOOOOOOOOO",
        "OOSSOOGOOOOOOOOO",
        "OOOOOOOOOOOOOOOO",
        "OOOOOOOOOOOOOOOO",
    ),
    "stone_square": (
        "OOOGGGGGGGGGGOOO",
        "OOSSSSSSSSSSSSOO",
        "OSSWWWWWWWWWSSGO",
        "GSSWSSSSSSSSOGGG",
        "GSSWSSSSSSSOOGGG",
        "GSSWSSSSSSSOOGGG",
        "GSSWSSSSSSOOOGGG",
        "GSSSSSSSSSOOOGGG",
        "GSSSSSSSSOOOOGGG",
        "GSSSSSSSOOOOOGGG",
        "GSSSSSSOOOOOOGGG",
        "GSSSSOOOOOOOOGGG",
        "GSOOOOOOOOOOOGGG",
        "OGGGGGGGGGGGGGGO",
        "OOGGGGGGGGGGGGOO",
        "OOOGGGGGGGGGGOOO",
    ),
}

STAKE = (
    "................",
    ".......B........",
    "......BAB.......",
    "......AsB.......",
    ".....BAsBB......",
    ".....BAABB......",
    ".....BAPBB......",
    ".....PPPPP......",
    ".....OssOP......",
    ".....PPPPP......",
    ".....BABPB......",
    ".....BABPB......",
    ".....BAABB......",
    ".....BABBB......",
    ".....BPBBP......",
    ".....PPPPP......",
)

SPRITES = {
    "units/villager_slow.png": VILLAGER,
    **{f"work/{name}.png": rows for name, rows in STONES.items()},
    "work/stake.png": STAKE,
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="only verify PNGs")
    args = parser.parse_args()
    palette = {rgb(key)[:3] for key in DB16}

    for relative, rows in SPRITES.items():
        path = ART_DIR / relative
        if not args.check:
            if len(rows) != 16 or any(len(row) != 16 for row in rows):
                raise ValueError(f"{relative}: expected a 16×16 drawing")
            path.parent.mkdir(parents=True, exist_ok=True)
            img(rows).save(path)

        with Image.open(path) as source:
            pixels = source.convert("RGBA")
        if pixels.size != (16, 16):
            raise ValueError(f"{relative}: expected a 16×16 PNG")
        colors = pixels.getcolors(256)
        alpha = {color[3] for _, color in colors}
        opaque = {color[:3] for _, color in colors if color[3] == 255}
        if not alpha <= {0, 255} or not opaque <= palette:
            raise ValueError(f"{relative}: invalid alpha or palette")
        if relative.startswith("units/") and alpha != {0, 255}:
            raise ValueError(f"{relative}: expected a unit on a transparent background")
        if relative.startswith("work/stone_") and alpha != {255}:
            raise ValueError(f"{relative}: expected an opaque full-cell stone")
        print(f"{relative}: 16×16, {len(opaque)} DB16 colors, alpha {sorted(alpha)}")


if __name__ == "__main__":
    main()
