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
    """Status-line screen codes back to ASCII (digits, letters, space, *)."""
    out = ""
    for i in range(n):
        c = m.byte("STATUS1", start + i)
        out += chr(c + 0x20) if c < 0x40 else chr(c - 0x40)
    return out


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
m.call("DEMO_INIT")
line = screen_text(0, 40)
want = "GOLD  100  TURNS 10  TIME  30  GOLD  100"
if line != want:
    fail("status line 1 %r, want %r" % (line, want))
else:
    print("status line 1: %r" % line)
for _ in range(30):                              # one full demo round
    m.call("DEMO_SEC")
line = screen_text(0, 40)
want = "GOLD  110  TURNS  9  TIME  30  GOLD  110"
if line != want:
    fail("after a round %r, want %r" % (line, want))
else:
    print("after a round: %r" % line)

print("text: %d failed" % fails)
sys.exit(1 if fails else 0)
