#!/usr/bin/env python3
"""D63: boats leave a fading trail of white dots (TRAIL_INIT / TRAIL_TIC),
on py65."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

COLS = 20
MAPSCR = 0x3400
I_PTBT, I_FORT = 8, 1

m = Machine()
m.call("VARS_INIT")
m.call("MAP_ROWS")
m.call("MAP_DRAW")
m.call("MAP_INIT")
m.call("TRAIL_INIT")
fails = 0
T = {n: m.addr(n) for n in ("T_SEA", "T_WAVE1", "T_WAVE2", "T_SPARK", "T_SEAB", "T_SEAB1",
                            "T_SEAB9", "T_WRECK", "T_GRASS4", "T_SPKA1", "T_SPKB1",
                            "T_SPKC1", "T_SPKD1")}
RATE = m.addr("SPK_RATE")
STEPS = m.addr("SPK_STEPS")
N = m.addr("TL_N")
BASE = {0: "T_SPKD1", 1: "T_SPKB1", 9: "T_SPKC1", 10: "T_SPKD1"}


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def chars(col, row):
    a = MAPSCR + row * 80 + col * 2
    return m.mem[a], m.mem[a + 1], m.mem[a + 40], m.mem[a + 41]


def tile(t):
    return tuple(m.byte(n, t) for n in ("TILECH", "TILECTR", "TILECBL", "TILECBR"))


def spark(row, step):
    return tile(T[BASE.get(row, "T_SPKA1")] + step - 1)


def terrain(col, row):
    return m.byte("ISLTILE", row * COLS + col)


def boat(p, col, row, kind=I_PTBT):
    m.poke("BOATK", *([kind] if p == 0 else [m.byte("BOATK"), kind]))
    m.poke("CURCOL", *([col] if p == 0 else [m.byte("CURCOL"), col]))
    m.poke("CURROW", *([row] if p == 0 else [m.byte("CURROW"), row]))


def tic():
    m.call("TRAIL_TIC")


def sail(p, path):
    """Boat p on each square of path in turn, one frame each."""
    for col, row in path:
        boat(p, col, row)
        tic()


def fresh():
    m.call("TRAIL_INIT")
    m.poke("BOATK", 0, 0)
    tic()


def find(want, rows=range(11)):
    return [(c, r) for r in rows for c in range(COLS) if terrain(c, r) == want]


# the corner rows' open sea away from the corners is fixed tiles
for t, r in (("T_SEAB", 0), ("T_SEAB1", 1), ("T_SEAB9", 9), ("T_SEAB", 10)):
    if [c for c, rr in find(T[t]) if rr == r] != list(range(4 if r in (0, 10) else 1, 16 if r in (0, 10) else 19)):
        fail("row %d: %s squares %r" % (r, t, [c for c, rr in find(T[t]) if rr == r]))
# each trail tile: per quarter either the row's sea there or white
# dots (inverse); the brightest step dotted all over; the steps, and
# their top left + bottom right pair (TL_SHOWN), all different
g = m.byte("TILECH", T["T_GRASS4"])
for r, top, bot in ((5, 0, 0), (1, g, 0), (9, 0, g), (0, g, g), (10, g, g)):
    for s in range(1, STEPS + 1):
        ch = spark(r, s)
        sea = (top, top, bot, bot)
        if any(c != w and not c & 0x80 for c, w in zip(ch, sea)):
            fail("row %d step %d: characters %r" % (r, s, ch))
    if not all(c & 0x80 for c in spark(r, STEPS)):
        fail("row %d: the brightest step is not dotted all over" % r)
    pairs = {(spark(r, s)[0], spark(r, s)[3]) for s in range(1, STEPS + 1)}
    if len(pairs) != STEPS or (top, bot) in pairs:
        fail("row %d: steps not told apart by their corners" % r)

# a boat crossing open sea: the square it leaves sparkles, brightest
# first, a step fainter every SPK_RATE frames, then plain sea again
for row in (3, 1, 9, 0, 10):
    sea = T["T_SEA"] if 2 <= row <= 8 else T[{0: "T_SEAB", 1: "T_SEAB1", 9: "T_SEAB9", 10: "T_SEAB"}[row]]
    a, b = [c for c in range(COLS) if terrain(c, row) == sea][:2]
    fresh()
    sail(0, [(a, row), (b, row)])
    if chars(b, row) != tile(sea):
        fail("row %d: the boat's own square sparkles" % row)
    for s in range(STEPS, 0, -1):
        for k in range(RATE):
            if chars(a, row) != spark(row, s):
                fail("row %d: step %d frame %d shows %r" % (row, s, k, chars(a, row)))
                break
            tic()
    if chars(a, row) != tile(sea):
        fail("row %d: not sea again after the sparkle" % row)

# over the ambient waves and sparkles too, which come back after
for t in ("T_WAVE1", "T_WAVE2", "T_SPARK"):
    c, r = find(T[t], range(2, 9))[0]
    fresh()
    sail(0, [(c, r), (c, r + 1)])
    if chars(c, r) != spark(r, STEPS):
        fail("no sparkle on %s" % t)
    for k in range(STEPS * RATE):
        tic()
    if chars(c, r) != tile(T[t]):
        fail("%s not back after the sparkle" % t)

# none on an item, land, a harbour, or the corners themselves
row = 3
a, b = [c for c in range(COLS) if terrain(c, row) == T["T_SEA"]][:2]
fresh()
m.call("MAP_SET", a=I_FORT, x=a, y=row)
before = chars(a, row)
sail(0, [(a, row), (b, row)])
if chars(a, row) != before:
    fail("a sparkle over an item")
m.call("MAP_SET", a=0, x=a, y=row)
fresh()
before = chars(0, 0)
sail(0, [(0, 0), (1, 0)])
if chars(0, 0) != before:
    fail("a sparkle in a dark corner")

# a cursor (no boat) leaves nothing
fresh()
m.poke("CURCOL", a)
m.poke("CURROW", row)
tic()
m.poke("CURCOL", b)
tic()
if chars(a, row) != tile(T["T_SEA"]):
    fail("a cursor left a sparkle")

# something drawn over a sparkle stays
fresh()
sail(0, [(a, row), (b, row)])
m.call("MAP_PUT", a=T["T_WRECK"], x=a, y=row)
for k in range(STEPS * RATE + 2):
    tic()
if chars(a, row) != tile(T["T_WRECK"]):
    fail("a wreck over a sparkle was changed")
if any(m.byte("TLSTEP", i) for i in range(N)):
    fail("the sparkle under the wreck was not freed")
m.call("MAP_SET", a=0, x=a, y=row)

# the boat comes back over its sparkle: it starts bright again
fresh()
sail(0, [(a, row), (b, row)])
for k in range(RATE + 1):
    tic()
sail(0, [(a, row), (b, row)])
if chars(a, row) != spark(row, STEPS) or sum(1 for i in range(N) if m.byte("TLSTEP", i)) != 2:
    fail("coming back: %r, %d slots" % (chars(a, row), sum(1 for i in range(N) if m.byte("TLSTEP", i))))

# a long run: at most TL_N sparkles, the oldest cleared first; both players
fresh()
sea = find(T["T_SEA"], range(2, 9))
run = [s for s in sea if s[1] < 8][:12]
other = [s for s in sea if s[1] == 8][:3]
if len(run) < 12 or len(other) < 3:
    fail("not enough open sea for the long run")
sail(1, other)
sail(0, run)
lit = [s for s in run[:-1] + other[:-1] if chars(*s) != tile(T["T_SEA"])]
if lit != run[-1 - N:-1]:
    fail("not the newest %d sparkles: %r" % (N, lit))
for k in range(STEPS * RATE + 2):
    tic()
if any(chars(*s) != tile(T["T_SEA"]) for s in run + other):
    fail("sparkles left after they faded")

print("trail: %d failed" % fails)
sys.exit(1 if fails else 0)
