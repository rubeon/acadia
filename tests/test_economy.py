#!/usr/bin/env python3
"""T-ECO-1: buying items at the cursor, and KEYPL routing (D17) (py65)."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

COLS = 20
PRICES = {1: 50, 2: 40, 3: 3, 4: 35, 5: 75, 6: 60}
R_ITEM, R_LAND, R_TAKEN, R_GOLD = 1, 2, 3, 4
KBCODE_2 = 0x1E                       # keyboard code of "2"

m = Machine()
m.call("VARS_INIT")
m.call("MAP_ROWS")
m.call("MAP_DRAW")
m.call("MAP_INIT")
m.call("PM_INIT")
m.call("CUR_INIT")
m.call("GAME_NEW")                    # 100 gold each
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def gold(p):
    a = m.addr("GOLD") + 2 * p
    return m.mem[a] | m.mem[a + 1] << 8


def set_gold(p, v):
    m.poke(m.addr("GOLD") + 2 * p, v, v >> 8)


def count(p, item):
    return m.byte("COUNT", 10 * p + item)


def item_at(col, row):
    return m.byte("MAPITEM", row * COLS + col)


def cursor(p, col, row):
    m.poke(m.addr("CURCOL") + p, col)
    m.poke(m.addr("CURROW") + p, row)


def buy(p, item):
    a, _, _, c = m.call("ECO_BUY", a=item, x=p)
    return (False, a) if c else (True, None)


def expect_buy(what, p, item, col, row, ok, reason=None):
    cursor(p, col, row)
    g0, n0, i0 = gold(p), count(p, item), item_at(col, row)
    got = buy(p, item)
    if ok:
        want_g = g0 - PRICES[item]
        if got != (True, None) or gold(p) != want_g or count(p, item) != n0 + 1 \
                or item_at(col, row) != item:
            fail("%s: got %r, gold %d (want %d), count %d, item %d"
                 % (what, got, gold(p), want_g, count(p, item), item_at(col, row)))
    else:
        if got != (False, reason) or gold(p) != g0 or count(p, item) != n0 \
                or item_at(col, row) != i0:
            fail("%s: got %r, want refusal %d; gold %d->%d" % (what, got, reason, g0, gold(p)))


# player 1 (index 0) on the left island, player 2 on the right
expect_buy("P1 fort on own land", 0, 1, 4, 5, True)
expect_buy("occupied square", 0, 3, 4, 5, False, R_TAKEN)
expect_buy("P1 on P2's island", 0, 3, 14, 5, False, R_LAND)
expect_buy("sea square", 0, 3, 9, 5, False, R_LAND)
expect_buy("harbour square", 0, 3, 1, 4, False, R_LAND)
expect_buy("off the map", 0, 3, 20, 5, False, R_LAND)
for item in (7, 8, 9):
    expect_buy("item %d not yet" % item, 0, item, 5, 5, False, R_ITEM)
expect_buy("P2 factory on own land", 1, 2, 14, 5, True)
expect_buy("P2 on P1's island", 1, 3, 5, 5, False, R_LAND)

# gold boundaries
set_gold(0, 35)
expect_buy("exactly enough", 0, 4, 5, 5, True)
if gold(0) != 0:
    fail("gold not 0 after exact purchase")
set_gold(0, 74)
expect_buy("one short", 0, 5, 6, 5, False, R_GOLD)
set_gold(0, 2)
expect_buy("crop one short", 0, 3, 6, 5, False, R_GOLD)
set_gold(0, 300)                      # borrow across the high byte
expect_buy("16-bit gold", 0, 6, 6, 5, True)
if gold(0) != 240:
    fail("gold %d after 300 - 60" % gold(0))

# the status bar shows the new gold: "GOLD  240" at offset 5
txt = "".join(chr(m.byte("STATUS1", 5 + i) + 0x20) for i in range(4))
if txt != " 240":
    fail("status bar gold %r" % txt)

# KEYPL routing through INPUT_POLL (D17), with the hardware faked
def press(fire0, fire1):
    m.poke("PORTA", 0xFF)             # sticks centred
    m.poke("TRIG0", 0 if fire0 else 1)
    m.poke("TRIG1", 0 if fire1 else 1)
    m.poke("KBCODE", KBCODE_2)
    m.poke("SKSTAT", 0xFB)            # bit 2 clear: a key is held
    m.poke("KEYDOWN", 0)              # a fresh press
    m.call("INPUT_POLL")
    return m.byte("KEY"), m.byte("KEYPL")


for f0, f1, want in [(0, 0, (2, 0)), (1, 0, (2, 0)), (0, 1, (2, 1)), (1, 1, (0xFF, 0xFF))]:
    got = press(f0, f1)
    if got != want:
        fail("fire %d/%d: KEY, KEYPL = %r, want %r" % (f0, f1, got, want))
m.poke("KEYDOWN", 1)                  # key still held: no repeat
m.call("INPUT_POLL")
if (m.byte("KEY"), m.byte("KEYPL")) != (0xFF, 0xFF):
    fail("held key repeated")

# end to end: player 2 holds fire and presses 2 -> factory at their cursor
cursor(1, 15, 3)
g = gold(1)
press(0, 1)
m.call("ECO_KEY")
if item_at(15, 3) != 2 or gold(1) != g - 40:
    fail("ECO_KEY: player 2's factory not bought (item %d, gold %d)" % (item_at(15, 3), gold(1)))

print("economy: %d failed" % fails)
sys.exit(1 if fails else 0)
