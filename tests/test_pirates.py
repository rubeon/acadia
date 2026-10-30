#!/usr/bin/env python3
"""T-EVT-3: pirates, and PT boats against fishing boats (py65).

RANDOM is a fixed byte in the test machine, so RAND_N gives the same
answer every time: 0 makes every 1-in-N chance happen, 5 makes the
spawn and kick rolls fail.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

WT_HURR = 3
I_FORT, I_PTBT, I_FSBT, I_P1 = 1, 8, 9, 0x80
K_LAND, K_KIND, K_P1 = 1, 0x7F, 0x80
T_WRECK = 11
PM_MAP, HP_MAP = 24, 48
SH_CUR = 0
P = 2                                    # first pirate slot
NEVER = 5
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def put(i, fx, fy, vx=0, vy=0):
    """Pirate i (0/1) with its box's top left at map pixel fx - 8, fy - 8."""
    m.mem[m.addr("FACT") + P + i] = 1
    for name, v in (("FXH", fx), ("FYH", fy), ("FVX", vx & 0xFF), ("FVY", vy & 0xFF),
                    ("FXL", 0), ("FYL", 0)):
        m.mem[m.addr(name) + P + i] = v


def at(col, row):
    """FXH, FYH with the pirate exactly on square col, row."""
    return col * 8 + 8, row * 8 + 8


def clear():
    m.call("PIR_INIT")
    m.call("WTH_INIT")                   # no wreck showing (SNKT)
    for p in (0, 1):
        m.poke("BOATK", 0, 0)
        steer(p, 0, 0, 0)


def tic(n=1, rnd=NEVER):
    m.poke("RANDOM", rnd)
    for _ in range(n):
        m.call("PIR_TIC")


def steer(p, kind, x, y):
    """Player p steers a boat (kind 0: cursor) with its top left at x, y."""
    m.mem[m.addr("BOATK") + p] = kind
    m.mem[m.addr("CURX") + p] = x
    m.mem[m.addr("CURY") + p] = y
    m.mem[m.addr("CURCOL") + p] = (x + 4) // 8
    m.mem[m.addr("CURROW") + p] = (y + 4) // 8


def item(col, row):
    return m.byte("MAPITEM", row * 20 + col)


def count(p, k):
    return m.byte("COUNT", 10 * p + k)


def set_count(p, k, v):
    m.mem[m.addr("COUNT") + 10 * p + k] = v


def chars(col, row):
    return m.mem[m.addr("MAPSCR") + row * 80 + col * 2]


def coast(p):
    """A sea square with a land square of player p's island to its east,
    and a sea square two to the west of that (out of the land's reach)."""
    for row in range(3, 8):
        for col in range(1, 19):
            k = m.byte("ISLKIND", row * 20 + col)
            e = m.byte("ISLKIND", row * 20 + col + 1)
            if (k & K_KIND != K_LAND and e & K_KIND == K_LAND
                    and (e & K_P1) == (K_P1 if p else 0)
                    and all(m.byte("ISLKIND", r * 20 + c) & K_KIND != K_LAND
                            for r in (row - 1, row, row + 1) for c in (col - 1, col))):
                return col, row
    raise RuntimeError("no coast")


for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "GAME_NEW"):
    m.call(r)
m.call("ECO_INIT")

# spawning: a pirate in slot 2, not a school; the second takes slot 3
clear()
m.call("FISH_INIT")
tic(rnd=0)
if not m.byte("FACT", P) or m.byte("FACT", P + 1) or m.byte("FACT") or m.byte("FACT", 1):
    fail("spawn: FACT %r" % [m.byte("FACT", i) for i in range(4)])
if m.byte("FYH", P) not in range(8, 16) or m.byte("FXH", P) > 2:
    fail("pirate starts at %d, %d" % (m.byte("FXH", P), m.byte("FYH", P)))
tic(rnd=0)
if not m.byte("FACT", P + 1):
    fail("no second pirate")

# moving: the original's speed, 51/256 pixel per unit and tic
clear()
put(0, 40, 12, vx=4)
tic(10)
x = m.byte("FXH", P) + m.byte("FXL", P) / 256
if abs(x - (40 + 4 * 51 * 10 / 256)) > 0.01:
    fail("drift to %.2f" % x)
put(0, 2, 12, vx=-15)
tic(2)
if m.byte("FACT", P):
    fail("pirate off the left edge still out")
# land stops it
col, row = coast(0)
fx, fy = at(col, row)
put(0, fx - 1, fy, vx=15)
tic(3)
if m.byte("FVX", P) or m.byte("FXH", P) != fx - 1:
    fail("pirate ran into land: FXH %d FVX %d" % (m.byte("FXH", P), m.byte("FVX", P)))

