#!/usr/bin/env python3
"""D56: the choice of map (py65).

MAP_LOAD puts each map's data block over the live tables and works out
the CPU's steps by sea; they must match what tools/mkfont.py works out
for map 1 (in ISLANDS.ASM), and follow the same rules on every map.
SU_GO turns the MAP line into MAPNO, RANDOM into any of the maps.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

K_LAND, K_HARB, K_KIND, K_P1 = 1, 3, 0x7F, 0x80
ROWS, COLS = 11, 20
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def table(m, name):
    return [m.byte(name, i) for i in range(ROWS * COLS)]


def steps(kinds, goal):
    """Breadth first, as sea_steps in tools/mkfont.py."""
    s = [255] * (ROWS * COLS)
    todo = [i for i in range(ROWS * COLS) if goal(i) and kinds[i] & K_KIND != K_LAND]
    for i in todo:
        s[i] = 0
    for i in todo:
        r, c = divmod(i, COLS)
        for nr, nc in ((r, c - 1), (r, c + 1), (r - 1, c), (r + 1, c)):
            n = nr * COLS + nc
            if 0 <= nr < ROWS and 0 <= nc < COLS and s[n] == 255 and kinds[n] & K_KIND != K_LAND:
                s[n] = s[i] + 1
                todo.append(n)
    return s


m = Machine()
rng = random.Random(1)
m.on_read("RANDOM", lambda: rng.randrange(256))
m.poke("PAL", 0x0F)
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT"):
    m.call(r)
n_maps = m.addr("N_MAPS")
blk = m.addr("MAPBLK")
first = {t: table(m, t) for t in ("AI_HD", "AI_UP", "AI_DN")}
live0 = [m.byte("TILECH", i) for i in range(blk)]

for mp in list(range(1, n_maps)) + [0]:
    m.call("MAP_LOAD", a=mp, limit=3000000)
    src = (m.byte("MAPSH", mp) << 8) | m.byte("MAPSL", mp)
    if [m.byte("TILECH", i) for i in range(blk)] != [m.mem[src + i] for i in range(blk)]:
        fail("map %d: live tables differ from its block" % (mp + 1))
    kinds = table(m, "ISLKIND")
    for name, goal in (("AI_HD", lambda i: kinds[i] == K_HARB | K_P1),
                       ("AI_UP", lambda i: i < 2 * COLS),
                       ("AI_DN", lambda i: i >= (ROWS - 2) * COLS)):
        got, want = table(m, name), steps(kinds, goal)
        if got != want:
            bad = [i for i in range(ROWS * COLS) if got[i] != want[i]]
            fail("map %d %s: %d squares wrong, first %d: %d want %d"
                 % (mp + 1, name, len(bad), bad[0], got[bad[0]], want[bad[0]]))
    # both islands the same size, one harbour each, rows 0-1 and 9-10 sea
    for p1 in (0, K_P1):
        land = sum(1 for k in kinds if k == K_LAND | p1)
        harb = sum(1 for k in kinds if k == K_HARB | p1)
        if land != 35 or harb != 1:
            fail("map %d player %d: %d land squares, %d harbours" % (mp + 1, p1 >> 7, land, harb))
    if any(k & K_KIND == K_LAND for i, k in enumerate(kinds) if i < 40 or i >= 180):
        fail("map %d: land in the fish and pirate rows" % (mp + 1))
    fp = [m.byte("FONTPG", i) for i in range(m.addr("N_FONTS"))]
    if any(m.byte("ROWFONT", r) not in fp for r in range(22)):
        fail("map %d: ROWFONT uses a font not in FONTPG" % (mp + 1))

# back on map 1: the same as the program started with
if first != {t: table(m, t) for t in first}:
    fail("map 1's AI_ tables worked out differently from ISLANDS.ASM's")
if [m.byte("TILECH", i) for i in range(blk)] != live0:
    fail("map 1's block differs from the live tables at start-up")
m.call("MAP_LOAD", a=0)                 # already live: nothing to do

# SU_GO: MAP line 1 to N_MAPS is that map; N_MAPS + 1 any of them
fmap = m.addr("SU_VAL") + m.addr("SU_FMAP")
for v in range(1, n_maps + 1):
    m.poke("SU_VAL", 10, 30, 2, 2)
    m.poke(fmap, v)
    m.call("SU_GO", limit=3000000)
    if m.byte("MAPNO") != v - 1 or m.byte("MAPLD") != v - 1:
        fail("map line %d: MAPNO %d, loaded %d" % (v, m.byte("MAPNO"), m.byte("MAPLD")))
seen = set()
for _ in range(30):
    m.poke("SU_VAL", 10, 30, 2, 2)
    m.poke(fmap, n_maps + 1)
    m.call("SU_GO", limit=3000000)
    seen.add(m.byte("MAPNO"))
    if m.byte("SU_VAL", m.addr("SU_FMAP")) != n_maps + 1:
        fail("RANDOM was not kept for the next game")
if seen != set(range(n_maps)):
    fail("RANDOM over 30 games picked %r" % sorted(seen))

# the demo always plays map 1 (its script is made for it)
m.poke(fmap, 2)
m.call("DEMO_GO", limit=3000000)
if m.byte("MAPNO") != 0 or m.byte("MAPLD") != 0:
    fail("demo: MAPNO %d, loaded %d" % (m.byte("MAPNO"), m.byte("MAPLD")))
m.call("DEMO_END")
if m.byte("SU_VAL", m.addr("SU_FMAP")) != 2:
    fail("demo did not put the MAP line back")

print("maps: %d failed" % fails)
sys.exit(1 if fails else 0)
