#!/usr/bin/env python3
"""D59: boats leave a trail of waves (TRAIL_INIT / TRAIL_TIC), on py65."""

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
T = {n: m.addr(n) for n in ("T_SEA", "T_WAVE1", "T_WAVE2", "T_SEAB1", "T_SEAB9",
                            "T_WAVE2B", "T_WAVE1C", "T_WRECK", "T_FORT")}
RATE = m.addr("WV_RATE")


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


def boat(p, col, row, kind=I_PTBT):
    m.poke("BOATK", *([kind] if p == 0 else [m.byte("BOATK"), kind]))
    m.poke("CURCOL", *([col] if p == 0 else [m.byte("CURCOL"), col]))
    m.poke("CURROW", *([row] if p == 0 else [m.byte("CURROW"), row]))


def tic(frame):
    m.poke("FRAME", frame & 0xFF)
    m.call("TRAIL_TIC")


def sail(p, path, frame):
    """Boat p on each square of path in turn, one frame each."""
    for col, row in path:
        boat(p, col, row)
        tic(frame)
        frame += 1
    return frame


def find(want, rows=range(11)):
    """Squares of the given terrain, nothing on them."""
    return [(c, r) for r in rows for c in range(COLS) if terrain(c, r) == want]


# STANDARD's plain open sea in rows 2-8; rows 1 and 9 away from the
# corners use the fixed tiles; rows 0 and 10 have no plain sea tile
sea = find(T["T_SEA"], range(2, 9))
if len(sea) < 20:
    fail("only %d plain sea squares in rows 2-8" % len(sea))
if [r for c, r in find(T["T_SEAB1"])] != [1] * 18 or [r for c, r in find(T["T_SEAB9"])] != [9] * 18:
    fail("rows 1 / 9 not T_SEAB1 / T_SEAB9 between the corners")
for t in ("T_SEAB1", "T_SEAB9"):
    if any(c & 0x7F not in (0, m.byte("TILECH", m.addr("T_GRASS4"))) for c in tile(T[t])):
        fail("%s is not plain sea and PF0 sea" % t)
# the new wave tiles reuse the animated characters, no new ones
if tile(T["T_WAVE2B"])[2:] != tile(T["T_WAVE2"])[2:] or tile(T["T_WAVE2B"])[:2] != tile(T["T_SEAB1"])[:2]:
    fail("T_WAVE2B is not T_SEAB1's top over T_WAVE2's bottom")
if tile(T["T_WAVE1C"])[:2] != tile(T["T_WAVE1"])[:2] or tile(T["T_WAVE1C"])[2:] != tile(T["T_SEAB9"])[2:]:
    fail("T_WAVE1C is not T_WAVE1's top over T_SEAB9's bottom")

# a boat crossing open sea: the square it leaves gets the wave that
# shows its crest now, and keeps it until that wave goes calm
row = 3
path = [(c, row) for c in range(COLS) if terrain(c, row) == T["T_SEA"]][:2]
(a, _), (b, _) = path
for start, want, ends in ((0, "T_WAVE1", 3 * RATE), (RATE + 5, "T_WAVE1", 3 * RATE),
                          (2 * RATE, "T_WAVE2", 5 * RATE), (3 * RATE + 9, "T_WAVE2", 5 * RATE)):
    m.call("TRAIL_INIT")
    sail(0, path, start)
    if chars(a, row) != tile(T[want]):
        fail("frame %d: left square shows %r, want %s" % (start, chars(a, row), want))
    if chars(b, row) != tile(T["T_SEA"]):
        fail("frame %d: the boat's own square has a wake" % start)
    for f in range(start + 2, ends + 2):
        tic(f)
        shown = chars(a, row) == tile(T[want])
        if shown != (f < ends):
            fail("frame %d start %d: wake %s at frame %d" % (f, start, "still there" if shown else "gone", f))
            break
    if chars(a, row) != tile(T["T_SEA"]):
        fail("frame %d: not plain sea after the wake" % start)

# rows 1 and 9 have one wave each; a wake that starts calm waits for it
for r, want, lag in ((1, "T_WAVE2B", 2), (9, "T_WAVE1C", 0)):
    for ph in range(4):
        m.call("TRAIL_INIT")
        sail(0, [(6, r), (7, r)], ph * RATE)
        if chars(6, r) != tile(T[want]):
            fail("row %d phase %d: %r, want %s" % (r, ph, chars(6, r), want))
        shown = (ph ^ lag) != 3
        end = None
        for f in range(ph * RATE + 2, ph * RATE + 6 * RATE):
            tic(f)
            if chars(6, r) != tile(T[want]):
                end = f
                break
            if ((f // RATE) & 3) ^ lag != 3:
                shown = True
        if end is None or not shown or ((end // RATE) & 3) ^ lag != 3:
            fail("row %d phase %d: wake ended at frame %r" % (r, ph, end))

# no wake in rows 0 and 10, on land, the harbour, an item or a decorative wave
m.call("TRAIL_INIT")
for r in (0, 10):
    before = chars(8, r)
    sail(0, [(8, r), (9, r)], 0)
    if chars(8, r) != before:
        fail("a wake in row %d" % r)
m.call("MAP_SET", a=I_FORT, x=a, y=row)
before = chars(a, row)
sail(0, [(a, row), (b, row)], 0)
if chars(a, row) != before:
    fail("a wake over an item")
m.call("MAP_SET", a=0, x=a, y=row)
w1 = find(T["T_WAVE1"], range(2, 9))[0]
m.call("TRAIL_INIT")
sail(0, [w1, (w1[0], w1[1] + 1)], 0)
if chars(*w1) != tile(T["T_WAVE1"]) or any(m.byte("TLTILE", i) for i in range(m.addr("TL_N"))):
    fail("a wake on a decorative wave")

# a cursor (no boat) leaves nothing; lifting a boat starts afresh
m.call("TRAIL_INIT")
m.poke("BOATK", 0, 0)
m.poke("CURCOL", a)
m.poke("CURROW", row)
tic(0)
m.poke("CURCOL", b)
tic(1)
if chars(a, row) != tile(T["T_SEA"]):
    fail("a cursor left a wake")

# something drawn over a wake stays when the wake ends
m.call("TRAIL_INIT")
sail(0, path, 0)
m.call("MAP_PUT", a=T["T_WRECK"], x=a, y=row)
for f in range(2, 4 * RATE):
    tic(f)
if chars(a, row) != tile(T["T_WRECK"]):
    fail("a wreck over a wake was cleared")
if any(m.byte("TLTILE", i) for i in range(m.addr("TL_N"))):
    fail("the wake under the wreck was not freed")
m.call("MAP_SET", a=0, x=a, y=row)

# a long run: at most TL_N wakes, the oldest cleared first; both players
m.call("TRAIL_INIT")
run = [(c, r) for c, r in sea if r == 2][:12]
other = [(c, r) for c, r in sea if r == 8][:3]
f = sail(1, other, 0)
f = sail(0, run, f)
woken = [s for s in run[:-1] + other[:-1] if chars(*s) != tile(T["T_SEA"])]
if len(woken) != m.addr("TL_N"):
    fail("%d wakes showing, want %d" % (len(woken), m.addr("TL_N")))
if woken != run[-1 - m.addr("TL_N"):-1]:
    fail("not the newest wakes: %r" % woken)
for f in range(f, f + 6 * RATE):
    tic(f)
if any(chars(*s) != tile(T["T_SEA"]) for s in run + other):
    fail("wakes left after they ended")

print("trail: %d failed" % fails)
sys.exit(1 if fails else 0)
