#!/usr/bin/env python3
"""T-ECO-4: round score (original $5ABD-$5B5F) and a full ECO_ROUND (py65)."""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

FORT, FACT, CROP, SCHL, HOSP, HOUS, REBL, PTBT, FSBT = range(1, 10)
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def rnd(n, d):
    q, r = divmod(n, d)
    return q + (1 if 2 * r >= d else 0)


def model(pop, rgold, c):
    g = lambda k: c.get(k, 0)
    p100 = max(1, pop // 100)                     # truncated; at least 1 (D28)
    part = lambda n, d: min(30, rnd(rnd(n, p100), d))
    housing = part(g(HOUS) * 500, 3)
    gdp = part(rgold * 100, 12)
    food = part((g(CROP) + g(FSBT)) * 500, 3)
    return min(100, housing + gdp + food + g(SCHL) + g(HOSP))


def word(name, p):
    a = m.addr(name) + 2 * p
    return m.mem[a] | m.mem[a + 1] << 8


def set_word(name, p, v):
    m.poke(m.addr(name) + 2 * p, v, v >> 8)


def score(pop, rgold, counts, p=0, prev=0, total=0):
    m.call("VARS_INIT")
    for item, n in counts.items():
        m.poke(m.addr("COUNT") + 10 * p + item, n)
    set_word("POP", p, pop)
    set_word("RGOLD", p, rgold)
    m.poke(m.addr("RSCORE") + p, prev)
    set_word("SCORE", p, total)
    m.call("ECO_SCORE", x=p)
    return m.byte("RSCORE", p), m.byte("PRSCORE", p), word("SCORE", p)


def check(what, pop, rgold, counts, p=0, want=None):
    want = model(pop, rgold, counts) if want is None else want
    got = score(pop, rgold, counts, p, prev=33, total=500)
    if got != (want, 33, 500 + want):
        fail("%s: RSCORE, PRSCORE, SCORE %r, want %r" % (what, got, (want, 33, 500 + want)))


ex = {FACT: 2, CROP: 4, SCHL: 1, HOSP: 1, HOUS: 1, FSBT: 1}
check("worked example", 1043, 14, ex, want=61)
check("worked example, player 2", 1043, 14, ex, p=1, want=61)
check("nothing", 1000, 0, {}, want=0)
check("population 0 (p100 -> 1)", 0, 10, {HOUS: 1, CROP: 1})
check("population 99 (p100 -> 1)", 99, 10, {HOUS: 1})
check("population 100", 100, 10, {HOUS: 1})
check("p100 truncates (1099)", 1099, 14, ex)
check("p100 truncates (1100)", 1100, 14, ex)
check("caps 30/30/30", 1000, 999, {HOUS: 20, CROP: 30})
check("total capped at 100", 1000, 999, {HOUS: 20, CROP: 30, SCHL: 10, HOSP: 10})
check("earned gold over 255", 2000, 300, {})
check("earned gold 65535", 9999, 65535, {})
check("crops + boats over 65", 9999, 0, {CROP: 40, FSBT: 40})
check("max items", 9999, 999, {k: 35 for k in (FACT, CROP, SCHL, HOSP, HOUS, FSBT)})

rng = random.Random(9)
for _ in range(300):
    counts = {k: rng.randrange(0, 36) for k in (FACT, CROP, SCHL, HOSP, HOUS, FSBT)}
    check("random", rng.randrange(0, 10000), rng.randrange(0, 2000), counts, p=rng.randrange(2))

# a full round from the start of a game: the worked example end to end
m.call("VARS_INIT")
m.call("ECO_INIT")
for item, n in ex.items():
    m.poke(m.addr("COUNT") + item, n)
m.call("ECO_ROUND")
got = (word("GOLD", 0), word("POP", 0), m.byte("RSCORE", 0), word("SCORE", 0), word("RGOLD", 0))
if got != (124, 1043, 61, 61, 0):
    fail("ECO_ROUND worked example: gold, pop, round score, total, earned = %r" % (got,))
else:
    print("ECO_ROUND worked example: gold 124, pop 1043, score 61, earned reset")
p2 = (word("GOLD", 1), word("POP", 1), m.byte("RSCORE", 1))
print("ECO_ROUND player 2 (nothing built): gold %d, pop %d, score %d" % p2)
m.call("ECO_ROUND")
if m.byte("PRSCORE", 0) != 61 or word("SCORE", 0) != 61 + m.byte("RSCORE", 0):
    fail("second round: PRSCORE %d, SCORE %d" % (m.byte("PRSCORE", 0), word("SCORE", 0)))
else:
    print("second round: score %d, previous 61, total %d" % (m.byte("RSCORE", 0), word("SCORE", 0)))

print("score: %d failed" % fails)
sys.exit(1 if fails else 0)
