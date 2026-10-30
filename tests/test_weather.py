#!/usr/bin/env python3
"""T-EVT-4: rain, tropical storms and hurricanes (py65).

RANDOM is a fixed byte in the test machine, so RAND_N gives the same
answer every time: 0 makes every 1-in-N chance happen, 5 makes the
spawn and kick rolls fail (and RAND_N(12) = 5: rain, RAND_N(101) = 5).
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

WT_RAIN, WT_STRM, WT_HURR = 1, 2, 3
I_FORT, I_CROP, I_PTBT, I_FSBT, I_P1 = 1, 3, 8, 9, 0x80
K_LAND, K_KIND, K_P1 = 1, 0x7F, 0x80
T_WRECK = 11
PM_MAP, HP_MAP = 24, 48
NEVER = 5
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def s8(v):
    return v - 256 if v > 127 else v


def put(i, kind, wx, wy, vx=0, vy=0):
    m.mem[m.addr("WACT") + i] = kind
    for name, v in (("WXH", wx), ("WYH", wy), ("WVX", vx & 0xFF), ("WVY", vy & 0xFF),
                    ("WXL", 0), ("WYL", 0)):
        m.mem[m.addr(name) + i] = v


def clear():
    m.call("WTH_INIT")


def tic(n=1, rnd=NEVER):
    m.poke("RANDOM", rnd)
    for _ in range(n):
        m.call("WTH_TIC")


def over(kind, col, row):
    """WXH, WYH that put a kind's centre on square col, row."""
    half = 16 if kind == WT_HURR else 4
    return col * 8 + 4, row * 8 + 4 - half + 8


def own_land(p):
    """A land square of player p's island, with land around it."""
    for row in range(3, 8):
        for col in range(20):
            k = m.byte("ISLKIND", row * 20 + col)
            if k & K_KIND == K_LAND and (k & K_P1) == (K_P1 if p else 0):
                return col, row
    raise RuntimeError("no land")


def pop(p):
    return m.byte("POP", 2 * p) | m.byte("POP", 2 * p + 1) << 8


def gold(p):
    return m.byte("GOLD", 2 * p) | m.byte("GOLD", 2 * p + 1) << 8


def rgold(p):
    return m.byte("RGOLD", 2 * p) | m.byte("RGOLD", 2 * p + 1) << 8


def item(col, row):
    return m.byte("MAPITEM", row * 20 + col)


def count(p, k):
    return m.byte("COUNT", 10 * p + k)


def chars(col, row):
    a = m.addr("MAPSCR") + row * 80 + col * 2
    return m.mem[a]


for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "GAME_NEW"):
    m.call(r)
m.call("ECO_INIT")

# spawning: the type roll, the start, the second waits for the first
for rnd, kind in ((0, WT_HURR), (2, WT_STRM), (5, WT_RAIN)):
    clear()
    m.poke("RANDOM", rnd)
    m.call("WTH_NEW", x=0)
    got = [m.byte(n) for n in ("WACT", "WXH", "WYH", "WVX", "WVY")]
    if got != [kind, 27, 0, 4, 5]:
        fail("RANDOM %d: new weather %r, want type %d at 27, 0 moving 4, 5" % (rnd, got, kind))
clear()
tic(rnd=0)
if m.byte("WACT") != WT_HURR or m.byte("WACT", 1):
    fail("a tic with every roll coming up: %r" % [m.byte("WACT"), m.byte("WACT", 1)])
put(0, WT_RAIN, 40, 23)
m.poke("RANDOM", NEVER)
m.call("WTH_NEW", x=1)
if m.byte("WACT", 1):
    fail("second weather started while the first is still at the top")
put(0, WT_RAIN, 40, 24)
m.call("WTH_NEW", x=1)
if m.byte("WACT", 1) != WT_RAIN:
    fail("second weather not started once the first is a row clear")

# moving: drift at 38/256 per unit (3/4 of the original, D43), gone off the map
clear()
put(0, WT_RAIN, 40, 20, vx=4, vy=5)
tic(10)
x = m.byte("WXH") + m.byte("WXL") / 256
y = m.byte("WYH") + m.byte("WYL") / 256
if abs(x - (40 + 4 * 38 * 10 / 256)) > 0.01 or abs(y - (20 + 5 * 38 * 10 / 256)) > 0.01:
    fail("drift to %.2f, %.2f" % (x, y))
