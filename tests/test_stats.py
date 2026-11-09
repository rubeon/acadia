#!/usr/bin/env python3
"""T-SCR-5 (D61): the stats screen at the end of a game (py65)."""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

m = Machine()
fails = 0
MAXR = 50
X0, W, YB, GAP = m.addr("CT_X0"), m.addr("CT_W"), m.addr("CT_YBOT"), m.addr("CT_GAP")
STEPS = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000]
BIG = 2000000


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def row_addr(y):
    if y < 25:
        return 0x9C00 + 40 * y
    if y < 50:
        return 0xBC00 + 40 * (y - 25)
    return m.addr("MAPSCR") + 40 * (y - 50)


def pixel(x, y):
    b = m.mem[row_addr(y) + x // 4]
    return (b >> (6 - 2 * (x & 3))) & 3


def text(off, n=40):
    out = ""
    for i in range(n):
        c = m.byte("CTTXT", off + i) & 0x3F
        out += chr(c + 0x20) if c else " "
    return out


def scale_ref(vals):
    """The lowest grid line and the step CT_SCALE should pick."""
    lo_v, hi_v = min(vals), max(vals)
    for st in STEPS:
        lo = lo_v - lo_v % st
        if hi_v - lo <= 5 * st:
            return lo, st
    return lo, st


def x_ref(i, n):
    return X0 + (i * W // (n - 1) if n > 1 else 0)


def y_ref(v, lo, st):
    return YB - (v - lo) * GAP // st


for r in ("VARS_INIT", "DISP_INIT"):
    m.call(r)

# --- the display list: in DLIST's page, 64 chart lines, 6 DLIs ---------
dl = m.addr("CTDLIST")
if dl >> 8 != m.addr("DLIST") >> 8:
    fail("CTDLIST %04X not in DLIST's page" % dl)
lines, moded, dlis, lms, pc = 0, 0, 0, [], dl
while True:
    op = m.mem[pc]
    if op & 0x80:
        dlis += 1
    if op == 0x41:
        break
    mode = op & 0x0F
    if mode == 0:
        lines += ((op >> 4) & 7) + 1
        pc += 1
        continue
    lines += {4: 8, 0xD: 2}[mode]
    moded += mode == 0xD
    if op & 0x40:
        lms.append(m.mem[pc + 1] | m.mem[pc + 2] << 8)
        pc += 3
    else:
        pc += 1
if moded != 64 or dlis != m.addr("CT_NDLI") or lines > 216:
    fail("CTDLIST: %d mode D lines, %d DLIs, %d scan lines" % (moded, dlis, lines))
want = [m.addr("STATUS1"), m.addr("CT_TAB"), 0x9C00, 0xBC00, m.addr("MAPSCR"), m.addr("CT_XL")]
if lms != want:
    fail("CTDLIST screen addresses %r" % ["%04X" % a for a in lms])
if pc >= 0x3900:
    fail("CTDLIST runs into the variables (%04X)" % pc)

# --- CT_REC keeps each round, up to 50 ----------------------------------
m.call("GAME_NEW")
for rnd in range(52):
    m.poke("CURTRN", rnd)
    m.poke("RSCORE", rnd + 1, 99 - rnd)
    m.poke("POP", (1000 + rnd) & 0xFF, (1000 + rnd) >> 8, (2000 + rnd) & 0xFF, (2000 + rnd) >> 8)
    m.poke("RGOLD", (300 + rnd) & 0xFF, (300 + rnd) >> 8, (9000 + rnd) & 0xFF, (9000 + rnd) >> 8)
    m.call("CT_REC")
for rnd in (0, 7, 49):
    got = []
    for s in range(6):
        a, x, y, c = m.call("CT_GET", x=s, y=rnd)
        got.append(a | x << 8)
    want = [rnd + 1, 99 - rnd, 1000 + rnd, 2000 + rnd, 300 + rnd, 9000 + rnd]
    if got != want:
        fail("round %d kept %r, want %r" % (rnd, got, want))

# income over 9999 is charted as 9999 (the scale's steps reach 10000)
m.poke("CURTRN", 3)
m.poke("RGOLD", 0x10, 0x27, 0xE0, 0x2E)    # 10000, 12000
m.call("CT_REC")
got = [m.call("CT_GET", x=s, y=3)[0] | m.call("CT_GET", x=s, y=3)[1] << 8 for s in (4, 5)]
if got != [9999, 9999]:
    fail("income 10000 / 12000 kept as %r" % got)

# ECO_ROUND records the round's earned gold before clearing it (D66)
m.call("GAME_NEW")
m.poke("CURTRN", 0)
m.poke("RGOLD", 55, 0, 7, 0)
m.call("ECO_ROUND", limit=BIG)
got = [m.call("CT_GET", x=s, y=0)[0] for s in (4, 5)]
if got != [55, 7] or m.word("RGOLD") != 0:
    fail("ECO_ROUND: income %r, RGOLD after %d" % (got, m.word("RGOLD")))


# --- the scale and the lines on random games ----------------------------
def game(n, seed):
    rng = random.Random(seed)
    sc = [[rng.randint(0, 100) for _ in range(n)] for _ in range(2)]
    pop = [[max(0, min(9999, 1000 + rng.randint(-20, 400) * i)) for i in range(n)] for _ in range(2)]
    gold = [[rng.randint(0, 9999) if seed % 2 else rng.randint(80, 140) for _ in range(n)] for _ in range(2)]
    for p in range(2):
        for i in range(n):
            m.mem[m.addr("HSC") + p * MAXR + i] = sc[p][i]
            m.mem[m.addr("HPOPL") + p * MAXR + i] = pop[p][i] & 0xFF
            m.mem[m.addr("HPOPH") + p * MAXR + i] = pop[p][i] >> 8
            m.mem[m.addr("HINCL") + p * MAXR + i] = gold[p][i] & 0xFF
            m.mem[m.addr("HINCH") + p * MAXR + i] = gold[p][i] >> 8
    return [sc, pop, gold]


for n, seed in ((10, 1), (50, 2), (2, 3), (1, 4), (23, 5)):
    data = game(n, seed)
    m.poke("SCORE", 0x34, 0x02, 0x21, 0x01)
    m.poke("CURTRN", n)
    m.call("GAME_OVER")
    m.call("CT_ENTER", limit=BIG)
    if m.byte("CT_ON") != 1 or m.byte("CT_N") != n:
        fail("CT_ENTER: CT_ON %d CT_N %d" % (m.byte("CT_ON"), m.byte("CT_N")))
    for pg in range(3):
        m.poke("CT_PG", pg)
        m.call("CT_DRAW", limit=BIG)
        vals = data[pg][0] + data[pg][1]
        lo, st = (0, 20) if pg == 0 else scale_ref(vals)
        if (m.word("CT_LO"), m.word("CT_D")) != (lo, st):
            fail("n %d page %d: scale %d step %d, want %d step %d"
                 % (n, pg, m.word("CT_LO"), m.word("CT_D"), lo, st))
            continue
        # each round's point is on the line of its player (or under the
        # other player's line, which is drawn over it)
        for p in range(2):
            for i in range(n):
                x, y = x_ref(i, n), y_ref(data[pg][p][i], lo, st)
                if not 5 <= y <= YB:
                    fail("n %d page %d: line %d out of the grid" % (n, pg, y))
                got = pixel(x, y)       # player 1's line is drawn last
                if got != 2 if p == 0 else got not in (2, 3):
                    fail("n %d page %d player %d round %d: pixel %d,%d is %d"
                         % (n, pg, p + 1, i + 1, x, y, got))
        # grid lines: dotted from column 6
        for k in range(6 if n > 1 else 0):    # (1 round: a flat line on one)
            y = YB - GAP * k
            if sum(pixel(x, y) == 1 for x in range(X0, X0 + W, 2)) < 10:
                fail("n %d page %d: no grid line at %d" % (n, pg, y))
        # page names: this one inverse
        tabs = [m.byte("CT_TAB", c) for c in (4, 17, 31)]
        if [t >= 0x80 for t in tabs] != [i == pg for i in range(3)]:
            fail("page %d names: %r" % (pg, ["%02X" % t for t in tabs]))
    xl = text(40)
    if not xl.strip().startswith("1") or str(n) not in xl:
        fail("n %d round numbers %r" % (n, xl))
    leg = text(80)
    for p in range(2):
        best = str(max(data[0][p]))
        if "BEST " + best not in leg:
            fail("n %d legend %r, want BEST %s" % (n, leg, best))
    print("n %2d: %r" % (n, xl))
    print("      %r" % leg)

# the round numbers for 50 rounds: 1, 5, 10 ... 45, 50 (no clash)
m.poke("CURTRN", 50)
m.call("CT_ENTER", limit=BIG)
xl = text(40).split()
if xl != ["1", "5", "10", "15", "20", "25", "30", "35", "40", "45", "50"]:
    fail("50 rounds: %r" % xl)
m.poke("CURTRN", 12)
m.call("CT_ENTER", limit=BIG)
if text(40).split() != ["1", "5", "10", "12"]:
    fail("12 rounds: %r" % text(40).split())
m.poke("CURTRN", 11)
m.call("CT_ENTER", limit=BIG)
if text(40).split() != ["1", "5", "10", "11"]:
    fail("11 rounds: %r" % text(40).split())
m.poke("CURTRN", 47)
m.call("CT_ENTER", limit=BIG)
if text(40).split()[-2:] != ["40", "47"]:
    fail("47 rounds (45 is too close): %r" % text(40).split())

# --- the stick flips pages, both ways round -----------------------------
m.poke("CT_PG", 0)
m.poke("CT_J", 0)
for joy, want in ((8, 1), (0, 1), (8, 2), (0, 2), (8, 0), (0, 0), (4, 2), (4, 2), (0, 2), (4, 1)):
    m.poke("JOY0", joy)
    m.call("CT_FRAME", limit=BIG)
    if m.byte("CT_PG") != want:
        fail("stick %d: page %d, want %d" % (joy, m.byte("CT_PG"), want))
m.poke("JOY0", 0)

# --- the VBI points the DLIs at CT_DLI; each DLI sets its zone's colours
m.poke("COLRSH", 0)
m.poke("DRKMSK", 0xFF)
m.call("ST_VBI")
if m.word("VDSLST") != m.addr("CT_DLI") or m.byte("CT_DI") != 0:
    fail("ST_VBI with the stats screen: VDSLST %04X" % m.word("VDSLST"))
zones = []
for i in range(7):
    m.interrupt("CT_DLI")
    zones.append(tuple(m.byte(r) for r in ("COLBK", "COLPF0", "COLPF1", "COLPF2", "COLPF3")))
if zones[3] != (0x00, 0x16, 0x48, 0xAC, 0xAC) or zones[6] != zones[5]:
    fail("DLI colours %r" % zones)
m.poke("CT_ON", 0)
m.call("ST_VBI")
if m.word("VDSLST") != m.addr("DLI_ST"):
    fail("ST_VBI after the stats screen: VDSLST %04X" % m.word("VDSLST"))

print("stats: %d failed" % fails)
sys.exit(1 if fails else 0)
