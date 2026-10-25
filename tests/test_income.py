#!/usr/bin/env python3
"""T-ECO-2: end-of-round income (original $59CD-$5A27) (py65)."""

import os
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


def word(name, p):
    a = m.addr(name) + 2 * p
    return m.mem[a] | m.mem[a + 1] << 8


def set_word(name, p, v):
    m.poke(m.addr(name) + 2 * p, v, v >> 8)


def setup(counts0, counts1=None, gold=(100, 100)):
    m.call("VARS_INIT")
    for p, counts in enumerate((counts0, counts1 or {})):
        for item, n in counts.items():
            m.poke(m.addr("COUNT") + 10 * p + item, n)
        set_word("GOLD", p, gold[p])


def income_both():
    """ECO_INCOME for both players (ECO_ROUND also scores and then
    resets the earned gold, which these checks read)."""
    m.call("ECO_INCOME", x=0)
    m.call("ECO_INCOME", x=1)


def py_income(c):
    f, s, h, b = (c.get(k, 0) for k in (FACT, SCHL, HOSP, FSBT))
    return 4 * f + b + min(30, f * (s + h) + h)


def check(what, counts0, counts1=None, gold=(100, 100)):
    setup(counts0, counts1, gold)
    income_both()
    for p, c in enumerate((counts0, counts1 or {})):
        earned = py_income(c)
        want_gold = min(9999, gold[p] + earned + 10)
        got = (word("GOLD", p), word("RGOLD", p))
        if got != (want_gold, earned):
            fail("%s, player %d: gold, earned %r, want %r" % (what, p + 1, got, (want_gold, earned)))


# worked example (utopia-rules.md): earned 14, gold +24
ex = {FACT: 2, CROP: 4, SCHL: 1, HOSP: 1, HOUS: 1, FSBT: 1}
setup(ex)
income_both()
if (word("GOLD", 0), word("RGOLD", 0)) != (124, 14):
    fail("worked example: gold %d, earned %d (want 124, 14)" % (word("GOLD", 0), word("RGOLD", 0)))
else:
    print("worked example: earned 14, gold 100 -> 124")

check("nothing built", {})
check("worked example both players", ex, {FACT: 3, FSBT: 4})
check("bonus under the cap", {FACT: 5, SCHL: 3, HOSP: 0})         # 5 x 3 = 15
check("bonus capped", {FACT: 10, SCHL: 2, HOSP: 1})               # 31 -> 30
check("big bonus product", {FACT: 35, SCHL: 30, HOSP: 30})        # 2130 -> 30
check("hospitals only", {HOSP: 4})                                # bonus 4
check("bonus exactly 30", {FACT: 7, SCHL: 2, HOSP: 2})            # 7 x 4 + 2 = 30
check("many boats", {FSBT: 60, FACT: 30})                         # earned 120+60+30
check("gold cap", {FACT: 10}, gold=(9990, 9999))
check("RGOLD over 255", {FACT: 60, FSBT: 30, SCHL: 1})            # 240+30+30 = 300

# earned gold accumulates over the round until scoring resets it
setup({FACT: 1})
set_word("RGOLD", 0, 7)                                          # e.g. fish caught
income_both()
if word("RGOLD", 0) != 7 + 4:                                     # 1 factory earns 4
    fail("RGOLD did not add to gold earned during the round: %d" % word("RGOLD", 0))

print("income: %d failed" % fails)
sys.exit(1 if fails else 0)
