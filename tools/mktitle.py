#!/usr/bin/env python3
"""Generate src/title_gfx.asm: the sunset title screen (T-REL-4, D70).

The picture is 160 colour clocks by 192 scan lines, after Rube's
reference (2026-11-06): a sunset sky in bands of colour with dark cloud
streaks, "Acadia" in pale gold at the top left, a black island with the
game's fort and two houses, the sun setting to its right over dark
water with a glitter path, and REBUILD at the bottom right.

  lines   0-3    blank: sky
  lines   4-55   LOGO: 26 ANTIC mode D lines (2 scan lines each): the
                 logo (PF1, with a PF2 shadow) and clouds (PF0)
  lines  56-143  TTSCN: 11 mode 4 rows in TTFONT: clouds (PF0 dark,
                 PF1 lit underside), the island (PF2, black)
  lines 144-167  3 mode 4 rows of water in RAM: TITLE.ASM scatters the
                 glitter characters TG_* there every few frames
  lines 168-175  a mode 6 row in RAM: PRESS FIRE (TTPRS), once shown
  lines 176-191  a mode 7 row: REBUILD at the right (TTREB)

A DLI on the line above runs a kernel (TT_DLI): every second scan line
it sets COLBK, COLPF0 and COLPF1 from TTBK / TTP0 / TTP1 (96 entries
each), so the sky, clouds, logo, glitter and text take their colours
per line.  COLPF2 is black and COLPF3 the bright glitter throughout.
The sun is player 3 (TITLE.ASM), not drawn here.

TTFONT (1K): code 0 blank; codes 1-10 the caption letters, 1 bit a
pixel for modes 6 and 7; codes 11-18 the glitter (mode 4); codes 19 up
the scene's characters, merged where they differ least until they fit.

All art here is new (the logo is drawn by hand below); nothing comes
from the original game.

Run from the repo root:  python3 -I tools/mktitle.py [--preview FILE]
(--preview needs PIL and draws the screen with an approximate palette.)
"""

import math
import random
import sys

W, H = 160, 192
TOP = 4                 # first logo line
BAND = 26               # mode D lines in LOGO
SC_Y = TOP + 2 * BAND   # 56: first scene line
SC_ROWS = 11            # mode 4 rows in TTSCN
HOR = SC_Y + 8 * SC_ROWS  # 144: the horizon, first water line
WT_ROWS = 3             # mode 4 rows of water (RAM)
PR_Y = HOR + 8 * WT_ROWS  # 168: PRESS FIRE (mode 6)
RB_Y = PR_Y + 8         # 176: REBUILD (mode 7, 16 lines)
NPAIR = H // 2          # colour table entries
GFXMAX = 1840           # bytes free at TITLEGFX (MEM_A800.ASM: $8000-$872F)
SUN_X = 140             # the sun's centre (colour clock), TITLE.ASM's TT_SUNX
SUN_COL = SUN_X // 4    # its character column, for the glitter path
SUNSHAPE = [0x3C, 0x7E, 0xFF, 0xFF, 0xFF, 0xFF, 0x7E, 0x3C]  # TITLE.ASM's TT_SUNS

# ---------------------------------------------------------------------
#  Colours (Atari hue * 16 + luminance)
# ---------------------------------------------------------------------
SKY = [0x70, 0x70, 0x60, 0x60, 0x62, 0x62, 0x52, 0x52, 0x54, 0x54, 0x44, 0x44,
       0x46, 0x36, 0x36, 0x38, 0x38, 0x38, 0x3A, 0x2A, 0x2A, 0x2A, 0x2C, 0x2C]
LOGOC = [0x1E, 0x1E, 0x1E, 0x2E, 0x2E, 0x2E, 0x2E, 0x2C, 0x2C, 0x2C, 0x2A, 0x2A]
WATER = [0x62, 0x62, 0x60, 0x60, 0x70, 0x70, 0x70, 0x80, 0x80, 0x80, 0x80, 0x00]
SUNGL = [0x1E, 0x1C, 0x2C, 0x2C, 0x2A, 0x2A, 0x3A, 0x3A, 0x38, 0x38, 0x36, 0x36]
SKYGL = [0x46, 0x46, 0x44, 0x44, 0x54, 0x54, 0x54, 0x52, 0x52, 0x62, 0x62, 0x62]
C_TEXT = 0x00           # COLBK under the two text rows
C_PRS = 0x1C            # PRESS FIRE
C_REB = 0x2C            # REBUILD


