#!/usr/bin/env python3
"""Generate the Acadia map fonts, tile list and island data.

Writes three files (do not edit them by hand):

  src/tiles.asm     tile-number and cell-kind equates
  src/font_map.asm  the map fonts (1K each, fixed addresses) and the
                    help font
  src/islands.asm   TILECH / TILECTR / TILECBL / TILECBR (tile ->
                    character codes), HLPCH (help font codes),
                    ROWFONT (font page per character row), ISLKIND
                    (cell kinds), ISLTILE (terrain tile per square) and
                    AI_HD / AI_UP / AI_DN (steps by sea for the CPU's
                    boat: to its harbour, above, below the islands)

The map is ANTIC mode 4 (D50).  Each map square is one tile = 2 x 2
mode 4 characters = 8 x 16 pixels at 160 resolution, shown 8 colour
clocks wide and 16 scan lines tall (the same size as the old mode 5
squares, so sprites and grid maths are unchanged).

Islands are drawn at pixel level.  Each island starts as a square
outline (LEFT and RIGHT below); a seeded, deterministic erosion pass
makes the coast ragged at 160 x 88, which is doubled to 160 x 176 and
smoothed.  Land pixels next to the sea are sand, the rest textured
grass; sea pixels next to the land in a land square are surf.  Every
square holding any land is a land square (buildable, boats can't
enter), as in the original.  Fixed tiles (sea, waves, grass, items, ...)
have the same character codes in every font; coast characters go into
the font of the character row they sit on, and the display switches
fonts per character row with a DLI.

Pixel letters: . sea (COLBK)  G grass (PF0)  D dark (PF1)
               Y sand / yellow (PF2)  W white (PF3)
A character (4 x 8 pixels) can't hold both Y and W: its 11 pixels are
PF2, or PF3 when the character is inverse (bit 7 of its code).
All art here is new; nothing comes from the original game.

Run from the repo root:  python3 -I tools/mkfont.py [--preview DIR]
"""

import random
import sys
import os
import zlib
import struct

TW, TH = 8, 16                 # tile size in pixels
CROWS = 22                     # character rows in the map

# ---------------------------------------------------------------------
#  Item tiles, numbered as the keypad keys (1-9): (name, art)
# ---------------------------------------------------------------------
ITEMS = {
    1: ("fort", [
        "WGWGGWGW",
        "WWWGGWWW",
        "WWWGGWWW",
        "WDWWWWDW",
        "WWWWWWWW",
        "WWDWWDWW",
        "WWWWWWWW",
        "WDWWWWDW",
        "WWWWWWWW",
        "WWWDDWWW",
        "WWDDDDWW",
        "WWDDDDWW",
        "WWDDDDWW",
        "WWDDDDWW",
        "DDDDDDDD",
        "GGGGGGGG"]),
    2: ("factory", [
        "GGGGGWWG",
        "GGGGWWWW",
        "GGGGGWWG",
        "GGGGGGDG",
        "GGGGGGDG",
        "GDGGGDDG",
        "DDGDDDDD",
        "DDDDDDDD",
        "DDDDDDDD",
        "DYDYDYDD",
        "DDDDDDDD",
        "DYDYDYDD",
        "DDDDDDDD",
        "DDDDDDDD",
        "GGGGGGGG",
        "GGGGGGGG"]),
    3: ("crop", [
        "GGGGGGGG",
        "GYYYYYYG",
        "GDDDDDDG",
        "GYYYYYYG",
        "GDDDDDDG",
        "GYYYYYYG",
        "GDDDDDDG",
        "GYYYYYYG",
        "GDDDDDDG",
        "GYYYYYYG",
        "GDDDDDDG",
        "GYYYYYYG",
        "GDDDDDDG",
        "GYYYYYYG",
        "GGGGGGGG",
        "GGGGGGGG"]),
    4: ("school", [
        "GGGGGDWW",
        "GGGGGDWW",
        "GGGGGDGG",
        "GGGDDDGG",
        "GGDDDDDG",
        "GDDDDDDD",
        "DDDDDDDD",
        "WWWWWWWW",
        "WDWWWWDW",
        "WDWWWWDW",
        "WWWWWWWW",
        "WDWDDWDW",
        "WWWDDWWW",
        "WWWDDWWW",
        "DDDDDDDD",
        "GGGGGGGG"]),
    5: ("hospital", [
        "GGGGGGGG",
        "WWWWWWWW",
        "WWWDDWWW",
        "WWWDDWWW",
        "WDDDDDDW",
        "WDDDDDDW",
        "WWWDDWWW",
        "WWWDDWWW",
        "WWWWWWWW",
        "WDWWWWDW",
        "WWWWWWWW",
        "WWWDDWWW",
        "WWWDDWWW",
        "WWWDDWWW",
        "DDDDDDDD",
        "GGGGGGGG"]),
    6: ("house", [
        "GGGGGGGG",
        "GGGGGGGG",
        "GGGDDGGG",
        "GGDDDDGG",
        "GDDDDDDG",
        "DDDDDDDD",
        "DDDDDDDD",
        "GGGGGGGG",
        "GWWWWWWG",
        "GWDWWDWG",
        "GWWWWWWG",
        "GWWDDWWG",
        "GWWDDWWG",
        "GWWDDWWG",
        "GDDDDDDG",
        "GGGGGGGG"]),
    7: ("rebel", [
        "GGGGGGGG",
        "GYGGGGYG",
        "GDGGGGDG",
        "GDGDDGDG",
        "GDDDDDDG",
        "DGDDDDGD",
        "GGDDDDGG",
        "GGDDDDGG",
        "GGDGGDGG",
        "GGDGGDGG",
        "GDDGGDDG",
        "GGGGGGGG",
        "GGGGGGGG",
        "GGGGGGGG",
        "GGGGGGGG",
        "GGGGGGGG"]),
    8: ("PT boat", [
        "........",
        "........",
        "........",
        "........",
        "........",
        "...YY...",
        "..YYYY..",
        ".YYYYYY.",
        "DDDDDDDD",
        "DDDDDDDD",
        ".DDDDDD.",
        "..DDDD..",
        "........",
        "........",
        "........",
        "........"]),
    9: ("fishing boat", [
        "........",
        "...D....",
        "...DY...",
        "...DYY..",
        "...DYYY.",
        "...DYYYY",
        "...DYYY.",
        "...D....",
        "...D....",
        "DDDDDDDD",
        "DDDDDDDD",
        ".DDDDDD.",
        "..DDDD..",
        "........",
        "........",
        "........"]),
}

