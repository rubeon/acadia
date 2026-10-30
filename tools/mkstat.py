#!/usr/bin/env python3
"""Generate the Acadia status bar font (T-GFX-3, D54).

Writes src/font_stat.asm (do not edit it by hand): STFONT, a 1K ANTIC
mode 4 font for the two status lines.  A mode 4 pixel is one colour
clock by one scan line, so letters are 3 x 7 pixels in a 4 x 8 cell.

  codes $00-$3F  letters, digits and signs at their screen codes, in
                 white (11: PF2), so .SBYTE strings print as before;
                 with bit 7 set the same pixels show PF3 (turquoise)
  codes $40-$7F  the same glyphs in red (10: PF1): a number printed
                 with TXCOL = $40 (player 1's colour)
  codes $60-$65  icons, 2 characters each: the gold bar, player 1's person
                 (red body), player 2's person (11 body: print it with
                 bit 7 set for turquoise).  They replace red signs no
                 number uses.

Pixel letters in the icons: . COLBK  Y PF0 gold  R PF1 red  W PF2 white.
All art here is new; nothing comes from the original game.

Run from the repo root:  python3 -I tools/mkstat.py [--preview FILE]
"""

import sys

ADDR = 0x9800

G = {
    "A": [".#.", "#.#", "#.#", "###", "#.#", "#.#", "#.#"],
    "B": ["##.", "#.#", "#.#", "##.", "#.#", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "#..", "##.", "#..", "#..", "###"],
    "F": ["###", "#..", "#..", "##.", "#..", "#..", "#.."],
    "G": [".##", "#..", "#..", "#.#", "#.#", "#.#", ".##"],
    "H": ["#.#", "#.#", "#.#", "###", "#.#", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..#", "..#", "..#", "..#", "..#", "#.#", ".#."],
    "K": ["#.#", "#.#", "##.", "#..", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#", "#.#", "#.#"],
    "N": ["##.", "#.#", "#.#", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", "#.#", "#.#", ".#."],
    "P": ["##.", "#.#", "#.#", "##.", "#..", "#..", "#.."],
    "Q": [".#.", "#.#", "#.#", "#.#", "#.#", "##.", ".##"],
    "R": ["##.", "#.#", "#.#", "##.", "##.", "#.#", "#.#"],
    "S": [".##", "#..", "#..", ".#.", "..#", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "#.#", "#.#", ".#."],
    "V": ["#.#", "#.#", "#.#", "#.#", "#.#", ".#.", ".#."],
    "W": ["#.#", "#.#", "#.#", "#.#", "###", "###", "#.#"],
    "X": ["#.#", "#.#", ".#.", ".#.", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", "#.#", ".#.", ".#.", ".#.", ".#."],
    "Z": ["###", "..#", "..#", ".#.", "#..", "#..", "###"],
    "0": [".#.", "#.#", "#.#", "#.#", "#.#", "#.#", ".#."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    "2": ["##.", "..#", "..#", ".#.", "#..", "#..", "###"],
    "3": ["##.", "..#", "..#", ".#.", "..#", "..#", "##."],
    "4": ["#.#", "#.#", "#.#", "###", "..#", "..#", "..#"],
    "5": ["###", "#..", "#..", "##.", "..#", "..#", "##."],
    "6": [".##", "#..", "#..", "##.", "#.#", "#.#", ".#."],
    "7": ["###", "..#", "..#", ".#.", ".#.", ".#.", ".#."],
    "8": [".#.", "#.#", "#.#", ".#.", "#.#", "#.#", ".#."],
    "9": [".#.", "#.#", "#.#", ".##", "..#", "..#", "##."],
    "!": [".#.", ".#.", ".#.", ".#.", ".#.", "...", ".#."],
    "-": ["...", "...", "...", "###", "...", "...", "..."],
    "+": ["...", "...", ".#.", "###", ".#.", "...", "..."],
    "*": ["...", "#.#", ".#.", "###", ".#.", "#.#", "..."],
    ",": ["...", "...", "...", "...", "...", ".#.", "#.."],
    ".": ["...", "...", "...", "...", "...", "...", ".#."],
    ":": ["...", ".#.", "...", "...", "...", ".#.", "..."],
    "/": ["..#", "..#", ".#.", ".#.", ".#.", "#..", "#.."],
    "(": ["..#", ".#.", "#..", "#..", "#..", ".#.", "..#"],
    ")": ["#..", ".#.", "..#", "..#", "..#", ".#.", "#.."],
    "?": ["##.", "..#", "..#", ".#.", ".#.", "...", ".#."],
    "'": [".#.", ".#.", "...", "...", "...", "...", "..."],
}

# icons, two characters (8 x 8 pixels) each.  A pixel is about 1.6
# times as wide as it is tall.  The gold bar sits at the top of line 1
# and the person at the bottom of line 2, so the two don't read as one
# shape.
BAR = ["...WWWW.",          # a gold bar seen from the front: the top
       "..WYYYY.",          # face's edges catch the light
       ".YYYYYYY",
       ".YYYYYYY",
       ".YYYYYYY",
       "........",
       "........",
       "........"]
PERSON = ["........",       # a board-game pawn: round head, collar,
          "...YY...",       # narrow waist, wide foot
          "...YY...",
          "..BBBB..",
          "...BB...",
          "..BBBB..",
          ".BBBBBB.",
          ".BBBBBB."]
IC_BAR, IC_PER1, IC_PER2 = 0x60, 0x62, 0x64


def screen_code(ch):
    return ord(ch) - 0x20


def glyph(rows, bits):
    """3 x 7 glyph -> 8 font bytes, pixels 0-2, row 7 blank."""
    out = []
    for r in rows + ["..."]:
        b = 0
        for i, p in enumerate(r):
            if p == "#":
                b |= bits << (6 - 2 * i)
        out.append(b)
    return out


def icon(art, colours):
    """8 x 8 art -> two characters' bytes (left, right)."""
    left, right = [], []
    for r in art:
        for half, dest in ((r[:4], left), (r[4:], right)):
            b = 0
            for i, p in enumerate(half):
                b |= colours.get(p, 0) << (6 - 2 * i)
            dest.append(b)
    return left, right


def build():
    font = [[0] * 8 for _ in range(128)]
    for ch, rows in G.items():
        c = screen_code(ch)
        font[c] = glyph(rows, 3)            # white (PF2 / PF3)
        font[c + 0x40] = glyph(rows, 2)     # red (PF1)
    icons = ((IC_BAR, BAR, {"Y": 1, "W": 3}),
             (IC_PER1, PERSON, {"Y": 1, "B": 2}),
             (IC_PER2, PERSON, {"Y": 1, "B": 3}))
    for code, art, col in icons:
        font[code], font[code + 1] = icon(art, col)
    return font


def main():
    font = build()
    out = ["; " + "=" * 69,
           ";  FONT_STAT.ASM -- generated by tools/mkstat.py; do not edit by hand",
           ";  Status bar font STFONT (ANTIC mode 4, D54): white letters at their",
           ";  screen codes, the same in red at +$40, icons at $60-$65",
           "; " + "=" * 69, "",
           "IC_BAR  =  $%02X          ; gold bar, 2 characters" % IC_BAR,
           "IC_PER1 =  $%02X          ; player 1's person (red)" % IC_PER1,
           "IC_PER2 =  $%02X          ; player 2's person (print with bit 7: turquoise)" % IC_PER2,
           "TX_RED  =  $40          ; TXCOL: red digits (player 1)",
           "TX_TURQ =  $80          ; TXCOL: turquoise digits (player 2)",
           "",
           "        *= $%04X" % ADDR,
           "STFONT"]
    for c, bs in enumerate(font):
        out.append("        .BYTE " + ",".join("$%02X" % b for b in bs) + "   ; $%02X" % c)
    open("src/font_stat.asm", "w").write("\n".join(out) + "\n")
    if len(sys.argv) > 2 and sys.argv[1] == "--preview":
        preview(font, sys.argv[2])


def preview(font, path):
    from PIL import Image
    pal = {0: (24, 40, 110), 1: (220, 180, 60), 2: (220, 70, 70), 3: (240, 240, 240)}
    im = Image.new("RGB", (32 * 8, 4 * 8))
    for c in range(128):
        x0, y0 = (c % 32) * 8, (c // 32) * 8
        for y, b in enumerate(font[c]):
            for i in range(4):
                p = (b >> (6 - 2 * i)) & 3
                for dx in range(2):
                    im.putpixel((x0 + 2 * i + dx, y0 + y), pal[p])
    im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(path)


main()
