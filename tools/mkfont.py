#!/usr/bin/env python3
"""Generate the Acadia map fonts, tile list and island data.

Writes three files (do not edit them by hand):

  src/tiles.asm     tile-number and cell-kind equates
  src/font_map.asm  the map fonts (1K each, fixed addresses), with the
                    island pair chosen by ISL_B at assembly time
  src/islands.asm   per island pair: TILECH (tile -> character code),
                    ROWFONT (font page per map row), ISLKIND (cell
                    kinds) and ISLTILE (terrain tile per square)

Islands are drawn at pixel level.  Each island starts as a square
outline (PAIRS below); a seeded, deterministic erosion pass makes the
coast ragged, then the bitmap is cut into 8 x 8 squares.  Every square
holding any land is a land square (buildable, boats can't enter), as
in the original.  Identical squares share a tile.  Fixed tiles (sea,
grass, items, ...) have the same character codes in every font; coast
tiles go into the font of the map row they sit on, and the display
switches fonts per row with a DLI.

Each map square is one tile = 2 mode 5 characters = 8 x 8 pixels at
160 resolution, shown 8 colour clocks wide and 16 scan lines tall.
Tiles drawn in white use inverse characters (bit 7 set).
All art here is new; nothing comes from the original game.

Pixel letters: . sea (COLBK)  G grass (PF0)  D dark (PF1)
               Y light (PF2 yellow, or PF3 white on inverse tiles)

Run from the repo root:  python3 -I tools/mkfont.py [--preview DIR]
"""

import random
import sys
import os
import zlib
import struct

# ---------------------------------------------------------------------
#  Item tiles, numbered as the keypad keys (1-9).  (name, inverse, art)
# ---------------------------------------------------------------------
ITEMS = {
    1: ("fort", False, [
        "DGDGGDGD",
        "DDDDDDDD",
        "GDDDDDDG",
        "GDDDDDDG",
        "GDDGGDDG",
        "GDDGGDDG",
        "GDDDDDDG",
        "GGGGGGGG"]),
    2: ("factory", False, [
        "GGGGGYYG",
        "GGGGYYGG",
        "GGGGGDGG",
        "GDGDGDGG",
        "DDDDDDDG",
        "DDDDDDDG",
        "DYDYDYDG",
        "GGGGGGGG"]),
    3: ("crop", False, [
        "GDGGDGGD",
        "GDGGDGGD",
        "GGGGGGGG",
        "DGGDGGDG",
        "DGGDGGDG",
        "GGGGGGGG",
        "GDGGDGGD",
        "GDGGDGGD"]),
    4: ("school", True, [
        "GGGDYYGG",
        "GGGDGGGG",
        "GGYYYYGG",
        "GYYYYYYG",
        "YYYYYYYY",
        "GYDYYDYG",
        "GYYDDYYG",
        "GGGGGGGG"]),
    5: ("hospital", True, [
        "GGGGGGGG",
        "GYYYYYYG",
        "GYYDDYYG",
        "GYDDDDYG",
        "GYDDDDYG",
        "GYYDDYYG",
        "GYYYYYYG",
        "GGGGGGGG"]),
    6: ("house", False, [
        "GGGYYGGG",
        "GGYYYYGG",
        "GYYYYYYG",
        "YYYYYYYY",
        "GDDDDDDG",
        "GDYDDYDG",
        "GDDDDDDG",
        "GGGGGGGG"]),
    7: ("rebel", False, [
        "GGGDDGGG",
        "GGGDDGGG",
        "GDDDDDDG",
        "DGDDDDGD",
        "GGDDDDGG",
        "GGDGGDGG",
        "GGDGGDGG",
        "GDDGGDDG"]),
    8: ("PT boat", False, [
        "........",
        "........",
        "...DD...",
        "..DDDD..",
        "YDDDDDDD",
        ".DDDDDD.",
        "........",
        "........"]),
    9: ("fishing boat", False, [
        "...D....",
        "...DY...",
        "...DYY..",
        "...DYYY.",
        "...D....",
        "DDDDDDDD",
        ".DDDDDD.",
        "........"]),
}


