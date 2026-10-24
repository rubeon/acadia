#!/usr/bin/env python3
"""Generate the Acadia map font, tile list and island data.

Writes three files (do not edit them by hand):

  src/tiles.asm     tile-number equates (T_SEA, T_FORT, ...) and N_TILES
  src/font_map.asm  the mode 5 map font at $3000 (fixed address)
  src/islands.asm   TILECH (tile -> first character code) and, for each
                    island pair, ISLKIND (cell kinds) and ISLTILE (tiles)

Each map square is one tile = 2 mode 5 characters = 8 x 8 pixels at
160 resolution, shown 8 colour clocks wide and 16 scan lines tall.
Tile n uses characters 2n and 2n+1; tiles drawn in white use inverse
characters (bit 7 set), so their light pixels show COLPF3.
All art here is new; nothing comes from the original game.

Islands are text pictures (see PAIRS below); coast tiles are picked
automatically from each square's neighbours, and only the variants the
islands actually use go into the font.

Pixel letters: . sea (COLBK)  G grass (PF0)  D dark (PF1)
               Y light (PF2 yellow, or PF3 white on inverse tiles)

Run from the repo root:  python3 -I tools/mkfont.py
"""

import sys

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

# ---------------------------------------------------------------------
#  Islands.  One string per square row, 20 squares wide, 11 rows.
#    .  sea                 #  land (buildable)
#    +  diagonal coast: half land, not buildable, boats can't enter;
#       it must touch land on exactly two adjacent sides
#    H  harbour (sea square with a pier; boats launch and park here)
#    r  rock (decorative only: plays as open sea)
#  Columns 0-9 belong to player 0 (left), 10-19 to player 1 (right).
#  Rows 0-1 and 9-10 stay open sea: fish and pirates enter there.
# ---------------------------------------------------------------------
LEFT_A = [
    "..........",
    "..........",
    ".+####+...",
    ".######+..",
    "H########.",
    ".####.###.",
    ".###+.+##.",
    ".+##.r.#+.",
    "..+#......",
    "..........",
    "..........",
]

RIGHT_B = [
    "..........",
    "..........",
    "....+####.",
    ".+#######.",
    ".########H",
    ".###.####.",
    ".+##.###+.",
    "....r##+..",
    ".....#+...",
    "..........",
    "..........",
]


def mirror(rows):
    return [r[::-1] for r in rows]


PAIRS = {
    "A": ("mirror pair", [l + r for l, r in zip(LEFT_A, mirror(LEFT_A))]),
    "B": ("same left island, different right island",
          [l + r for l, r in zip(LEFT_A, RIGHT_B)]),
}

ROWS, COLS = 11, 20
BANDS = (0, 1, 9, 10)            # rows that must stay open sea

N, E, S, W = 1, 2, 4, 8
DIRS = {N: (-1, 0), E: (0, 1), S: (1, 0), W: (0, -1)}
OPP = {N: S, S: N, E: W, W: E}
# diagonal corners: (bit, dr, dc, the two orthogonal sides)
NE_, SE_, SW_, NW_ = 1, 2, 4, 8
CORNERS = {NE_: (-1, 1, N, E), SE_: (1, 1, S, E), SW_: (1, -1, S, W),
           NW_: (-1, -1, N, W)}

# Cell kinds (ISLKIND); bit 7 = owned by player 1 (right island)
K_SEA, K_LAND, K_COAST, K_HARB, K_ROCK, K_P1 = 0, 1, 2, 3, 4, 0x80


def cell(m, r, c):
    if 0 <= r < ROWS and 0 <= c < COLS:
        return m[r][c]
    return "."


def coast_sides(m, r, c):
    """Sides (bit set) a '+' square's land triangle covers."""
    sides = 0
    for d, (dr, dc) in DIRS.items():
        if cell(m, r + dr, c + dc) == "#":
            sides |= d
    if sides not in (N | E, S | E, S | W, N | W):
        sys.exit("'+' at row %d col %d must touch land on exactly two "
                 "adjacent sides (has mask %d)" % (r, c, sides))
    return sides


def landlike(m, r, c, toward):
    """Is the edge of square (r,c) facing direction OPP[toward] land?"""
    ch = cell(m, r, c)
    if ch == "#":
        return True
    if ch == "+":
        return bool(coast_sides(m, r, c) & OPP[toward])
    return False


