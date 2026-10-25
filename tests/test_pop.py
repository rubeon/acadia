#!/usr/bin/env python3
"""T-ECO-3: population update (original $5A32-$5AAD) against a Python model (py65)."""

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


def model(pop, c):
    g = lambda k: c.get(k, 0)
    p10 = rnd(pop, 10)
    fert = 40 + 3 * g(CROP) + 3 * g(HOSP) + g(HOUS) - 3 * g(SCHL)
    fert = max(0, min(64, fert))                     # cap 64; floor 0 (D27)
    mort = max(2, 11 - 3 * g(HOSP)) + g(FACT)
    births = rnd(p10 * fert, 100)
    deaths = rnd(p10 * mort, 100)
    return max(0, min(9999, pop + births - deaths))


def word(name, p):
    a = m.addr(name) + 2 * p
    return m.mem[a] | m.mem[a + 1] << 8


def run(pop, counts, p=0):
    m.call("VARS_INIT")
    for item, n in counts.items():
        m.poke(m.addr("COUNT") + 10 * p + item, n)
    m.poke(m.addr("POP") + 2 * p, pop, pop >> 8)
    m.call("ECO_POP", x=p)
    return word("POP", p)


def check(what, pop, counts, p=0, want=None):
    want = model(pop, counts) if want is None else want
    got = run(pop, counts, p)
    if got != want:
        fail("%s: pop %d -> %d, want %d" % (what, pop, got, want))


ex = {FACT: 2, CROP: 4, SCHL: 1, HOSP: 1, HOUS: 1, FSBT: 1}
check("worked example", 1000, ex, want=1043)
check("worked example, player 2", 1000, ex, p=1, want=1043)
check("nothing built", 1000, {})                       # 40 - 11 per 1000
check("population 0", 0, ex, want=0)
check("p10 rounds up (1045)", 1045, ex)
check("p10 rounds down (1044)", 1044, ex)
check("near a multiple of 100", 1999, ex)
check("fertility capped at 64", 5000, {CROP: 30, HOSP: 5, HOUS: 20})
check("fertility below 0 -> no births", 2000, {SCHL: 30})
check("mortality floor 2", 2000, {HOSP: 10})
check("factories after the floor", 2000, {HOSP: 10, FACT: 20})
check("cap at 9999", 9990, {CROP: 30, HOSP: 10})
check("max items", 9999, {FACT: 35, CROP: 35, SCHL: 35, HOSP: 35, HOUS: 35, FSBT: 35})
check("deaths exceed births", 3000, {FACT: 40})

# both players in one ECO_ROUND, independently
m.call("VARS_INIT")
m.call("ECO_INIT")
for item, n in ex.items():
    m.poke(m.addr("COUNT") + item, n)
m.call("ECO_ROUND")
if (word("POP", 0), word("POP", 1)) != (1043, model(1000, {})):
    fail("ECO_ROUND populations %d, %d" % (word("POP", 0), word("POP", 1)))
else:
    print("ECO_ROUND: player 1 pop 1043, player 2 pop %d" % word("POP", 1))

rng = random.Random(5)
for _ in range(300):
    counts = {k: rng.randrange(0, 36) for k in (FACT, CROP, SCHL, HOSP, HOUS, FSBT)}
    check("random", rng.randrange(0, 10000), counts, p=rng.randrange(2))

print("pop: %d failed" % fails)
sys.exit(1 if fails else 0)
