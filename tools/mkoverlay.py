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
  solid black   cut line
  dotted grey   bleed edge (the art runs 1.5 mm past the cut line)

The outlines, tabs and key positions are traced from scans of original
overlays (REF_5200, REF_TP); each card's width in mm (W5200_MM, WTP_MM)
sets the scale.  The widths are estimates: measure a real overlay, set
them, and run this again.

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
# The 5200 overlay is traced from a scan of an original (QIX, Atari,
# 1982), in that scan's pixels with the card's top left at 0, 0; one
# real measurement (the card's width, W5200_MM) scales it to mm.
W5200_MM = 51.0                  # card width in mm (estimate: measure one)
REF_5200 = {
    "w": 296, "h": 450,          # the card, without the tabs
    # tabs: (edge, left edge from the card's left, width, height)
    "tabs": [("top", 67.5, 40, 13), ("top", 189.0, 40, 13),
             ("bottom", 36.5, 25, 14), ("bottom", 231.5, 25, 14)],
    "col_x": [56.0, 148.0, 240.0],          # window centres
    "row_y": [88.0, 179.0, 270.0, 361.0],
    "hole_w": 56, "hole_h": 34,             # window size
    "radius": 6,                            # card corners
}


# The touch pad overlay is traced the same way from a scan of a
# keypad overlay (Codebreaker): two tabs on each edge, a title band at
# the top, the 12 touch areas marked by frames.
WTP_MM = 64.0                    # card width in mm (estimate: measure one)
REF_TP = {
    "w": 1463, "h": 2175,
    "tabs": [("top", 213, 214, 75), ("top", 1036, 214, 75),
             ("bottom", 131, 218, 75), ("bottom", 1114, 218, 75)],
    "col_x": [287.0, 735.0, 1185.0],
    "row_y": [533.5, 978.0, 1434.5, 1880.5],
    "hole_w": 320, "hole_h": 209,           # the frames (no windows)
    "radius": 12,
    "band": ("top", 225),
}


def scaled(ref, w_mm):
    k = w_mm / ref["w"]
    d = {"w": w_mm, "h": ref["h"] * k, "radius": ref["radius"] * k,
         "tabs": [(e, x * k, w * k, h * k) for e, x, w, h in ref["tabs"]],
         "col_x": [v * k for v in ref["col_x"]], "row_y": [v * k for v in ref["row_y"]],
         "hole_w": ref["hole_w"] * k, "hole_h": ref["hole_h"] * k}
    if "band" in ref:
        d["band"] = (ref["band"][0], ref["band"][1] * k)
    else:                        # the logo band under the last row
        d["band"] = ("bottom", d["h"] - (d["row_y"][3] + d["hole_h"] / 2) - 2.5)
    return d


DIM_5200 = scaled(REF_5200, W5200_MM)
DIM_TP = scaled(REF_TP, WTP_MM)
BLEED = 1.5
SHEET_W, SHEET_H = 215.9, 279.4  # US Letter; A4 is 210 x 297

# ---------------------------------------------------------------------
#  Key labels, in keypad order 1 2 3 / 4 5 6 / 7 8 9 / * 0 #
# ---------------------------------------------------------------------
NAMES = {1: "FORT", 2: "FACTORY", 3: "CROPS", 4: "SCHOOL", 5: "HOSPITAL",
         6: "HOUSING", 7: "REBELS", 8: "PT BOAT", 9: "FISHING"}
KEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
LABELS_5200 = {"0": ("HELM", "boat"), "*": ("PRICES", None), "#": ("INFO", "hold")}
LABELS_TP = {"0": ("HELM", "boat"), "*": ("PRICES", None), "#": ("PAUSE", None)}


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