put(0, WT_STRM, 80, 95, vy=15)
tic(2)
if m.byte("WACT"):
    fail("weather below the map still out")
put(0, WT_STRM, 2, 40, vx=-15)
tic(2)
if m.byte("WACT"):
    fail("weather off the left edge still out")

# rain over a crop: every 12 tics 1 gold for the crop's owner
col, row = own_land(1)
m.call("MAP_SET", a=I_CROP, x=col, y=row)
clear()
g, rg = gold(1), rgold(1)
put(0, WT_RAIN, *over(WT_RAIN, col, row))
tic(11)
if m.byte("WRCNT", 1) != 11 or gold(1) != g or m.byte("WDMG", 1):
    fail("11 tics of rain: count %d gold %d damage %d"
         % (m.byte("WRCNT", 1), gold(1), m.byte("WDMG", 1)))
tic(1)
if m.byte("WRCNT", 1) != 0 or gold(1) != g + 1 or rgold(1) != rg + 1:
    fail("12th tic of rain: count %d gold %d->%d" % (m.byte("WRCNT", 1), g, gold(1)))
if item(col, row) != I_CROP:
    fail("rain destroyed the crop")
# rain over sea or bare land: nothing
put(0, WT_RAIN, *over(WT_RAIN, 9, 5))
tic(20)
if m.byte("WRCNT", 1) or m.byte("WRCNT", 0):
    fail("rain counted over open sea")

# a storm over a fort, with a fort next to it: no protection, 125 tics
col, row = own_land(0)
m.call("MAP_SET", a=I_FORT, x=col, y=row)
m.call("MAP_SET", a=I_FORT, x=col + 1, y=row)
m.poke("COUNT", 2)                       # (two forts for player 1)
m.mem[m.addr("COUNT") + I_FORT] = 2
p0 = pop(0)
clear()
put(0, WT_STRM, *over(WT_STRM, col, row))
tic(124)
if item(col, row) != I_FORT or m.byte("WDMG") != 124:
    fail("124 tics of storm: item %d damage %d" % (item(col, row), m.byte("WDMG")))
tic(1)
if item(col, row) or count(0, I_FORT) != 1 or m.byte("WDMG"):
    fail("125th tic: item %d forts %d damage %d" % (item(col, row), count(0, I_FORT), m.byte("WDMG")))
if pop(0) != p0 - 5:
    fail("people killed: %d -> %d, want 5 (RANDOM = 5)" % (p0, pop(0)))
if item(col + 1, row) != I_FORT:
    fail("the storm hit the next square too")
# a hurricane needs 25; damage goes to the square's owner only
m.call("MAP_SET", a=I_FORT, x=col, y=row)
clear()
put(0, WT_HURR, *over(WT_HURR, col, row))
tic(24)
if item(col, row) != I_FORT or m.byte("WDMG") != 120 or m.byte("WDMG", 1):
    fail("24 tics of hurricane: item %d damage %r" % (item(col, row), [m.byte("WDMG"), m.byte("WDMG", 1)]))
tic(1)
if item(col, row):
    fail("hurricane: fort still there after 25 tics")
# population never goes below 0
m.call("MAP_SET", a=I_FORT, x=col, y=row)
m.poke("POP", 3, 0)
clear()
put(0, WT_HURR, *over(WT_HURR, col, row))
tic(25)
if pop(0) != 0:
    fail("population below 0: %d" % pop(0))
m.call("MAP_SET", a=0, x=col + 1, y=row)

# a parked boat sinks: wreck for 3 s, then sea again; no one dies
sea = chars(9, 5)
m.call("MAP_SET", a=I_FSBT | I_P1, x=9, y=5)
m.mem[m.addr("COUNT") + 10 + I_FSBT] = 1
p1 = pop(1)
clear()
put(0, WT_HURR, *over(WT_HURR, 9, 5))
tic(25)
if item(9, 5) or count(1, I_FSBT) != 0 or pop(1) != p1:
    fail("sunk boat: item %d boats %d people %d->%d" % (item(9, 5), count(1, I_FSBT), p1, pop(1)))