WRECK = [
    "........",
    "......D.",
    ".....D..",
    "....D...",
    "..DDDDD.",
    ".D.D.D..",
    "........",
    "........"]


BLANK = ["........"] * 8

ROCK = [
    "........",
    "........",
    "...D....",
    "..DDD...",
    ".DDDYD..",
    ".DDDDDD.",
    "........",
    "........"]

# Harbour pier, drawn for land to the west; mirrored for land to the east
PIER_W = [
    "........",
    "........",
    "YYYYYYY.",
    "DDDDDDD.",
    "D..D..D.",
    "D..D..D.",
    "........",
    "........"]

ITEM_EQU = ["T_FORT", "T_FACTORY", "T_CROP", "T_SCHOOL", "T_HOSPITAL",
            "T_HOUSE", "T_REBEL", "T_PTBOAT", "T_FISHBOAT"]

PIX = {".": 0, "G": 1, "D": 2, "Y": 3}

BEACH = True        # 1-pixel yellow beach along the coast (D16)

# ---------------------------------------------------------------------
#  Island outlines.  One string per square row, 10 squares per island.
#    .  sea      #  land      H  harbour (pier; boats launch here)
#    r  rock (decorative only: plays as open sea)
#  The erosion pass roughens the coast inside the land squares; it
#  never adds land to a sea square, so the outline fixes the square
#  count.  Rows 0-1 and 9-10 stay open sea (fish and pirate bands);
#  screen columns 9-10 stay open sea (channel).
# ---------------------------------------------------------------------
LEFT_A = [
    "..........",
    "..........",
    "..###..##.",
    "..######..",
    ".H#####...",
    "..#######.",
    "...######.",
    "..###..##.",
    "..#.......",
    "..........",
    "..........",
]

RIGHT_B = [
    "..........",
    "..........",
    ".##..###..",
    ".#######..",
    "...#####H.",
    "..######..",
    ".####.##..",
    "..###.##..",
    "...#......",
    "..........",
    "..........",
]

PAIRS = [
    ("A", "mirror pair", LEFT_A, None, 11),
    ("B", "same left island, different right island", LEFT_A, RIGHT_B, 11),
]
SEED_RIGHT_B = 29

ROWS, COLS = 11, 20
PW, PH = COLS * 8, ROWS * 8
BANDS = (0, 1, 9, 10)
CHANNEL = (9, 10)

# Cell kinds (ISLKIND); bit 7 = owned by player 1 (right island)
K_SEA, K_LAND, K_HARB, K_ROCK, K_P1 = 0, 1, 3, 4, 0x80


def value_noise(rng, w, h, step):
    gw, gh = w // step + 2, h // step + 2
    g = [[rng.random() for _ in range(gw)] for _ in range(gh)]

    def at(x, y):
        fx, fy = x / step, y / step
        x0, y0 = int(fx), int(fy)
        tx, ty = fx - x0, fy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[y0][x0] * (1 - tx) + g[y0][x0 + 1] * tx
        b = g[y0 + 1][x0] * (1 - tx) + g[y0 + 1][x0 + 1] * tx
        return a * (1 - ty) + b * ty
    return at


