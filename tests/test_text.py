#!/usr/bin/env python3
"""T-SVC-4: TXT_DEC / TXT_STR and the status bar layout (py65)."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def screen_text(start, n):
    """Status-line screen codes back to ASCII, colour dropped."""
    return m.status(start, n)


def dec(value, width, offset=10):
    m.poke("STATUS1", *([0x21] * 40))          # fill with "A" to catch overrun
    m.set_long("M_NUM", value)
    m.call("TXT_DEC", a=width, x=offset)
    return screen_text(offset, width), screen_text(offset - 1, 1) + screen_text(offset + width, 1)


for value, width, want in [(0, 4, "   0"), (7, 4, "   7"), (42, 4, "  42"), (999, 4, " 999"),
                           (1000, 4, "1000"), (9999, 4, "9999"), (10000, 4, "****"),
                           (120, 3, "120"), (30, 3, " 30"), (5, 1, "5"), (10, 1, "*"),
                           (65535, 5, "65535"), (100, 2, "**"), (0, 1, "0")]:
    got, edges = dec(value, width)
    if got != want or edges != "AA":
        fail("TXT_DEC(%d, width %d) = %r (neighbours %r), want %r" % (value, width, got, edges, want))

# TXT_STR: a constant string from the status template, at offset 50 (line 2)
tpl = m.addr("STATTPL")
m.mem[0x0600:0x0606] = [0x27, 0x2F, 0x2C, 0x24, 0x00, 0xFF]   # "GOLD " + end
_, x, _, _ = m.call("TXT_STR", a=0x00, y=0x06, x=50)
if screen_text(50, 5) != "GOLD " or x != 55:
    fail("TXT_STR wrote %r, X=%d" % (screen_text(50, 5), x))

# status bar: template plus STAT_DRAW with the demo values
m.call("VARS_INIT")
for i in range(80):
    m.mem[m.addr("STATUS1") + i] = m.mem[tpl + i]
line = screen_text(40, 40)                       # template is exactly 2 x 40
want = "  @@                             @@     "
if line != want:
    fail("status line 2 template %r, want %r" % (line, want))
m.call("GAME_NEW")
line = screen_text(0, 40)
want = "  $$  100  TURNS 10  TIME  30    $$  100"
if line != want:
    fail("status line 1 %r, want %r" % (line, want))
else:
    print("status line 1: %r" % line)
line = screen_text(40, 40)
want = "  @@ 1000                        @@ 1000"
if line != want:
    fail("status line 2 %r, want %r" % (line, want))
for _ in range(30):                              # one full round
    m.call("GAME_SEC")
line = screen_text(0, 40)
want = "P1    0       ROUND SCORES       P2    0"
if (m.byte("STATUS1") & 0xC0 != 0x40 or m.byte("STATUS1", 39) & 0xC0 != 0x80
        or m.byte("ST_L1") != m.addr("C_SRED")):
    fail("round summary colours %02X %02X" % (m.byte("STATUS1"), m.byte("STATUS1", 39)))
if line != want:
    fail("round summary %r, want %r" % (line, want))
for _ in range(120):                             # both summary pages
    m.call("GAME_TIC")
line = screen_text(0, 40)
want = "  $$  110  TURNS  9  TIME  30    $$  110"
if line != want:
    fail("after a round %r, want %r" % (line, want))
else:
    print("after a round: %r" % line)
line = screen_text(40, 40)
pops = [m.byte("POP", 2 * p) + 256 * m.byte("POP", 2 * p + 1) for p in (0, 1)]
want = "  @@%5d                        @@%5d" % tuple(pops)
if line != want:
    fail("line 2 after a round %r, want %r" % (line, want))
else:
    print("line 2 after a round: %r" % line)

# colours (D54): on line 2 player 1's numbers red, player 2's
# turquoise, the rest white (line 1's PF1 is the gold bars' dark gold);
# the icons in place, player 2's person inverse
m.call("STAT_LINE")
raw = [m.byte("STATUS1", i) for i in range(80)]
for i, c in enumerate(raw):
    want = 0
    if c & 0x3F and 44 <= i < 49:
        want = 0x40
    elif c & 0x3F and 75 <= i < 80:
        want = 0x80
    if (c & 0x7F) >= 0x60:
        continue                                 # icons: checked below
    if c & 0xC0 != want:
        fail("status offset %d: code %02X, colour bits want %02X" % (i, c, want))
icons = {i: c for i, c in enumerate(raw) if (c & 0x7F) >= 0x60}
want = {2: 0x60, 3: 0x61, 33: 0x60, 34: 0x61, 42: 0x62, 43: 0x63, 73: 0xE4, 74: 0xE5}
if icons != want:
    fail("status icons %r, want %r" % (icons, want))
if m.byte("TXCOL"):
    fail("TXCOL %02X after STAT_DRAW, want 0" % m.byte("TXCOL"))
if m.byte("ST_L1") != m.addr("C_SDKG"):
    fail("ST_L1 %02X with the gold bars showing" % m.byte("ST_L1"))

# each screen byte of a field is written once, with its final value: a
# leading zero must never show, even for a moment (no flicker)
base = m.addr("STATUS1")
writes = []
m.mem.subscribe_to_write(range(base, base + 80), lambda a, v: writes.append((a - base, v)))
for value, width in [(100, 4), (7, 4), (0, 3), (9999, 4), (65535, 5), (10000, 4), (42, 2)]:
    del writes[:]
    m.set_long("M_NUM", value)
    m.call("TXT_DEC", a=width, x=10)
    want = "%*d" % (width, value) if len(str(value)) <= width else "*" * width
    offsets = [a for a, _ in writes]
    if sorted(offsets) != list(range(10, 10 + width)):
        fail("TXT_DEC(%d) wrote offsets %r" % (value, offsets))
    for a, v in writes:
        if v != (0 if want[a - 10] == " " else ord(want[a - 10]) - 0x20):
            fail("TXT_DEC(%d) wrote %02X at %d, want %r" % (value, v, a, want))

print("text: %d failed" % fails)
sys.exit(1 if fails else 0)
