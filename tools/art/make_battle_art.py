"""Battle art for 永昌堡·守潮 (ART-001 §3.1–3.3, §3.5): 16x16 tiles and units, UI icons, lanterns.
Everything is drawn pixel by pixel in DB16. Units share one body template; hats, colors and
weapons change. Usage: python make_battle_art.py OUTDIR  (writes tiles/, units/, ui/, previews)."""
import random
import sys
from pathlib import Path
from PIL import Image

DB16 = {
    "K": "140c1c", "P": "442434", "N": "30346d", "G": "4e4a4e", "B": "854c30", "D": "346524",
    "R": "d04648", "O": "757161", "L": "597dce", "A": "d27d2c", "S": "8595a1", "g": "6daa2c",
    "s": "d2aa99", "C": "6dc2ca", "y": "dad45e", "W": "deeed6",
}


def rgb(k):
    h = DB16[k]
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def blank(w=16, h=16, fill="."):
    return [[fill] * w for _ in range(h)]


def put(g, rows, x0=0, y0=0, slots=None):
    """Paint string rows onto grid g; '.' is transparent; digits are looked up in slots."""
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            if slots and ch in slots:
                ch = slots[ch]
            if ch == ".":
                continue
            yy, xx = y0 + y, x0 + x
            if 0 <= yy < len(g) and 0 <= xx < len(g[0]):
                g[yy][xx] = ch
    return g


def img(g):
    im = Image.new("RGBA", (len(g[0]), len(g)), (0, 0, 0, 0))
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), rgb(ch))
    return im


def noise(g, base, specks, seed, density=0.12):
    rnd = random.Random(seed)
    for y in range(len(g)):
        for x in range(len(g[0])):
            g[y][x] = base
            if rnd.random() < density:
                g[y][x] = rnd.choice(specks)
    return g


