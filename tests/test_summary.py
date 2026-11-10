#!/usr/bin/env python3
"""T-SCR-11 (D84): the stats screen's summary page and its counts (py65).

The counts kept during play (items bought, gold by source, boats lost
by cause), cleared by a new game; the page's text, colours, display
list; the stick reaching it from both sides.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

I_FORT, I_FACT, I_CROP, I_SCHL, I_HOSP, I_HOUS, I_REBL, I_PTBT, I_FSBT = range(1, 10)
K_LAND, K_KIND, K_P1 = 1, 0x7F, 0x80
NEVER = 5
P = 2                                    # first pirate slot
BIG = 2000000

m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def blt(p, k):
    return m.byte("SYBLT", 10 * p + k)


def gold(p, s):
    a = m.addr("SYGOLD") + 6 * p + 2 * s
    return m.mem[a] | m.mem[a + 1] << 8


def lost(p, c):
    return m.byte("SYLOST", 3 * p + c)


def count(p, k):
    return m.byte("COUNT", 10 * p + k)


def set_count(p, k, v):
    m.mem[m.addr("COUNT") + 10 * p + k] = v


def rgold(p):
    return m.word("RGOLD") if p == 0 else m.byte("RGOLD", 2) | m.byte("RGOLD", 3) << 8


def steer(p, kind, x, y):
    m.mem[m.addr("BOATK") + p] = kind
    m.mem[m.addr("CURX") + p] = x
    m.mem[m.addr("CURY") + p] = y
    m.mem[m.addr("CURCOL") + p] = (x + 4) // 8
    m.mem[m.addr("CURROW") + p] = (y + 4) // 8


def land(p, n):
    """n free land squares of player p's island."""
    out = []
    for row in range(11):
        for col in range(20):
            k = m.byte("ISLKIND", row * 20 + col)
            if k & K_KIND == K_LAND and (k & K_P1) == (K_P1 if p else 0) \
                    and m.byte("MAPITEM", row * 20 + col) == 0:
                out.append((col, row))
    return out[:n]


for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "MAP_DRAW", "MAP_INIT",
          "PM_INIT", "CUR_INIT", "GAME_NEW"):
    m.call(r, limit=BIG)

# --- the counts follow COUNT, so GAME_START clears them with it ---------
cnt = m.addr("COUNT")
if (m.addr("SYBLT"), m.addr("SYGOLD"), m.addr("SYLOST")) != (cnt + 20, cnt + 40, cnt + 52) \
        or m.addr("SY_NCLR") != 58:
    fail("counts at %04X %04X %04X (COUNT %04X), SY_NCLR %d"
         % (m.addr("SYBLT"), m.addr("SYGOLD"), m.addr("SYLOST"), cnt, m.addr("SY_NCLR")))
for i in range(58):
    m.mem[cnt + i] = 0x55
m.call("GAME_NEW", limit=BIG)
if any(m.mem[cnt + i] for i in range(58)):
    fail("GAME_NEW left counts: %r" % [m.mem[cnt + i] for i in range(58)])

# --- buying counts every item, rebels too ------------------------------
m.call("MAP_INIT")
for p in (0, 1):
    m.poke(m.addr("GOLD") + 2 * p, 0x0F, 0x27)  # 9999
    sq = land(p, 3)
    for k, (c, r) in zip((I_FORT, I_CROP, I_CROP), sq):
        m.poke(m.addr("CURCOL") + p, c)
        m.poke(m.addr("CURROW") + p, r)
        if m.call("ECO_BUY", a=k, x=p, limit=BIG)[3]:
            fail("player %d couldn't buy %d at %d,%d" % (p + 1, k, c, r))
    m.call("ECO_BUY", a=I_FSBT, x=p, limit=BIG)  # into the harbour
    m.call("ECO_BUY", a=I_REBL, x=p, limit=BIG)  # for the other island
    m.call("ECO_BUY", a=I_PTBT, x=p, limit=BIG)  # refused: harbour taken
    want = {I_FORT: 1, I_CROP: 2, I_FSBT: 1, I_REBL: 1}
    got = {k: blt(p, k) for k in range(1, 10) if blt(p, k)}
    if got != want:
        fail("player %d bought %r, want %r" % (p + 1, got, want))
    if count(p, I_REBL):
        fail("player %d: a rebel in COUNT" % (p + 1))