def outline(x, y, d, grow=0.0):
    """Card outline with its tabs, clockwise from the top left; grow
    moves every edge out (the bleed)."""
    w, h, r = d["w"], d["h"], d["radius"] + grow
    x0, y0, x1, y1 = x - grow, y - grow, x + w + grow, y + h + grow
    rt = 0.8 + grow                       # tab tip corners
    top = sorted((t for t in d["tabs"] if t[0] == "top"), key=lambda t: t[1])
    bot = sorted((t for t in d["tabs"] if t[0] == "bottom"), key=lambda t: -t[1])
    p = ["M%s %s" % (f(x0 + r), f(y0))]
    for _, tx, tw, th in top:
        a, b, ty = x + tx - grow, x + tx + tw + grow, y0 - th
        p.append("H%sV%sA%s %s 0 0 1 %s %sH%sA%s %s 0 0 1 %s %sV%s"
                 % (f(a), f(ty + rt), f(rt), f(rt), f(a + rt), f(ty), f(b - rt),
                    f(rt), f(rt), f(b), f(ty + rt), f(y0)))
    p.append("H%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %s"
             % (f(x1 - r), f(r), f(r), f(x1), f(y0 + r), f(y1 - r), f(r), f(r), f(x1 - r), f(y1)))
    for _, tx, tw, th in bot:
        a, b, ty = x + tx + tw + grow, x + tx - grow, y1 + th
        p.append("H%sV%sA%s %s 0 0 1 %s %sH%sA%s %s 0 0 1 %s %sV%s"
                 % (f(a), f(ty - rt), f(rt), f(rt), f(a - rt), f(ty), f(b + rt),
                    f(rt), f(rt), f(b), f(ty - rt), f(y1)))
    p.append("H%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %sZ"
             % (f(x0 + r), f(r), f(r), f(x0), f(y1 - r), f(y0 + r), f(r), f(r), f(x0 + r), f(y0)))
    return "".join(p)


def tab_h(d, edge):
    return max([t[3] for t in d["tabs"] if t[0] == edge] or [0])


def card(x, y, d, uid, title):
    """Background, bleed, the logo band (sunset sky, logo, title) and
    the cut outline.  Returns (back, front) lists of SVG elements."""
    edge, bh = d["band"]
    stops = [c for _, c in MT["SKY"]]
    if edge == "bottom":                 # the sky runs up from the bottom
        stops = stops[::-1]
    back = ['<defs><linearGradient id="sky%s" x1="0" y1="0" x2="0" y2="1">' % uid]
    for i, c in enumerate(stops):
        dark = (i == 0) if edge == "top" else (i == len(stops) - 1)
        back.append('<stop offset="%s" stop-color="%s"/>'
                    % (f(i / (len(stops) - 1.0)), C_BG if dark else hexc(MT["atari_rgb"](c))))
    back.append('</linearGradient>')
    back.append('<clipPath id="clip%s"><path d="%s"/></clipPath></defs>'
                % (uid, outline(x, y, d, BLEED)))
    back.append('<g clip-path="url(#clip%s)">' % uid)
    ty, by = tab_h(d, "top") + BLEED, tab_h(d, "bottom") + BLEED
    back.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>'
                % (f(x - BLEED), f(y - ty), f(d["w"] + 2 * BLEED), f(d["h"] + ty + by), C_BG))
    if edge == "top":
        gy, gh, ly = y - ty, bh + ty, y + bh
        cy = y + bh * 0.44
    else:
        gy, gh, ly = y + d["h"] - bh, bh + by, y + d["h"] - bh - 0.5
        cy = y + d["h"] - bh * 0.52
    back.append('<rect x="%s" y="%s" width="%s" height="%s" fill="url(#sky%s)"/>'
                % (f(x - BLEED), f(gy), f(d["w"] + 2 * BLEED), f(gh), uid))
    back.append('<rect x="%s" y="%s" width="%s" height="0.5" fill="%s"/>'
                % (f(x - BLEED), f(ly), f(d["w"] + 2 * BLEED), C_GOLD))
    back += logo(x + d["w"] / 2, cy, bh * 0.58)
    if title and edge == "top":
        back.append(text(x + d["w"] / 2, y - tab_h(d, "top") + 3.9, title, 2.4, C_GOLD))
    back.append('</g>')
    front = ['<path d="%s" fill="none" stroke="#9a9a9a" stroke-width="0.2" '
             'stroke-dasharray="0.4 0.6"/>' % outline(x, y, d, BLEED),
             '<path d="%s" fill="none" stroke="#000000" stroke-width="0.25"/>' % outline(x, y, d)]
    return back, front