def sky(y):
    return SKY[min(y * len(SKY) // HOR, len(SKY) - 1)]


def dark(c, n):
    return (c & 0xF0) | max(0, (c & 0x0F) - n)


def lite(c, n):
    return (c & 0xF0) | min(0x0E, (c & 0x0F) + n)


def tables():
    bk, p0, p1 = [], [], []
    for i in range(NPAIR):
        y = 2 * i
        if y < HOR:
            bk.append(sky(y))
            p0.append(dark(sky(y), 4) if sky(y) & 0x0F >= 4 else 0x50)
            if TOP <= y < SC_Y:
                p1.append(LOGOC[(y - TOP) * len(LOGOC) // (SC_Y - TOP)])
            else:
                p1.append(lite(sky(y), 2))
        elif y < PR_Y:
            k = (y - HOR) // 2
            bk.append(WATER[k])
            p0.append(SKYGL[k])
            p1.append(SUNGL[k])
        else:
            bk.append(C_TEXT)
            p0.append(C_TEXT)
            p1.append(C_PRS if y < RB_Y else C_REB)
    return bk, p0, p1


# ---------------------------------------------------------------------
#  The logo, drawn by hand: a swash A, then the small letters
# ---------------------------------------------------------------------
BIG_A = """
...........##..........
..........###..........
..........####.........
.........#.####........
.........#.####........
........#...####.......
........#...####.......
.......#.....####......
.......#.....####......
......#......#####.....
......#.......####.....
.....#........####.....
.....#.........####....
....##########.####....
....#..........####....
...#............####...
...#............####...
..#.............####...
..#..............####..
.##..............####..
###..............####..
.##.............######.
.#.............########
"""
# small letters: x-height rows, then the rows above it (ascender, dot)
SMALL = {
    "c": (["..#####.", ".##...##", "##.....#", "##......", "##......", "##......",
           "##......", "##......", "##.....#", ".##...##", "..#####."], []),
    "a": ([".#####..", "##...##.", ".....##.", ".....##.", "..#####.", ".##..##.",
           "##...##.", "##...##.", "##...##.", "##..###.", ".###.###"], []),
    "d": (["..###.###.", ".##..####.", "##....###.", "##....###.", "##....###.",
           "##....###.", "##....###.", "##....###.", "##....###.", ".##..####.",
           "..###.####"],
          [".....####.", "......###.", "......###.", "......###.", "......###.",
           "......###."]),
    "i": (["###..", ".##..", ".##..", ".##..", ".##..", ".##..", ".##..", ".##..",
           ".##..", ".##..", "####."],
          [".....", ".##..", ".##..", ".....", ".....", "....."]),
}
LOGO_X, LOGO_Y = 8, 1   # top left of the A, in mode D pixels / lines


def logo_pixels():
    big = BIG_A.strip("\n").split("\n")
    h = len(big)
    px = set()
    for r, line in enumerate(big):
        for c, v in enumerate(line):
            if v == "#":
                px.add((c, r))
    x = len(big[0]) + 1
    for ch in "cadia":
        body, above = SMALL[ch]
        top = h - len(body)
        for r, line in enumerate(body):
            for c, v in enumerate(line):
                if v == "#":
                    px.add((x + c, top + r))
        for r, line in enumerate(above):
            for c, v in enumerate(line):
                if v == "#":
                    px.add((x + c, top - len(above) + r))
        x += len(body[0]) + 1
    return {(LOGO_X + c, LOGO_Y + r) for c, r in px}


# ---------------------------------------------------------------------
#  The picture: pix[y][x] = 0 COLBK, 1 PF0, 2 PF1, 3 PF2
# ---------------------------------------------------------------------
CLOUDS = [  # (top line, centre, length): long thin streaks
    (14, 128, 46), (30, 132, 50), (46, 140, 60), (58, 36, 64), (72, 22, 78),
    (82, 136, 66), (98, 40, 52), (104, 140, 56), (118, 18, 34)]
ISLAND = (30, 128, 118)  # left, right, top line
FORT_X = 82
HOUSES = (62, 100)


def clouds(pix):
    rnd = random.Random(5)
    for (y, cx, ln) in CLOUDS:
        th = 4 + ln // 20
        a0 = cx - ln // 2
        ph = rnd.random() * 6
        for x in range(max(a0, 0), min(a0 + ln, W)):
            t = (x - a0) / ln
            ht = int(round(th * (math.sin(math.pi * t) ** 0.6)
                           * (0.75 + 0.25 * math.sin(x * 0.45 + ph))))
            for k in range(ht):
                yy = y + th - k
                edge = min(x - a0, a0 + ln - x)
                if (edge < 5 or k == ht - 1) and (x + yy) % 2:
                    continue                    # dithered ends and top
                pix[yy][x] = 1
            if ht > 0 and x % 7 != 3 and y + th + 1 >= SC_Y:
                pix[y + th + 1][x] = 2          # lit underside (not in LOGO)
        for _ in range(rnd.randint(2, 3)):     # wisps
            bx = cx + rnd.randint(-ln, ln)
            for x in range(max(0, bx), min(W, bx + rnd.randint(4, 11))):
                if x % 2 == 0 or rnd.random() < 0.5:
                    pix[y + th][x] = 1


def island(pix):
    x0, x1, top = ISLAND
    rnd = random.Random(3)
    tops = {}
    for x in range(x0, x1 + 1):
        t = (x - x0) / (x1 - x0)
        h = (HOR - top) * (math.sin(math.pi * t) ** 0.7)
        h += 3 * math.sin(t * 17 + 3) + rnd.uniform(-1.2, 1.2)
        tops[x] = int(round(HOR - max(0.0, h)))
    for x, t in tops.items():
        for y in range(t, HOR):
            pix[y][x] = 3

    def box(xa, xb, ya, yb):
        for y in range(ya, yb):
            for x in range(xa, xb):
                pix[y][x] = 3
    fy = top + 2                                # the fort on the hill
    box(FORT_X - 8, FORT_X + 8, fy, fy + 8)
    for c in range(FORT_X - 8, FORT_X + 8, 3):
        box(c, c + 2, fy - 2, fy)
    box(FORT_X - 3, FORT_X + 3, fy - 12, fy)    # keep
    for c in range(FORT_X - 3, FORT_X + 3, 2):
        box(c, c + 1, fy - 14, fy - 12)
    box(FORT_X, FORT_X + 1, fy - 20, fy - 14)   # flag pole and flag
    box(FORT_X + 1, FORT_X + 4, fy - 20, fy - 17)
    for hx in HOUSES:                           # houses down the slope
        hy = tops[hx]
        box(hx - 3, hx + 3, hy - 3, hy + 1)
        for k in range(4):                      # roof
            box(hx - 4 + k, hx + 4 - k, hy - 4 - k, hy - 3 - k)


def picture():
    pix = [[0] * W for _ in range(H)]
    clouds(pix)
    island(pix)
    logo = logo_pixels()
    for (x, r) in logo:                         # shadow first, then gold
        for dy in (0, 1):
            y = TOP + 2 * r + 2 + dy
            if (x + 1, r + 1) not in logo:
                pix[y][x + 1] = 3
    for (x, r) in logo:
        for dy in (0, 1):
            pix[TOP + 2 * r + dy][x] = 2
    for y in range(HOR, H):                     # water and text: drawn at
        pix[y] = [0] * W                        # run time
    for y in range(0, TOP):
        pix[y] = [0] * W
    return pix


# ---------------------------------------------------------------------
#  Glitter (mode 4) and caption letters (mode 6/7)
# ---------------------------------------------------------------------
GLITTER = [   # 8 lines of 4 pixels; 2 = PF1 gold, 3 = PF3 (inverse), 1 = PF0
    ["0000", "2220", "0000", "0000", "0000", "0022", "0000", "0000"],
    ["0000", "0000", "0222", "0000", "0000", "0000", "2200", "0000"],
    ["0220", "0000", "0000", "0000", "2222", "0000", "0000", "0000"],
    ["0000", "0000", "0000", "2200", "0000", "0000", "0000", "0222"],
    ["0000", "0000", "0330", "0000", "0000", "0000", "3300", "0000"],
    ["0000", "3330", "0000", "0000", "0000", "0033", "0000", "0000"],
    ["0000", "0000", "1100", "0000", "0000", "0000", "0011", "0000"],
    ["0000", "0000", "0000", "0000", "0111", "0000", "0000", "0000"],
]
TG_SUN, TG_NSUN = 11, 4     # gold glitter codes
TG_BRT, TG_NBRT = 15, 2     # bright ones: print with bit 7 set (PF3)
TG_SKY, TG_NSKY = 17, 2     # dim sky reflections (PF0)
SC_FIRST = 19

LETTERS = {   # 5 x 7 capitals
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
}
LETTER_ORDER = "PRESFIBULD"   # codes 1-10


def letter_code(ch):
    return 0 if ch == " " else 1 + LETTER_ORDER.index(ch)


def text_row(s):
    assert len(s) == 20
    return [0 if ch == " " else 0x40 | letter_code(ch) for ch in s]  # PF1


PRS_TXT = " PRESS FIRE         "
REB_TXT = "            REBUILD "


# ---------------------------------------------------------------------
#  Characters for the scene: cut, count, merge to fit
# ---------------------------------------------------------------------
def scene_chars(pix):
    cells = []
    for r in range(SC_ROWS):
        for c in range(40):
            cells.append(tuple(tuple(pix[SC_Y + 8 * r + y][4 * c + x] for x in range(4))
                               for y in range(8)))
    blank = tuple(tuple([0] * 4) for _ in range(8))
    count = {}
    for ch in cells:
        if ch != blank:
            count[ch] = count.get(ch, 0) + 1
    room = 128 - SC_FIRST
    kept = sorted(count, key=lambda ch: -count[ch])

    def dist(a, b):
        return sum(1 for y in range(8) for x in range(4) if a[y][x] != b[y][x])
    merged = {}
    while len(kept) > room:                    # drop the rarest into its
        ch = kept.pop()                        # nearest kept character
        near = min(kept + [blank], key=lambda k: dist(ch, k))
        merged[ch] = near
    for ch in list(merged):                    # follow merge chains
        while merged[ch] in merged:
            merged[ch] = merged[merged[ch]]
    code = {blank: 0}
    for i, ch in enumerate(kept):
        code[ch] = SC_FIRST + i
    screen = [code[merged.get(ch, ch)] for ch in cells]
    return kept, screen, len(count)


def mode4_bytes(rows):
    out = []
    for line in rows:
        v = 0
        for p in line:
            v = (v << 2) | int(p)
        out.append(v)
    return out


def font(kept):
    f = [0] * 1024
    for ch in LETTER_ORDER:
        g = LETTERS[ch]
        base = 8 * letter_code(ch)
        for y, line in enumerate(g):
            v = 0
            for x, p in enumerate(line):
                if p == "#":
                    v |= 0x40 >> x             # 1 blank column on the left
            f[base + y] = v
    for i, g in enumerate(GLITTER):
        f[8 * (TG_SUN + i):8 * (TG_SUN + i) + 8] = mode4_bytes(g)
    for i, ch in enumerate(kept):
        f[8 * (SC_FIRST + i):8 * (SC_FIRST + i) + 8] = mode4_bytes(ch)
    return f


def band_bytes(pix):
    out = []
    for r in range(BAND):
        line = pix[TOP + 2 * r]
        for b in range(40):
            v = 0
            for i in range(4):
                v = (v << 2) | line[4 * b + i]
            out.append(v)
    return out


# ---------------------------------------------------------------------
#  Output
# ---------------------------------------------------------------------
def emit_bytes(out, label, data, per=16):
    out.write("%s\n" % label)
    for i in range(0, len(data), per):
        out.write("        .BYTE " + ",".join("$%02X" % v for v in data[i:i + per]) + "\n")


def main():
    pix = picture()
    kept, screen, nuniq = scene_chars(pix)
    bk, p0, p1 = tables()
    logo = band_bytes(pix)
    prs, reb = text_row(PRS_TXT), text_row(REB_TXT)
    size = len(logo) + len(screen) + len(prs) + len(reb) + 3 * NPAIR
    assert size <= GFXMAX, "title graphics: %d bytes, room for %d" % (size, GFXMAX)
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], pix, kept, screen, bk, p0, p1)
    out = sys.stdout
    w = out.write
    w("; =====================================================================\n")
    w(";  TITLE_GFX.ASM -- the sunset title screen's graphics (T-REL-4, D70),\n")
    w(";  generated by tools/mktitle.py; do not edit.  %d bytes at TITLEGFX,\n" % size)
    w(";  the font at TTFONTA.  %d scene characters (%d before merging).\n"
      % (len(kept), nuniq))
    w("; =====================================================================\n\n")
    w("LOGO_H  =  %d           ; mode D lines in LOGO\n" % BAND)
    w("TT_SROWS = %d           ; mode 4 rows in TTSCN\n" % SC_ROWS)
    w("; TITLE.ASM's equates TT_NL (%d), TT_WROWS (%d), TT_HORL (%d), TT_SCOL (%d),\n"
      % (NPAIR, WT_ROWS, HOR, SUN_COL))
    w("; TG_SUN (%d), TG_BRT (%d), TG_SKY (%d) must match these.\n\n"
      % (TG_SUN, TG_BRT, TG_SKY))
    w("        *= TITLEGFX\n")
    emit_bytes(out, "LOGO", logo, 20)
    emit_bytes(out, "TTSCN", screen, 20)
    w("; the caption and the prompt, mode 6/7 codes (letters 1-10, PF1)\n")
    emit_bytes(out, "TTREB", reb, 20)
    emit_bytes(out, "TTPRS", prs, 20)
    w("; per pair of scan lines: COLBK, COLPF0, COLPF1 (TT_DLI)\n")
    emit_bytes(out, "TTBK", bk)
    emit_bytes(out, "TTP0", p0)
    emit_bytes(out, "TTP1", p1)
    w("\n        *= TTFONTA        ; 1K aligned (MEM_A800.ASM / MEM_5200.ASM)\n")
    emit_bytes(out, "TTFONT", font(kept))
    w("\n; preview of the logo and scene: . sky  - cloud  = lit  # gold/island\n")
    for y in list(range(TOP, SC_Y, 2)) + list(range(SC_Y, HOR)):
        w(";  " + "".join(".-=#"[v] for v in pix[y]) + "\n")


# ---------------------------------------------------------------------
#  --preview: the screen as the Atari would show it (approximate NTSC)
# ---------------------------------------------------------------------
def atari_rgb(c):
    hue, lum = (c >> 4) & 15, c & 14
    y = 0.03 + lum / 15.0 * 0.85
    i = q = 0.0
    if hue:
        a = math.radians(-48 + (hue - 1) * 27)
        i, q = 0.25 * math.cos(a), 0.25 * math.sin(a)
    rgb = (y + 0.956 * i + 0.621 * q, y - 0.272 * i - 0.647 * q, y - 1.106 * i + 1.703 * q)
    return tuple(max(0, min(255, int(v * 255))) for v in rgb)


def preview(fn, pix, kept, screen, bk, p0, p1):
    from PIL import Image
    f = font(kept)
    img = Image.new("RGB", (168, 240), atari_rgb(SKY[0]))
    put = img.putpixel
    rnd = random.Random(1)
    water = [0] * (40 * WT_ROWS)              # one frame of glitter, as
    for r in range(WT_ROWS):                   # TITLE.ASM makes it
        hw = r + 1
        for _ in range(r + 2):
            c = rnd.randint(TG_SUN, TG_SUN + TG_NSUN - 1)
            water[40 * r + SUN_COL - hw + rnd.randint(0, 2 * hw)] = c
        water[40 * r + SUN_COL - hw + rnd.randint(0, 2 * hw)] = 0x80 | rnd.choice((TG_BRT, TG_BRT + 1))
        for _ in range(2):
            water[40 * r + rnd.randint(0, 39)] = rnd.choice((TG_SKY, TG_SKY + 1))
    for y in range(H):
        cols = [bk[y // 2], p0[y // 2], p1[y // 2], 0x00, 0x1E]
        rgb = [atari_rgb(c) for c in cols]
        for x in range(W):
            v = 0
            if y < SC_Y:
                v = pix[y][x]
            elif y < HOR:
                ch = screen[40 * ((y - SC_Y) // 8) + x // 4]
                v = (f[8 * ch + (y - SC_Y) % 8] >> (6 - 2 * (x % 4))) & 3
            elif y < PR_Y:
                ch = water[40 * ((y - HOR) // 8) + x // 4]
                v = (f[8 * (ch & 0x7F) + (y - HOR) % 8] >> (6 - 2 * (x % 4))) & 3
                if v == 3 and ch & 0x80:
                    v = 4
            else:
                row, ly = (text_row(PRS_TXT), (y - PR_Y)) if y < RB_Y else \
                          (text_row(REB_TXT), (y - RB_Y) // 2)
                ch = row[x // 8]
                bits = f[8 * (ch & 0x3F) + ly]
                v = 2 if ch and bits & (0x80 >> (x % 8)) else 0
            put((x + 4, y + 24), rgb[v])
        top = HOR - 12                         # the sun: player 3, over
        if top <= y < HOR:                     # the playfield, cut at the
            row = SUNSHAPE[(y - top) // 2]     # horizon
            for b in range(8):
                if row & (0x80 >> b):
                    put((SUN_X - 4 + b + 4, y + 24), atari_rgb(0x1E))
    img.resize((672, 480), Image.NEAREST).save(fn)


main()
