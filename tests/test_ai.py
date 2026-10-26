#!/usr/bin/env python3
"""T-AI-1, T-AI-3: the CPU governor (py65).

RANDOM is fed from a seeded generator.  The last part plays whole
1-player games (the person does nothing) at each level.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

I_FORT, I_FACT, I_CROP, I_SCHL, I_HOSP, I_HOUS, I_REBL, I_PTBT, I_FSBT = range(1, 10)
K_LAND, K_KIND, K_P1 = 1, 0x7F, 0x80
J_UP, J_DOWN, J_LEFT, J_RIGHT = 1, 2, 4, 8
KC_1 = 0x1F
GS_OVER = 3
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def machine(seed):
    m = Machine()
    rng = random.Random(seed)
    m.on_read("RANDOM", lambda: rng.randrange(256))
    m.poke("PAL", 0x0F)
    for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT"):
        m.call(r)
    return m


def start(m, players, level, rounds=10, secs=30):
    m.poke("SU_VAL", rounds, secs, players, level)
    m.call("SU_GO")


def frame(m, kb=None, fire1=False):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF)
    m.poke("TRIG0", 1)
    m.poke("TRIG1", 0 if fire1 else 1)
    m.poke("CONSOL", 7)
    if kb is None:
        m.poke("SKSTAT", 0xFF)
    else:
        m.poke("SKSTAT", 0xFB)
        m.poke("KBCODE", kb)
    m.call("GAME_FRAME", limit=3000000)


def count(m, p, k):
    return m.byte("COUNT", 10 * p + k)


def gold(m, p):
    return m.byte("GOLD", 2 * p) | m.byte("GOLD", 2 * p + 1) << 8


m = machine(1)
land = []
for row in range(11):
    for col in range(20):
        k = m.byte("ISLKIND", row * 20 + col)
        if k & K_KIND == K_LAND and k & K_P1:
            land.append((col, row))


def item(sq):
    return m.byte("MAPITEM", sq[1] * 20 + sq[0])


def near(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1])) <= 1 and a != b


# 2 players: no CPU; player 2's stick and fire are their own
start(m, 2, 2)
for _ in range(200):
    frame(m)
if any(count(m, 1, k) for k in range(1, 10)) or gold(m, 1) != 100:
    fail("CPU played in a 2-player game")

# 1 player: a key is player 1's even with fire 2 held; the CPU buys
m = machine(2)
start(m, 1, 2)
frame(m, kb=KC_1, fire1=True)
if m.byte("JOY1") or m.byte("FIRE1"):
    fail("player 2's stick reaches the game in a 1-player game")
spent = 100 - gold(m, 0)
if spent not in (0, 50):
    fail("key 1 in a 1-player game: player 1 spent %d" % spent)
for _ in range(600):
    frame(m)
if not count(m, 1, I_CROP):
    fail("CPU bought no crop in 10 s: %r" % [count(m, 1, k) for k in range(1, 10)])

# the stick heads for the square and buys once the cursor sits on it
m = machine(3)
start(m, 1, 2)
m.call("MAP_INIT")
m.poke("AIST", 1)
m.poke("AI_IT", I_CROP)
target = land[len(land) // 2]
m.poke("AI_C", target[0])
m.poke("AI_R", target[1])
m.poke("AITMR", 255)
for n in range(400):
    cur = (m.byte("CURCOL", 1), m.byte("CURROW", 1))
    frame(m)
    if n == 0:
        want = ((J_RIGHT if target[0] > cur[0] else J_LEFT if target[0] < cur[0] else 0)
                | (J_DOWN if target[1] > cur[1] else J_UP if target[1] < cur[1] else 0))
        if m.byte("JOY1") != want:
            fail("stick %d from %r to %r, want %d" % (m.byte("JOY1"), cur, target, want))
    if not m.byte("AIST"):
        break
if item(target) != I_CROP or count(m, 1, I_CROP) != 1:
    fail("CPU did not buy its crop at %r (AIST %d)" % (target, m.byte("AIST")))

# where: next to a fort; a fort where it covers the most buildings
m.call("MAP_INIT")
fort = land[len(land) // 2]
m.call("MAP_SET", a=I_FORT, x=fort[0], y=fort[1])
for _ in range(20):
    m.poke("AI_IT", I_HOUS)
    m.call("AI_SPOT")
    spot = (m.byte("AI_C"), m.byte("AI_R"))
    if not near(spot, fort):
        fail("house spot %r not next to the fort at %r" % (spot, fort))
        break
m.call("MAP_INIT")
block = [sq for sq in land if near(sq, land[10])][:4]
for sq in block:
    m.call("MAP_SET", a=I_FACT, x=sq[0], y=sq[1])
m.poke("AI_IT", I_FORT)
m.call("AI_SPOT")
spot = (m.byte("AI_C"), m.byte("AI_R"))
around = sum(near(spot, sq) for sq in block)
best = max(sum(near(sq, b) for b in block) for sq in land if sq not in block)
if around != best:
    fail("fort spot %r covers %d buildings, best is %d" % (spot, around, best))
for sq in land:                          # no free land: C set
    m.call("MAP_SET", a=I_FACT, x=sq[0], y=sq[1])
if not m.call("AI_SPOT")[3]:
    fail("AI_SPOT found a square on a full island")

# what: crops first, then the plan; nothing it can't pay for
m.call("MAP_INIT")
for k in range(1, 10):
    m.mem[m.addr("COUNT") + 10 + k] = 0
m.poke("POP", 0xE8, 3, 0xE8, 3)          # 1000 people: need 10 / 6 + 1 = 2
m.poke("SU_VAL", 10, 30, 1, 2)
order = []
for _ in range(12):
    a = m.call("AI_PICK")[0]
    order.append(a)
    if a:
        m.mem[m.addr("COUNT") + 10 + a] += 1
if order[:6] != [I_CROP, I_CROP, I_FACT, I_HOUS, I_HOUS, I_SCHL]:
    fail("plan order %r" % order)
m.poke("GOLD", 0, 0, 2, 0)               # 2 gold: a crop costs 3
for k in range(1, 10):
    m.mem[m.addr("COUNT") + 10 + k] = 0
m.poke("AIST", 0)
m.poke("AITMR", 1)
m.call("AI_TIC")
if m.byte("AIST"):
    fail("CPU set off to buy a crop with 2 gold")

# whole games: the CPU beats a person who does nothing, and the levels
# differ; level 2 scores 50 or more a round after round 5
results = {}
for level in (1, 2, 3):
    m = machine(10 + level)
    start(m, 1, level)
    scores, last = [], None
    while m.byte("GSTATE") != GS_OVER:
        frame(m)
        st = (m.byte("CURTRN"), m.byte("GSTATE"))
        if st != last and st[1] == 1:
            scores.append(m.byte("RSCORE", 1))
        last = st
    total = (m.word("SCORE"), m.byte("SCORE", 2) | m.byte("SCORE", 3) << 8)
    late = sum(scores[5:]) / len(scores[5:])
    results[level] = total[1]
    print("level %d: rounds %r, rounds 6+ %.1f, total %d vs %d" % (level, scores, late, total[1], total[0]))
    if total[1] <= total[0]:
        fail("level %d did not beat a do-nothing player" % level)
    if level >= 2 and late < 50:
        fail("level %d scores %.1f a round after round 5" % (level, late))
if not results[1] < results[2]:
    fail("level 1 not weaker than level 2: %r" % results)

print("ai: %d failed" % fails)
sys.exit(1 if fails else 0)