def grass_art(sea, notch):
    """Grass with beach on sea sides, rounded outer corners, inner notches."""
    a = [["G"] * 8 for _ in range(8)]
    for i in range(8):
        if sea & N: a[0][i] = "Y"
        if sea & S: a[7][i] = "Y"
        if sea & W: a[i][0] = "Y"
        if sea & E: a[i][7] = "Y"
    # rounded outer corners where both sides face the sea
    for (s1, s2, rr, cc, dr, dc) in ((N, E, 0, 7, 1, -1), (S, E, 7, 7, -1, -1),
                                     (S, W, 7, 0, -1, 1), (N, W, 0, 0, 1, 1)):
        if sea & s1 and sea & s2:
            a[rr][cc] = "."
            a[rr][cc + dc] = "."
            a[rr + dr][cc] = "."
            a[rr + dr][cc + dc] = "Y"
    # inner corners: sea diagonally, land on both sides -> sand notch
    for bit, (rr, cc, dr, dc) in ((NE_, (0, 7, 1, -1)), (SE_, (7, 7, -1, -1)),
                                  (SW_, (7, 0, -1, 1)), (NW_, (0, 0, 1, 1))):
        if notch & bit:
            a[rr][cc] = "Y"         # one pixel joins the two beach lines
    return ["".join(x) for x in a]


def coast_art(sides):
    """Half-square: land triangle against the two given sides."""
    a = [["."] * 8 for _ in range(8)]
    for y in range(8):
        for x in range(8):
            # distance from the land corner along the diagonal
            xx = x if sides & W else 7 - x
            yy = y if sides & N else 7 - y
            d = xx + yy
            if d < 7:
                a[y][x] = "G"
            elif d == 7:
                a[y][x] = "Y"
    return ["".join(x) for x in a]


def classify(m):
    """Return per-square (kind, tile key) for map m."""
    out = []
    for r in range(ROWS):
        row = []
        for c in range(COLS):
            ch = m[r][c]
            p1 = K_P1 if c >= COLS // 2 else 0
            if ch == ".":
                row.append((K_SEA, ("sea",)))
            elif ch == "r":
                row.append((K_ROCK, ("rock",)))
            elif ch == "H":
                if cell(m, r, c - 1) == "#":
                    row.append((K_HARB | p1, ("pier", W)))
                elif cell(m, r, c + 1) == "#":
                    row.append((K_HARB | p1, ("pier", E)))
                else:
                    sys.exit("harbour at row %d col %d needs land to its "
                             "west or east" % (r, c))
            elif ch == "+":
                row.append((K_COAST | p1, ("coast", coast_sides(m, r, c))))
            elif ch == "#":
                sea = 0
                for d, (dr, dc) in DIRS.items():
                    if not landlike(m, r + dr, c + dc, d):
                        sea |= d
                notch = 0
                for bit, (dr, dc, s1, s2) in CORNERS.items():
                    if not (sea & s1) and not (sea & s2) and \
                            cell(m, r + dr, c + dc) not in "#+":
                        notch |= bit
                row.append((K_LAND | p1, ("grass", sea, notch)))
            else:
                sys.exit("unknown map character %r" % ch)
        out.append(row)
    return out


def pier_art(land):
    return PIER_W if land == W else [x[::-1] for x in PIER_W]


def stats(m, cls):
    """Fairness numbers for each island."""
    res = []
    for side, cols in (("left", range(0, 10)), ("right", range(10, 20))):
        land = [(r, c) for r in range(ROWS) for c in cols if m[r][c] == "#"]
        coast = sum(1 for r in range(ROWS) for c in cols if m[r][c] == "+")
        harb = [(r, c) for r in range(ROWS) for c in cols if m[r][c] == "H"]
        edges = 0
        for r, c in land:
            edges += bin(cls[r][c][1][1]).count("1")
        edges += coast                       # one diagonal edge each
        rows = [r for r, c in land]
        hr = ["row %d, %d from the %s edge" %
              (r, c if side == "left" else COLS - 1 - c, "west" if side == "left" else "east")
              for r, c in harb]
        res.append((side, len(land), coast, edges, min(rows) - 2, 8 - max(rows), hr))
    return res


# ---------------------------------------------------------------------
#  Build the tile list: fixed tiles first, then the variants used
# ---------------------------------------------------------------------
TILES = [("T_SEA", "open sea", False, ["........"] * 8),
         ("T_GRASS", "plain grass", False, grass_art(0, 0))]
for k in range(1, 10):
    name, inv, a = ITEMS[k]
    TILES.append((ITEM_EQU[k - 1], "%d %s" % (k, name), inv, a))
TILES.append(("T_WRECK", "wreck of a parked boat", False, WRECK))
TILES.append(("T_SPARE", "spare (blank)", False, BLANK))
TILES.append(("T_ROCK", "rock (decorative)", False, ROCK))
KEYIDX = {("sea",): 0, ("grass", 0, 0): 1, ("rock",): len(TILES) - 1}