# --- gold by source ------------------------------------------------------
m.call("GAME_NEW", limit=BIG)
m.poke("FCNT", 0, 0)
for _ in range(100):                     # 100 touches: 2 gold
    m.call("FISH_TOUCH", x=0, limit=BIG)
m.poke("EG_AMT", 3, 0)
m.call("SY_CROP", x=1)
m.poke("EG_AMT", 0x10, 0x01)             # 272
m.call("SY_CROP", x=1)
for p in (0, 1):                         # 2 factories, a school, a hospital,
    set_count(p, I_FACT, 2)              # 3 fishing boats: 8 + 3 + 5
    set_count(p, I_SCHL, 1)
    set_count(p, I_HOSP, 1)
    set_count(p, I_FSBT, 3)
    m.call("ECO_INCOME", x=p, limit=BIG)
want = [[2 + 3, 0, 13], [3, 275, 13]]
got = [[gold(p, s) for s in range(3)] for p in (0, 1)]
if got != want:
    fail("gold by source %r, want %r" % (got, want))
for p in (0, 1):
    if sum(got[p]) != rgold(p):
        fail("player %d: sources add up to %d, RGOLD %d" % (p + 1, sum(got[p]), rgold(p)))
m.poke("SYGOLD", 0xFE, 0xFF)             # stops at 65535
m.poke("EG_AMT", 5, 0)
m.call("SY_GOLD", x=0, y=0)
if gold(0, 0) != 65535:
    fail("gold over 65535: %d" % gold(0, 0))

# --- boats lost by cause -------------------------------------------------
m.call("GAME_NEW", limit=BIG)
for why in range(3):
    for p in (0, 1):
        for k in (I_PTBT, I_FSBT, I_CROP):
            set_count(p, k, 5)
            m.poke("WH_P", p)
            m.poke("WH_K", k)
            m.poke("SY_WHY", why)
            m.call("SY_LOSS")
            if count(p, k) != 4:
                fail("SY_LOSS: player %d item %d count %d" % (p + 1, k, count(p, k)))
got = [[lost(p, c) for c in range(3)] for p in (0, 1)]
if got != [[2, 2, 2], [2, 2, 2]]:
    fail("boats lost %r (crops must not count)" % got)

# in play: a pirate sinks player 2's steered fishing boat, player 1's PT
# boat player 2's other one; then the cause is weather again
m.call("GAME_NEW", limit=BIG)
m.call("ECO_INIT")
m.call("PIR_INIT")
m.call("WTH_INIT")
m.poke("RANDOM", NEVER)
set_count(1, I_FSBT, 2)
steer(0, 0, 0, 0)
steer(1, I_FSBT, 80, 4)
for name, v in (("FACT", 1), ("FXH", 80 + 8 + 7), ("FYH", 12), ("FVX", 0), ("FVY", 0),
                ("FXL", 0), ("FYL", 0)):
    m.mem[m.addr(name) + P] = v
m.call("SY_PIR", limit=BIG)
if [lost(1, c) for c in range(3)] != [0, 1, 0] or m.byte("BOATK", 1):
    fail("pirate: lost %r, BOATK %d" % ([lost(1, c) for c in range(3)], m.byte("BOATK", 1)))
m.call("PIR_INIT")
steer(1, I_FSBT, 80, 4)
steer(0, I_PTBT, 82, 6)
m.call("SY_PIR", limit=BIG)
if [lost(1, c) for c in range(3)] != [0, 1, 1] or m.byte("BOATK", 1) or m.byte("SY_WHY"):
    fail("PT boat: lost %r, BOATK %d, SY_WHY %d"
         % ([lost(1, c) for c in range(3)], m.byte("BOATK", 1), m.byte("SY_WHY")))
