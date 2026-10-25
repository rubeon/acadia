#!/usr/bin/env python3
"""T-SVC-1: check MATH.ASM against Python on a 6502 core (py65)."""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

m = Machine()
fails = 0
checks = 0


def check(what, got, want):
    global fails, checks
    checks += 1
    if got != want:
        fails += 1
        print("FAIL %s: got %r, want %r" % (what, got, want))


def mul8(a, b):
    m.call("MUL8", a=a, x=b)
    return m.long("M_NUM")


def muln(n, k):
    m.set_long("M_NUM", n)
    _, _, _, c = m.call("MULN", a=k)
    return m.long("M_NUM"), c


def divn(n, d, rounded=False):
    m.set_long("M_NUM", n)
    a, _, _, c = m.call("DIVNR" if rounded else "DIVN", a=d)
    return m.long("M_NUM"), (a if not rounded else None), c


def py_round(n, d):
    q, r = divmod(n, d)
    return q + (1 if 2 * r >= d else 0)


# exhaustive-ish 8 x 8 and fixed cases
for a, b in [(0, 0), (1, 255), (255, 255), (12, 34), (128, 2), (99, 64)]:
    check("MUL8 %d*%d" % (a, b), mul8(a, b), a * b)
for a in range(0, 256, 17):
    for b in range(0, 256, 13):
        check("MUL8 %d*%d" % (a, b), mul8(a, b), a * b)

# 24 x 8, overflow flag
for n, k in [(999, 64), (36, 250), (65535, 255), (0xFFFFFF, 1), (0xFFFFFF, 2), (0x10000, 255)]:
    want = n * k
    check("MULN %d*%d" % (n, k), muln(n, k), (want & 0xFFFFFF, want > 0xFFFFFF))

# division, truncating and rounded, and divide by zero
for n, d in [(1000, 10), (1043, 10), (1045, 10), (1044, 10), (9999, 100),
             (63936, 100), (5300, 100), (65535, 1), (0xFFFFFF, 255), (7, 7), (0, 3), (255, 2)]:
    q, r = divmod(n, d)
    check("DIVN %d/%d" % (n, d), divn(n, d), (q, r, False))
    check("DIVNR %d/%d" % (n, d), divn(n, d, True)[::2], (py_round(n, d), False))
check("DIVN /0", divn(1234, 0), (0xFFFFFF, 0, True))
check("DIVNR /0", divn(1234, 0, True)[::2], (0xFFFFFF, True))

rng = random.Random(1)
for _ in range(500):
    n, d = rng.randrange(0, 1 << 24), rng.randrange(1, 256)
    q, r = divmod(n, d)
    check("DIVN rand", divn(n, d), (q, r, False))
    check("DIVNR rand", divn(n, d, True)[::2], (py_round(n, d), False))
    k = rng.randrange(0, 256)
    n16 = rng.randrange(0, 1 << 16)
    check("MULN rand", muln(n16, k), (n16 * k, False))

# worked example from utopia-rules.md: births and deaths for pop 1000
m.set_long("M_NUM", 1000)
m.call("DIVNR", a=10)                       # pop / 10 = 100
check("pop/10", m.long("M_NUM"), 100)
m.call("MULN", a=53)                        # x fertility 53
m.call("DIVNR", a=100)                      # / 100 rounded
check("births", m.long("M_NUM"), 53)
m.set_long("M_NUM", 1 * 500)                # housing: (1 x 500 / 10) / 3
m.call("DIVN", a=10)
m.call("DIVN", a=3)
check("housing", m.long("M_NUM"), 16)

print("math: %d checks, %d failed" % (checks, fails))
sys.exit(1 if fails else 0)
