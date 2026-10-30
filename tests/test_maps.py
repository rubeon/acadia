#!/usr/bin/env python3
"""D56: the choice of map (py65).

MAP_LOAD puts each map's data block over the live tables and works out
the CPU's steps by sea; they must match a breadth-first search in
Python, as tools/mkfont.py's are for map 1.  RANDOM is drawn afresh
for every game: two islands of RM_N squares, each in one piece on its
own side, no sea shut in, a harbour on each outer coast, and each land
square showing the coast piece for its land neighbours.  SU_GO turns
the MAP line into MAPNO.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

K_SEA, K_LAND, K_HARB, K_KIND, K_P1 = 0, 1, 3, 0x7F, 0x80
ROWS, COLS = 11, 20
STANDARD, CLASSIC, RANDOM = range(3)
LONG = 5000000
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def table(m, name):
    return [m.byte(name, i) for i in range(ROWS * COLS)]


def nbrs(i):
    r, c = divmod(i, COLS)
    for nr, nc in ((r, c - 1), (r, c + 1), (r - 1, c), (r + 1, c)):
        if 0 <= nr < ROWS and 0 <= nc < COLS:
            yield nr * COLS + nc


def steps(kinds, goal):
    """Breadth first, as sea_steps in tools/mkfont.py."""
    s = [255] * (ROWS * COLS)
    todo = [i for i in range(ROWS * COLS) if goal(i) and kinds[i] & K_KIND != K_LAND]
    for i in todo:
        s[i] = 0
    for i in todo:
        for n in nbrs(i):
            if s[n] == 255 and kinds[n] & K_KIND != K_LAND:
                s[n] = s[i] + 1
                todo.append(n)
    return s


def check_map(m, mp, what):
    kinds = table(m, "ISLKIND")
    for name, goal in (("AI_HD", lambda i: kinds[i] == K_HARB | K_P1),
                       ("AI_UP", lambda i: i < 2 * COLS),
                       ("AI_DN", lambda i: i >= (ROWS - 2) * COLS)):
        got, want = table(m, name), steps(kinds, goal)
        if got != want:
            bad = [i for i in range(ROWS * COLS) if got[i] != want[i]]
            fail("%s %s: %d squares wrong, first %d: %d want %d"
                 % (what, name, len(bad), bad[0], got[bad[0]], want[bad[0]]))
    size = {STANDARD: 35, CLASSIC: 29, RANDOM: m.addr("RM_N")}[mp]
    for p1 in (0, K_P1):
        land = [i for i, k in enumerate(kinds) if k == K_LAND | p1]
        harb = [i for i, k in enumerate(kinds) if k == K_HARB | p1]
        if len(land) != size or len(harb) != 1:
            fail("%s player %d: %d land squares, %d harbours" % (what, p1 >> 7, len(land), len(harb)))
            continue
        if not any(n in land for n in nbrs(harb[0])):
            fail("%s player %d: harbour with no land beside it" % (what, p1 >> 7))
    if any(k & K_KIND == K_LAND for i, k in enumerate(kinds) if i < 40 or i >= 180):
        fail("%s: land in the fish and pirate rows" % what)
    up = table(m, "AI_UP")
    if any(k & K_KIND != K_LAND and up[i] == 255 for i, k in enumerate(kinds)):
        fail("%s: sea shut in by land" % what)
    fp = [m.byte("FONTPG", i) for i in range(m.addr("N_FONTS"))]
    if any(m.byte("ROWFONT", r) not in fp for r in range(22)):
        fail("%s: ROWFONT uses a font not in FONTPG" % what)
    return kinds


def check_random(m, what):
    kinds = check_map(m, RANDOM, what)
    tiles = table(m, "ISLTILE")
    for p1, cols in ((0, range(1, 9)), (K_P1, range(11, 19))):
        land = {i for i, k in enumerate(kinds) if k == K_LAND | p1}
        if any(i % COLS not in cols or not 2 <= i // COLS <= 8 for i in land):
            fail("%s player %d: land outside rows 2-8, columns %d-%d"
                 % (what, p1 >> 7, cols[0], cols[-1]))
        seen, todo = set(), [min(land)]
        while todo:
            i = todo.pop()
            if i in land and i not in seen:
                seen.add(i)
                todo += list(nbrs(i))
        if seen != land:
            fail("%s player %d: island in %d pieces or more" % (what, p1 >> 7, 2))
        h = [i for i, k in enumerate(kinds) if k == K_HARB | p1][0]
        r, c = divmod(h, COLS)
        row = [x % COLS for x in land if x // COLS == r]
        if (p1 == 0 and c != min(row) - 1) or (p1 and c != max(row) + 1):
            fail("%s player %d: harbour %d, %d not on the outer coast" % (what, p1 >> 7, r, c))
        want = m.addr("T_PIER_W") if p1 else m.addr("T_PIER_E")
        if tiles[h] != want:
            fail("%s player %d: harbour tile %d" % (what, p1 >> 7, tiles[h]))
        for i in land:
            mask = sum(b for b, d in ((1, -COLS), (2, 1), (4, COLS), (8, -1))
                       if kinds[i + d] & K_KIND == K_LAND)
            r, c = divmod(i, COLS)
            t = m.byte("GRSTL", (r & 3) * 4 + (c & 3)) if mask == 15 else m.byte("RNDTILE", mask)
            if tiles[i] != t:
                fail("%s: square %d, %d tile %d, want %d" % (what, r, c, tiles[i], t))
                break
    return kinds


m = Machine()
rng = random.Random(1)
m.on_read("RANDOM", lambda: rng.randrange(256))
m.poke("PAL", 0x0F)
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT"):
    m.call(r)
blk = m.addr("MAPBLK")
first = {t: table(m, t) for t in ("AI_HD", "AI_UP", "AI_DN")}
live0 = [m.byte("TILECH", i) for i in range(blk)]

# the fixed maps: their block in place; CLASSIC's owners from its lists
for mp in (CLASSIC, STANDARD):
    m.call("MAP_LOAD", a=mp, limit=LONG)
    src = (m.byte("MAPSH", mp) << 8) | m.byte("MAPSL", mp)
    if [m.byte("TILECH", i) for i in range(blk)] != [m.mem[src + i] for i in range(blk)]:
        fail("map %d: live tables differ from its block" % (mp + 1))
    kinds = check_map(m, mp, "map %d" % (mp + 1))
    if mp == CLASSIC and (kinds[8 * COLS + 11] != K_LAND or kinds[2 * COLS + 10] != K_LAND | K_P1
                          or kinds[6 * COLS + 2] != K_HARB or kinds[4 * COLS + 18] != K_HARB | K_P1):
        fail("CLASSIC: owners or harbours not the original's")
if first != {t: table(m, t) for t in first}:
    fail("map 1's AI_ tables worked out differently from ISLANDS.ASM's")
if [m.byte("TILECH", i) for i in range(blk)] != live0:
    fail("map 1's block differs from the live tables at start-up")

# RANDOM: new islands each time, all of them sound
pairs = set()
for game in range(12):
    m.call("MAP_LOAD", a=RANDOM, limit=LONG)
    pairs.add(tuple(check_random(m, "random %d" % game)))
if len(pairs) < 12:
    fail("RANDOM: only %d different pairs in 12 games" % len(pairs))
m.call("MAP_LOAD", a=STANDARD, limit=LONG)  # and back
if first != {t: table(m, t) for t in first} or table(m, "ISLKIND") != [m.mem[
        ((m.byte("MAPSH", 0) << 8) | m.byte("MAPSL", 0)) + 4 * m.addr("N_TILES") + 22 + i]
        for i in range(ROWS * COLS)]:
    fail("STANDARD after RANDOM is not STANDARD again")

# SU_GO: the MAP line's value 1-3 is map 0-2
fmap = m.addr("SU_VAL") + m.addr("SU_FMAP")
for v in (1, 2, 3, 3):
    m.poke("SU_VAL", 10, 30, 2, 2)
    m.poke(fmap, v)
    m.call("SU_GO", limit=LONG)
    if m.byte("MAPNO") != v - 1 or m.byte("MAPLD") != v - 1:
        fail("map line %d: MAPNO %d, loaded %d" % (v, m.byte("MAPNO"), m.byte("MAPLD")))

# the demo always plays map 1 (its script is made for it)
m.poke(fmap, 2)
m.call("DEMO_GO", limit=LONG)
if m.byte("MAPNO") != 0 or m.byte("MAPLD") != 0:
    fail("demo: MAPNO %d, loaded %d" % (m.byte("MAPNO"), m.byte("MAPLD")))
m.call("DEMO_END")
if m.byte("SU_VAL", m.addr("SU_FMAP")) != 2:
    fail("demo did not put the MAP line back")

print("maps: %d failed" % fails)
sys.exit(1 if fails else 0)