if chars(9, 5) != m.byte("TILECH", T_WRECK):
    fail("no wreck shown")
m.poke("WACT", 0, 0)
tic(59)
if chars(9, 5) != m.byte("TILECH", T_WRECK):
    fail("wreck gone too early")
tic(1)
if chars(9, 5) != sea:
    fail("wreck still there after 3 s")

# a hurricane sinks a steered boat it touches; a storm does not
clear()
m.poke("BOATK", I_FSBT, 0)
m.poke("SPRSHP", 2, 0)
m.mem[m.addr("COUNT") + I_FSBT] = 1
m.poke("CURX", 40, m.byte("CURX", 1))
m.poke("CURY", 40, m.byte("CURY", 1))
put(0, WT_STRM, 40, 44)
tic(3)
if m.byte("BOATK") != I_FSBT:
    fail("a storm sank a steered boat")
put(0, WT_HURR, 40 + 16, 40)            # its left edge 8 past the boat's
tic(1)
if m.byte("BOATK") != I_FSBT:
    fail("hurricane 1 pixel clear sank the boat")
put(0, WT_HURR, 40 + 15, 40)            # one pixel of overlap
tic(1)
if m.byte("BOATK") or count(0, I_FSBT) or m.byte("SPRSHP"):
    fail("hurricane over a steered boat: BOATK %d boats %d shape %d"
         % (m.byte("BOATK"), count(0, I_FSBT), m.byte("SPRSHP")))

# WTH_SHOW: positions and colours per row, shapes in player 2 memory
clear()
put(0, WT_RAIN, 40, 40)                 # lines 32-39: row 4
put(1, WT_HURR, 120, 64)                # lines 56-87: rows 7-10
m.call("WTH_SHOW")
hp = [m.byte("HP2ROW", r) for r in range(11)]
want = [0] * 4 + [40 + HP_MAP - 8] + [0, 0] + [120 + HP_MAP - 8] * 4
if hp != want:
    fail("HP2ROW %r, want %r" % (hp, want))
cols = [m.byte("WCROW", r) for r in (4, 7, 10)]
if cols != [0x0C, 0x0E, 0x0E]:
    fail("WCROW %r" % cols)
pm = m.addr("PMAREA") + 0x300
for i, (wy, h) in enumerate(((40, 8), (64, 32))):
    line = wy - 8 + PM_MAP
    if not all(m.mem[pm + line:pm + line + h][k] or k % 4 for k in range(0, h, 8)):
        fail("weather %d not drawn at P2 line %d" % (i, line))
    if m.mem[pm + line - 1] or (line + h < 128 and m.mem[pm + line + h]):
        fail("weather %d: stray lines around it" % i)
# sharing rows: they take turns
put(1, WT_STRM, 120, 44)
shown = []
for f in range(2):
    m.poke("FRAME", f)
    m.call("WTH_SHOW")
    shown.append(tuple(m.byte("WDRAWN", i) != 0xFF for i in (0, 1)))
if sorted(shown) != [(False, True), (True, False)]:
    fail("weather sharing rows: shown %r" % shown)

# in the game: none during the summary, GAME_START clears it all
clear()
m.poke("GSTATE", 1)
m.poke("RANDOM", 0)
m.poke("PAL", 0x0F)
for _ in range(30):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.call("GAME_FRAME")
if m.byte("WACT") or m.byte("WACT", 1):
    fail("weather started during the round summary")
m.poke("GSTATE", 0)
for _ in range(10):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.call("GAME_FRAME")
if not m.byte("WACT"):
    fail("no weather during a round")
m.poke("WDMG", 7, 8)
m.call("GAME_START")
if m.byte("WACT") or m.byte("WACT", 1) or m.byte("WDMG") or m.byte("WRCNT", 1):
    fail("GAME_START left weather or damage")

print("weather: %d failed" % fails)
sys.exit(1 if fails else 0)