classified = {}
for pname, (desc, m) in PAIRS.items():
    assert len(m) == ROWS and all(len(r) == COLS for r in m), "map size " + pname
    for r in BANDS:
        assert set(m[r]) <= set(".r"), "pair %s row %d must be open sea" % (pname, r)
    cls = classify(m)
    classified[pname] = cls
    for row in cls:
        for kind, key in row:
            if key in KEYIDX:
                continue
            KEYIDX[key] = len(TILES)
            if key[0] == "pier":
                TILES.append((None, "harbour pier, land to the %s" % ("west" if key[1] == W else "east"),
                              False, pier_art(key[1])))
            elif key[0] == "coast":
                TILES.append((None, "diagonal coast, land side mask %d" % key[1], False,
                              coast_art(key[1])))
            else:
                TILES.append((None, "grass, beach mask %d, notch mask %d" % key[1:], False,
                              grass_art(*key[1:])))

if len(TILES) * 2 > 128:
    sys.exit("font full: %d tiles need %d characters" % (len(TILES), 2 * len(TILES)))
T = {t[0]: n for n, t in enumerate(TILES) if t[0]}


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


# tiles.asm
out = banner("TILES.ASM", "Map tile numbers and cell kinds.  Tile n = characters 2n, 2n+1.")
for n, (equ, comment, inv, a) in enumerate(TILES):
    if equ:
        out.append("%-11s= %-4d ; %s" % (equ, n, comment))
out.append("%-11s= %-4d ; item k (1-9) is tile T_ITEM+k-1" % ("T_ITEM", T["T_FORT"]))
out.append("%-11s= %-4d ; number of tiles" % ("N_TILES", len(TILES)))
out.append("")
out.append("; Cell kinds (ISLKIND); bit 7 set = square belongs to player 1")
for name, v, what in (("K_SEA", K_SEA, "open sea"),
                      ("K_LAND", K_LAND, "land, buildable"),
                      ("K_COAST", K_COAST, "diagonal coast: not buildable, blocks boats"),
                      ("K_HARB", K_HARB, "harbour: boats launch and park here"),
                      ("K_ROCK", K_ROCK, "rock: decorative, plays as sea"),
                      ("K_KIND", 0x7F, "mask for the kind"),
                      ("K_P1", K_P1, "owner bit: player 1 (right island)")):
    out.append("%-11s= $%02X  ; %s" % (name, v, what))
open("src/tiles.asm", "w").write("\n".join(out) + "\n")

# font_map.asm
out = banner("FONT_MAP.ASM", "Mode 5 map font, 1K aligned.  2 bits per pixel:\n"
             ";  00 COLBK sea, 01 PF0 grass, 10 PF1 dark, 11 PF2 yellow / PF3 white")
out += ["        *= $3000", "MAPFONT"]
for n, (equ, comment, inv, a) in enumerate(TILES):
    l, r = tile_bytes(a)
    out.append("; tile %d: %s%s" % (n, comment, " (inverse chars)" if inv else ""))
    out.append("        .BYTE " + hexes(l))
    out.append("        .BYTE " + hexes(r))
open("src/font_map.asm", "w").write("\n".join(out) + "\n")

# islands.asm
out = banner("ISLANDS.ASM", "Tile-to-character table and island data (20 x 11 squares).")
out.append("; TILECH: first character code of each tile (bit 7 = inverse/white)")
codes = [(2 * n) | (0x80 if TILES[n][2] else 0) for n in range(len(TILES))]
out.append("TILECH")
for i in range(0, len(codes), 16):
    out.append("        .BYTE " + hexes(codes[i:i + 16]))
report = []
first = True
for pname, (desc, m) in PAIRS.items():
    cls = classified[pname]
    out.append("")
    out.append("        .IF ISL_B" if pname == "B" else "        .IF ISL_B=0")
    out.append("; Island pair %s: %s" % (pname, desc))
    out.append("; ISLKIND: cell kind per square (K_ values, bit 7 = player 1)")
    out.append("ISLKIND")
    for r in range(ROWS):
        out.append("        .BYTE " + hexes([k for k, key in cls[r]]) + "   ; " + m[r])
    out.append("; ISLTILE: terrain tile per square, drawn by MAP_DRAW")
    out.append("ISLTILE")
    for r in range(ROWS):
        out.append("        .BYTE " + hexes([KEYIDX[key] for k, key in cls[r]]))
    out.append("        .ENDIF")
    report.append("Pair %s (%s):" % (pname, desc))
    for side, land, coast, edges, top, bot, hr in stats(m, cls):
        report.append("  %-5s buildable %d, diagonal coast %d, coastline edges %d, "
                      "rows to top band %d / bottom band %d, harbour %s"
                      % (side, land, coast, edges, top, bot, "; ".join(hr) or "none"))
open("src/islands.asm", "w").write("\n".join(out) + "\n")

print("%d tiles, %d of 128 characters" % (len(TILES), 2 * len(TILES)))
print("\n".join(report))