if any(lost(0, c) for c in range(3)):
    fail("player 1 lost %r" % [lost(0, c) for c in range(3)])

# --- the display list -----------------------------------------------------
dl = m.addr("SYDLIST")
lines, text_lines, dlis, lms, pc, hint_at = 0, 0, 0, [], dl, None
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
    if mode != 4:
        fail("SYDLIST: mode %X" % mode)
    if op & 0x40:
        lms.append(m.mem[pc + 1] | m.mem[pc + 2] << 8)
        if lms[-1] == m.addr("CT_HINT"):
            hint_at = lines
        pc += 3
    else:
        pc += 1
    lines += 8
if dlis != m.addr("CT_NDLI") or lines != 214 or hint_at != 206:
    fail("SYDLIST: %d DLIs, %d scan lines, hint at %r" % (dlis, lines, hint_at))
want = [m.addr("STATUS1"), m.addr("CT_TAB"), m.addr("SYSCR"), m.addr("CT_HINT")]
if lms != want or m.addr("SYSCR") & 0xFF:
    fail("SYDLIST screen addresses %r" % ["%04X" % a for a in lms])
if (pc + 2) >> 10 != dl >> 10:
    fail("SYDLIST %04X-%04X crosses a 1K boundary" % (dl, pc + 2))
if m.addr("SYEND") > m.addr("TTFONTA") or m.addr("SY_DRAW") < m.addr("PSFONTA"):
    fail("STATS4.ASM at %04X-%04X, not between the pause and title fonts"
         % (m.addr("SY_DRAW"), m.addr("SYEND")))

# --- the page ------------------------------------------------------------
m.call("GAME_NEW", limit=BIG)
built = [[3, 12, 40, 2, 1, 7, 0, 1, 104], [0, 5, 9, 0, 0, 2, 11, 3, 6]]
golds = [[1234, 7, 65535], [0, 960, 10000]]
losses = [[1, 0, 22], [0, 3, 1]]
for p in (0, 1):
    for k in range(9):
        m.mem[m.addr("SYBLT") + 10 * p + k + 1] = built[p][k]
    for s in range(3):
        m.poke(m.addr("SYGOLD") + 6 * p + 2 * s, golds[p][s] & 0xFF, golds[p][s] >> 8)
    for c in range(3):
        m.mem[m.addr("SYLOST") + 3 * p + c] = losses[p][c]
m.poke("SCORE", 0x34, 0x02, 0x21, 0x01)
m.poke("CURTRN", 5)
m.call("GAME_OVER", limit=BIG)
for i in range(1000):                    # an old chart in the memory
    m.mem[m.addr("SYSCR") + i] = 0xAA
m.call("CT_ENTER", limit=BIG)
if m.byte("CT_PG") != m.addr("CT_SUMP") or m.byte("SDLSTL") | m.byte("SDLSTH") << 8 != dl:
    fail("CT_ENTER: page %d, display list %02X%02X"
         % (m.byte("CT_PG"), m.byte("SDLSTH"), m.byte("SDLSTL")))


def screen(row):
    out = ""
    for i in range(40):
        c = m.byte("SYSCR", 40 * row + i)
        if c in (0x62, 0x63):
            out += "a"
        elif c in (0xE4, 0xE5):
            out += "b"
        else:
            out += chr((c & 0x3F) + 0x20) if c & 0x3F else " "
    return out


def put(line, end, text):
    return line[:end + 1 - len(text)] + text + line[end + 1:]


names = ["FORTS", "FACTORIES", "CROPS", "SCHOOLS", "HOSPITALS", "HOUSES", "REBELS",
         "PT BOATS", "FISH BOATS"]