def key_label(key, table):
    if key in table:
        return table[key]
    return NAMES[int(key)], None


def labels(x, y, d, table, back, front, windows):
    """Each key's label: its number (gold) and name above a printed
    frame round the key, the item's icon (1-9) or the key's symbol
    inside.  windows=True cuts the keys out instead (not used: the
    originals have no holes)."""
    hw, hh = d["hole_w"], d["hole_h"]
    lab = d["row_y"][1] - d["row_y"][0] - hh      # room between rows
    pitch = d["col_x"][1] - d["col_x"][0]
    big = min(lab * 0.22, 2.6)                    # label size
    for i, key in enumerate(KEYS):
        cx = x + d["col_x"][i % 3]
        hy = y + d["row_y"][i // 3] - hh / 2      # the window's top
        name, sub = key_label(key, table)
        item = key.isdigit() and key != "0"
        if windows and (item or sub):              # the icon (or sub) under the label
            base = hy - 0.72 * lab
        else:
            base = hy - 0.25 * lab
        s = '<tspan fill="%s">%s</tspan> %s' % (C_GOLD, key, name)
        n = len(key) + 1 + len(name)
        tw = min(0.66 * big * n, pitch - 1.2)
        fit = ' textLength="%s" lengthAdjust="spacingAndGlyphs"' % f(tw) if 0.66 * big * n > tw else ""
        back.append(text(cx, base, s, big, extra=fit))
        if windows:
            if item:
                sz = 0.52 * lab
                back += icon(int(key), cx - sz / 2, hy - 0.08 * lab - sz, sz)
            elif sub:
                back.append(text(cx, hy - 0.3 * lab, sub, 0.75 * big, C_GOLD, weight="normal"))
            back.append('<rect x="%s" y="%s" width="%s" height="%s" rx="0.8" fill="#ffffff"/>'
                        % (f(cx - hw / 2), f(hy), f(hw), f(hh)))
            front.append('<rect x="%s" y="%s" width="%s" height="%s" rx="0.8" fill="none" '
                         'stroke="#000000" stroke-width="0.25"/>'
                         % (f(cx - hw / 2), f(hy), f(hw), f(hh)))
        else:                # a printed frame round the touch area
            back.append('<rect x="%s" y="%s" width="%s" height="%s" rx="1.2" fill="%s" '
                        'stroke="%s" stroke-width="0.8"/>'
                        % (f(cx - hw / 2 + 0.4), f(hy + 0.4), f(hw - 0.8), f(hh - 0.8), C_BG2, C_GOLD))
            if item:
                sz = min(hh - 1.4, hw - 2.0)
                back += icon(int(key), cx - sz / 2, hy + 1.1, sz)
            else:
                back.append(text(cx, hy + hh / 2 + 0.36 * hh * 0.5 - (0.12 * hh if sub else 0),
                                 key, hh * 0.5, C_TEXT))
            if sub:          # a hint under the key's symbol
                back.append(text(cx, hy + hh - 0.9, sub, min(0.7 * big, hh * 0.2), C_GOLD,
                                 weight="normal"))


def overlay_5200(x, y, uid):
    back, front = card(x, y, DIM_5200, uid, None)
    labels(x, y, DIM_5200, LABELS_5200, back, front, False)
    return back + front


def overlay_tp(x, y, uid):
    back, front = card(x, y, DIM_TP, uid, None)
    labels(x, y, DIM_TP, LABELS_TP, back, front, False)
    return back + front


# ---------------------------------------------------------------------
#  Sheet
# ---------------------------------------------------------------------
def sheet(title, d, make, notes):
    gap = 14.0
    total = 2 * d["w"] + gap
    x0 = (SHEET_W - total) / 2
    y0 = 52.0 + tab_h(d, "top")
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
    by = y0 + d["h"] + tab_h(d, "bottom") + 16
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
    "No windows: the keys are pressed through the card. Slide it into the controller.",
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