WRECK = [
    "........",
    "........",
    "........",
    "........",
    "......D.",
    ".....D..",
    "....D...",
    "...D....",
    "..DDDDD.",
    ".D.D.D..",
    "........",
    "..W...W.",
    "........",
    "........",
    "........",
    "........"]

BLANK = ["........"] * 16

ROCK = [
    "........",
    "........",
    "........",
    "........",
    "...DD...",
    "..DDDD..",
    ".DDYDDD.",
    ".DDDDDD.",
    "DDDDDDDD",
    "DDDDDDDD",
    ".WW..WW.",
    "........",
    "........",
    "........",
    "........",
    "........"]

# Harbour pier, drawn for land to the west; mirrored for land to the east
PIER_W = [
    "........",
    "........",
    "........",
    "........",
    "YYYYYYY.",
    "YYYYYYY.",
    "DDDDDDD.",
    "D..D..D.",
    "D..D..D.",
    "D..D..D.",
    "........",
    "........",
    "........",
    "........",
    "........",
    "........"]

# Wave glints and sparkles on the open sea (white: inverse characters),
# animated by WAVE_ANI in WV_PH phases.  A wave tile has one crest at
# (row, column) that rolls right and breaks; WAVE2 runs WV_PH / 2
# behind.  The sparkle tile has two dots that twinkle in turn.
WV_PH = 4
CREST = [[".WW.", "W..W"],          # phase 0: a crest
         [".WW.", "W..W"],          # 1: the same, 1 pixel right
         ["..W.", ".W.W"],          # 2: breaking up, 2 right
         []]                        # 3: calm