right = {1: "FISHING", 2: "CROPS", 3: "FACTORIES", 6: "WEATHER", 7: "PIRATES", 8: "PT BOATS"}
expect = []
for row in range(10):
    line = " " * 40
    if row == 0:
        line = put(put(put(put(line, 4, "BUILT"), 12, "aa"), 16, "bb"), 27, "GOLD FROM")
        line = put(put(line, 33, "aa"), 39, "bb")
    else:
        line = put(line, len(names[row - 1]) - 1, names[row - 1])
        line = put(put(line, 12, str(built[0][row - 1])), 16, str(built[1][row - 1]))
    if row == 5:
        line = put(put(put(line, 28, "BOATS LOST"), 33, "aa"), 39, "bb")
    if row in right:
        line = put(line, 18 + len(right[row]), right[row])
        v = [golds[p][row - 1] for p in (0, 1)] if row < 4 else [losses[p][row - 6] for p in (0, 1)]
        line = put(put(line, 33, str(v[0])), 39, str(v[1]))
    expect.append(line)
for row in range(10):
    if screen(row) != expect[row]:
        fail("line %d:\n  got  %r\n  want %r" % (row, screen(row), expect[row]))
    print(screen(row))
# numbers in the players' colours, names plain
for row in range(1, 10):
    cols = ((12, 0x40), (16, 0x80)) + (((33, 0x40), (39, 0x80)) if row in right else ())
    for col, bits in cols:
        c = m.byte("SYSCR", 40 * row + col)
        if c & 0xC0 != bits:
            fail("line %d column %d: %02X, want colour bits %02X" % (row, col, c, bits))
    c = m.byte("SYSCR", 40 * row)
    if c & 0xC0:
        fail("line %d: name in colour %02X" % (row, c))
if any(m.byte("SYSCR", i) for i in range(400, 1000)):
    fail("SYSCR not cleared after the text")
# the page names: SUMMARY first and lit
tabs = "".join(chr((m.byte("CT_TAB", i) & 0x3F) + 0x20) if m.byte("CT_TAB", i) & 0x3F else " "
               for i in range(40))
if tabs.split() != ["SUMMARY", "SCORE", "PEOPLE", "INCOME"] or tabs.index("SUMMARY") != 2:
    fail("page names %r" % tabs)
lit = [i for i in range(40) if m.byte("CT_TAB", i) >= 0x80]
if lit != list(range(2, 9)):
    fail("lit columns %r" % lit)

# --- the stick: right to SCORE (the chart's list), left back --------------
m.poke("CT_J", 0)
for joy, pg, d in ((8, 0, "CTDLIST"), (0, 0, "CTDLIST"), (4, 3, "SYDLIST"), (0, 3, "SYDLIST"),
                   (4, 2, "CTDLIST"), (0, 2, "CTDLIST"), (8, 3, "SYDLIST")):
    m.poke("JOY0", joy)
    m.call("CT_FRAME", limit=BIG)
    if m.byte("CT_PG") != pg or m.byte("SDLSTL") | m.byte("SDLSTH") << 8 != m.addr(d):
        fail("stick %d: page %d display list %02X%02X, want %d %s"
             % (joy, m.byte("CT_PG"), m.byte("SDLSTH"), m.byte("SDLSTL"), pg, d))
# fire (after letting go): the setup screen and its display list
m.poke("JOY0", 0)
for fire in (0, 1):
    m.poke("FIRE0", fire)
    m.call("CT_FRAME", limit=BIG)
m.poke("FIRE0", 0)
if m.byte("CT_ON") or m.byte("SDLSTL") | m.byte("SDLSTH") << 8 != m.addr("SU_DL"):
    fail("leaving: CT_ON %d, display list %02X%02X"
         % (m.byte("CT_ON"), m.byte("SDLSTH"), m.byte("SDLSTL")))

print("summary: %d failed" % fails)
sys.exit(1 if fails else 0)
