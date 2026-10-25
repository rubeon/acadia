#!/usr/bin/env python3
"""T-SPR-1: cursor movement, snap to grid, clamping and P/M drawing (py65).

JOY0 / JOY1 (input-layer variables) are poked directly, then CUR_MOVE
is called once per simulated frame.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

UP, DOWN, LEFT, RIGHT = 1, 2, 4, 8
PM_P0, PM_MAP, HP_MAP = 0x4200, 24, 48
SHAPE = [0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF]

m = Machine()
m.call("VARS_INIT")
m.call("PM_INIT")
m.call("CUR_INIT")
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def state(p):
    return (m.byte("CURX", p), m.byte("CURY", p), m.byte("CURCOL", p), m.byte("CURROW", p))


def frames(n, joy0=0, joy1=0):
    m.poke("JOY0", joy0)
    m.poke("JOY1", joy1)
    for _ in range(n):
        m.call("CUR_MOVE")


def expect(what, p, want):
    got = state(p)
    if got != want:
        fail("%s: player %d at x,y,col,row %r, want %r" % (what, p, got, want))


def check_drawn(p):
    """Exactly the cursor shape, at its line, in this player's P/M bytes."""
    base = PM_P0 + 0x80 * p
    col = [m.mem[base + i] for i in range(0x80)]
    y = m.byte("CURY", p) + PM_MAP
    want = [0] * 0x80
    want[y:y + 8] = SHAPE
    if col != want:
        fail("player %d P/M bytes wrong (cursor line %d)" % (p, y))
    if m.byte("SPRHP", p) != HP_MAP + m.byte("CURX", p):
        fail("player %d horizontal position %d" % (p, m.byte("SPRHP", p)))


expect("start", 0, (32, 40, 4, 5))
expect("start", 1, (112, 40, 14, 5))
check_drawn(0)
check_drawn(1)

frames(3, joy0=RIGHT)
expect("3 frames right", 0, (35, 40, 4, 5))
frames(3)
expect("released at +3: snaps back", 0, (32, 40, 4, 5))
frames(5, joy0=RIGHT)
expect("5 frames right", 0, (37, 40, 5, 5))
frames(2)
expect("gliding on", 0, (39, 40, 5, 5))
frames(1)
expect("snapped forward", 0, (40, 40, 5, 5))
frames(5)
expect("stays put", 0, (40, 40, 5, 5))

frames(6, joy0=DOWN + LEFT)
expect("diagonal", 0, (34, 46, 4, 6))
frames(8)
expect("diagonal release", 0, (32, 48, 4, 6))
check_drawn(0)

frames(4, joy0=LEFT + RIGHT)
expect("left+right cancel", 0, (32, 48, 4, 6))

frames(300, joy0=LEFT + UP)
expect("clamped top-left", 0, (0, 0, 0, 0))
frames(300, joy0=RIGHT + DOWN)
expect("clamped bottom-right", 0, (152, 80, 19, 10))
check_drawn(0)

# player 1 moves on its own stick only
before0 = state(0)
frames(10, joy1=UP)
expect("player 1 up", 1, (112, 30, 14, 4))
if state(0) != before0:
    fail("player 0 moved on player 1's stick")
frames(8)
expect("player 1 snapped", 1, (112, 32, 14, 4))
check_drawn(1)
check_drawn(0)

print("cursor: %d failed" % fails)
sys.exit(1 if fails else 0)
