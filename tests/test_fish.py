#!/usr/bin/env python3
"""T-EVT-2: schools of fish and fishing (py65).

RANDOM is a fixed byte in the test machine, so RAND_N gives the same
answer every time: RANDOM = 0 makes every 1-in-N chance happen (a
school appears and gets an east kick each tic), RANDOM = 5 makes none
of them happen.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

I_PTBT, I_FSBT, I_P1 = 8, 9, 0x80
K_LAND, K_KIND = 1, 0x7F
F_TOP, F_BOT = 8, 80
TOPY, BOTY = 12, 84             # schools on rows 0-1 and 9-10
PM_MAP, HP_MAP = 24, 48
ALWAYS, NEVER = 0, 5
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def s8(v):
    return v - 256 if v > 127 else v


def school(i):
    return dict(act=m.byte("FACT", i), x=m.byte("FXH", i) + m.byte("FXL", i) / 256,
                y=m.byte("FYH", i) + m.byte("FYL", i) / 256,
                vx=s8(m.byte("FVX", i)), vy=s8(m.byte("FVY", i)))


def put(i, fx, fy, vx=0, vy=0):
    m.poke("FACT", *[1 if j == i else m.byte("FACT", j) for j in (0, 1)][:2])
    for name, v in (("FXH", fx), ("FYH", fy), ("FVX", vx & 0xFF), ("FVY", vy & 0xFF),
                    ("FXL", 0), ("FYL", 0)):
        m.mem[m.addr(name) + i] = v


def tic(n=1, rnd=NEVER):
    m.poke("RANDOM", rnd)
    for _ in range(n):
        m.call("FISH_TIC")


def land(col, row):
    if not (0 <= col < 20 and 0 <= row < 11):
        return False
    return m.byte("ISLKIND", row * 20 + col) & K_KIND == K_LAND


def box_hit(fx, fy):
    """Is any corner of a school at FXH fx, FYH fy on land?"""
    return any(land((fx + dx) // 8, (fy + dy) // 8) for dx in (-8, -1) for dy in (-8, -1)
               if fx + dx >= 0 and fy + dy >= 0)


def gold(p):
    return m.byte("GOLD", 2 * p) | m.byte("GOLD", 2 * p + 1) << 8


def rgold(p):
    return m.byte("RGOLD", 2 * p) | m.byte("RGOLD", 2 * p + 1) << 8


for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "GAME_NEW"):
    m.call(r)
if m.byte("FACT") or m.byte("FACT", 1):
    fail("schools out at the start of a game")

# spawning: the first in the top band from the left, the second in
# the other band (D14)
tic(rnd=ALWAYS)
s = school(0)
if not s["act"] or m.byte("FYH") != F_TOP or s["vx"] != 4 or school(1)["act"]:
    fail("first school %r" % s)
tic(rnd=ALWAYS)
if not school(1)["act"] or m.byte("FYH", 1) != F_BOT:
    fail("second school %r, want the bottom band" % school(1))
tic(5, rnd=ALWAYS)
if m.byte("FACT") + m.byte("FACT", 1) != 2:
    fail("more than two schools?")
print("spawned: %r / %r" % (school(0), school(1)))

# no spawn, no kick: steady drift of v x 51/256 pixel per tic
m.call("FISH_INIT")
put(0, 20, F_TOP, vx=3)
tic(10)
want = 20 + 3 * 34 * 10 / 256
if abs(school(0)["x"] - want) > 0.01 or school(0)["y"] != F_TOP:
    fail("drift: x %.3f, want %.3f" % (school(0)["x"], want))

# leaving the map: gone
put(0, 2, F_TOP, vx=-15)
tic(2)
if school(0)["act"]:
    fail("school off the left edge still out: %r" % school(0))
put(0, 166, F_BOT, vx=15)
tic(2)
if school(0)["act"]:
    fail("school off the right edge still out")

# land stops an axis: head east along row 4 into the left island
row = 4
col0 = next(c for c in range(20) if land(c, row))
put(0, 8, row * 8 + 8, vx=15)
tic(40)
s = school(0)
fx = int(s["x"])
if s["vx"] != 0 or not s["act"] or box_hit(fx, int(s["y"])) or not box_hit(fx + 2, int(s["y"])):
    fail("east into the island: %r, coast at column %d" % (s, col0))
print("stopped at the coast: %r" % s)

# heading south from row 1 into the island: stops above the coast
col = next(c for c in range(20) if land(c, 2))
put(0, col * 8 + 8, TOPY, vy=15)
tic(30)
s = school(0)
if s["vy"] != 0 or box_hit(int(s["x"]), int(s["y"])) or int(s["y"]) < 14:
    fail("south into the island at column %d: %r" % (col, s))
print("stopped above the coast: %r" % s)

# a boat parked on top of a school doesn't trap it
m.call("MAP_SET", a=I_PTBT, x=5, y=0)
put(0, 5 * 8 + 8, 8, vx=15)
tic(10)
if school(0)["x"] < 5 * 8 + 8 + 5:
    fail("school trapped under a parked PT boat: %r" % school(0))
m.call("MAP_SET", a=0, x=5, y=0)

# a parked PT boat stops a school, a parked fishing boat does not
put(0, 8 + 9 * 8 - 12, 8, vx=15)              # row 0, heading for column 9
m.call("MAP_SET", a=I_PTBT, x=9, y=0)
tic(20)
if school(0)["vx"] != 0 or (int(school(0)["x"]) - 1) // 8 != 8:
    fail("parked PT boat did not stop the school: %r" % school(0))
m.call("MAP_SET", a=I_FSBT | I_P1, x=9, y=0)
put(0, 8 + 9 * 8 - 12, 8, vx=15)
tic(6)
if (int(school(0)["x"]) - 1) // 8 < 9:
    fail("parked fishing boat stopped the school: %r" % school(0))

# fishing, parked: P2's boat at (9, 0), school sitting on it
m.call("FISH_INIT")
put(0, 8 + 9 * 8, 8, vx=0)
g, rg = gold(1), rgold(1)
tic(49)
if m.byte("FCNT", 1) != 49 or gold(1) != g:
    fail("49 touches: count %d gold %d" % (m.byte("FCNT", 1), gold(1)))
tic(1)
if m.byte("FCNT", 1) != 0 or gold(1) != g + 1 or rgold(1) != rg + 1:
    fail("50th touch: count %d gold %d->%d earned %d->%d"
         % (m.byte("FCNT", 1), g, gold(1), rg, rgold(1)))
if m.byte("FCNT", 0):
    fail("P1 counted P2's fish")
m.call("MAP_SET", a=0, x=9, y=0)

# fishing, steered: P1 steers a fishing boat over a school
put(0, 8 + 40, 8 + 40)
m.poke("BOATK", I_FSBT, 0)
m.poke("CURX", 40 + 7, m.byte("CURX", 1))
m.poke("CURY", 40 - 7, m.byte("CURY", 1))
tic(3)
if m.byte("FCNT", 0) != 3:
    fail("steered fishing boat 7 pixels off: %d touches" % m.byte("FCNT", 0))
m.poke("CURX", 40 + 8, m.byte("CURX", 1))
tic(3)
if m.byte("FCNT", 0) != 3:
    fail("steered boat 8 pixels off still fishing")
m.poke("CURX", 40, m.byte("CURX", 1))
m.poke("BOATK", I_PTBT, 0)
tic(3)
if m.byte("FCNT", 0) != 3:
    fail("a PT boat caught fish")
m.poke("BOATK", 0, 0)

# FISH_SHOW: two schools in different rows, both drawn
m.call("FISH_INIT")
put(0, 8 + 20, TOPY)           # rows 0-1
put(1, 8 + 100, BOTY)          # rows 9-10
m.call("FISH_SHOW")
pm = m.addr("PMAREA") + 0x380
hp = [m.byte("HP3ROW", r) for r in range(11)]
want = [20 + HP_MAP] * 2 + [0] * 7 + [100 + HP_MAP] * 2
if hp != want:
    fail("HP3ROW %r, want %r" % (hp, want))
for i, fy in ((0, TOPY), (1, BOTY)):
    line = fy - 8 + PM_MAP
    if not any(m.mem[pm + line:pm + line + 8]) or m.byte("FDRAWN", i) != line:
        fail("school %d not drawn at P3 line %d" % (i, line))
# sharing a row: they take turns, frame by frame
put(1, 8 + 100, TOPY + 4)
shown = []
for f in range(2):
    m.poke("FRAME", f)
    m.call("FISH_SHOW")
    shown.append(tuple(m.byte("FDRAWN", i) != 0xFF for i in (0, 1)))
if sorted(shown) != [(False, True), (True, False)]:
    fail("schools sharing rows: shown %r" % shown)
# moving: the old lines are cleared
put(0, 8 + 20, BOTY)
m.poke("FACT", 1, 0)
m.call("FISH_SHOW")
old = TOPY - 8 + PM_MAP
if any(m.mem[pm + old:pm + old + 8]):
    fail("old school lines not erased")

# in the game: no fish during the summary, and GAME_START clears them
m.call("FISH_INIT")
m.poke("GSTATE", 1)
m.poke("RANDOM", ALWAYS)
m.poke("PAL", 0x0F)
for _ in range(30):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.call("GAME_FRAME")
if m.byte("FACT") or m.byte("FACT", 1):
    fail("a school appeared during the round summary")
m.poke("GSTATE", 0)
for _ in range(10):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.call("GAME_FRAME")
if not m.byte("FACT"):
    fail("no school during a round")
m.call("GAME_START")
if m.byte("FACT") or m.byte("FACT", 1) or m.byte("FCNT", 1):
    fail("GAME_START left schools or touches")

print("fish: %d failed" % fails)
sys.exit(1 if fails else 0)
