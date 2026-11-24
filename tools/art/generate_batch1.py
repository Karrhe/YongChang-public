#!/usr/bin/env python3
"""Generate original ART-001 batch 1 sprites. Requires Pillow."""

import argparse
import json
from pathlib import Path
from random import Random

from PIL import Image, ImageColor, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
INK, PLUM, WOOD, RUST, GREY, STONE, SKIN, CREAM = (
    "#140c1c", "#442434", "#854c30", "#d27d2c",
    "#4e4a4e", "#8595a1", "#d2aa99", "#deeed6",
)
NAVY, BLUE, WATER, MUD, GREEN, LEAF, GOLD, RED = (
    "#30346d", "#597dce", "#6dc2ca", "#757161",
    "#346524", "#6daa2c", "#dad45e", "#d04648",
)
PALETTE = {
    ImageColor.getrgb(color) for color in (
        INK, PLUM, WOOD, RUST, GREY, STONE, SKIN, CREAM,
        NAVY, BLUE, WATER, MUD, GREEN, LEAF, GOLD, RED,
    )
}


def canvas(background=None, width=16):
    image = Image.new("RGBA", (width, 16), background or (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def land(background, shades, seed):
    image, draw = canvas(background)
    rng = Random(seed)
    for _ in range(29):
        x, y = rng.randrange(15), rng.randrange(16)
        draw.line((x, y, x + rng.randrange(2), y), rng.choice(shades))
    return image


def field():
    image, draw = canvas(GREEN)
    for y in range(1, 16, 4):
        draw.line((0, y + 1, 15, y + 1), MUD)
        for x in range(1, 15, 4):
            draw.line((x, y + 1, x + 1, y), LEAF)
            draw.point((x + 2, y), GOLD)
    return image


def water(background, crest, phase):
    image, draw = canvas(background)
    for x, y, length in [(1, 2, 5), (9, 5, 5), (4, 9, 7), (0, 13, 4), (10, 14, 5)]:
        for dx in range(length):
            draw.point(((x + dx + phase) % 16, y), crest if dx < length - 2 else STONE)
    return image


def house(hall=False):
    image = land(MUD if hall else GREEN, (WOOD, LEAF), 24)
    draw = ImageDraw.Draw(image)
    draw.rectangle((2, 11, 14, 14), fill=MUD)
    draw.rectangle((3, 7, 12, 12), fill=CREAM if hall else SKIN, outline=WOOD)
    draw.rectangle((6, 9, 9, 12), fill=INK)
    draw.line((4, 9, 4, 10), GOLD)
    draw.line((11, 9, 11, 10), GOLD)
    draw.polygon([(0, 8), (4, 4), (5, 2), (10, 2), (11, 4), (15, 8)],
                 fill=PLUM if hall else WOOD, outline=INK)
    draw.line((4, 4, 11, 4), RED if hall else RUST)
    draw.line((2, 7, 13, 7), RED if hall else SKIN)
    if hall:
        draw.rectangle((6, 8, 9, 9), fill=RED)
        draw.point((7, 8), GOLD)
    return image


def stonework(draw, left, top, right, bottom):
    draw.rectangle((left, top, right, bottom), fill=GREY)
    for y in range(top, bottom, 3):
        offset = 2 if (y - top) % 6 else 0
        for x in range(left - offset, right + 1, 4):
            start, end = max(left, x), min(right, x + 2)
            if start <= end:
                draw.line((start, y, end, y), STONE)
                if y + 1 <= bottom:
                    draw.line((start, y + 1, end, y + 1), MUD)


def wall(material, condition):
    image, draw = canvas()
    if material == "stone":
        if condition == "ruin":
            for x, y in [(1, 9), (5, 7), (8, 10), (12, 8)]:
                draw.polygon([(x, y + 2), (x + 1, y), (x + 3, y), (x + 3, y + 2)],
                             fill=STONE, outline=GREY)
        else:
            stonework(draw, 0, 5, 15, 11)
            draw.line((0, 12, 15, 12), INK)
            if condition == "cracked":
                draw.line([(8, 5), (6, 7), (8, 8), (7, 11)], PLUM, width=2)
        return image

    if condition == "ruin":
        draw.line([(0, 10), (4, 7), (6, 9)], WOOD, width=2)
        draw.line([(9, 11), (13, 8), (15, 9)], WOOD, width=2)
        for x, y in [(2, 11), (7, 12), (12, 6), (14, 12)]:
            draw.line((x, y, x + 1, y - 1), RUST)
        return image

    draw.rectangle((0, 7, 15, 10), fill=WOOD, outline=PLUM)
    for x in (1, 5, 9, 13):
        tip = 6 if condition == "cracked" and x == 9 else 3
        draw.polygon([(x, tip + 2), (x + 1, tip), (x + 2, tip + 2),
                      (x + 2, 12), (x, 12)], fill=RUST, outline=WOOD)
        draw.point((x + 1, 8), GOLD)
    if condition == "cracked":
        draw.line([(8, 8), (10, 9), (9, 11)], INK)
    return image


def gate(material, opened):
    image, draw = canvas()
    if material == "stone":
        stonework(draw, 0, 3, 15, 6)
        for left in (0, 12):
            stonework(draw, left, 6, left + 3, 13)
        draw.line((4, 6, 11, 6), INK)
    else:
        for left in (0, 13):
            draw.rectangle((left, 4, left + 2, 13), fill=WOOD, outline=PLUM)
            draw.line((left + 1, 4, left + 1, 12), RUST)

    leaf_edges = [(3, 4), (11, 12)] if opened else [(3, 7), (8, 12)]
    for left, right in leaf_edges:
        draw.rectangle((left, 7, right, 12), fill=WOOD, outline=PLUM)
        draw.line((left, 8, right, 8), RUST)
        draw.line((left, 11, right, 11), RUST)
    if not opened:
        draw.line((6, 10, 9, 10), GOLD)
    return image


def tower(stone=False):
    image = land(MUD if stone else GREEN, (GREY, LEAF), 29)
    draw = ImageDraw.Draw(image)
    if stone:
        stonework(draw, 2, 5, 13, 14)
        for x in (1, 6, 11):
            draw.rectangle((x, 2, x + 3, 5), fill=STONE, outline=GREY)
        draw.rectangle((6, 7, 9, 10), fill=INK)
    else:
        for x in (4, 11):
            draw.rectangle((x, 6, x + 1, 14), fill=WOOD)
        draw.line((5, 13, 11, 8), WOOD, width=2)
        draw.rectangle((3, 7, 12, 9), fill=RUST, outline=PLUM)
        draw.polygon([(1, 6), (5, 2), (10, 2), (14, 6)], fill=WOOD, outline=INK)
        draw.line((4, 5, 11, 5), RUST)
    return image


def beacon(frame=None):
    image, draw = canvas()
    draw.line((4, 15, 7, 10), WOOD, width=2)
    draw.line((11, 15, 8, 10), WOOD, width=2)
    draw.polygon([(3, 9), (12, 9), (10, 12), (5, 12)], fill=GREY, outline=INK)
    draw.line((4, 9, 11, 9), MUD)
    if frame is not None:
        tip = (9, 1) if frame == 0 else (6, 2)
        draw.polygon([(4, 9), (5, 5), (7, 6), tip, (11, 6), (11, 9)], fill=RED)
        draw.polygon([(5, 9), (8, 5), (10, 9)], fill=RUST)
        draw.line((7, 9, 8, 7), GOLD)
    return image


def barrier():
    image, draw = canvas()
    for x in (0, 5, 10):
        draw.line((x, 12, x + 5, 5), WOOD, width=3)
        draw.line((x, 12, x + 5, 5), RUST)
        draw.line((x + 1, 6, x + 4, 13), WOOD, width=2)
    draw.line((1, 10, 14, 10), PLUM)
    draw.line((3, 9, 12, 9), GOLD)
    return image


def person(coat, highlight, hat, gear=None, hair=INK, headwear="band"):
    image, draw = canvas()
    # Frontal three-quarter silhouette with the equipment kept outside the face.
    draw.rectangle((5, 11, 7, 14), fill=NAVY, outline=INK)
    draw.rectangle((9, 11, 11, 14), fill=NAVY, outline=INK)
    draw.polygon([(5, 7), (10, 7), (12, 9), (12, 11), (10, 12),
                  (5, 12), (3, 10), (3, 9)], fill=coat, outline=INK)
    draw.line((5, 8, 8, 10), highlight)
    draw.line((5, 11, 10, 11), WOOD)
    draw.point((8, 11), GOLD)
    draw.point((3, 10), SKIN)
    draw.point((12, 10), SKIN)
    draw.rounded_rectangle((4, 2, 11, 7), radius=1, fill=SKIN, outline=INK)
    draw.line((5, 3, 10, 3), hair)
    draw.point((10, 5), INK)
    draw.point((6, 5), INK)
    if headwear == "helmet":
        draw.polygon([(3, 4), (4, 2), (6, 1), (9, 1), (11, 2), (12, 4)],
                     fill=hat, outline=INK)
        draw.line((6, 2, 9, 2), highlight)
    elif headwear == "straw":
        draw.polygon([(2, 4), (5, 1), (10, 1), (13, 4)], fill=hat, outline=WOOD)
        draw.line((4, 3, 11, 3), GOLD)
    else:
        draw.line((4, 4, 11, 4), hat)
        draw.line((4, 5, 3, 7), hat)
    if hair == CREAM:
        draw.line((6, 7, 9, 7), CREAM)
        draw.point((8, 8), STONE)

    if gear == "spear":
        draw.line((14, 3, 14, 14), WOOD)
        draw.line((13, 4, 13, 12), PLUM)
        draw.line((12, 10, 14, 10), SKIN)
        draw.polygon([(13, 4), (14, 0), (15, 4)], fill=STONE)
        draw.point((14, 1), CREAM)
    elif gear == "crossbow":
        draw.line([(10, 9), (11, 7), (13, 7), (15, 9)], WOOD)
        draw.line((10, 9, 15, 9), SKIN)
        draw.line((12, 12, 14, 7), PLUM)
        draw.point((14, 7), CREAM)
    elif gear in ("hammer", "axe"):
        draw.line((12, 12, 13, 5), WOOD, width=2)
        draw.rectangle((11, 4, 15, 6), fill=GREY)
        draw.line((11, 4, 15, 4), STONE)
        if gear == "axe":
            draw.polygon([(14, 4), (15, 3), (15, 8), (13, 7)], fill=STONE)
    elif gear == "satchel":
        draw.rectangle((1, 9, 4, 12), fill=WOOD, outline=INK)
        draw.line((2, 10, 3, 10), GOLD)
    elif gear == "basket":
        draw.polygon([(1, 9), (5, 9), (4, 12), (2, 12)], fill=RUST, outline=WOOD)
        draw.line((2, 9, 4, 9), GOLD)
    elif gear == "blade":
        draw.line((11, 11, 15, 6), GREY, width=2)
        draw.line((12, 10, 15, 6), CREAM)
        draw.line((10, 10, 12, 12), RUST)
    return image


def boat():
    image, draw = canvas(width=32)
    draw.polygon([(0, 9), (6, 10), (25, 10), (31, 8), (27, 13),
                  (23, 15), (8, 15), (4, 13)], fill=WOOD, outline=INK)
    draw.line([(2, 10), (7, 12), (24, 12), (29, 10)], RUST)
    draw.line((8, 14, 23, 14), PLUM)
    draw.line((13, 1, 13, 10), WOOD)
    draw.polygon([(6, 8), (8, 4), (12, 2), (12, 8)], fill=SKIN, outline=PLUM)
    draw.line((8, 6, 11, 6), CREAM)
    draw.polygon([(14, 1), (20, 2), (14, 4)], fill=RED)
    draw.rectangle((21, 7, 24, 10), fill=RED, outline=PLUM)
    draw.rectangle((22, 4, 24, 6), fill=SKIN)
    draw.line((21, 4, 25, 4), INK)
    draw.line([(27, 4), (29, 6), (28, 8)], WOOD)
    draw.line((27, 4, 28, 8), GOLD)
    draw.line((24, 7, 30, 6), CREAM)
    return image


def tiles():
    road = land(MUD, (WOOD, SKIN), 2)
    draw = ImageDraw.Draw(road)
    for y in range(16):
        inset = (1, 1, 2, 2)[y // 4]
        draw.line((0, y, inset, y), GREEN)
        draw.line((15 - inset, y, 15, y), GREEN)
    return {
        "field": field(),
        "road": road,
        "house": house(),
        "mud": land(MUD, (WOOD, GREY, STONE), 8),
        "mud_flooded": water(NAVY, BLUE, 0),
        "beach": land(GOLD, (SKIN, CREAM, MUD), 12),
        "sea": water(BLUE, WATER, 0),
        "sea_2": water(BLUE, WATER, 3),
        "fence": wall("fence", "intact"),
        "fence_cracked": wall("fence", "cracked"),
        "fence_ruin": wall("fence", "ruin"),
        "stone": wall("stone", "intact"),
        "stone_cracked": wall("stone", "cracked"),
        "stone_ruin": wall("stone", "ruin"),
        "fence_gate_closed": gate("fence", False),
        "fence_gate_open": gate("fence", True),
        "stone_gate_closed": gate("stone", False),
        "stone_gate_open": gate("stone", True),
        "tower": tower(),
        "watchtower": tower(stone=True),
        "beacon": beacon(),
        "beacon_lit": beacon(0),
        "beacon_lit_2": beacon(1),
        "ancestral_hall": house(hall=True),
        "safe": land(MUD, (GREY, STONE, SKIN), 23),
        "barrier": barrier(),
    }


def units():
    return {
        "hero": person(BLUE, WATER, NAVY, "spear"),
        "hero_2": person(LEAF, GOLD, GREEN, "hammer", headwear="straw"),
        "hero_3": person(NAVY, WATER, STONE, "spear", headwear="helmet"),
        "companion": person(RUST, GOLD, RED, "spear"),
        "companion_2": person(BLUE, CREAM, NAVY, "hammer", headwear="straw"),
        "companion_3": person(GREEN, GOLD, LEAF, "spear", headwear="helmet"),
        "spearman": person(NAVY, BLUE, GREY, "spear", headwear="helmet"),
        "crossbow": person(GREEN, WATER, GREY, "crossbow", headwear="helmet"),
        "craftsman": person(WOOD, SKIN, RUST, "hammer"),
        "courier": person(WATER, CREAM, BLUE, "satchel"),
        "elder2": person(MUD, STONE, NAVY, "satchel", hair=CREAM),
        "militia": person(WOOD, GOLD, RUST, "spear"),
        "villager": person(LEAF, CREAM, RUST, "basket", headwear="straw"),
        "villager_2": person(SKIN, CREAM, PLUM, "basket"),
        "raider": person(PLUM, RED, RED, "blade"),
        "axeman": person(RED, RUST, PLUM, "axe", headwear="helmet"),
        "chief": person(PLUM, GOLD, RED, "blade", headwear="helmet"),
        "archer_boat": boat(),
        "qiao": person(NAVY, GOLD, GREY, "spear", hair=CREAM, headwear="helmet"),
    }


def verify(manifest):
    for group in ("tiles", "units"):
        folder = ROOT / "assets" / "art" / group
        expected = {folder / f"{sprite_id}.png" for sprite_id in manifest[group]}
        if set(folder.glob("*.png")) != expected:
            raise ValueError(f"{folder}: PNG filenames do not match the manifest")
        for path in sorted(expected):
            size = (32, 16) if group == "units" and path.stem == "archer_boat" else (16, 16)
            with Image.open(path) as image:
                if image.format != "PNG" or image.mode != "RGBA" or image.size != size:
                    raise ValueError(f"{path}: expected a {size[0]}x{size[1]} RGBA PNG")
                pixels = set(image.getdata())
            for r, g, b, alpha in pixels:
                if alpha not in (0, 255) or (alpha == 255 and (r, g, b) not in PALETTE):
                    raise ValueError(f"{path}: invalid pixel {(r, g, b, alpha)}")
            if not any(pixel[3] == 255 for pixel in pixels):
                raise ValueError(f"{path}: fully transparent sprite")
            if group == "units" and not any(pixel[3] == 0 for pixel in pixels):
                raise ValueError(f"{path}: unit sprite lacks a transparent background")
    print(
        f"Verified {len(manifest['tiles'])} tiles and {len(manifest['units'])} units "
        "(16x16, archer_boat 32x16). All opaque pixels use Dawnbringer 16; "
        "alpha is binary."
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true", help="check existing PNGs")
    args = parser.parse_args()
    manifest_path = ROOT / "data/rules/art.json"
    if not args.verify_only:
        generated = {"tiles": tiles(), "units": units()}
        for group, sprites in generated.items():
            folder = ROOT / "assets" / "art" / group
            folder.mkdir(parents=True, exist_ok=True)
            for sprite_id, image in sprites.items():
                image.save(folder / f"{sprite_id}.png")
        manifest = {group: list(sprites) for group, sprites in generated.items()}
        manifest["tile_frames"] = {
            "sea": ["sea", "sea_2"],
            "beacon_lit": ["beacon_lit", "beacon_lit_2"],
        }
        manifest["unit_aliases"] = {"reinforcement": "spearman", "bonus": "militia"}
        manifest_path.write_text(json.dumps({"art": manifest}, indent="\t") + "\n", encoding="utf-8")
    verify(json.loads(manifest_path.read_text(encoding="utf-8"))["art"])


if __name__ == "__main__":
    main()
