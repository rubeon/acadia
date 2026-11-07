#!/usr/bin/env python3
"""
mkoverlay.py: printable keypad overlays for Acadia (T-DOC-2).

Writes, in millimetres at real size, one SVG per controller:

  docs/overlays/acadia-5200.svg      Atari 5200 controller keypad overlay
  docs/overlays/acadia-touchpad.svg  Atari CX21 Video Touch Pad overlay

Each SVG is a print sheet (US Letter, content kept inside A4 too) with
two overlays, a 50 mm check bar and a short how-to.  The overlay art
(the item icons and the "Acadia" logo) is the game's own, read from
tools/mkfont.py (ITEMS, PAL) and tools/mktitle.py (logo, sky colours),
so it stays in step with the game.  tools/overlay_render.js turns the
SVGs into PDF and PNG.

Lines on the sheet:
  solid black   cut line (outline, and each key window on the 5200)
  dotted grey   bleed edge (the art runs 1.5 mm past the cut line)

The physical sizes are in DIM_5200 / DIM_TP below.  They are estimates
(no published template was found): measure a real overlay and correct
them there, then run this again.

Run from the repo root:
  python3 -I tools/mkoverlay.py
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name, keep):
    """Run a tools/ script without its trailing main() call."""
    src = open(os.path.join(ROOT, "tools", name)).read()
    src = src[:src.rstrip().rfind("\nmain()")]
    g = {"__name__": "mkoverlay_" + name}
    exec(compile(src, name, "exec"), g)
    return {k: g[k] for k in keep}


MF = load("mkfont.py", ["ITEMS", "PAL"])
MT = load("mktitle.py", ["logo_pixels", "atari_rgb", "SKY", "LOGOC"])

# ---------------------------------------------------------------------
#  Sizes in mm (estimates: see the docstring)
# ---------------------------------------------------------------------
DIM_5200 = {
    "w": 46.0, "h": 70.0,        # card, below the tab
    "tab_w": 22.0, "tab_h": 6.0,  # pull tab, centred on the top edge
    "head": 13.0,                # logo band at the top
    "pitch_x": 13.5, "pitch_y": 13.5,  # key centres
    "hole_w": 10.0, "hole_h": 7.0,     # key windows
    "label": 6.0,                # label band above each window
}
DIM_TP = {
    "w": 64.0, "h": 83.0,
    "tab_w": 26.0, "tab_h": 7.0,
    "head": 13.0,
    "pitch_x": 19.0, "pitch_y": 16.5,  # touch areas (no windows)
}
BLEED = 1.5
SHEET_W, SHEET_H = 215.9, 279.4  # US Letter; A4 is 210 x 297

# ---------------------------------------------------------------------
#  Key labels, in keypad order 1 2 3 / 4 5 6 / 7 8 9 / * 0 #
# ---------------------------------------------------------------------
NAMES = {1: "FORT", 2: "FACTORY", 3: "CROPS", 4: "SCHOOL", 5: "HOSPITAL",
         6: "HOUSING", 7: "REBELS", 8: "PT BOAT", 9: "FISHING"}
KEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
LABELS_5200 = {"0": ("HELM", "boat"), "*": ("PRICES", None), "#": ("INFO", "hold")}
LABELS_TP = {"0": ("HELM", "boat"), "*": ("PAUSE", None), "#": ("PRICES", None)}


def hexc(rgb):
    return "#%02x%02x%02x" % tuple(rgb)


C_BG = "#160c2e"                       # night indigo (the sky's top, darker for print)
C_BG2 = "#2e1446"                      # dark violet
C_GOLD = hexc(MT["atari_rgb"](0x2E))   # the logo's pale gold
C_TEXT = "#f2ead2"
C_DIM = hexc(MT["atari_rgb"](0x2A))
FONT = "Helvetica, Arial, 'Liberation Sans', sans-serif"


def f(v):
    return ("%.3f" % v).rstrip("0").rstrip(".")


# ---------------------------------------------------------------------
#  Art
# ---------------------------------------------------------------------
def icon(k, x, y, size):
    """Item k's map tile, size mm square, top left at x, y.  A tile is
    8 x 16 art pixels, each 2 colour clocks by 1 line, so square."""
    art = MF["ITEMS"][k][1]
    pw, ph = size / 8.0, size / 16.0
    out = ['<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>'
           % (f(x), f(y), f(size), f(size), hexc(MF["PAL"]["."]))]
    for r, row in enumerate(art):
        c = 0
        while c < 8:              # runs of one colour, to keep the file small
            e = c
            while e < 8 and row[e] == row[c]:
                e += 1
            if row[c] != ".":
                out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>'
                           % (f(x + c * pw), f(y + r * ph), f((e - c) * pw + 0.01),
                              f(ph + 0.01), hexc(MF["PAL"][row[c]])))
            c = e
    out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="none" stroke="%s" '
               'stroke-width="0.15"/>' % (f(x), f(y), f(size), f(size), C_GOLD))
    return out


def logo(cx, cy, height):
    """The title screen's "Acadia" in pale gold with its black shadow,
    centred on cx, cy, height mm tall.  Mode D pixels are square."""
    px = MT["logo_pixels"]()
    x0 = min(p[0] for p in px)
    y0 = min(p[1] for p in px)
    w = max(p[0] for p in px) - x0 + 1
    h = max(p[1] for p in px) - y0 + 1
    s = height / h
    ox, oy = cx - w * s / 2, cy - h * s / 2
    out = []
    for dx, col in ((1, "#000000"), (0, C_GOLD)):   # shadow one pixel right/down
        d = []
        for (x, y) in sorted(px, key=lambda p: (p[1], p[0])):
            d.append("M%s %sh%sv%sh-%sz" % (f(ox + (x - x0 + dx) * s), f(oy + (y - y0 + dx) * s),
                                          f(s + 0.005), f(s + 0.005), f(s + 0.005)))
        out.append('<path fill="%s" d="%s"/>' % (col, "".join(d)))
    return out


def text(x, y, s, size, col=C_TEXT, anchor="middle", weight="bold", extra=""):
    return ('<text x="%s" y="%s" font-family="%s" font-size="%s" font-weight="%s" '
            'fill="%s" text-anchor="%s"%s>%s</text>'
            % (f(x), f(y), FONT, f(size), weight, col, anchor, extra, s))


def outline(x, y, w, h, tw, th, grow=0.0):
    """Card outline with a centred tab on top, rounded corners."""
    x, y, w, h = x - grow, y - grow, w + 2 * grow, h + 2 * grow
    tw, th = tw + 2 * grow, th
    r, rt = 2.0 + grow, 2.0 + grow
    tx = x + (w - tw) / 2
    return ("M%s %s" % (f(x + r), f(y)) +
            "H%s" % f(tx) + "V%s" % f(y - th + rt) +
            "A%s %s 0 0 1 %s %s" % (f(rt), f(rt), f(tx + rt), f(y - th)) +
            "H%s" % f(tx + tw - rt) +
            "A%s %s 0 0 1 %s %s" % (f(rt), f(rt), f(tx + tw), f(y - th + rt)) +
            "V%s" % f(y) + "H%s" % f(x + w - r) +
            "A%s %s 0 0 1 %s %s" % (f(r), f(r), f(x + w), f(y + r)) +
            "V%s" % f(y + h - r) +
            "A%s %s 0 0 1 %s %s" % (f(r), f(r), f(x + w - r), f(y + h)) +
            "H%s" % f(x + r) +
            "A%s %s 0 0 1 %s %s" % (f(r), f(r), f(x), f(y + h - r)) +
            "V%s" % f(y + r) +
            "A%s %s 0 0 1 %s %s" % (f(r), f(r), f(x + r), f(y)) + "Z")


def card(x, y, d, uid, title):
    """Background, bleed, header with the logo, tab and cut outline.
    Returns (back, front) lists of SVG elements."""
    back = ['<defs><linearGradient id="sky%s" x1="0" y1="0" x2="0" y2="1">' % uid]
    stops = [c for _, c in MT["SKY"]]
    for i, c in enumerate(stops):
        back.append('<stop offset="%s" stop-color="%s"/>'
                    % (f(i / (len(stops) - 1.0)), C_BG if i == 0 else hexc(MT["atari_rgb"](c))))
    back.append('</linearGradient>')
    back.append('<clipPath id="clip%s"><path d="%s"/></clipPath></defs>'
                % (uid, outline(x, y, d["w"], d["h"], d["tab_w"], d["tab_h"], BLEED)))
    back.append('<g clip-path="url(#clip%s)">' % uid)
    back.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>'
                % (f(x - BLEED), f(y - d["tab_h"] - BLEED), f(d["w"] + 2 * BLEED),
                   f(d["h"] + d["tab_h"] + 2 * BLEED), C_BG))
    back.append('<rect x="%s" y="%s" width="%s" height="%s" fill="url(#sky%s)"/>'
                % (f(x - BLEED), f(y - d["tab_h"] - BLEED), f(d["w"] + 2 * BLEED),
                   f(d["head"] + d["tab_h"] + BLEED), uid))
    back.append('<rect x="%s" y="%s" width="%s" height="0.5" fill="%s"/>'
                % (f(x - BLEED), f(y + d["head"]), f(d["w"] + 2 * BLEED), C_GOLD))
    back += logo(x + d["w"] / 2, y + d["head"] * 0.44, d["head"] * 0.58)
    back.append(text(x + d["w"] / 2, y - d["tab_h"] + 3.9, title, 2.4, C_GOLD))
    back.append('</g>')
    front = ['<path d="%s" fill="none" stroke="#9a9a9a" stroke-width="0.2" '
             'stroke-dasharray="0.4 0.6"/>'
             % outline(x, y, d["w"], d["h"], d["tab_w"], d["tab_h"], BLEED),
             '<path d="%s" fill="none" stroke="#000000" stroke-width="0.25"/>'
             % outline(x, y, d["w"], d["h"], d["tab_w"], d["tab_h"])]
    return back, front


def key_label(key, table):
    if key in table:
        return table[key]
    return NAMES[int(key)], None


def overlay_5200(x, y, uid):
    d = DIM_5200
    back, front = card(x, y, d, uid, "ATARI 5200")
    gx = x + d["w"] / 2 - d["pitch_x"]
    for i, key in enumerate(KEYS):
        col, row = i % 3, i // 3
        cx = gx + col * d["pitch_x"]
        top = y + d["head"] + 1.0 + row * d["pitch_y"]
        hy = top + d["label"]
        name, sub = key_label(key, LABELS_5200)
        if key.isdigit() and key != "0":
            back += icon(int(key), cx - 6.0, top + 1.0, 3.6)
            fit = ' textLength="7.4" lengthAdjust="spacingAndGlyphs"' if len(name) > 6 else ""
            back.append(text(cx + 1.8, top + 3.5, name, 1.75, extra=fit))
        else:
            back.append(text(cx, top + 2.9, name, 1.9))
            if sub:
                back.append(text(cx, top + 4.9, sub, 1.4, C_GOLD, weight="normal"))
        # the window: cut out, white so it shows on the print
        back.append('<rect x="%s" y="%s" width="%s" height="%s" rx="0.8" fill="#ffffff"/>'
                    % (f(cx - d["hole_w"] / 2), f(hy), f(d["hole_w"]), f(d["hole_h"])))
        front.append('<rect x="%s" y="%s" width="%s" height="%s" rx="0.8" fill="none" '
                     'stroke="#000000" stroke-width="0.25"/>'
                     % (f(cx - d["hole_w"] / 2), f(hy), f(d["hole_w"]), f(d["hole_h"])))
    return back + front


def overlay_tp(x, y, uid):
    d = DIM_TP
    back, front = card(x, y, d, uid, "VIDEO TOUCH PAD")
    gx = x + d["w"] / 2 - 1.5 * d["pitch_x"]
    gy = y + d["head"] + 1.5
    for i, key in enumerate(KEYS):
        col, row = i % 3, i // 3
        cx0, cy0 = gx + col * d["pitch_x"], gy + row * d["pitch_y"]
        cw, ch = d["pitch_x"], d["pitch_y"]
        back.append('<rect x="%s" y="%s" width="%s" height="%s" rx="1.2" fill="%s" '
                    'stroke="%s" stroke-width="0.3"/>'
                    % (f(cx0 + 0.6), f(cy0 + 0.6), f(cw - 1.2), f(ch - 1.2), C_BG2, C_DIM))
        back.append(text(cx0 + 2.0, cy0 + 3.8, key, 2.6, C_GOLD, anchor="start"))
        name, sub = key_label(key, LABELS_TP)
        cx = cx0 + cw / 2
        if key.isdigit() and key != "0":
            back += icon(int(key), cx - 3.0, cy0 + 2.2, 6.0)
            back.append(text(cx, cy0 + ch - 2.6, name, 2.1))
        else:
            back.append(text(cx, cy0 + ch / 2 + 0.8 - (1.2 if sub else 0), name, 2.8))
            if sub:
                back.append(text(cx, cy0 + ch / 2 + 3.4, sub, 1.9, C_GOLD, weight="normal"))
    back.append(text(x + d["w"] / 2, y + d["h"] - 1.1, "1 player: touch pad in port 2, stick in port 1",
                     1.5, C_GOLD, weight="normal"))
    return back + front


# ---------------------------------------------------------------------
#  Sheet
# ---------------------------------------------------------------------
def sheet(title, d, make, notes):
    gap = 14.0
    total = 2 * d["w"] + gap
    x0 = (SHEET_W - total) / 2
    y0 = 52.0 + d["tab_h"]
    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<svg xmlns="http://www.w3.org/2000/svg" width="%smm" height="%smm" viewBox="0 0 %s %s">'
           % (f(SHEET_W), f(SHEET_H), f(SHEET_W), f(SHEET_H)),
           '<title>%s</title>' % title,
           '<rect width="100%" height="100%" fill="#ffffff"/>']
    out += logo(SHEET_W / 2, 22, 11)
    out.append(text(SHEET_W / 2, 36, title, 5, "#222222"))
    for k in range(2):
        out += make(x0 + k * (d["w"] + gap), y0, str(k))
    # the 50 mm check bar
    by = y0 + d["h"] + 18
    bx = (SHEET_W - 50) / 2
    out.append('<path d="M%s %sh50M%s %sv4M%s %sv4" stroke="#000" stroke-width="0.3"/>'
               % (f(bx), f(by), f(bx), f(by - 2), f(bx + 50), f(by - 2)))
    for i in range(1, 5):
        out.append('<path d="M%s %sv2" stroke="#000" stroke-width="0.2"/>' % (f(bx + 10 * i), f(by - 1)))
    out.append(text(SHEET_W / 2, by + 5, "50 mm: measure this to check the print scale", 3,
                    "#222222", weight="normal"))
    ny = by + 16
    for line in notes:
        out.append(text(25, ny, line, 3.2, "#222222", anchor="start", weight="normal"))
        ny += 5.5
    out.append('</svg>')
    return "\n".join(out) + "\n"


COMMON = [
    "Print at 100% (actual size, no fit to page) on matte card stock, about 200-250 g/m2.",
    "Cut along the solid black lines; the art runs past them so a cut a little outside is fine.",
]
NOTES_5200 = COMMON + [
    "Cut out the 12 key windows with a craft knife, then slide the overlay into the controller.",
    "Two copies, one for each controller. Top side button: helm a boat. Bottom: fire.",
    "START: begin / total scores. PAUSE: pause. Hold # for the score pages, press again to step.",
]
NOTES_TP = COMMON + [
    "No windows: the pad is pressed through the card. Slide it into the touch pad's slot.",
    "For 1-player games on the Atari 800/XL/XE; the game finds the pad in port 2 by itself.",
    "Two copies on the sheet, one spare.",
]


def main():
    out_dir = os.path.join(ROOT, "docs", "overlays")
    os.makedirs(out_dir, exist_ok=True)
    for fn, title, d, make, notes in (
            ("acadia-5200.svg", "Atari 5200 keypad overlay", DIM_5200, overlay_5200, NOTES_5200),
            ("acadia-touchpad.svg", "Video Touch Pad overlay", DIM_TP, overlay_tp, NOTES_TP)):
        with open(os.path.join(out_dir, fn), "w") as fh:
            fh.write(sheet(title, d, make, notes))
        sys.stdout.write("wrote docs/overlays/%s\n" % fn)


main()