# a parked fishing boat under it, no fort near: sunk after 20 tics
sea = chars(10, 1)
m.call("MAP_SET", a=I_FSBT, x=10, y=1)
set_count(0, I_FSBT, 2)
clear()
put(0, *at(10, 1))
tic(19)
if item(10, 1) != I_FSBT or m.byte("PTCH") != 19:
    fail("19 tics: item %d count %d" % (item(10, 1), m.byte("PTCH")))
tic(1)
if item(10, 1) or count(0, I_FSBT) != 1 or m.byte("PTCH"):
    fail("20th tic: item %d boats %d count %d" % (item(10, 1), count(0, I_FSBT), m.byte("PTCH")))
wreck = T_WRECK
if m.byte("BNDVAR", 1):                  # a corner row: its own wreck (D55)
    wreck = m.byte("BNDVAR", 1) + T_WRECK - m.addr("T_PTBOAT")
if chars(10, 1) != m.byte("TILECH", wreck) or not m.byte("SNKT"):
    fail("no wreck after a pirate sank a boat")
if not m.byte("FACT", P):
    fail("the pirate went down with the boat")
# while a wreck shows nothing counts
m.call("MAP_SET", a=I_FSBT | I_P1, x=11, y=1)
put(0, *at(11, 1))
tic(5)
if m.byte("PTCH", 1):
    fail("attacks counted while a wreck shows: %d" % m.byte("PTCH", 1))
m.poke("SNKT", 0)
tic(5)
if m.byte("PTCH", 1) != 5:
    fail("player 2's boat: count %d" % m.byte("PTCH", 1))
m.call("MAP_SET", a=0, x=11, y=1)

# fort protection: the owner's fort next to the boat, not the other's
for p in (0, 1):
    col, row = coast(p)
    m.call("MAP_SET", a=I_FORT, x=col + 1, y=row)
    for owner in (0, 1):
        m.call("MAP_SET", a=I_FSBT | (I_P1 if owner else 0), x=col, y=row)
        clear()
        put(0, *at(col, row))
        tic(25)
        safe = owner == p
        if (item(col, row) != 0) != safe:
            fail("player %d's fort, player %d's boat: item %d after 25 tics"
                 % (p + 1, owner + 1, item(col, row)))
    m.call("MAP_SET", a=0, x=col, y=row)
    m.call("MAP_SET", a=0, x=col + 1, y=row)

# a steered fishing boat touching it sinks, unless any fort is near
clear()
set_count(1, I_FSBT, 1)
put(0, 80 + 8 + 8, 12)                   # 8 pixels clear of the boat
steer(1, I_FSBT, 80, 4)
m.poke("SPRSHP", 3, 1)
tic(1)
if m.byte("BOATK", 1) != I_FSBT:
    fail("boat 1 pixel clear of a pirate sank")
put(0, 80 + 8 + 7, 12)
tic(1)
if m.byte("BOATK", 1) or count(1, I_FSBT) or m.byte("SPRSHP", 1) != SH_CUR:
    fail("steered fishing boat: BOATK %d boats %d shape %d"
         % (m.byte("BOATK", 1), count(1, I_FSBT), m.byte("SPRSHP", 1)))
col, row = coast(0)                      # player 1's fort guards player 2
m.call("MAP_SET", a=I_FORT, x=col + 1, y=row)
clear()
set_count(1, I_FSBT, 1)
steer(1, I_FSBT, col * 8, row * 8)
put(0, *at(col, row))
tic(3)
if m.byte("BOATK", 1) != I_FSBT:
    fail("a fort did not guard a steered fishing boat")
m.call("MAP_SET", a=0, x=col + 1, y=row)

# a steered PT boat stops a pirate dead, and does not sink it
clear()
steer(0, I_PTBT, 80, 4)
put(0, 80 + 8 + 4, 12, vx=5, vy=2)
tic(1)
if m.byte("FVX", P) or m.byte("FVY", P) or not m.byte("FACT", P):
    fail("PT boat: pirate speed %d, %d, out %d"
         % (m.byte("FVX", P), m.byte("FVY", P), m.byte("FACT", P)))

# a steered PT boat attacks the other player's parked fishing boat
m.call("MAP_SET", a=I_FSBT | I_P1, x=10, y=1)
set_count(1, I_FSBT, 1)
clear()
steer(0, I_PTBT, 80, 8)
tic(19)
if item(10, 1) != I_FSBT | I_P1 or m.byte("PTCH", 1) != 19:
    fail("PT boat, 19 tics: item %02x count %d" % (item(10, 1), m.byte("PTCH", 1)))
tic(1)
if item(10, 1) or count(1, I_FSBT):
    fail("PT boat, 20 tics: item %02x boats %d" % (item(10, 1), count(1, I_FSBT)))
m.call("MAP_SET", a=I_FSBT, x=10, y=1)    # its own: left alone
clear()
steer(0, I_PTBT, 80, 8)
tic(25)
if item(10, 1) != I_FSBT or m.byte("PTCH"):
    fail("PT boat attacked its own fishing boat")