WAVE_GLINTS = {"T_WAVE1": [(4, 1)], "T_WAVE2": [(10, 1)]}
WAVE_LAG = {"T_WAVE1": 0, "T_WAVE2": WV_PH // 2, "T_SPARK": 0}
SPARKS = [[(3, 1)], [(3, 1)], [(6, 3)], []]     # dots (row, column) by phase


def wave_frame(name, phase):
    """8 x 16 art of animated sea tile name in phase 0-3."""
    a = [list("........") for _ in range(TH)]
    p = (phase + WAVE_LAG[name]) % WV_PH
    if name == "T_SPARK":
        for row, col in SPARKS[p]:
            a[row][col] = "W"
    for row, col in WAVE_GLINTS.get(name, []):
        for dy, line in enumerate(CREST[p]):
            for dx, ch in enumerate(line):
                if ch == "W":
                    a[row + dy][col + min(p, 2) + dx] = "W"
    return ["".join(x) for x in a]


WAVE1 = wave_frame("T_WAVE1", 0)
WAVE2 = wave_frame("T_WAVE2", 0)
SPARK = wave_frame("T_SPARK", 0)

# Grass texture: a few dark specks on green.  Full grass squares pick
# one of four variants (grass_tile) built from the same two speck
# characters in different quarters, so the specks don't line up and
# cost no extra characters; coast squares use the same variant.
GRASS = [
    "GGGGGGGG",
    "GGGGGGGG",
    "GDGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGDG",
    "GGGGGGGG",
    "GGGGGGGG"]

GRASS2 = [
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGDGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGDGGGGG",
    "GGGGGGGG",
    "GGGGGGGG"]

GRASS3 = [
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GDGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG",
    "GGGGGGGG"]

GRASS4 = ["GGGGGGGG"] * 16
GRASS_ART = (GRASS, GRASS2, GRASS3, GRASS4)

ITEM_EQU = ["T_FORT", "T_FACTORY", "T_CROP", "T_SCHOOL", "T_HOSPITAL",
            "T_HOUSE", "T_REBEL", "T_PTBOAT", "T_FISHBOAT"]

PIX = {".": 0, "G": 1, "D": 2, "Y": 3, "W": 3}

# ---------------------------------------------------------------------
#  Island outlines.  One string per square row, 10 squares per island.
#    .  sea      #  land      H  harbour (pier; boats launch here)
#    r  rock (decorative only: plays as open sea)
#  The erosion pass roughens the coast inside the land squares; it
#  never adds land to a sea square, so the outline fixes the square
#  count.  Rows 0-1 and 9-10 stay open sea (fish and pirate bands);
#  screen columns 9-10 stay open sea (channel).
# ---------------------------------------------------------------------
LEFT = [
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

RIGHT = [
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

# Island pair B was chosen (D24): this left island and a different,
# non-mirrored right island with the same number of land squares.
# It is map 1, ACADIA, on the setup screen's MAP line (D56).

# Map 2, ISLES: each side three or four islets, 35 squares in all.
ISLES_L = [
    "..........",
    "..........",
    "...###.##.",
    "..####.##.",
    ".H####.##.",
    "..#####...",
    "..........",
    "..#######.",
    "..######..",
    "..........",
    "..........",
]

ISLES_R = [
    "..........",
    "..........",
    ".##..####.",
    ".###.####.",
    ".###.###H.",
    ".##..####.",
    "..........",
    "...######.",
    "....####..",
    "..........",
    "..........",
]

# Map 3, LAGOON: horseshoe islands round a sheltered bay, the left one
# open to the channel, the right one to the south.
LAGOON_L = [
    "..........",
    "..........",
    "...####...",
    "..#######.",
    ".H###..##.",
    "..###.....",
    "..###..##.",
    "..#######.",
    "...####...",
    "..........",
    "..........",
]

LAGOON_R = [
    "..........",
    "..........",
    "..######..",
    ".########.",
    ".###..##H.",
    ".###..###.",
    ".##....##.",
    ".##...##..",
    "..#....#..",
    "..........",
    "..........",
]

# The maps (D56): setup name (6 characters), outlines, erosion seeds and
# the 1K font slots their coast characters go in.  Map 1's fonts stay
# where they were; the other maps' fonts fill free RAM above the logo.
MAPS = [
    ("ACADIA", LEFT, RIGHT, (11, 29), [0x3000, 0x4800, 0x8800]),
    (" ISLES", ISLES_L, ISLES_R, (12, 31), [0x8C00, 0x9C00, 0xA000, 0xBC00]),
    ("LAGOON", LAGOON_L, LAGOON_R, (13, 37), [0xA400, 0xA800, 0xAC00]),
]
N_FONTS = 4                    # fonts per map at most (FONTPG padded to this)
MAPSRC = 0xB000                # the maps' data blocks (MAPS0, MAPS1, ...)

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


def pair_map(left, right, seeds):
    """Full 160 x 88 land bitmap plus the 20-column outline."""
    lb = island_bitmap(left, seeds[0])
    rb = island_bitmap(right, seeds[1])
    bm = [lb[y] + rb[y] for y in range(PH)]
    outline = [l + r for l, r in zip(left, right)]
    return bm, outline



H2 = ROWS * TH                 # 176 pixel rows


def land_176(bm, outline):
    """The land bitmap at 160 x 176: rows doubled, smoothed, kept inside
    the land squares, every land square's centre solid."""
    land = [[bm[y // 2][x] for x in range(PW)] for y in range(H2)]
    for _ in range(2):
        nl = [row[:] for row in land]
        for y in range(1, H2 - 1):
            for x in range(1, PW - 1):
                n = sum(land[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1))
                if n >= 6:
                    nl[y][x] = True
                elif n <= 3:
                    nl[y][x] = False
        land = nl
    for y in range(H2):
        for x in range(PW):
            if outline[y // TH][x // TW] != "#":
                land[y][x] = False
    for r in range(ROWS):
        for c in range(COLS):
            if outline[r][c] == "#":
                for y in range(r * TH + 5, r * TH + 11):
                    for x in range(c * TW + 2, c * TW + 6):
                        land[y][x] = True
    return land


def coast_art(land, sy, sx):
    """8 x 16 art for land square sy, sx: sand edge, textured grass,
    surf on the sea next to the land."""
    tex = GRASS_ART[grass_pick(sy, sx)]
    def isl(x, y):
        return 0 <= x < PW and 0 <= y < H2 and land[y][x]
    a = []
    for y in range(sy * TH, sy * TH + TH):
        row = ""
        for x in range(sx * TW, sx * TW + TW):
            if land[y][x]:
                edge = any(not isl(x + dx, y + dy)
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (0, 2), (0, -2)))
                row += "Y" if edge else tex[y % TH][x % TW]
            else:
                near = any(isl(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-2, -1, 0, 1, 2))
                row += "W" if near and (x * 7 + y * 3) % 5 < 3 else "."
        a.append(row)
    return fix_chars(a)


def fix_chars(a):
    """A character can't hold both Y and W: the one with more pixels
    in it wins."""
    a = [list(r) for r in a]
    for cy in (0, 8):
        for cx in (0, 4):
            px = [a[y][x] for y in range(cy, cy + 8) for x in range(cx, cx + 4)]
            if "Y" in px and "W" in px:
                win = "W" if px.count("W") > px.count("Y") else "Y"
                for y in range(cy, cy + 8):
                    for x in range(cx, cx + 4):
                        if a[y][x] in "YW":
                            a[y][x] = win
    return ["".join(r) for r in a]


def pier_art(land_west):
    return PIER_W if land_west else [x[::-1] for x in PIER_W]


FIXED = [("T_SEA", "open sea", ["........"] * 16),
         ("T_GRASS", "plain grass", GRASS)]
for _k in range(1, 10):
    _n, _a = ITEMS[_k]
    FIXED.append((ITEM_EQU[_k - 1], "%d %s" % (_k, _n), _a))
FIXED += [("T_WRECK", "wreck of a parked boat", WRECK),
          ("T_SPARE", "spare (blank)", BLANK),
          ("T_ROCK", "rock (decorative)", ROCK),
          ("T_PIER_W", "harbour pier, land to the west", pier_art(True)),
          ("T_PIER_E", "harbour pier, land to the east", pier_art(False)),
          ("T_WAVE1", "open sea, a wave", WAVE1),
          ("T_WAVE2", "open sea, another wave", WAVE2),
          ("T_SPARK", "open sea, sparkles", SPARK),
          ("T_GRASS2", "plain grass, other specks", GRASS2),
          ("T_GRASS3", "plain grass, one speck", GRASS3),
          ("T_GRASS4", "plain grass, no specks", GRASS4)]
T = {t[0]: n for n, t in enumerate(FIXED)}
NFIX = len(FIXED)


def quarters(a):
    """The 4 characters of 8 x 16 art: (bytes, inverse) for top left,
    top right, bottom left, bottom right."""
    assert len(a) == TH and all(len(r) == TW for r in a), a
    out = []
    for cy, cx in ((0, 0), (0, 4), (8, 0), (8, 4)):
        px = [a[y][cx:cx + 4] for y in range(cy, cy + 8)]
        flat = "".join(px)
        assert not ("Y" in flat and "W" in flat), "Y and W in one character: %r" % px
        bs = tuple(PIX[r[0]] << 6 | PIX[r[1]] << 4 | PIX[r[2]] << 2 | PIX[r[3]] for r in px)
        out.append((bs, "W" in flat))
    return out


# Rounded corners (D55): the top and bottom CORNER_CR character rows hold
# no land.  There COLBK is the darker corner blue and the sea is drawn
# in PF0 (light sea, set per row by VD_SHADE instead of grass), except
# a quarter ellipse CORNER_RX colour clocks wide and the rows' height
# tall in each corner of the map, left at COLBK.  So the dark corners
# run into the screen border and the dark area under the map.
CORNER_CR = (0, 1, 2, 19, 20, 21)
CORNER_RX = 32


def corner_dark(x, y):
    """Is map pixel x (0-159), line y (0-175) in a dark corner?"""
    ry = 8 * 3
    if ry <= y < 176 - ry:
        return False
    dy = (y + 0.5 - ry) / ry if y < ry else (y + 0.5 - (176 - ry)) / ry
    if x < CORNER_RX:
        dx = (x + 0.5 - CORNER_RX) / CORNER_RX
    elif x >= 160 - CORNER_RX:
        dx = (x + 0.5 - (160 - CORNER_RX)) / CORNER_RX
    else:
        return False
    return dx * dx + dy * dy > 1


def corner_art(a, r, c):
    """Art a of a square in row r, column c as drawn in the corner rows:
    its sea pixels PF0 (G), but dark (sea, COLBK) in the corners."""
    out = []
    for y, row in enumerate(a):
        ly = r * TH + y
        if ly // 8 not in CORNER_CR:
            out.append(row)
            continue
        out.append("".join("." if p == "." and corner_dark(c * TW + x, ly)
                           else "G" if p == "." else p
                           for x, p in enumerate(row)))
    return out


def wave_tile(r, c):
    """Decorative sea tile for open-sea square r, c."""
    h = (r * 7 + c * 13) % 18
    return {0: T["T_WAVE1"], 9: T["T_WAVE2"], 5: T["T_SPARK"]}.get(h, T["T_SEA"])


def grass_pick(r, c):
    """Which grass variant (0-3) land square r, c uses."""
    return (r * 5 + c * 3 + r * c) % 4


def grass_tile(r, c):
    """Grass tile for full land square r, c."""
    return (T["T_GRASS"], T["T_GRASS2"], T["T_GRASS3"], T["T_GRASS4"])[grass_pick(r, c)]


def build_pair(mapname, left, right, seeds, font_addr):
    bm, outline = pair_map(left, right, seeds)
    for r in BANDS:
        assert set(outline[r]) <= set(".r"), "map %s row %d must be open sea" % (mapname, r)
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
                sys.exit("map %s: sea square row %d col %d is enclosed by land" % (mapname, r, c))
    for r in range(ROWS):
        for c in CHANNEL:
            assert outline[r][c] in ".r", "map %s channel at row %d" % (mapname, r)
    land = land_176(bm, outline)
    tiles = list(FIXED)
    index = {}
    kinds = [[0] * COLS for _ in range(ROWS)]
    tgrid = [[0] * COLS for _ in range(ROWS)]
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
                a = coast_art(land, r, c)
                k = K_LAND | p1
                if a == GRASS_ART[grass_pick(r, c)]:
                    t = grass_tile(r, c)
                else:
                    key = (r, tuple(a))
                    if key not in index:
                        index[key] = len(tiles)
                        tiles.append((None, "coast, row %d" % r, a))
                    t = index[key]
            elif ch == "." and r in BANDS:
                a = corner_art(FIXED[T["T_SEA"]][2], r, c)    # no waves here
                key = (r, tuple(a))
                if key not in index:
                    index[key] = len(tiles)
                    tiles.append((None, "sea, row %d" % r, a))
                t, k = index[key], K_SEA
            elif ch == ".":
                t, k = wave_tile(r, c), K_SEA
            else:
                sys.exit("unknown outline character %r" % ch)
            kinds[r][c], tgrid[r][c] = k, t
    # parked boats and wrecks in the corner rows: their sea in PF0 (the
    # corner itself is not cut out under them); MAP_PUT picks these
    # through BNDVAR
    bndvar = [0] * ROWS
    for r in BANDS:
        bndvar[r] = len(tiles)
        for name in ("T_PTBOAT", "T_FISHBOAT", "T_WRECK"):
            a = [row.replace(".", "G") if (r * TH + y) // 8 in CORNER_CR else row
                 for y, row in enumerate(FIXED[T[name]][2])]
            tiles.append((None, "%s, row %d" % (name, r), a))
    # characters: fixed ones (deduplicated) get the same codes in every
    # font; coast ones go into the font of their character row
    fixed_code, fixed_list, anim = {}, [], []
    for t in range(NFIX):
        name = tiles[t][0]
        frames = [quarters(wave_frame(name, ph)) for ph in range(WV_PH)] if name in WAVE_LAG else None
        for q, (bs, inv) in enumerate(quarters(tiles[t][2])):
            if frames and any(any(f[q][0]) for f in frames):
                # an animated character: its own code, its bytes per phase
                anim.append((t, q, len(fixed_list), [f[q][0] for f in frames]))
                fixed_list.append(bs)
            elif bs not in fixed_code:
                fixed_code[bs] = len(fixed_list)
                fixed_list.append(bs)
    nfc = len(fixed_list)
    acode = {(t, q): code for t, q, code, fr in anim}
    rowchars = [[] for _ in range(CROWS)]          # coast chars per char row
    for t in range(NFIX, len(tiles)):
        r = int(tiles[t][1].split()[-1])
        for q, (bs, inv) in enumerate(quarters(tiles[t][2])):
            cr = 2 * r + q // 2
            if bs not in fixed_code and bs not in rowchars[cr]:
                rowchars[cr].append(bs)
    # a new font only starts on an odd character row (a square's second),
    # whose DLI sets CHBASE; DLI_SQ has no time for it (D52).  So rows
    # are taken in groups: 0, then 1-2, 3-4, ... 21.
    fonts, rowfont = [[]], []
    groups = [[0]] + [[cr, cr + 1] if cr + 1 < CROWS else [cr] for cr in range(1, CROWS, 2)]
    for grp in groups:
        need = []
        for cr in grp:
            need += [bs for bs in rowchars[cr] if bs not in need]
        new = [bs for bs in need if bs not in fonts[-1]]
        if nfc + len(fonts[-1]) + len(new) > 128:
            fonts.append([])
            new = need
        if nfc + len(need) > 128:
            sys.exit("character rows %r need %d coast characters; max %d"
                     % (grp, len(need), 128 - nfc))
        fonts[-1] += new
        rowfont += [len(fonts) - 1] * len(grp)
    assert all(rowfont[cr] == rowfont[cr - 1] or cr % 2 for cr in range(1, CROWS))
    if len(fonts) > len(font_addr):
        sys.exit("map %s needs %d map fonts; only %d fit" % (mapname, len(fonts), len(font_addr)))
    # the 4 codes of each tile (bit 7 = inverse: 11 pixels white)
    codes = []
    for t, td in enumerate(tiles):
        cs = []
        for q, (bs, inv) in enumerate(quarters(td[2])):
            if (t, q) in acode:
                code, inv = acode[(t, q)], True
            elif bs in fixed_code:
                code = fixed_code[bs]
            else:
                r = int(td[1].split()[-1])
                f = fonts[rowfont[2 * r + q // 2]]
                code = nfc + f.index(bs)
            cs.append(code | (0x80 if inv else 0))
        codes.append(cs)
    fixed_chars = fixed_list
    stats = []
    for side, cols in (("left", range(0, 10)), ("right", range(10, 20))):
        lsq = [(r, c) for r in range(ROWS) for c in cols if outline[r][c] == "#"]
        full = sum(1 for r, c in lsq if tgrid[r][c] in (T["T_GRASS"], T["T_GRASS2"], T["T_GRASS3"], T["T_GRASS4"]))
        px = sum(1 for y in range(H2) for x in range(cols.start * TW, cols.stop * TW) if land[y][x])
        rows = [r for r, c in lsq]
        harb = [(r, c if side == "left" else COLS - 1 - c)
                for r in range(ROWS) for c in cols if outline[r][c] == "H"]
        stats.append("  %-5s land squares %d (%d full, %d coast), land pixels %d "
                     "(%.0f%% of its squares), land rows %d-%d, harbour %s"
                     % (side, len(lsq), full, len(lsq) - full, px,
                        100.0 * px / (TW * TH * len(lsq)), min(rows), max(rows),
                        ", ".join("row %d, %d from the outer edge" % h for h in harb)))
    return dict(name=mapname, font_addr=font_addr, land=land, outline=outline, tiles=tiles, bndvar=bndvar,
                kinds=kinds, tgrid=tgrid, fonts=fonts, rowfont=rowfont,
                codes=codes, fixed_chars=fixed_chars, anim=anim, stats=stats)

def sea_steps(kinds, goal):
    """Steps by sea from each square to the nearest square where
    goal(row, column) is true: 4 ways, never over land; 255 for land
    and squares that can't reach one."""
    rows, cols = len(kinds), len(kinds[0])
    steps = [[255] * cols for _ in range(rows)]
    todo = [(r, c) for r in range(rows) for c in range(cols)
            if goal(r, c) and kinds[r][c] & 0x7F != K_LAND]
    for r, c in todo:
        steps[r][c] = 0
    for r, c in todo:                    # breadth first: todo grows
        for nr, nc in ((r, c - 1), (r, c + 1), (r - 1, c), (r + 1, c)):
            if (0 <= nr < rows and 0 <= nc < cols and steps[nr][nc] == 255
                    and kinds[nr][nc] & 0x7F != K_LAND):
                steps[nr][nc] = steps[r][c] + 1
                todo.append((nr, nc))
    return steps


def hexes(bs):
    return ",".join("$%02X" % b for b in bs)


def banner(name, what):
    return ["; " + "=" * 69,
            ";  %s -- generated by tools/mkfont.py; do not edit by hand" % name,
            ";  " + what,
            "; " + "=" * 69, ""]



# map fonts, 1K aligned, at the slots MAPS gives; $4C00 holds the help
# font.  The live island data (islands.asm) is at $9000, the status bar
# font (tools/mkstat.py) at $9800, the maps' data blocks at MAPSRC.

# ---------------------------------------------------------------------
#  Help font (T-SCR-3): the fixed tiles at their usual codes, then 3 x 5
#  letters and digits for mode 5 text.  A glyph's code is its screen
#  code + HELP_OFS (digits $30-$39, letters $41-$5A); space is code 0,
#  the blank sea tile.  Glyph pixels are 11: yellow (PF2), or white
#  (PF3) when the character is inverse.
# ---------------------------------------------------------------------
HELP_ADDR = 0x4C00
HELP_OFS = 32
GLYPHS = {
    "0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", ".#.", "#..", "###"], "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "##.", "..#", "##."],
    "6": [".##", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "##."],
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
    "Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
    ":": ["...", ".#.", "...", ".#.", "..."], "-": ["...", "...", "###", "...", "..."],
    ".": ["...", "...", "...", "...", ".#."],
}


def screen_code(ch):
    """Atari screen code of an ASCII character (as .SBYTE gives it)."""
    a = ord(ch)
    return a - 32 if 32 <= a < 96 else a




# 8 x 8 item icons for the help screen (mode 5), in the map tiles' style
HELP_ITEMS = {
    1: ["WGWGGWGW", "WWWWWWWW", "WDWWWWDW", "WWWWWWWW",
        "WWWDDWWW", "WWDDDDWW", "WWDDDDWW", "DDDDDDDD"],
    2: ["GGGGGWWG", "GGGGWWGG", "GGGGGDGG", "GDGGDDGG",
        "DDDDDDDD", "DDDDDDDD", "DDDDDDDD", "GGGGGGGG"],
    3: ["GYYYYYYG", "GDDDDDDG", "GYYYYYYG", "GDDDDDDG",
        "GYYYYYYG", "GDDDDDDG", "GYYYYYYG", "GGGGGGGG"],
    4: ["GGGGDWWG", "GGGDDDGG", "GDDDDDDG", "DDDDDDDD",
        "WWWWWWWW", "WDWWWWDW", "WWWDDWWW", "DDDDDDDD"],
    5: ["WWWWWWWW", "WWWDDWWW", "WDDDDDDW", "WWWDDWWW",
        "WWWWWWWW", "WDWDDWDW", "WWWDDWWW", "DDDDDDDD"],
    6: ["GGGDDGGG", "GGDDDDGG", "GDDDDDDG", "DDDDDDDD",
        "GWWWWWWG", "GWDWWDWG", "GWWDDWWG", "GWWDDWWG"],
    7: ["GYGGGGYG", "GDGDDGDG", "GDDDDDDG", "DGDDDDGD",
        "GGDDDDGG", "GGDGGDGG", "GDDGGDDG", "GGGGGGGG"],
    8: ["........", "........", "...YY...", "..YYYY..",
        "DDDDDDDD", ".DDDDDD.", "..DDDD..", "........"],
    9: ["...D....", "...DY...", "...DYY..", "...DYYY.",
        "...D....", "DDDDDDDD", ".DDDDDD.", "........"],
}


def help_art(a):
    """8 x 8 mode 5 version of 8 x 16 art for the help screen: each pair
    of rows merged (white / yellow over dark over grass over sea)."""
    pri = {"W": 3, "Y": 3, "D": 2, "G": 1, ".": 0}
    out = []
    for y in range(0, TH, 2):
        out.append("".join(max(a[y][x], a[y + 1][x], key=lambda p: pri[p]) for x in range(TW)))
    for cx in (0, 4):            # a mode 5 character is 4 x 8: Y or W
        px = [out[y][x] for y in range(8) for x in range(cx, cx + 4)]
        if "Y" in px and "W" in px:
            win = "W" if px.count("W") > px.count("Y") else "Y"
            out = [r[:cx] + "".join(win if p in "YW" else p for p in r[cx:cx + 4]) + r[cx + 4:]
                   for r in out]
    return out


def help_font():
    """Return the help font's bytes (128 characters, 1K) and each fixed
    tile's left and right codes in it."""
    font = [0] * 1024
    lcodes, rcodes = [], []
    for t in range(NFIX):
        k = t - T["T_ITEM" if "T_ITEM" in T else "T_FORT"] + 1
        a = HELP_ITEMS[k] if 1 <= k <= 9 else help_art(FIXED[t][2])
        for half in (0, 1):
            code = 2 * t + half
            px = [r[4 * half:4 * half + 4] for r in a]
            font[8 * code:8 * code + 8] = [PIX[r[0]] << 6 | PIX[r[1]] << 4 | PIX[r[2]] << 2 | PIX[r[3]]
                                           for r in px]
            inv = 0x80 if "W" in "".join(px) else 0
            (lcodes if half == 0 else rcodes).append(code | inv)
    for ch, g in GLYPHS.items():
        code = screen_code(ch) + HELP_OFS
        assert 2 * NFIX <= code < 128, ch
        for y, row in enumerate(g):
            font[8 * code + 2 + y] = sum(3 << (6 - 2 * x) for x, c in enumerate(row) if c == "#")
    return font, lcodes, rcodes

def write_png(path, rgb, w, h):
    raw = b"".join(b"\x00" + bytes(v for p in rgb[y * w:(y + 1) * w] for v in p)
                   for y in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    open(path, "wb").write(png)




PAL = {".": (74, 104, 182), "G": (55, 136, 64), "D": (0, 37, 0), "Y": (235, 215, 126),
       "W": (236, 236, 236)}


def preview(p, path):
    """Render the pair as the Atari shows it (pixel = 4 x 2)."""
    w, h = PW * 4, H2 * 2
    rgb = [PAL["."]] * (w * h)
    for r in range(ROWS):
        for c in range(COLS):
            a = p["tiles"][p["tgrid"][r][c]][2]
            for y in range(TH):
                for x in range(TW):
                    col = PAL[a[y][x]]
                    for dy in range(2):
                        base = ((r * TH + y) * 2 + dy) * w + (c * TW + x) * 4
                        for dx in range(4):
                            rgb[base + dx] = col
    write_png(path, rgb, w, h)


def main():
    prev_dir = None
    if "--preview" in sys.argv:
        prev_dir = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(prev_dir, exist_ok=True)
    ps = [build_pair(*m) for m in MAPS]
    p = ps[0]
    for q in ps[1:]:
        assert q["fixed_chars"] == p["fixed_chars"] and q["anim"] == p["anim"]
    if prev_dir:
        for q in ps:
            preview(q, os.path.join(prev_dir, "map-%s.png" % q["name"].strip().lower()))
    ntiles = max(len(q["tiles"]) for q in ps)

    # tiles.asm
    out = banner("TILES.ASM", "Map tile numbers and cell kinds.")
    for n, (equ, comment, a) in enumerate(FIXED):
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
    nfc = len(p["fixed_chars"])
    out = banner("FONT_MAP.ASM", "Map fonts (ANTIC mode 4), 1K aligned.  2 bits per pixel:\n"
                 ";  00 COLBK sea, 01 PF0 grass, 10 PF1 dark, 11 PF2 yellow / PF3 white\n"
                 ";  %d fixed characters first (same codes in every font), then this\n"
                 ";  font's coast characters.  Each map (D56) has its own fonts." % nfc)
    for mi, q in enumerate(ps):
        for fi, f in enumerate(q["fonts"]):
            out.append("; map %d (%s) font %d: character rows %s, %d coast characters"
                       % (mi + 1, q["name"].strip(), fi,
                          ",".join(str(r) for r in range(CROWS) if q["rowfont"][r] == fi), len(f)))
            out.append("        *= $%04X" % q["font_addr"][fi])
            out.append("MFNT%d%d" % (mi, fi))
            for bs in q["fixed_chars"] + f:
                out.append("        .BYTE " + hexes(bs))
    out.append("")
    out.append("; help font (T-SCR-3, mode 5): fixed tiles at codes 2t, 2t+1 (HLPCH,")
    out.append("; HLPCHR), then 3 x 5 letters and digits at screen code + HELP_OFS")
    out.append("        *= $%04X" % HELP_ADDR)
    out.append("HLPFONT")
    hf, hl, hr = help_font()
    last = max(screen_code(c) for c in GLYPHS) + HELP_OFS
    for i in range(0, 8 * (last + 1), 8):
        out.append("        .BYTE " + hexes(hf[i:i + 8]))
    out.append("HELP_OFS = %d" % HELP_OFS)
    an = p["anim"]
    out.append("")
    out.append("; WVDATA: the wave characters' frames, WV_PH phases of WV_N characters")
    out.append("; (WAVE_ANI, D51); it fills the help font's 1K block up to CODE2")
    out.append("WVDATA")
    for ph in range(WV_PH):
        for t, q, code, fr in an:
            out.append("        .BYTE " + hexes(fr[ph]) + "   ; phase %d, tile %d quarter %d, code $%02X"
                       % (ph, t, q, code))
    assert HELP_ADDR + 8 * (last + 1) + 8 * WV_PH * len(an) <= HELP_ADDR + 1024, "help block full"
    open("src/font_map.asm", "w").write("\n".join(out) + "\n")

    def map_block(q, mi, live):
        """A map's data block: the live one (labels used by the game,
        RAM: MAP_LOAD copies a map's block over it) or a map's copy."""
        o = []
        def lab(name):
            return name if live else "%s%d" % (name[:4], mi)
        for qi, (name, what) in enumerate((("TILECH", "top left"), ("TILECTR", "top right"),
                                          ("TILECBL", "bottom left"), ("TILECBR", "bottom right"))):
            codes = [cs[qi] for cs in q["codes"]] + [0] * (ntiles - len(q["codes"]))
            if live:
                o.append("; %s: character code of each tile's %s quarter (bit 7 = white)" % (name, what))
                o.append(name)
            elif qi == 0:
                o.append("MAPS%d" % mi)
            for i in range(0, len(codes), 16):
                o.append("        .BYTE " + hexes(codes[i:i + 16]))
        if live:
            o.append("; ROWFONT: font page (CHBASE) for each character row (2 per square row)")
            o.append("ROWFONT")
        names = [">MFNT%d%d" % (mi, f) for f in q["rowfont"]]
        o.append("        .BYTE " + ",".join(names[:11]))
        o.append("        .BYTE " + ",".join(names[11:]))
        if live:
            o.append("; ISLKIND: cell kind per square (K_ values, bit 7 = player 1)")
            o.append("ISLKIND")
        for r in range(ROWS):
            o.append("        .BYTE " + hexes(q["kinds"][r]) + "   ; " + q["outline"][r])
        if live:
            o.append("; ISLTILE: terrain tile per square, drawn by MAP_DRAW")
            o.append("ISLTILE")
        for r in range(ROWS):
            o.append("        .BYTE " + hexes(q["tgrid"][r]))
        if live:
            o.append("; BNDVAR: per square row, the tile drawn for a PT boat there (+1 a")
            o.append("; fishing boat, +2 a wreck), 0 for the usual ones (corner rows, D55)")
            o.append("BNDVAR")
        o.append("        .BYTE " + hexes(q["bndvar"]))
        if live:
            o.append("; FONTPG: each map font's page, for WAVE_ANI")
            o.append("FONTPG")
        fp = list(range(len(q["fonts"])))
        fp += [fp[-1]] * (N_FONTS - len(fp))
        o.append("        .BYTE " + ",".join(">MFNT%d%d" % (mi, f) for f in fp))
        if live:
            o.append("MAPEND")
            o.append("MAPBLK  = MAPEND-TILECH ; bytes MAP_LOAD copies")
        return o

    # islands.asm
    out = banner("ISLANDS.ASM", "Island data, tile codes and font per character row (20 x 11).\n"
                 ";  The block from TILECH to FONTPG and the AI_ tables are RAM: they\n"
                 ";  start as map 1's, and MAP_LOAD copies a map's block (MAPS0 ...)\n"
                 ";  over them and works out the AI_ tables again (D56).")
    out += map_block(p, 0, True)
    out.append("; AI_HD: steps by sea (4 ways, not over land) from each square to")
    out.append("; player 2's harbour, the CPU's way home (AI.ASM); $FF: land or none.")
    out.append("; MAP_LOAD works these out for each map; map 1's are here for tests.")
    out.append("AI_HD")
    steps = sea_steps(p["kinds"], lambda r, c: p["kinds"][r][c] == K_HARB | K_P1)
    for r in range(ROWS):
        out.append("        .BYTE " + hexes(steps[r]))
    out.append("; AI_UP, AI_DN: steps by sea to the open sea above the islands")
    out.append("; (rows 0-1) and below them (rows 9-10), the CPU's way round them")
    for name, goal in (("AI_UP", lambda r, c: r < 2), ("AI_DN", lambda r, c: r > ROWS - 3)):
        out.append(name)
        steps = sea_steps(p["kinds"], goal)
        for r in range(ROWS):
            out.append("        .BYTE " + hexes(steps[r]))
    out.append("; HLPCH, HLPCHR: help font codes of each fixed tile's left / right half")
    out.append("HLPCH   .BYTE " + hexes(hl))
    out.append("HLPCHR  .BYTE " + hexes(hr))
    out.append("; Wave animation (WAVE_ANI, D51): WV_N characters, WV_PH phases.")
    out.append("; WVDL / WVDH: a character's offset in its font (code x 8) less")
    out.append("; 8 x its index, so one Y indexes both WVDATA (in FONT_MAP.ASM) and")
    out.append("; the font.  WVSRCL / WVSRCH: each phase's WVDATA.")
    offs = [code * 8 - i * 8 for i, (t, q, code, fr) in enumerate(an)]
    assert all(o >= 0 for o in offs)
    out.append("WVDL    .BYTE " + hexes([o & 255 for o in offs]))
    out.append("WVDH    .BYTE " + hexes([o >> 8 for o in offs]))
    out.append("WVSRCL  .BYTE " + ",".join("<[WVDATA+%d]" % (ph * 8 * len(an)) for ph in range(WV_PH)))
    out.append("WVSRCH  .BYTE " + ",".join(">[WVDATA+%d]" % (ph * 8 * len(an)) for ph in range(WV_PH)))
    out.append("WV_N    = %d" % len(an))
    out.append("WV_PH   = %d" % WV_PH)
    out.append("N_TILES = %d" % ntiles)
    out.append("N_FONTS = %d" % N_FONTS)
    out.append("N_MAPS  = %d" % len(ps))
    out.append("")
    out.append("; The maps' data blocks (D56), each laid out as TILECH ... FONTPG")
    out.append("        *= $%04X" % MAPSRC)
    out.append("MAPSL   .BYTE " + ",".join("<MAPS%d" % i for i in range(len(ps))))
    out.append("MAPSH   .BYTE " + ",".join(">MAPS%d" % i for i in range(len(ps))))
    for mi, q in enumerate(ps):
        out.append("; map %d: %s" % (mi + 1, q["name"].strip()))
        out += map_block(q, mi, False)
    out.append("MAPSEND")
    out.append("; MAPNAME: each map's name on the setup screen, then RANDOM")
    out.append("MAPNAME")
    for q in ps:
        out.append('        .SBYTE "%s"' % q["name"])
    out.append('        .SBYTE "RANDOM"')
    open("src/islands.asm", "w").write("\n".join(out) + "\n")

    for q in ps:
        print("map %s: %d tiles, %d fonts (coast characters per font %s), character rows -> font %s"
              % (q["name"].strip(), len(q["tiles"]), len(q["fonts"]),
                 "/".join(str(len(f)) for f in q["fonts"]), "".join(map(str, q["rowfont"]))))
        print("\n".join(q["stats"]))

main()
