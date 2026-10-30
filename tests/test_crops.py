#!/usr/bin/env python3
"""T-ECO-6: crop loss at the end of a round (py65).

RANDOM is fed from a seeded generator, so RAND_N rolls like the real
POKEY: each crop should be lost about 1 time in 3.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

I_FORT, I_CROP, I_HOUS = 1, 3, 6
K_LAND, K_KIND, K_P1 = 1, 0x7F, 0x80
m = Machine()
rng = random.Random(6)
m.on_read("RANDOM", lambda: rng.randrange(256))
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def item(col, row):
    return m.byte("MAPITEM", row * 20 + col)


def count(p, k):
    return m.byte("COUNT", 10 * p + k)


def chars(col, row):
    return m.mem[m.addr("MAPSCR") + row * 80 + col * 2]


for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "GAME_NEW"):
    m.call(r)

# every land square of both islands: crops on the even ones, houses on
# the odd ones (houses must stay)
land = {0: [], 1: []}
for row in range(11):
    for col in range(20):
        k = m.byte("ISLKIND", row * 20 + col)
        if k & K_KIND == K_LAND:
            land[1 if k & K_P1 else 0].append((col, row))
terrain = {sq: chars(*sq) for p in land for sq in land[p]}

lost, total = 0, 0
for rnd in range(20):
    m.call("MAP_INIT")
    m.call("MAP_DRAW")
    for p in (0, 1):
        crops = 0
        for i, (col, row) in enumerate(land[p]):
            m.call("MAP_SET", a=I_HOUS if i % 2 else I_CROP, x=col, y=row)
            crops += not i % 2
        m.mem[m.addr("COUNT") + 10 * p + I_CROP] = crops
        m.mem[m.addr("COUNT") + 10 * p + I_HOUS] = len(land[p]) - crops
    m.call("ECO_CROPS")
    for p in (0, 1):
        left = 0
        for i, (col, row) in enumerate(land[p]):
            it = item(col, row)
            if i % 2:
                if it != I_HOUS:
                    fail("round %d: a house went at %d, %d" % (rnd, col, row))
                continue
            total += 1
            if it == I_CROP:
                left += 1
            elif it == 0:
                lost += 1
                if chars(col, row) != terrain[(col, row)]:
                    fail("round %d: lost crop at %d, %d not redrawn as island" % (rnd, col, row))
            else:
                fail("round %d: item %d at %d, %d" % (rnd, it, col, row))
        if count(p, I_CROP) != left:
            fail("round %d player %d: crop count %d, %d crops left" % (rnd, p, count(p, I_CROP), left))
        if count(p, I_HOUS) != len(land[p]) // 2:
            fail("round %d player %d: house count changed" % (rnd, p))
share = lost / total
print("crops lost: %d of %d (%.1f %%)" % (lost, total, 100 * share))
if not 0.28 < share < 0.39:
    fail("crop loss %.3f, want about 1/3" % share)

# a count already at 0 stays at 0
m.call("MAP_INIT")
m.call("MAP_SET", a=I_CROP, x=land[0][0][0], y=land[0][0][1])
m.mem[m.addr("COUNT") + I_CROP] = 0
for _ in range(30):
    m.call("ECO_CROPS")
if item(*land[0][0]) or count(0, I_CROP):
    fail("crop not lost in 30 rounds or count below 0: %d" % count(0, I_CROP))

# ECO_ROUND ends with the crop loss
m.call("GAME_NEW")
m.call("MAP_INIT")
for col, row in land[1]:
    m.call("MAP_SET", a=I_CROP, x=col, y=row)
m.mem[m.addr("COUNT") + 10 + I_CROP] = len(land[1])
m.call("ECO_ROUND")
n = sum(item(c, r) == I_CROP for c, r in land[1])
if n == len(land[1]) or count(1, I_CROP) != n:
    fail("ECO_ROUND: %d of %d crops left, count %d" % (n, len(land[1]), count(1, I_CROP)))

print("crops: %d failed" % fails)
sys.exit(1 if fails else 0)