m.call("MAP_SET", a=0, x=10, y=1)

# a steered fishing boat touching the other's steered PT boat sinks,
# unless a fort of its own is near
for fort in (None, 0, 1):
    col, row = coast(0)
    if fort is not None:
        col, row = coast(fort)
        m.call("MAP_SET", a=I_FORT, x=col + 1, y=row)
    clear()
    set_count(0, I_FSBT, 1)
    steer(0, I_FSBT, col * 8, row * 8)
    steer(1, I_PTBT, col * 8 + 7, row * 8 - 7)
    tic(1)
    sunk = m.byte("BOATK") == 0
    if sunk != (fort != 0):
        fail("fishing boat vs PT boat, fort of %r: sunk %r" % (fort, sunk))
    if fort is not None:
        m.call("MAP_SET", a=0, x=col + 1, y=row)
clear()
steer(0, I_FSBT, 80, 40)
steer(1, I_PTBT, 88, 40)                 # 1 pixel clear
tic(1)
if not m.byte("BOATK"):
    fail("fishing boat sank 1 pixel clear of a PT boat")

# a hurricane sinks a pirate it touches
clear()
put(0, 80, 40)
m.poke("RANDOM", NEVER)
for wx, gone in ((80 - 16, False), (80 - 15, True)):
    for name, v in (("WACT", WT_HURR), ("WXH", wx), ("WYH", 40), ("WVX", 0), ("WVY", 0)):
        m.poke(name, v)
    m.call("WTH_TIC")
    if (m.byte("FACT", P) == 0) != gone:
        fail("hurricane at %d: pirate out %d" % (wx, m.byte("FACT", P)))

# PIR_SHOW: the shape in missile memory, HMROW per row; sharing rows
clear()
put(0, 40, 40)                           # lines 32-39: row 4
put(1, 120, 76)                          # lines 68-75: rows 8-9
m.call("PIR_SHOW")
hm = [m.byte("HMROW", r) for r in range(11)]
want = [0] * 4 + [40 + HP_MAP - 8] + [0] * 3 + [120 + HP_MAP - 8] * 2 + [0]
if hm != want:
    fail("HMROW %r, want %r" % (hm, want))
msl = m.addr("PMAREA") + 0x180
shape = [m.byte("PIRSHP", k) for k in range(8)]
for fy in (40, 76):
    line = fy - 8 + PM_MAP
    if list(m.mem[msl + line:msl + line + 8]) != shape or m.mem[msl + line - 1]:
        fail("pirate not drawn at missile line %d" % line)
put(1, 120, 44)
shown = []
for f in range(2):
    m.poke("FRAME", f)
    m.call("PIR_SHOW")
    shown.append(tuple(m.byte("FDRAWN", P + i) != 0xFF for i in (0, 1)))
if sorted(shown) != [(False, True), (True, False)]:
    fail("pirates sharing rows: shown %r" % shown)
m.poke("FACT", 0, 0, 0, 0)
m.call("PIR_SHOW")
if any(m.mem[msl:msl + 128]):
    fail("missile memory not cleared when the pirates are gone")

# the DLIs place M3-M0 side by side; the help screen hides them
m.poke("HMROW", 0, 77)
m.poke("DLIROW", 2)                  # character row 2 starts square row 1
m.interrupt("DLI_SQ")
pos = [m.byte("HPOSM3"), m.byte("HPOSM2"), m.byte("HPOSM1"), m.byte("HPOSM0")]
if pos != [77, 79, 81, 83]:
    fail("DLI_ROW missile positions %r" % pos)
m.poke("HMROW", 0, 0)
m.poke("DLIROW", 3)                  # mid-square: only the font changes
m.interrupt("DLI_ROW")
if m.byte("HPOSM3") != 77 or m.byte("DLIROW") != 4:
    fail("DLI_ROW mid-square moved the missiles: %d" % m.byte("HPOSM3"))
m.poke("HELPON", 1)
m.interrupt("DLI_MAP")
if m.byte("HPOSM3") or m.byte("HPOSM0") > 6:
    fail("missiles on screen behind the help screen")
m.poke("HELPON", 0)

# in the game: pirates come during a round; GAME_START clears them
clear()
m.poke("PAL", 0x0F)
m.poke("RANDOM", 0)
for _ in range(10):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.call("GAME_FRAME")
if not m.byte("FACT", P):
    fail("no pirates during a round")
m.poke("PTCH", 7, 8)
m.call("GAME_START")
if m.byte("FACT", P) or m.byte("FACT", P + 1) or m.byte("PTCH") or m.byte("PTCH", 1):
    fail("GAME_START left pirates or attack counts")
if m.byte("GPRIOR") != 0x11:
    fail("PRIOR %02x, want $11 (fifth player)" % m.byte("GPRIOR"))

print("pirates: %d failed" % fails)
sys.exit(1 if fails else 0)
