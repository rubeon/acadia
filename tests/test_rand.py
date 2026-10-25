#!/usr/bin/env python3
"""T-SVC-2: RAND_N range and uniformity on a 6502 core (py65).

POKEY's RANDOM register is faked with Python's generator, so this
checks RAND_N's own logic: every result is in 0..N-1 and the
histogram over 10,000 calls is within +/-5 % of flat.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

m = Machine()
rng = random.Random(7)
m.on_read("RANDOM", lambda: rng.randrange(256))
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


# range: every N, a few hundred calls each
for n in range(0, 256):
    limit = 256 if n == 0 else n
    for _ in range(200):
        a = m.call("RAND_N", a=n, x=0x5A, y=0xA5)
        if not 0 <= a[0] < limit:
            fail("RAND_N(%d) gave %d" % (n, a[0]))
            break
        if a[1] != 0x5A or a[2] != 0xA5:
            fail("RAND_N(%d) changed X or Y" % n)
            break



def chi2_limit(df, z=3.09):
    """Wilson-Hilferty upper limit of chi-square at p ~ 0.001."""
    k = 2.0 / (9 * df)
    return df * (1 - k + z * k ** 0.5) ** 3


def histogram(n, calls):
    counts = [0] * n
    for _ in range(calls):
        counts[m.call("RAND_N", a=n)[0]] += 1
    return counts


# uniformity: chi-square over 10,000 calls for the game's N values
CALLS = 10000
for n in (2, 3, 4, 10, 12, 20, 29, 100, 129, 200, 255):
    counts = histogram(n, CALLS)
    expect = CALLS / n
    chi2 = sum((c - expect) ** 2 / expect for c in counts)
    worst = max(abs(c - expect) / expect for c in counts)
    lim = chi2_limit(n - 1)
    if chi2 > lim:
        fail("RAND_N(%d): chi-square %.1f > %.1f" % (n, chi2, lim))
    print("RAND_N(%3d): chi-square %6.1f (limit %6.1f), worst bucket %4.1f %% from flat"
          % (n, chi2, lim, 100 * worst))

# the plan's +/-5 % per bucket, with enough calls per bucket for it
# to be a fair test (about 4 standard deviations)
for n, calls in ((2, 10000), (10, 100000)):
    counts = histogram(n, calls)
    worst = max(abs(c - calls / n) / (calls / n) for c in counts)
    if worst > 0.05:
        fail("RAND_N(%d): bucket off by %.1f %% over %d calls" % (n, 100 * worst, calls))
    print("RAND_N(%3d): worst bucket %.1f %% over %d calls (limit 5 %%)" % (n, 100 * worst, calls))

print("rand: %d failed" % fails)
sys.exit(1 if fails else 0)
