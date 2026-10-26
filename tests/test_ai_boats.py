#!/usr/bin/env python3
"""T-AI-2: the CPU's fishing boat (py65).

RANDOM is fed from a seeded generator.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

I_FSBT, I_P1 = 9, 0x80
J_UP, J_DOWN, J_LEFT, J_RIGHT = 1, 2, 4, 8
AS_GOB, AS_FISH, AS_PARK = 2, 3, 4
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def machine(seed, level):
    m = Machine()
    rng = random.Random(seed)
    m.on_read("RANDOM", lambda: rng.randrange(256))
    m.poke("PAL", 0x0F)
    for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT"):
        m.call(r)
    m.poke("SU_VAL", 10, 30, 1, level)
    m.call("SU_GO")
    return m


def frame(m):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF)
    m.poke("TRIG0", 1)
    m.poke("TRIG1", 1)
    m.poke("CONSOL", 7)
    m.poke("SKSTAT", 0xFF)
    m.call("GAME_FRAME", limit=3000000)


def school(m, slot, x, y):
    """Slot out and still, its top left corner at map pixel x, y."""
    for name, v in (("FACT", 1), ("FXL", 0), ("FXH", x + 8), ("FYL", 0),
                    ("FYH", y + 8), ("FVX", 0), ("FVY", 0)):
        m.mem[m.addr(name) + slot] = v


def boat_at(m, x, y):
    m.poke("CURX", 0, x)
    m.poke("CURY", 0, y)


def quiet(m):
    for s in (2, 3):
        m.mem[m.addr("FACT") + s] = 0
    m.poke("GOLD", 0, 0, 0, 0)


def gold(m, p):
    return m.byte("GOLD", 2 * p) | m.byte("GOLD", 2 * p + 1) << 8


def boats(m):
    return [(c, r) for r in range(11) for c in range(20)
            if m.byte("MAPITEM", r * 20 + c) == I_FSBT + I_P1]


# the nearest school, held to the map; none: C set
m = machine(1, 2)
for s in range(4):
    m.mem[m.addr("FACT") + s] = 0
if not m.call("AI_SCHOOL")[3]:
    fail("AI_SCHOOL found a school with none out")
boat_at(m, 100, 40)
school(m, 0, 20, 10)
school(m, 1, 120, 50)
if m.call("AI_SCHOOL")[3] or (m.byte("AI_TX"), m.byte("AI_TY")) != (120, 50):
    fail("nearest school: %r" % ((m.byte("AI_TX"), m.byte("AI_TY")),))
school(m, 1, 158, 86)                    # partly off the map
boat_at(m, 150, 70)
m.call("AI_SCHOOL")
if (m.byte("AI_TX"), m.byte("AI_TY")) != (152, 80):
    fail("school off the map: target %r" % ((m.byte("AI_TX"), m.byte("AI_TY")),))

# the stick towards a pixel
for (bx, by), (tx, ty), want in (((50, 50), (60, 40), J_RIGHT | J_UP),
                                 ((50, 50), (40, 60), J_LEFT | J_DOWN),
                                 ((50, 50), (50, 60), J_DOWN),
                                 ((50, 50), (50, 50), 0)):
    boat_at(m, bx, by)
    m.poke("AI_TX", tx)
    m.poke("AI_TY", ty)
    m.poke("JOY1", 0)
    m.call("AI_STEER")
    if m.byte("JOY1") != want:
        fail("steer %r to %r: stick %d, want %d" % ((bx, by), (tx, ty), m.byte("JOY1"), want))

# a pirate within 20 pixels on both axes: away from it
for (px, py), want in (((60, 55), J_LEFT | J_UP), ((40, 45), J_RIGHT | J_DOWN),
                       ((69, 69), J_LEFT | J_UP), ((70, 50), None), ((50, 30), None)):
    for s in range(4):
        m.mem[m.addr("FACT") + s] = 0
    school(m, 3, px, py)
    boat_at(m, 50, 50)
    m.poke("JOY1", 0)
    c = m.call("AI_FLEE")[3]
    if want is None:
        if c:
            fail("fled a pirate at %r" % ((px, py),))
    elif not c or m.byte("JOY1") != want:
        fail("pirate at %r: C %r stick %d, want %d" % ((px, py), c, m.byte("JOY1"), want))


def with_boat(seed, level):
    """A game where the CPU has a parked fishing boat and 0 gold."""
    m = machine(seed, level)
    m.poke("GOLD", 0, 0, 100, 0)
    m.call("ECO_BUY", a=I_FSBT, x=1)
    m.poke("GOLD", 0, 0, 0, 0)
    for s in range(4):
        m.mem[m.addr("FACT") + s] = 0
    return m


# saving up with a school out: it walks to the boat, lifts it and fishes
m = with_boat(2, 2)
home = boats(m)
if len(home) != 1:
    fail("bought boat parked at %r" % home)
school(m, 0, 60, 8)
seen, touches, pf = set(), 0, m.byte("FCNT", 1)
for n in range(1500):
    school(m, 0, 60, 8)                  # keep it still and out,
    quiet(m)                             # no pirates, no gold to spend
    frame(m)
    seen.add(m.byte("AIST"))
    f = m.byte("FCNT", 1)
    touches += (f - pf) % 50
    pf = f
if not {AS_GOB, AS_FISH} <= seen:
    fail("never went fishing: states %r" % sorted(seen))
if touches < 350:                     # 1 a tic, 20 tics a second
    fail("only %d touches in 25 s next to a still school" % touches)
x, y = m.byte("CURX", 1), m.byte("CURY", 1)
if abs(x - 60) > 8 or abs(y - 8) > 8:
    fail("boat at %d, %d, school at 60, 8" % (x, y))

# it can pay for the next item: park and go back to the cursor
m.poke("GOLD", 0, 0, 200, 0)
for n in range(600):
    school(m, 0, 60, 8)
    frame(m)
    if m.byte("AIST") not in (AS_FISH, AS_PARK):
        break
if m.byte("BOATK", 1) or len(boats(m)) != 1:
    fail("boat not parked: BOATK %d, parked %r" % (m.byte("BOATK", 1), boats(m)))

# no school: it parks
m = with_boat(3, 3)
school(m, 0, 60, 8)
for n in range(600):
    frame(m)
    if m.byte("AIST") == AS_FISH:
        break
for s in range(4):
    m.mem[m.addr("FACT") + s] = 0
for n in range(900):
    for s in range(2):
        m.mem[m.addr("FACT") + s] = 0
    frame(m)
    if not m.byte("AIST"):
        break
if m.byte("AIST") or m.byte("BOATK", 1) or len(boats(m)) != 1:
    fail("no school: AIST %d BOATK %d parked %r" % (m.byte("AIST"), m.byte("BOATK", 1), boats(m)))

# a pirate within 48 pixels: home round the island to the harbour,
# and park there
m = with_boat(5, 2)
home = boats(m)[0]
m.poke("CURCOL", 0, home[0])
m.poke("CURROW", 0, home[1])
boat_at(m, home[0] * 8, home[1] * 8)
m.call("BOAT_KEY", x=1)
if m.byte("BOATK", 1) != I_FSBT:
    fail("could not lift the boat at %r" % (home,))
boat_at(m, 96, 32)                       # in the bay between the islands
m.poke("CURCOL", 0, 12)
m.poke("CURROW", 0, 4)
m.poke("AIST", AS_PARK)
for n in range(1500):
    m.poke("GOLD", 0, 0, 0, 0)
    for s in range(4):
        m.mem[m.addr("FACT") + s] = 0
    x, y = m.byte("CURX", 1), m.byte("CURY", 1)
    school(m, 2, x + 30, y + 30)         # a pirate near, not too near
    frame(m)
    if not m.byte("AIST"):
        break
if m.byte("AIST") or boats(m) != [home]:
    fail("pirate out: AIST %d, boat at %r, harbour %r" % (m.byte("AIST"), boats(m), home))

# a hurricane (16 x 32) about to touch the boat: away from it
WT_HURR = 3
m.mem[m.addr("FACT") + 3] = 0
for (hx, hy), want in (((60, 40), J_LEFT | J_UP), ((30, 30), J_RIGHT | J_DOWN), ((90, 40), None)):
    boat_at(m, 50, 50)
    m.poke("WACT", WT_HURR, 0)
    m.poke("WXH", hx + 8)
    m.poke("WYH", hy + 8)
    m.poke("JOY1", 0)
    c = m.call("AI_FLEE")[3]
    if want is None:
        if c:
            fail("fled a hurricane at %r" % ((hx, hy),))
    elif not c or m.byte("JOY1") != want:
        fail("hurricane at %r: C %r stick %d, want %d" % ((hx, hy), c, m.byte("JOY1"), want))
m.poke("WACT", 0, 0)

# a pirate at its parked boat: it doesn't lift it
m = with_boat(8, 2)
home = boats(m)[0]
school(m, 0, 60, 8)
for n in range(600):
    school(m, 0, 60, 8)
    school(m, 2, home[0] * 8 + 10, home[1] * 8)
    m.poke("GOLD", 0, 0, 0, 0)
    frame(m)
    if m.byte("BOATK", 1):
        fail("lifted its boat next to a pirate")
        break

# a school on the other side of the islands: round them to it
for start, sch in (((112, 8), (112, 72)), ((96, 32), (20, 0)), ((40, 80), (130, 4))):
    m = with_boat(7, 2)
    m.poke("BOATK", 0, I_FSBT)
    m.poke("AIST", AS_FISH)
    m.poke("AITMR", 255)
    boat_at(m, *start)
    m.poke("CURCOL", 0, (start[0] + 4) // 8)
    m.poke("CURROW", 0, (start[1] + 4) // 8)
    for n in range(2400):
        quiet(m)
        m.mem[m.addr("FACT") + 1] = 0
        school(m, 0, *sch)
        m.poke("AITMR", 255)             # no decisions: keep fishing
        frame(m)
        x, y = m.byte("CURX", 1), m.byte("CURY", 1)
        if abs(x - sch[0]) < 8 and abs(y - sch[1]) < 8:
            break
    else:
        fail("from %r never reached the school at %r: at %d, %d" % (start, sch, x, y))

# fleeing keeps one way for a while, not back and forth
m = with_boat(6, 2)
m.poke("BOATK", 0, I_FSBT)
m.poke("AIST", AS_FISH)
boat_at(m, 40, 72)
m.poke("CURCOL", 0, 5)
m.poke("CURROW", 0, 9)
ways = []
for n in range(40):
    quiet(m)
    school(m, 0, 80, 72)                 # the school beyond the pirate
    if n < 5:
        school(m, 3, 52, 72)             # a pirate between, then gone
    frame(m)
    ways.append(m.byte("JOY1"))
if ways[:30] != [ways[0]] * 30 or not ways[0] & J_LEFT:
    fail("flee: stick %r" % ways)

# level 1 never fishes
m = with_boat(4, 1)
for n in range(1500):
    school(m, 0, 60, 8)
    frame(m)
    if m.byte("AIST") >= AS_GOB and m.byte("AIST") != 1:
        fail("level 1 went for its boat")
        break

print("ai boats: %d failed" % fails)
sys.exit(1 if fails else 0)