def island_bitmap(outline, seed):
    """Ragged land bitmap (10 squares = 80 px wide) for one island."""
    w, h = 80, PH
    land = [[outline[y // 8][x // 8] == "#" for x in range(w)] for y in range(h)]
    # distance (in pixels, 4-neighbour) to the nearest sea pixel
    INF = 99
    dist = [[INF if land[y][x] else 0 for x in range(w)] for y in range(h)]
    frontier = [(x, y) for y in range(h) for x in range(w) if not land[y][x]]
    for y in range(h):
        for x in (0, w - 1):
            if land[y][x]:
                dist[y][x] = 1
    d = 0
    while frontier:
        d += 1
        nxt = []
        for x, y in frontier:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and dist[ny][nx] > d:
                    dist[ny][nx] = d
                    nxt.append((nx, ny))
        frontier = nxt
    rng = random.Random(seed)
    big = value_noise(rng, w, h, 6)
    small = value_noise(rng, w, h, 3)
    out = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if not land[y][x]:
                continue
            # erosion depth 0-3 px (mostly 1): a ragged rim on solid squares
            e = (1 if small(x, y) > 0.5 else 0) + (1 if big(x, y) > 0.68 else 0) \
                + (1 if rng.random() < 0.12 else 0)
            out[y][x] = dist[y][x] > e
    # keep every land square's centre, a 4-pixel band through squares
    # that link land on opposite sides (so necks and arms stay solid),
    # and the square behind a harbour
    def isl(sy, sx):
        return 0 <= sy < ROWS and 0 <= sx < 10 and outline[sy][sx] == "#"
    for sy in range(ROWS):
        for sx in range(10):
            if outline[sy][sx] != "#":
                continue
            for y in range(sy * 8 + 3, sy * 8 + 5):
                for x in range(sx * 8 + 3, sx * 8 + 5):
                    out[y][x] = True
            if isl(sy, sx - 1) and isl(sy, sx + 1):
                for y in range(sy * 8 + 2, sy * 8 + 6):
                    for x in range(sx * 8, sx * 8 + 8):
                        out[y][x] = True
            if isl(sy - 1, sx) and isl(sy + 1, sx):
                for y in range(sy * 8, sy * 8 + 8):
                    for x in range(sx * 8 + 2, sx * 8 + 6):
                        out[y][x] = True
            for dx in (-1, 1):
                if 0 <= sx + dx < 10 and outline[sy][sx + dx] == "H":
                    for y in range(sy * 8, sy * 8 + 8):
                        for x in range(sx * 8, sx * 8 + 8):
                            out[y][x] = True
    # fill lakes: sea not connected to the open sea becomes land
    seen = [[False] * w for _ in range(h)]
    stack = [(x, y) for y in range(h) for x in (0, w - 1) if not out[y][x]]
    stack += [(x, y) for x in range(w) for y in (0, h - 1) if not out[y][x]]
    while stack:
        x, y = stack.pop()
        if seen[y][x] or out[y][x]:
            continue
        seen[y][x] = True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                stack.append((nx, ny))
    for y in range(h):
        for x in range(w):
            if not out[y][x] and not seen[y][x] and outline[y // 8][x // 8] == "#":
                out[y][x] = True
    return out


def pair_map(left, right, seed_left, seed_right, mirror):
    """Full 160 x 88 land bitmap plus the 20-column outline."""
    lb = island_bitmap(left, seed_left)
    if mirror:
        rb = [row[::-1] for row in lb]
        right = [r[::-1] for r in left]
    else:
        rb = island_bitmap(right, seed_right)
    bm = [lb[y] + rb[y] for y in range(PH)]
    outline = [l + r for l, r in zip(left, right)]
    return bm, outline


def square_art(bm, sy, sx, beach):
    a = []
    for y in range(sy * 8, sy * 8 + 8):
        row = ""
        for x in range(sx * 8, sx * 8 + 8):
            if not bm[y][x]:
                row += "."
                continue
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < PW and 0 <= ny < PH and not bm[ny][nx]:
                    edge = True
            row += "Y" if (beach and edge) else "G"
        a.append(row)
    return a


def pier_art(land_west):
    return PIER_W if land_west else [x[::-1] for x in PIER_W]


FIXED = [("T_SEA", "open sea", False, ["........"] * 8),
         ("T_GRASS", "plain grass", False, ["GGGGGGGG"] * 8)]
for _k in range(1, 10):
    _n, _i, _a = ITEMS[_k]
    FIXED.append((ITEM_EQU[_k - 1], "%d %s" % (_k, _n), _i, _a))
FIXED += [("T_WRECK", "wreck of a parked boat", False, WRECK),
          ("T_SPARE", "spare (blank)", False, BLANK),
          ("T_ROCK", "rock (decorative)", False, ROCK),
          ("T_PIER_W", "harbour pier, land to the west", False, pier_art(True)),
          ("T_PIER_E", "harbour pier, land to the east", False, pier_art(False))]
T = {t[0]: n for n, t in enumerate(FIXED)}
NFIX = len(FIXED)
PER_FONT = 64 - NFIX          # coast tiles that fit in one font


def build_pair(name, desc, left, right, seed_r, beach):
    mirror = right is None
    bm, outline = pair_map(left, right, 11, SEED_RIGHT_B if not mirror else seed_r, mirror)
    for r in BANDS:
        assert set(outline[r]) <= set(".r"), "pair %s row %d must be open sea" % (name, r)
    # every sea square must connect to the map edge through sea squares
    seen, stack = set(), [(r, c) for r in range(ROWS) for c in range(COLS)
                          if (r in (0, ROWS - 1) or c in (0, COLS - 1)) and outline[r][c] != "#"]
    while stack:
        r, c = stack.pop()
        if (r, c) in seen or not (0 <= r < ROWS and 0 <= c < COLS) or outline[r][c] == "#":
            continue
        seen.add((r, c))
        stack += [(r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)]
    for r in range(ROWS):
        for c in range(COLS):
            if outline[r][c] != "#" and (r, c) not in seen:
                sys.exit("pair %s: sea square row %d col %d is enclosed by land" % (name, r, c))
    for r in range(ROWS):
        for c in CHANNEL:
            assert outline[r][c] in ".r", "pair %s channel at row %d" % (name, r)
    tiles = list(FIXED)
    index = {}
    kinds = [[0] * COLS for _ in range(ROWS)]
    tgrid = [[0] * COLS for _ in range(ROWS)]
    rowtiles = [[] for _ in range(ROWS)]
    for r in range(ROWS):
        for c in range(COLS):
            ch = outline[r][c]
            p1 = K_P1 if c >= 10 else 0
            if ch == "H":
                if c > 0 and outline[r][c - 1] == "#":
                    t, k = T["T_PIER_W"], K_HARB | p1
                elif c < COLS - 1 and outline[r][c + 1] == "#":
                    t, k = T["T_PIER_E"], K_HARB | p1
                else:
                    sys.exit("harbour at row %d col %d needs land beside it" % (r, c))
            elif ch == "r":
                t, k = T["T_ROCK"], K_ROCK
            elif ch == "#":
                a = square_art(bm, r, c, beach)
                k = K_LAND | p1
                if a == ["GGGGGGGG"] * 8:
                    t = T["T_GRASS"]
                else:
                    key = (r, tuple(a))
                    if key not in index:
                        index[key] = len(tiles)
                        tiles.append((None, "coast, row %d" % r, False, a))
                        rowtiles[r].append(index[key])
                    t = index[key]
            elif ch == ".":
                t, k = T["T_SEA"], K_SEA
            else:
                sys.exit("unknown outline character %r" % ch)
            kinds[r][c], tgrid[r][c] = k, t
    # pack rows into fonts: consecutive rows share a font while it fits
    fonts, rowfont, cur = [[]], [], []
    for r in range(ROWS):
        if len(fonts[-1]) + len(rowtiles[r]) > PER_FONT:
            fonts.append([])
        if len(rowtiles[r]) > PER_FONT:
            sys.exit("row %d needs %d coast tiles; max %d" % (r, len(rowtiles[r]), PER_FONT))
        fonts[-1] += rowtiles[r]
        rowfont.append(len(fonts) - 1)
    code = {}
    for t in range(NFIX):
        code[t] = 2 * t
    for f in fonts:
        for i, t in enumerate(f):
            code[t] = 2 * (NFIX + i)
    for t, td in enumerate(tiles):
        if td[2]:
            code[t] |= 0x80
    stats = []
    for side, cols in (("left", range(0, 10)), ("right", range(10, 20))):
        land = [(r, c) for r in range(ROWS) for c in cols if outline[r][c] == "#"]
        full = sum(1 for r, c in land if tgrid[r][c] == T["T_GRASS"])
        px = sum(1 for y in range(PH) for x in range(cols.start * 8, cols.stop * 8) if bm[y][x])
        edge = 0
        for y in range(PH):
            for x in range(cols.start * 8, cols.stop * 8):
                if bm[y][x]:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if not (0 <= nx < PW and 0 <= ny < PH) or not bm[ny][nx]:
                            edge += 1
        rows = [r for r, c in land]
        harb = [(r, c if side == "left" else COLS - 1 - c)
                for r in range(ROWS) for c in cols if outline[r][c] == "H"]
        stats.append("  %-5s land squares %d (%d full, %d coast), land pixels %d "
                     "(%.0f%% of its squares), coastline %d px, land rows %d-%d, harbour %s"
                     % (side, len(land), full, len(land) - full, px,
                        100.0 * px / (64 * len(land)), edge,
                        min(rows), max(rows),
                        ", ".join("row %d, %d from the outer edge" % h for h in harb)))
    return dict(name=name, desc=desc, bm=bm, outline=outline, tiles=tiles,
                kinds=kinds, tgrid=tgrid, fonts=fonts, rowfont=rowfont,
                code=code, stats=stats)


def tile_bytes(a):
    """Return (left char 8 bytes, right char 8 bytes) for 8x8 art."""
    assert len(a) == 8 and all(len(r) == 8 for r in a), a
    left, right = [], []
    for row in a:
        p = [PIX[c] for c in row]
        left.append(p[0] << 6 | p[1] << 4 | p[2] << 2 | p[3])
        right.append(p[4] << 6 | p[5] << 4 | p[6] << 2 | p[7])
    return left, right


def hexes(bs):
    return ",".join("$%02X" % b for b in bs)


def banner(name, what):
    return ["; " + "=" * 69,
            ";  %s -- generated by tools/mkfont.py; do not edit by hand" % name,
            ";  " + what,
            "; " + "=" * 69, ""]


FONT_ADDR = [0x3000, 0x4800, 0x4C00, 0x5000]


def write_png(path, rgb, w, h):
    raw = b"".join(b"\x00" + bytes(v for p in rgb[y * w:(y + 1) * w] for v in p)
                   for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)


PAL = {".": (40, 72, 176), "G": (64, 150, 40), "D": (0, 0, 0), "Y": (224, 200, 60),
       "W": (236, 236, 236)}


def preview(p, path):
    """Render the pair as the Atari shows it (pixel = 4 x 4)."""
    S = 4
    w, h = PW * S, PH * S
    rgb = [PAL["."]] * (w * h)
    rgb = list(rgb)
    for r in range(ROWS):
        for c in range(COLS):
            t = p["tiles"][p["tgrid"][r][c]]
            for y in range(8):
                for x in range(8):
                    ch = t[3][y][x]
                    col = PAL["W"] if (ch == "Y" and t[2]) else PAL[ch]
                    for dy in range(S):
                        base = ((r * 8 + y) * S + dy) * w + (c * 8 + x) * S
                        for dx in range(S):
                            rgb[base + dx] = col
    write_png(path, rgb, w, h)


def main():
    prev_dir = None
    if "--preview" in sys.argv:
        prev_dir = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(prev_dir, exist_ok=True)
    built = [build_pair(n, d, l, r, s, BEACH) for n, d, l, r, s in PAIRS]
    if prev_dir:
        for n, d, l, r, s in PAIRS:
            for beach in (True, False):
                p = build_pair(n, d, l, r, s, beach)
                preview(p, os.path.join(prev_dir, "islands-%s-%s.png"
                                        % (n, "beach" if beach else "plain")))

    # tiles.asm
    out = banner("TILES.ASM", "Map tile numbers and cell kinds.")
    for n, (equ, comment, inv, a) in enumerate(FIXED):
        out.append("%-11s= %-4d ; %s" % (equ, n, comment))
    out.append("%-11s= %-4d ; item k (1-9) is tile T_ITEM+k-1" % ("T_ITEM", T["T_FORT"]))
    out.append("%-11s= %-4d ; fixed tiles, same character codes in every font" % ("N_FIXED", NFIX))
    out.append("")
    out.append("; Cell kinds (ISLKIND); bit 7 set = square belongs to player 1")
    for nm, v, what in (("K_SEA", K_SEA, "open sea"),
                        ("K_LAND", K_LAND, "land (any land pixels): buildable, boats can't enter"),
                        ("K_HARB", K_HARB, "harbour: boats launch and park here"),
                        ("K_ROCK", K_ROCK, "rock: decorative, plays as sea"),
                        ("K_KIND", 0x7F, "mask for the kind"),
                        ("K_P1", K_P1, "owner bit: player 1 (right island)")):
        out.append("%-11s= $%02X  ; %s" % (nm, v, what))
    open("src/tiles.asm", "w").write("\n".join(out) + "\n")

    # font_map.asm
    out = banner("FONT_MAP.ASM", "Map fonts, 1K aligned.  2 bits per pixel:\n"
                 ";  00 COLBK sea, 01 PF0 grass, 10 PF1 dark, 11 PF2 yellow / PF3 white\n"
                 ";  Fixed tiles first (same codes in every font), then this font's\n"
                 ";  coast tiles.")
    for p in built:
        out.append("        .IF ISL_B" if p["name"] == "B" else "        .IF ISL_B=0")
        for fi, f in enumerate(p["fonts"]):
            out.append("; pair %s, font %d: rows %s, %d coast tiles"
                       % (p["name"], fi, ",".join(str(r) for r in range(ROWS)
                                                  if p["rowfont"][r] == fi), len(f)))
            out.append("        *= $%04X" % FONT_ADDR[fi])
            out.append("MAPFONT" if fi == 0 else "MAPFNT%d" % fi)
            for t in list(range(NFIX)) + f:
                equ, comment, inv, a = p["tiles"][t]
                l, r = tile_bytes(a)
                out.append("; tile %d: %s%s" % (t, comment, " (inverse chars)" if inv else ""))
                out.append("        .BYTE " + hexes(l))
                out.append("        .BYTE " + hexes(r))
        out.append("        .ENDIF")
    open("src/font_map.asm", "w").write("\n".join(out) + "\n")

    # islands.asm
    out = banner("ISLANDS.ASM", "Island data, tile codes and font per row (20 x 11).")
    for p in built:
        out.append("        .IF ISL_B" if p["name"] == "B" else "        .IF ISL_B=0")
        out.append("; Island pair %s: %s" % (p["name"], p["desc"]))
        codes = [p["code"][t] for t in range(len(p["tiles"]))]
        out.append("; TILECH: character code of each tile's left half (bit 7 = white)")
        out.append("TILECH")
        for i in range(0, len(codes), 16):
            out.append("        .BYTE " + hexes(codes[i:i + 16]))
        out.append("; ROWFONT: font page (CHBASE) for each map row")
        out.append("ROWFONT .BYTE " + ",".join(
            ">MAPFONT" if f == 0 else ">MAPFNT%d" % f for f in p["rowfont"]))
        out.append("; ISLKIND: cell kind per square (K_ values, bit 7 = player 1)")
        out.append("ISLKIND")
        for r in range(ROWS):
            out.append("        .BYTE " + hexes(p["kinds"][r]) + "   ; " + p["outline"][r])
        out.append("; ISLTILE: terrain tile per square, drawn by MAP_DRAW")
        out.append("ISLTILE")
        for r in range(ROWS):
            out.append("        .BYTE " + hexes(p["tgrid"][r]))
        out.append("N_TILES = %d" % len(p["tiles"]))
        out.append("N_FONTS = %d" % len(p["fonts"]))
        out.append("        .ENDIF")
    open("src/islands.asm", "w").write("\n".join(out) + "\n")

    for p in built:
        print("Pair %s (%s): %d tiles, %d fonts (coast tiles per font %s), rows->font %s"
              % (p["name"], p["desc"], len(p["tiles"]), len(p["fonts"]),
                 "/".join(str(len(f)) for f in p["fonts"]), "".join(map(str, p["rowfont"]))))
        print("\n".join(p["stats"]))


main()
