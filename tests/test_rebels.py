#!/usr/bin/env python3
"""T-ECO-5: rebels (py65).

RANDOM is fed from a seeded generator, so placement rolls like the real
POKEY.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

I_FORT, I_FACT, I_HOUS, I_REBL = 1, 2, 6, 7
K_LAND, K_KIND, K_P1 = 1, 0x7F, 0x80
R_GOLD = 4
m = Machine()
rng = random.Random(5)
m.on_read("RANDOM", lambda: rng.randrange(256))
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def item(sq):
    col, row = sq
    return m.byte("MAPITEM", row * 20 + col)


def put(sq, it):
    m.call("MAP_SET", a=it, x=sq[0], y=sq[1])


def count(p, k):
    return m.byte("COUNT", 10 * p + k)


def set_count(p, k, v):
    m.mem[m.addr("COUNT") + 10 * p + k] = v


def gold(p):
    return m.byte("GOLD", 2 * p) | m.byte("GOLD", 2 * p + 1) << 8


def rebels(p):
    return [sq for sq in land[p] if item(sq) == I_REBL]


def near(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1])) <= 1


for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "GAME_NEW"):
    m.call(r)

land = {0: [], 1: []}                    # row by row, as RB_LAND lists them
for row in range(11):
    for col in range(20):
        k = m.byte("ISLKIND", row * 20 + col)
        if k & K_KIND == K_LAND:
            land[1 if k & K_P1 else 0].append((col, row))
for p in (0, 1):
    m.call("RB_LAND", x=p)
    got = [(m.byte("RBCOL", i), m.byte("RBROW", i)) for i in range(m.byte("RB_N"))]
    if got != land[p]:
        fail("RB_LAND player %d: %r" % (p, got))
    if len(land[p]) > 64:
        fail("RBCOL / RBROW too small for %d squares" % len(land[p]))

# the change in score, checked in the original's order
CASES = [  # previous, this round, +1 add / -1 remove / 0 nothing
    (50, 40, 1), (50, 41, 0), (40, 50, -1), (41, 50, 0),
    (25, 29, 1), (25, 30, 0), (20, 29, 1), (15, 29, -1),
    (75, 70, -1), (80, 70, 1), (60, 69, 0), (0, 69, -1), (0, 5, 1), (100, 100, -1)]
for p in (0, 1):
    for prev, cur, want in CASES:
        m.call("MAP_INIT")
        put(land[p][3], I_REBL)
        m.mem[m.addr("PRSCORE") + p] = prev
        m.mem[m.addr("RSCORE") + p] = cur
        m.call("REB_TURN", x=p)
        n = len(rebels(p)) - 1
        if n != want:
            fail("player %d, score %d -> %d: rebels %+d, want %+d" % (p + 1, prev, cur, n, want))
        if rebels(1 - p):
            fail("player %d's turn put a rebel on the other island" % (p + 1))

# placement: never on a rebel, a fort or next to a fort; what is there
# is destroyed and counted off
for p in (0, 1):
    m.call("MAP_INIT")
    fort = land[p][len(land[p]) // 2]
    for sq in land[p]:
        put(sq, I_FORT if sq == fort else I_HOUS)
    set_count(p, I_HOUS, len(land[p]) - 1)
    free = [sq for sq in land[p] if not near(sq, fort)]
    for i in range(len(free)):
        if m.call("REB_ADD", x=p)[3]:
            fail("player %d: rebel %d not placed with free squares left" % (p + 1, i + 1))
    if sorted(rebels(p)) != sorted(free):
        fail("player %d: rebels on %r, want %r" % (p + 1, rebels(p), free))
    if item(fort) != I_FORT or any(item(sq) != I_HOUS for sq in land[p]
                                   if near(sq, fort) and sq != fort):
        fail("player %d: a fort or its neighbours were hit" % (p + 1))
    if count(p, I_HOUS) != len(land[p]) - 1 - len(free):
        fail("player %d: houses counted %d" % (p + 1, count(p, I_HOUS)))
    # nowhere left: C set, nothing changes
    before = [item(sq) for sq in land[p]]
    if not m.call("REB_ADD", x=p)[3] or [item(sq) for sq in land[p]] != before:
        fail("player %d: REB_ADD with no square left" % (p + 1))

# the rebel that goes is the first, row by row
m.call("MAP_INIT")
for i in (5, 9, 20):
    put(land[1][i], I_REBL)
m.call("REB_DEL", x=1)
if rebels(1) != [land[1][9], land[1][20]]:
    fail("REB_DEL left %r" % rebels(1))
m.call("MAP_INIT")
m.call("REB_DEL", x=0)                  # none: nothing happens

# buying one (key 7): 30 gold, cursor anywhere, onto the other island
m.call("MAP_INIT")
m.poke("GOLD", 100, 0)
m.poke("CURCOL", 9, 9)
m.poke("CURROW", 0, 0)
r = m.call("ECO_BUY", a=I_REBL, x=0)
if r[3] or gold(0) != 70 or len(rebels(1)) != 1 or rebels(0) or count(0, I_REBL) or count(1, I_REBL):
    fail("bought rebel: C %r gold %d rebels %r / %r" % (r[3], gold(0), rebels(0), rebels(1)))
m.poke("GOLD", 0, 0, 29, 0)
r = m.call("ECO_BUY", a=I_REBL, x=1)
if not r[3] or r[0] != R_GOLD or rebels(0) or gold(1) != 29:
    fail("rebel bought with 29 gold: %r" % (r,))
for sq in land[0]:                       # nowhere to go: gold spent anyway
    put(sq, I_FORT)
m.poke("GOLD", 30, 0, 30, 0)
r = m.call("ECO_BUY", a=I_REBL, x=1)
if r[3] or gold(1) != 0 or rebels(0):
    fail("rebel with no square: C %r gold %d" % (r[3], gold(1)))

# the end of a round: empty islands score low, each gets a rebel
m.call("GAME_NEW")
m.call("MAP_INIT")
m.call("ROUND_END")
if len(rebels(0)) != 1 or len(rebels(1)) != 1:
    fail("ROUND_END: rebels %r / %r (scores %d, %d)"
         % (rebels(0), rebels(1), m.byte("RSCORE"), m.byte("RSCORE", 1)))

print("rebels: %d failed" % fails)
sys.exit(1 if fails else 0)
