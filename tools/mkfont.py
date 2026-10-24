#!/usr/bin/env python3
"""Generate the Acadia map font, tile list and placeholder test map.

Writes three files (do not edit them by hand):

  src/tiles.asm     tile-number equates (T_SEA, T_FORT, ...) and N_TILES
  src/font_map.asm  the mode 5 map font at $3000 (fixed address)
  src/testmap.asm   TILECH (tile -> first character code) and TESTMAP,
                    a placeholder 20 x 11 grid of tile numbers

Each map square is one tile = 2 mode 5 characters = 8 x 8 pixels at
160 resolution, shown 8 colour clocks wide and 16 scan lines tall.
Tile n uses characters 2n and 2n+1; tiles drawn in white use inverse
characters (bit 7 set), so their light pixels show COLPF3.
All art here is new; nothing comes from the original game.

Pixel letters: . sea (COLBK)  G grass (PF0)  D dark (PF1)
               Y light (PF2 yellow, or PF3 white on inverse tiles)

Run from the repo root:  python3 -I tools/mkfont.py
"""

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


# ---------------------------------------------------------------------
#  Other tiles
# ---------------------------------------------------------------------
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

ITEM_EQU = ["T_FORT", "T_FACTORY", "T_CROP", "T_SCHOOL", "T_HOSPITAL",
            "T_HOUSE", "T_REBEL", "T_PTBOAT", "T_FISHBOAT"]

PIX = {".": 0, "G": 1, "D": 2, "Y": 3}
N, E, S, W = 1, 2, 4, 8          # beach mask bits: sea on that side


def grass_tile(mask):
    art = [["G"] * 8 for _ in range(8)]
    for i in range(8):
        if mask & N: art[0][i] = "Y"
        if mask & S: art[7][i] = "Y"
        if mask & W: art[i][0] = "Y"
        if mask & E: art[i][7] = "Y"
    return ["".join(r) for r in art]


# Tile list: (equate or None, comment, inverse, art)
TILES = [("T_SEA", "open sea", False, ["........"] * 8)]
for m in range(16):
    TILES.append(("T_GRASS" if m == 0 else None,
                  "grass, beach mask %d%s" % (m, " (plain)" if m == 0 else ""),
                  False, grass_tile(m)))
for k in range(1, 10):
    name, inv, art = ITEMS[k]
    TILES.append((ITEM_EQU[k - 1], "%d %s" % (k, name), inv, art))
TILES.append(("T_WRECK", "wreck of a parked boat", False, WRECK))
TILES.append(("T_SPARE", "spare (blank)", False, BLANK))

T = {t[0]: n for n, t in enumerate(TILES) if t[0]}
assert len(TILES) * 2 <= 128, "font full"

# ---------------------------------------------------------------------
#  Placeholder test map (T-MAP-1 replaces the islands)
#  . sea  G grass (beach added automatically)  1-9 items  X wreck
#  Rows 9-10 are a strip showing every tile once, in tile order.
# ---------------------------------------------------------------------
ROWS, COLS = 11, 20
ISLANDS = [
    "....................",
    "..GGGGG.......GGGG..",
    ".GG1GG2G.....GG7GGG.",
    ".G3GGGG4G...G1GG2GG.",
    "GGG5GG6GG8..GG6GG3G9",
    ".GG7GGGG9...GGG4G5G8",
    "..GGGGGG.X...GGGGGG.",
    "...GGGG.......GGG...",
    "....................",
]


def is_land(r, c):
    if r < 0 or r >= len(ISLANDS) or c < 0 or c >= COLS:
        return False
    return ISLANDS[r][c] in "G1234567"


def island_tile(r, c):
    ch = ISLANDS[r][c]
    if ch == ".":
        return T["T_SEA"]
    if ch == "X":
        return T["T_WRECK"]
    if ch == "G":
        mask = 0
        if not is_land(r - 1, c): mask |= N
        if not is_land(r + 1, c): mask |= S
        if not is_land(r, c - 1): mask |= W
        if not is_land(r, c + 1): mask |= E
        return T["T_GRASS"] + mask
    return T["T_FORT"] + int(ch) - 1


assert all(len(r) == COLS for r in ISLANDS), "map width"
for k in range(1, 10):
    for half in ([r[:10] for r in ISLANDS], [r[10:] for r in ISLANDS]):
        assert sum(r.count(str(k)) for r in half) == 1, "item %d" % k

grid = [[island_tile(r, c) for c in range(COLS)] for r in range(len(ISLANDS))]
strip = list(range(len(TILES))) + [T["T_SEA"]] * (2 * COLS - len(TILES))
grid.append(strip[:COLS])
grid.append(strip[COLS:])
assert len(grid) == ROWS


def tile_bytes(art):
    """Return (left char 8 bytes, right char 8 bytes) for 8x8 art."""
    assert len(art) == 8 and all(len(r) == 8 for r in art), art
    left, right = [], []
    for row in art:
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


# tiles.asm
out = banner("TILES.ASM", "Map tile numbers.  Tile n = characters 2n, 2n+1.")
for n, (equ, comment, inv, art) in enumerate(TILES):
    if equ:
        out.append("%-11s= %-4d ; %s" % (equ, n, comment))
out.append("%-11s= %-4d ; T_GRASS + mask: N 1, E 2, S 4, W 8 = sea on that side" % ("T_BEACH", T["T_GRASS"]))
out.append("%-11s= %-4d ; item k (1-9) is tile T_ITEM+k-1" % ("T_ITEM", T["T_FORT"]))
out.append("%-11s= %-4d ; number of tiles" % ("N_TILES", len(TILES)))
open("src/tiles.asm", "w").write("\n".join(out) + "\n")

# font_map.asm
out = banner("FONT_MAP.ASM", "Mode 5 map font, 1K aligned.  2 bits per pixel:\n"
             ";  00 COLBK sea, 01 PF0 grass, 10 PF1 dark, 11 PF2 yellow / PF3 white")
out += ["        *= $3000", "MAPFONT"]
for n, (equ, comment, inv, art) in enumerate(TILES):
    l, r = tile_bytes(art)
    out.append("; tile %d: %s%s" % (n, comment, " (inverse chars)" if inv else ""))
    out.append("        .BYTE " + hexes(l))
    out.append("        .BYTE " + hexes(r))
open("src/font_map.asm", "w").write("\n".join(out) + "\n")

# testmap.asm
out = banner("TESTMAP.ASM", "Tile-to-character table and placeholder test map.")
out.append("; TILECH: first character code of each tile (bit 7 = inverse/white)")
codes = [(2 * n) | (0x80 if TILES[n][2] else 0) for n in range(len(TILES))]
out.append("TILECH")
for i in range(0, len(codes), 16):
    out.append("        .BYTE " + hexes(codes[i:i + 16]))
out.append("")
out.append("; TESTMAP: %d x %d tile numbers.  PLACEHOLDER islands; T-MAP-1 replaces" % (COLS, ROWS))
out.append("; them.  The last two rows show every tile once, in tile-number order.")
out.append("TESTMAP")
for r, row in enumerate(grid):
    label = ISLANDS[r] if r < len(ISLANDS) else "tile strip"
    out.append("        .BYTE " + hexes(row) + "   ; " + label)
open("src/testmap.asm", "w").write("\n".join(out) + "\n")

print("%d tiles, %d chars" % (len(TILES), 2 * len(TILES)))