# ---------------------------------------------------------------- tiles
def t_field():
    g = noise(blank(), "D", ["D"], 1, 0)
    for y in range(16):
        for x in range(16):
            if x % 4 in (1, 2) and (y + x // 4) % 3 != 0:
                g[y][x] = "g"
            if x % 4 == 1 and (y + x) % 5 == 0:
                g[y][x] = "y"
    return g


def t_road():
    g = noise(blank(), "B", ["O", "A", "P"], 2, 0.10)
    for y in range(16):
        g[y][0] = g[y][15] = "P" if y % 3 else "B"
    return g


def t_house():
    g = blank(fill="D")
    roof = [
        "................",
        "..KKKKKKKKKKKK..",
        ".KGGGGGGGGGGGGK.",
        "KGSGSGSGSGSGSGSK",
        "KSGSGSGSGSGSGSGK",
        "KGSGSGSGSGSGSGSK",
        "KSGSGSGSGSGSGSGK",
        "KKKKKKKKKKKKKKKK",
        ".KWWWWWWWWWWWWK.",
        ".KWWWKKKKWWWWWK.",
        ".KWWWKBBKWWKKWK.",
        ".KWWWKBBKWWKSWK.",
        ".KWWWKBBKWWKKWK.",
        ".KWWWKBBKWWWWWK.",
        ".KKKKKKKKKKKKKK.",
        "................",
    ]
    return put(g, roof)


def t_mud(flooded=False):
    if not flooded:
        g = noise(blank(), "O", ["G", "B"], 3, 0.10)
        for x, y in [(2, 3), (3, 4), (4, 4), (5, 5), (9, 9), (10, 10), (11, 10), (12, 11), (6, 12), (7, 13)]:
            g[y][x] = "G"
    else:
        g = noise(blank(), "N", ["N"], 4, 0)
        for y in (3, 8, 13):
            for x in range(16):
                if (x + y) % 6 in (0, 1, 2):
                    g[y][x] = "L"
        for x, y in [(4, 5), (11, 11), (12, 11)]:
            g[y][x] = "O"
    return g


def t_beach():
    g = noise(blank(), "y", ["A", "W"], 5, 0.08)
    for x, y in [(3, 12), (11, 4)]:
        g[y][x] = "W"
    return g


def t_sea(frame):
    g = blank(fill="L")
    for y in (2, 7, 12):
        for x in range(16):
            if (x + frame * 2 + (y // 5) * 3) % 8 in (0, 1, 2):
                g[y][x] = "C"
            if (x + frame * 2 + (y // 5) * 3) % 8 == 3:
                g[y + 1][x] = "N"
    return g


def t_fence(state):
    g = blank(fill=".")
    posts = [1, 4, 7, 10, 13]
    for i, x in enumerate(posts):
        top = 3 if i % 2 == 0 else 4
        if state == "cracked" and i == 2:
            top = 9
        for y in range(top, 15):
            g[y][x] = "B"
            g[y][x + 1] = "A" if y > top else "B"
        g[top - 1][x] = "K"
        g[top - 1][x + 1] = "K"
    for y in (6, 11):
        for x in range(0, 16):
            if state == "cracked" and y == 6 and 6 <= x <= 9:
                continue
            if g[y][x] == ".":
                g[y][x] = "P"
    for x in range(16):
        g[15][x] = "K"
    if state == "ruin":
        g = blank(fill=".")
        put(g, [
            "................", "................", "................", "................",
            "................", "................", "................", "................",
            "................", "......KK........", "..KKKKBAK....KK.",
            ".KBAAAABK..KKBAK", "KBBAAKKBBKKBAABK", "KPBBKPPKBBBBBKPK", ".KKKK.KKKKKKKKK.",
            "................",
        ])
    return g


def t_stone_wall(state):
    """Diagonally laid stones (永昌堡 斜垒石块): each 3-px course slants the other way."""
    g = blank(fill="S")
    for y in range(3):
        for x in range(16):
            g[y][x] = "W" if y == 0 else "S"
            if y == 0 and x % 4 == 3:
                g[y][x] = "S"
    for x in range(16):
        g[3][x] = "G"
    for y in range(4, 15):
        course = (y - 4) // 3
        yy = (y - 4) % 3
        for x in range(16):
            slope = (x + yy) if course % 2 == 0 else (x - yy)
            joint = slope % 4 == 0
            shade = "O" if (slope // 4 + course) % 2 else "S"
            g[y][x] = "G" if joint or yy == 2 else shade
    for x in range(16):
        g[15][x] = "K"
    if state in ("cracked", "ruin"):
        for x, y in [(9, 1), (8, 2), (8, 3), (7, 4), (7, 5), (8, 6), (8, 7), (7, 8), (6, 9), (6, 10), (7, 11), (7, 12)]:
            g[y][x] = "K"
        for x, y in [(2, 0), (3, 0), (13, 0), (14, 0), (14, 1), (13, 1)]:
            g[y][x] = "."
    if state == "ruin":
        g = blank(fill=".")
        put(g, [
            "................", "................", "................", "................",
            "................", "................", "................", "................",
            "......KK........", "..KK.KSOK...KK..", ".KSOKKOOGK.KSOK.", "KSOOGSOGOOKSOOGK",
            "KOGOOOGOOGOOGOOK", "GOOGOOGOOOGOOGOG", "OGOOGOOGOOGOOGOO", "KKKKKKKKKKKKKKKK",
        ])
    return g


def t_gate(kind, opened):
    if kind == "fence":
        frame, plank, dark = "B", "A", "P"
    else:
        frame, plank, dark = "S", "B", "G"
    g = blank(fill=frame)
    for x in range(16):
        g[0][x] = "W" if kind == "stone" else "K"
        g[15][x] = "K"
    for y in range(16):
        g[y][0] = g[y][15] = "K"
    if kind == "stone":
        for y in range(1, 4):
            for x in range(1, 15):
                g[y][x] = "S" if (x + y) % 4 else "G"
    top = 4 if kind == "stone" else 2
    for y in range(top, 15):
        for x in range(2, 14):
            if opened:
                g[y][x] = "K" if y > top else "G"
            else:
                g[y][x] = plank if x not in (7, 8) else "K"
                if (x in (3, 12)) and y in (top + 2, 12):
                    g[y][x] = "G"
    if opened:
        for y in range(top, 15):
            g[y][2] = plank
            g[y][13] = plank
    return g


def t_tower(gen):
    if gen == 1:  # wooden watchtower 望楼
        return put(blank(fill="."), [
            "...KKKKKKKKKK...", "..KBBBBBBBBBBK..", "..KAKAKAKAKAKK..", "..KBBBBBBBBBBK..",
            "...KB.....KBK...", "...KB.KKK.KBK...", "...KBKBBBKKBK...", "...KB.KKK.KBK...",
            "...KBK...KKBK...", "...KB.K.K.KBK...", "...KB..K..KBK...", "...KB.K.K.KBK...",
            "...KBK...KKBK...", "..KKBKK.KKKBKK..", "..KBBBK.KBBBBK..", "..KKKKK.KKKKKK..",
        ])
    return put(blank(fill="."), [  # hollow brick watchtower 空心敌台
        "KWKWKWK..KWKWKWK", "KSKSKSKKKKSKSKSK", "KSSSSSSSSSSSSSSK", "KGGGGGGGGGGGGGGK",
        "KSOSOSOSOSOSOSOK", "KOSOSOSOSOSOSOSK", "KSOSOKKKKKKSOSOK", "KOSOKGGGGGGKOSOK",
        "KSOSKGKKKKGKSOSK", "KOSOKGK..KGKOSOK", "KSOSOKK..KKSOSOK", "KOSOSOSOSOSOSOSK",
        "KSOSOSOKKOSOSOSK", "KOSOSOSKKSOSOSOK", "KSOSOSOSOSOSOSOK", "KKKKKKKKKKKKKKKK",
    ])


def t_beacon(frame):
    """frame -1 = unlit, 0/1 = burning."""
    g = put(blank(fill="."), [
        "................", "................", "................", "................",
        "................", "................", "................", "......KKKK......",
        ".....KBABAK.....", "....KBABABAK....", "...KKKKKKKKKK...", "...KSOSOSOSOK...",
        "...KOSOSOSOSK...", "...KSOSOSOSOK...", "...KOSOSOSOSK...", "...KKKKKKKKKK...",
    ])
    if frame >= 0:
        flame = [
            ["......y.........", ".....yAy..y.....", "....yAAAyyA.....", "....ARAAAAAy....",
             "....ARRRARAy....", ".....ARRRRA.....", "......KKKK......"],
            [".........y......", ".....y..yAy.....", ".....AyyAAAy....", "....yAAAAARA....",
             "....yARARRRA....", ".....ARRRRA.....", "......KKKK......"],
        ][frame]
        put(g, flame, 0, 1)
    return g


def t_safe(kind):
    if kind == "hall":  # 宗祠一带: dark roof, red doors
        return put(blank(fill="D"), [
            "................", ".KKKKKKKKKKKKKK.", "KGGGGGGGGGGGGGGK", "KGSGSGSGSGSGSGSK",
            "KKKKKKKKKKKKKKKK", ".KPKWWWWWWWWKPK.", ".KPKWWKKKKWWKPK.", ".KPKWKRRRRKWKPK.",
            ".KPKWKRRRRKWKPK.", ".KPKWKRyyRKWKPK.", ".KPKWKRRRRKWKPK.", ".KPKWKRRRRKWKPK.",
            "KKKKKKKKKKKKKKKK", "KSSSSSSSSSSSSSSK", "KOOOOOOOOOOOOOOK", "................",
        ])
    g = blank(fill="O")  # 堡内: stone-paved yard
    for y in range(16):
        for x in range(16):
            if y % 4 == 3 or (x + (y // 4) * 4) % 8 == 7:
                g[y][x] = "G"
            elif (x * 7 + y * 3) % 11 == 0:
                g[y][x] = "S"
    return g


def t_barrier():
    return put(blank(fill="."), [
        "................", "................", "................", "..KK........KK..",
        "..KBK......KBK..", "...KBK....KBK...", "....KBK..KBK....", ".....KBKKBK.....",
        "...KKKBAABKKK...", "..KBBBBAABBBBK..", "...KKKBAABKKK...", ".....KBKKBK.....",
        "....KBK..KBK....", "...KBK....KBK...", "..KBK......KBK..", "..KK........KK..",
    ])


# ---------------------------------------------------------------- units
BODY = [
    "................", "................", "................", "................",
    ".....KKKKKK.....", "....K111111K....", "....K222222K....", "....K2K22K2K....",
    "....K222222K....", ".....KK22KK.....", "...KK333333KK...", "..K3333333333K..",
    "..K2K333333K2K..", "..K2K555555K2K..", "...KK66KK66KK...", "...K77K..K77K...",
]

HATS = {
    "none": [],
    "straw": [(1, ["......KKKK......", "....KKyAAyKK....", "..KKyAAAAAAyKK..", ".KAAAAAAAAAAAAK.", "..KKKKKKKKKKKK.."])],
    "wrap": [(3, [".....KKKKKK.....", "....K888888K....", "...K88888888K.."]), (4, ["..............K8"])],
    "wrap_knot": [(3, [".....KKKKKK..KK.", "....K888888KK88K", "...K88888888K..."])],
    "helmet": [(1, ["......KKKK......", ".....KSSSSK.....", "...KKSSSSSSKK...", "..KSSSSSSSSSSK..", "..KKKKKKKKKKKK.."])],
    "bun": [(2, [".......KKK......", "......K111K.....", ".....KK111KK...."])],
    "topknot": [(2, [".......KK.......", "......K11K......"])],
    "scholar": [(1, [".....KKKKKK.....", ".....K1111K.....", ".....K1111K.....", "....KKKKKKKK...."])],
}

WEAPONS = {
    "none": [],
    "spear": [(0, ["..............S.", ".............KWK", ".............KSK"] + ["..............B."] * 13)],
    "crossbow": [(10, ["K..............K", "KBBBBBBBBBBBBBBK", "K......B.......K"])],
    "hammer": [(7, ["............KKK.", "............KSK.", "............KSK.", ".............B..", ".............B..", ".............B.."])],
    "axe": [(5, ["............KK..", "...........KSSK.", "...........KSSSK", "............KBK.", ".............B..", ".............B..", ".............B..", ".............B.."])],
    "flag": [(1, ["............KKKK", "............KRRK", "............KRRK", "............KKKK"] + ["............B..."] * 11)],
    "blade": [(10, ["...............K", "..............KS", ".............KS.", "............KS.."])],
    "staff": [(2, ["..............B."] * 14)],
    "ledger": [(11, [".....KKKK.......", ".....KWWK.......", ".....KWWK.......", ".....KKKK......."])],
    "saber": [(11, ["..............K.", ".............KS.", "............KS..", "...........KB..."])],
    "pole": [(9, ["KKKKKKKKKKKKKKKK", "BBBBBBBBBBBBBBBB"])],
}

UNITS = {
    # id: (hat, weapon, slots 1 hair,2 skin,3 cloth,5 belt,6 legs,7 feet,8 hat cloth)
    "hero_gen1": ("straw", "spear", dict(zip("12356789", "PsOBsBO."))),
    "hero_gen2": ("wrap", "hammer", dict(zip("12356789", "PsOBsBG."))),
    "hero_gen3": ("helmet", "saber", dict(zip("12356789", "PsNRNGG."))),
    "a_tang": ("wrap_knot", "none", dict(zip("12356789", "PsBDsBD."))),
    "zhou_yan": ("topknot", "pole", dict(zip("12356789", "PsBPsBO."))),
    "a_he": ("bun", "ledger", dict(zip("12356789", "PsNPNGN."))),
    "spearman": ("helmet", "spear", dict(zip("12356789", "PsRBNGG."))),
    "militia": ("wrap", "spear", dict(zip("12356789", "PsOBsBD."))),
    "crossbow": ("wrap", "crossbow", dict(zip("12356789", "PsDBNGB."))),
    "craftsman": ("topknot", "hammer", dict(zip("12356789", "PsBGsBO."))),
    "courier": ("wrap", "flag", dict(zip("12356789", "PsLBsBN."))),
    "elder": ("topknot", "staff", dict(zip("12356789", "SsOGsBO."))),
    "qiao": ("topknot", "staff", dict(zip("12356789", "SsBGsBO."))),
    "villager_m": ("straw", "none", dict(zip("12356789", "PsWBsBO."))),
    "villager_f": ("bun", "none", dict(zip("12356789", "PsRPsBO."))),
    "raider": ("wrap", "blade", dict(zip("12356789", "PsPGssR."))),
    "axeman": ("wrap", "axe", dict(zip("12356789", "PsGBssR."))),
    "chief": ("wrap_knot", "saber", dict(zip("12356789", "PsPyPGR."))),
}


def unit(uid):
    hat, weapon, slots = UNITS[uid]
    slots = dict(slots)
    slots.setdefault("4", slots["3"])
    if slots.get("7") == "." or slots.get("7") is None:
        slots["7"] = "s"
    g = put(blank(), BODY, slots=slots)
    for y0, rows in HATS[hat]:
        put(g, rows, 0, y0, slots=slots)
    for y0, rows in WEAPONS[weapon]:
        put(g, rows, 0, y0)
    return g


def archer_boat():
    return put(blank(32, 16), [
        "................................", "................................", "..............KKKK..............",
        ".............KR88RK.............", ".............KssssK....K.........", ".............KsKsKK...KB.........",
        "............KKPPPPKKKKBK.........", "...........KsKPPPPKBBBK..........", "............KKPPPPK..KB..........",
        "...KKKKKKKKKKKKKKKKKKKKKKKKKKK..", "..KBBBBBBBBBBBBBBBBBBBBBBBBBBBBK.", "...KBAABAABAABAABAABAABAABAABK...",
        "....KBBBBBBBBBBBBBBBBBBBBBBBBK..", ".....KKKKKKKKKKKKKKKKKKKKKKKKK...", "..CC....CCC.....CC.....CCC...CC..",
        "................................",
    ], slots={"8": "R"})


# ---------------------------------------------------------------- UI and effects
def ui_icons():
    icons = {}
    icons["cursor"] = put(blank(), [
        "WWWW........WWWW", "WKKK........KKKW", "WK............KW", "WK............KW",
        "................", "................", "................", "................",
        "................", "................", "................", "................",
        "WK............KW", "WK............KW", "WKKK........KKKW", "WWWW........WWWW",
    ])
    icons["move_mark"] = put(blank(), [
        "................", ".CCCCCCCCCCCCCC.", ".C............C.", ".C............C.",
        ".C............C.", ".C............C.", ".C............C.", ".C............C.",
        ".C............C.", ".C............C.", ".C............C.", ".C............C.",
        ".C............C.", ".C............C.", ".CCCCCCCCCCCCCC.", "................",
    ])
    icons["target_mark"] = put(blank(), [
        "................", ".RR..........RR.", ".RRR........RRR.", "..RRR......RRR..",
        "...RRR....RRR...", "....RRR..RRR....", ".....RRRRRR.....", "......RRRR......",
        "......RRRR......", ".....RRRRRR.....", "....RRR..RRR....", "...RRR....RRR...",
        "..RRR......RRR..", ".RRR........RRR.", ".RR..........RR.", "................",
    ])
    icons["intent_arrow"] = put(blank(), [
        "................", "................", "................", "................",
        ".........KK.....", ".........KRK....", "..KKKKKKKKRRK...", "..KRRRRRRRRRRK..",
        "..KRRRRRRRRRRK..", "..KKKKKKKKRRK...", ".........KRK....", ".........KK.....",
        "................", "................", "................", "................",
    ])
    icons["intent_unknown"] = put(blank(), [
        "................", ".....KKKKKK.....", "....KyyyyyyK....", "...KyyKKKKyyK...",
        "...KKK...KyyK...", ".........KyyK...", "........KyyK....", ".......KyyK.....",
        "......KyyK......", "......KyyK......", ".......KK.......", "................",
        "......KKKK......", "......KyyK......", "......KKKK......", "................",
    ])
    tide = {
        "tide_low": ["................"] * 9 + ["LLLLLLLLLLLLLLLL", "NNNNNNNNNNNNNNNN"] + ["yyyyyyyyyyyyyyyy"] * 5,
        "tide_rising": ["................"] * 5 + ["...........KK...", "..........KWWK..", "C.C.C.C..KWWWWK.", "LLLLLLLLLLLLLLLL", "LLLLLLLLLLLLLLLL", "NNNNNNNNNNNNNNNN"] + ["yyyyyyyyyyyyyyyy"] * 5,
        "tide_high": ["................", "C.C.C.C.C.C.C.C.", "LLLLLLLLLLLLLLLL"] + ["LLLLLLLLLLLLLLLL"] * 9 + ["NNNNNNNNNNNNNNNN"] * 2 + ["yyyyyyyyyyyyyyyy"] * 2,
        "tide_ebbing": ["................"] * 5 + ["..KK............", ".KWWK...........", "KWWWWK..C.C.C.C.", "LLLLLLLLLLLLLLLL", "LLLLLLLLLLLLLLLL", "NNNNNNNNNNNNNNNN"] + ["yyyyyyyyyyyyyyyy"] * 5,
    }
    for k, rows in tide.items():
        icons[k] = put(blank(), rows)
    icons["tide_storm"] = put(blank(), [
        "....GGGGGG......", "..GGOOOOOOGG....", ".GOOOOOOOOOOG...", ".GGGGGGyGGGGG...",
        ".......yy.......", "......yy........", ".....yyyyy......", ".......yy.......",
        "......yy........", "LLLLLyLLLLLLLLLL", "LCLLLLLCLLLLLCLL", "LLLLLLLLLLLLLLLL",
        "NNNNNNNNNNNNNNNN", "LLLLLLLLLLLLLLLL", "NNNNNNNNNNNNNNNN", "NNNNNNNNNNNNNNNN",
    ])
    icons["res_grain"] = put(blank(), [
        "................", "......y.y.......", ".....yAyAy......", "......yAyAy.....",
        ".....yAyAy......", "......yAy.......", ".....KKKKKK.....", "....KBBBBBBK....",
        "...KBAAAAAABK...", "...KBAAAAAABK...", "...KBBBBBBBBK...", "...KBAAAAAABK...",
        "...KBAAAAAABK...", "....KBBBBBBK....", ".....KKKKKK.....", "................",
    ])
    icons["res_material"] = put(blank(), [
        "................", "................", "................", "....KKKKKKK.....",
        "...KSSSSSSSK....", "..KSSWSSSSSSK...", "..KOOOOOOOOOK...", "..KKKKKKKKKKKKK.",
        ".KBBBBBBBBBBBBK.", ".KBAAAAAAAAAABK.", ".KBBBBBBBBBBBBK.", ".KKKKKKKKKKKKKK.",
        ".KBBBBBBBBBBBBK.", ".KBAAAAAAAAAABK.", ".KKKKKKKKKKKKKK.", "................",
    ])
    icons["res_people"] = put(blank(), [
        "................", "...KKK....KKK...", "..KsssK..KsssK..", "..KsKsK..KsKsK..",
        "..KsssK..KsssK..", "...KKK....KKK...", "..KOOOK..KRRRK..", ".KOOOOOKKRRRRRK.",
        ".KOOOOOKKRRRRRK.", ".KsOOOsKKsRRRsK.", "..KOOOK..KRRRK..", "..KBKBK..KPKPK..",
        "..KBKBK..KPKPK..", "..KKKKK..KKKKK..", "................", "................",
    ])
    return icons


def lantern(color):
    return put(blank(8, 8), [
        "...KK...", "..KyyK..", ".K8888K.", "K8W8888K", "K888888K", ".K8888K.", "..KyyK..", "...yy...",
    ], slots={"8": color})


def door_lantern():
    return put(blank(16, 16), [
        "......KKKK......", ".......KK.......", ".......KK.......", ".....KKKKKK.....",
        "....KRRRRRRK....", "...KRWRRRRRRK...", "...KRyyyyyyRK...", "...KRRRRRRRRK...",
        "...KRyyyyyyRK...", "...KRRRRRRRRK...", "....KRRRRRRK....", ".....KKKKKK.....",
        ".......yy.......", "......y..y......", "................", "................",
    ])


def slash(frame):
    return put(blank(8, 8), [
        ["......WW", ".....WW.", "....WW..", "...WW...", "..WW....", ".WW.....", "WW......", "W......."],
        [".......C", "......CW", ".....CW.", "....CW..", "...CW...", "..CW....", ".CW.....", "CW......"],
    ][frame])


def ninepatch(kind):
    if kind == "dialog":
        return put(blank(), [
            # dark interior so the light dialogue text stays readable; wood frame, gold corners
            "..BBBBBBBBBBBB..", ".BAKKKKKKKKKKAB.", "BAKKKKKKKKKKKKAB", "BKKKKKKKKKKKKKKB",
            "BKKKKKKKKKKKKKKB", "BKKKKKKKKKKKKKKB", "BKKKKKKKKKKKKKKB", "BKKKKKKKKKKKKKKB",
            "BKKKKKKKKKKKKKKB", "BKKKKKKKKKKKKKKB", "BKKKKKKKKKKKKKKB", "BKKKKKKKKKKKKKKB",
            "BKKKKKKKKKKKKKKB", "BAKKKKKKKKKKKKAB", ".BAKKKKKKKKKKAB.", "..BBBBBBBBBBBB..",
        ])
    return put(blank(), [
        # brown wooden button, light top edge, dark bottom edge (light text on top)
        "..KKKKKKKKKKKK..", ".KAAAAAAAAAAAAK.", "KAABBBBBBBBBBAAK", "KABBBBBBBBBBBBAK",
        "KBBBBBBBBBBBBBBK", "KBBBBBBBBBBBBBBK", "KBBBBBBBBBBBBBBK", "KBBBBBBBBBBBBBBK",
        "KBBBBBBBBBBBBBBK", "KBBBBBBBBBBBBBBK", "KBBBBBBBBBBBBBBK", "KBBBBBBBBBBBBBBK",
        "KPBBBBBBBBBBBBPK", "KPPPPPPPPPPPPPPK", ".KPPPPPPPPPPPPK.", "..KKKKKKKKKKKK..",
    ])


def main(outdir):
    out = Path(outdir)
    tiles = {
        "field": t_field(), "road": t_road(), "house": t_house(), "mud": t_mud(), "mud_flooded": t_mud(True),
        "beach": t_beach(), "sea_0": t_sea(0), "sea_1": t_sea(1),
        "fence_intact": t_fence("intact"), "fence_cracked": t_fence("cracked"), "fence_ruin": t_fence("ruin"),
        "stone_wall_intact": t_stone_wall("intact"), "stone_wall_cracked": t_stone_wall("cracked"),
        "stone_wall_ruin": t_stone_wall("ruin"),
        "gate_fence_closed": t_gate("fence", False), "gate_fence_open": t_gate("fence", True),
        "gate_stone_closed": t_gate("stone", False), "gate_stone_open": t_gate("stone", True),
        "tower_gen1": t_tower(1), "tower": t_tower(2),
        "beacon_unlit": t_beacon(-1), "beacon_lit_0": t_beacon(0), "beacon_lit_1": t_beacon(1),
        "safe_hall": t_safe("hall"), "safe_fort": t_safe("fort"), "barrier": t_barrier(),
    }
    units = {k: unit(k) for k in UNITS}
    units["archer_boat"] = archer_boat()
    ui = ui_icons()
    ui.update({"dialog_9patch": ninepatch("dialog"), "button_9patch": ninepatch("button")})
    # Ending lanterns: names follow ending.json lantern.art (lantern_{group}.png) and go to ending/.
    ending = {"lantern_door": door_lantern()}
    for name, col in [("lantern_villager", "A"), ("lantern_defender", "R"), ("lantern_hero", "y")]:
        ending[name] = lantern(col)
    ui["slash_0"], ui["slash_1"] = slash(0), slash(1)
    sheets = {}
    for folder, items in (("tiles", tiles), ("units", units), ("ui", ui), ("ending", ending)):
        d = out / folder
        d.mkdir(parents=True, exist_ok=True)
        ims = []
        for name, g in items.items():
            im = img(g)
            im.save(d / f"{name}.png")
            ims.append(im)
        sheets[folder] = ims
    for folder, ims in sheets.items():
        sc, gap, per = 6, 6, 9
        cw = max(i.width for i in ims) * sc
        ch = max(i.height for i in ims) * sc
        rows = (len(ims) + per - 1) // per
        sheet = Image.new("RGBA", (per * (cw + gap) + gap, rows * (ch + gap) + gap), (60, 70, 60, 255))
        for i, im in enumerate(ims):
            big = im.resize((im.width * sc, im.height * sc), Image.NEAREST)
            sheet.alpha_composite(big, (gap + (i % per) * (cw + gap), gap + (i // per) * (ch + gap)))
        sheet.convert("RGB").save(out / f"preview_{folder}.png")
    print({k: len(v) for k, v in sheets.items()})


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "battle_art")
