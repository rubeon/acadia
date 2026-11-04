#!/usr/bin/env python3
"""D64: boats leave a fading wake, a thin line across or up and down
(TRAIL_INIT / TRAIL_TIC), on py65."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

COLS = 20
MAPSCR = 0x3400
I_FORT = 1
I_PTBT = 8

m = Machine()
m.call("VARS_INIT")
m.call("MAP_ROWS")
m.call("MAP_DRAW")
m.call("MAP_INIT")
m.call("TRAIL_INIT")
fails = 0
T = {n: m.addr(n) for n in ("T_SEA", "T_WAVE1", "T_WAVE2", "T_SPARK", "T_SEAB", "T_SEAB1",
                            "T_SEAB9", "T_WRECK")}
WK = {n: m.addr(n) for n in ("WK_H1", "WK_H2", "WK_H1B", "WK_H2B",
                             "WK_V1", "WK_V2", "WK_V1B", "WK_V2B")}
RATE = m.addr("WK_RATE")
STEPS = m.addr("WK_STEPS")
N = m.addr("TL_N")
SEA = {0: "T_SEAB", 1: "T_SEAB1", 9: "T_SEAB9", 10: "T_SEAB"}
BAND = {0: (1, 1), 1: (1, 0), 9: (0, 1), 10: (1, 1)}    # (top, bottom) on PF0 sea


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def chars(col, row):
    a = MAPSCR + row * 80 + col * 2
    return m.mem[a], m.mem[a + 1], m.mem[a + 40], m.mem[a + 41]


def tile(t):
    return tuple(m.byte(n, t) for n in ("TILECH", "TILECTR", "TILECBL", "TILECBR"))


def terrain(col, row):
    return m.byte("ISLTILE", row * COLS + col)


def wake(col, row, across, step, under=None):
    """What square col, row shows with a wake on terrain `under`."""
    tl, tr, bl, br = tile(under if under is not None else terrain(col, row))
    top, bot = BAND.get(row, (0, 0))
    if across:
        k = WK["WK_H%d%s" % (step, "B" if bot else "")]
        return tl, tr, k, k
    return (tl, WK["WK_V%d%s" % (step, "B" if top else "")],
            bl, WK["WK_V%d%s" % (step, "B" if bot else "")])


def boat(p, col, row):
    m.poke("BOATK", *([I_PTBT] if p == 0 else [m.byte("BOATK"), I_PTBT]))
    m.poke("CURCOL", *([col] if p == 0 else [m.byte("CURCOL"), col]))
    m.poke("CURROW", *([row] if p == 0 else [m.byte("CURROW"), row]))


def tic():
    m.call("TRAIL_TIC")


def sail(p, path):
    for col, row in path:
        boat(p, col, row)
        tic()


def fresh():
    m.call("TRAIL_INIT")
    m.poke("BOATK", 0, 0)
    tic()


def nslots():
    return sum(1 for i in range(N) if m.byte("TLSTEP", i))


# the wake characters: white (inverse), all different, in every font
if len(set(WK.values())) != 8 or not all(c & 0x80 for c in WK.values()):
    fail("wake characters %r" % WK)

# across and up / down, on every kind of row: dashes, then dots, then
# the square as it was
for row in (3, 1, 9, 0, 10):
    sea = T[SEA.get(row, "T_SEA")]
    a, b = [c for c in range(COLS) if terrain(c, row) == sea][:2]
    for across in (True, False):
        fresh()
        if across:
            sail(0, [(a, row), (b, row)])
        else:
            sail(0, [(a, row), (a, row + (1 if row < 10 else -1))])
        for s in range(STEPS, 0, -1):
            for k in range(RATE):
                if chars(a, row) != wake(a, row, across, s):
                    fail("row %d %s: step %d frame %d shows %r, want %r"
                         % (row, "across" if across else "up/down", s, k,
                            chars(a, row), wake(a, row, across, s)))
                    break
                tic()
        if chars(a, row) != tile(sea):
            fail("row %d %s: not sea again" % (row, "across" if across else "up/down"))

# over the ambient waves and sparkles too, which come back after
for t in ("T_WAVE1", "T_WAVE2", "T_SPARK"):
    c, r = [s for s in [(c, r) for r in range(2, 9) for c in range(COLS)]
            if terrain(*s) == T[t]][0]
    fresh()
    sail(0, [(c, r), (c + 1, r)])
    if chars(c, r) != wake(c, r, True, STEPS):
        fail("no wake on %s" % t)
    for k in range(STEPS * RATE):
        tic()
    if chars(c, r) != tile(T[t]):
        fail("%s not back after the wake" % t)

# none on an item or in the dark corners; a cursor leaves none
row = 3
a, b = [c for c in range(COLS) if terrain(c, row) == T["T_SEA"]][:2]
fresh()
m.call("MAP_SET", a=I_FORT, x=a, y=row)
before = chars(a, row)
sail(0, [(a, row), (b, row)])
if chars(a, row) != before:
    fail("a wake over an item")
m.call("MAP_SET", a=0, x=a, y=row)
fresh()
before = chars(0, 0)
sail(0, [(0, 0), (1, 0)])
if chars(0, 0) != before:
    fail("a wake in a dark corner")
fresh()
m.poke("CURCOL", a)
m.poke("CURROW", row)
tic()
m.poke("CURCOL", b)
tic()
if chars(a, row) != tile(T["T_SEA"]):
    fail("a cursor left a wake")

# something drawn over a wake stays
fresh()
sail(0, [(a, row), (b, row)])
m.call("MAP_PUT", a=T["T_WRECK"], x=a, y=row)
for k in range(STEPS * RATE + 2):
    tic()
if chars(a, row) != tile(T["T_WRECK"]):
    fail("a wreck over a wake was changed")
if nslots():
    fail("the wake under the wreck was not freed")
m.call("MAP_SET", a=0, x=a, y=row)

# the boat comes back over its wake the other way: only the new one shows
fresh()
sail(0, [(a, row), (b, row)])        # across: a gets a line
sail(0, [(b, row + 1), (b, row)])    # b, then up and down over b
sail(0, [(a, row), (a, row + 1)])    # back over a, then down
if chars(a, row) != wake(a, row, False, STEPS):
    fail("coming back: %r, want only the up / down line" % (chars(a, row),))

# a long run: at most TL_N wakes, the oldest cleared first; both players
fresh()
sea = [(c, r) for r in range(2, 9) for c in range(COLS) if terrain(c, r) == T["T_SEA"]]
run = [s for s in sea if s[1] < 8][:12]
other = [s for s in sea if s[1] == 8][:3]
if len(run) < 12 or len(other) < 3:
    fail("not enough open sea for the long run")
sail(1, other)
sail(0, run)
lit = [s for s in run[:-1] + other[:-1] if chars(*s) != tile(T["T_SEA"])]
if lit != run[-1 - N:-1]:
    fail("not the newest %d wakes: %r" % (N, lit))
for k in range(STEPS * RATE + 2):
    tic()
if any(chars(*s) != tile(T["T_SEA"]) for s in run + other):
    fail("wakes left after they faded")

print("trail: %d failed" % fails)
sys.exit(1 if fails else 0)
