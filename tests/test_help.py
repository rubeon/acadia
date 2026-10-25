#!/usr/bin/env python3
"""T-SCR-3: the purchase help screen (py65).

GAME_FRAME is called once per simulated frame with the joystick and
keyboard hardware faked, as the main loop would after each VBI.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

KC_H, KC_HELP, KC_P, KC_1 = 0x39, 0x11, 0x0A, 0x1F
RIGHT = 0x08
HELP_OFS, WHITE = 32, 0x80
T_ITEM = 2
NAMES = ["FORT", "FACTORY", "CROPS", "SCHOOL", "HOSPITAL", "HOUSING", "REBELS",
         "PT BOAT", "FISHING BOAT"]
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


m.poke("PAL", 0x0F)                       # NTSC
for r in ("VARS_INIT", "MAP_INIT", "DISP_INIT", "CUR_INIT", "TIC_INIT", "GAME_NEW"):
    m.call(r)


def frame(stick=0, kb=None):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF ^ stick)
    m.poke("TRIG0", 1)
    m.poke("TRIG1", 1)
    m.poke("CONSOL", 0x07)
    if kb is None:
        m.poke("SKSTAT", 0xFF)
    else:
        m.poke("SKSTAT", 0xFB)
        m.poke("KBCODE", kb)
    m.call("GAME_FRAME")


def tap(kb):
    frame(kb=kb)
    frame()


def text(codes):
    """Help screen characters back to text: '?' for anything not a glyph."""
    out = ""
    for c in codes:
        c &= 0x7F
        if c == 0:
            out += " "
        elif 48 <= c - HELP_OFS + 32 < 96 and c >= HELP_OFS + 13:
            out += chr(c - HELP_OFS + 32)
        else:
            out += "?"
    return out


def line(r):
    a = m.addr("HELPSCR") + 40 * r
    return m.mem[a:a + 40]


def state():
    return dict(remsec=m.byte("REMSEC"), ticsec=m.byte("TICSEC"), gold=m.word("GOLD"),
                curx=m.byte("CURX"), items=bytes(m.byte("MAPITEM", i) for i in range(220)))


for _ in range(60):
    frame()
spr = (m.byte("SPRHP"), m.byte("SPRHP", 1))
tap(KC_H)
if m.byte("HELPON") != 1 or m.byte("SDLSTL") != m.addr("HDLIST") & 0xFF:
    fail("H did not open the help screen (HELPON %d)" % m.byte("HELPON"))
if m.byte("SPRHP") or m.byte("SPRHP", 1):
    fail("cursors still on screen")

# the screen: a title, items 1-9 with key, tile, name, price, a way back
print("\n".join("|%s|" % text(line(r)) for r in (0, 1, 9, 10)))
if "ITEMS FOR SALE" not in text(line(0)) or "PRICE" not in text(line(0)):
    fail("title line %r" % text(line(0)))
if "H: BACK TO THE GAME" not in text(line(10)):
    fail("last line %r" % text(line(10)))
for k in range(1, 10):
    ln = line(k)
    t = text(ln)
    price = m.byte("PRICES", k)
    tile = m.byte("TILECH", T_ITEM + k - 1)
    if ln[2] != (0x10 + k + HELP_OFS) | WHITE:
        fail("item %d: key digit %02x" % (k, ln[2]))
    if (ln[5], ln[6]) != (tile, tile + 1):
        fail("item %d: tile %02x %02x, want %02x" % (k, ln[5], ln[6], tile))
    if t[9:9 + len(NAMES[k - 1])] != NAMES[k - 1]:
        fail("item %d: name %r" % (k, t[9:22]))
    if t[27:30] != "%3d" % price:
        fail("item %d: price %r, want %d" % (k, t[27:30], price))
    if any(c and not c & WHITE for c in ln[9:30] if c not in (tile, tile + 1)):
        fail("item %d: text not white" % k)

# the glyphs of the help font: blank at code 0, letters non-blank
font = m.addr("HLPFONT")
for ch in "AZ09:":
    c = ord(ch) - 32 + HELP_OFS
    if not any(m.mem[font + 8 * c:font + 8 * c + 8]):
        fail("help font has no glyph for %r" % ch)

# frozen: 5 s of stick, digit keys and P change nothing
frozen = state()
for i in range(300):
    if i % 20 == 0:
        tap(KC_1)
    elif i % 20 == 10:
        tap(KC_P)
    else:
        frame(stick=RIGHT)
if state() != frozen:
    fail("game moved behind the help screen: %r -> %r" % (frozen, state()))
if m.byte("PAUSED"):
    fail("P paused the game behind the help screen")

# HELP (XL/XE) closes it; the clock carries on from where it was
tap(KC_HELP)
if m.byte("HELPON") or m.byte("SDLSTL") != m.addr("DLIST") & 0xFF:
    fail("HELP did not close the help screen")
if (m.byte("SPRHP"), m.byte("SPRHP", 1)) != spr:
    fail("cursors not back: %r, want %r" % ((m.byte("SPRHP"), m.byte("SPRHP", 1)), spr))
if m.byte("REMSEC") != frozen["remsec"]:
    fail("seconds jumped on closing: %d -> %d" % (frozen["remsec"], m.byte("REMSEC")))
for _ in range(70):
    frame()
if m.byte("REMSEC") != frozen["remsec"] - 1:
    fail("clock not running after help: %d" % m.byte("REMSEC"))

# not while paused, not between rounds
tap(KC_P)
tap(KC_H)
if m.byte("HELPON"):
    fail("help opened while paused")
tap(KC_P)
m.poke("GSTATE", 1)
tap(KC_H)
if m.byte("HELPON"):
    fail("help opened during the round summary")
m.poke("GSTATE", 0)

# the DLI loads the help font while it is up, the row font otherwise
tap(KC_H)
m.poke("HP3ROW", 77)
m.interrupt("DLI_MAP")
if m.byte("CHBASE") != m.addr("HLPFONT") >> 8 or m.byte("HPOSP3") != 0:
    fail("DLI with help up: CHBASE %02x HPOSP3 %d" % (m.byte("CHBASE"), m.byte("HPOSP3")))
tap(KC_H)
m.poke("HP3ROW", 77)
m.interrupt("DLI_MAP")
if m.byte("CHBASE") != m.byte("ROWFONT") or m.byte("HPOSP3") != 77:
    fail("DLI on the map: CHBASE %02x HPOSP3 %d" % (m.byte("CHBASE"), m.byte("HPOSP3")))

print("help: %d failed" % fails)
sys.exit(1 if fails else 0)
