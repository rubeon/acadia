#!/usr/bin/env python3
"""T-SCR-4: status line 2, populations and the news slot (py65)."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


m = Machine()
NW_TICS = 60
NW = {"HURR": 0, "PSNK": 1, "LAND": 2, "TAKN": 3, "GOLD": 4, "SINK": 5, "DMG": 6,
      "REBL": 7, "NOBT": 8, "NOPK": 9}
TEXT = {"LAND": "NOT YOUR LAND",
        "TAKN": "SQUARE TAKEN", "GOLD": "NOT ENOUGH GOLD", "HURR": "HURRICANE!",
        "SINK": "BOAT SUNK", "PSNK": "PIRATE SUNK", "DMG": "STORM DAMAGE",
        "REBL": "REBELS!", "NOBT": "NO BOAT HERE", "NOPK": "NO PARKING HERE"}


def line2():
    return m.status(40, 40)


def slot():
    return line2()[10:30]


def centred(text):
    left = (20 - len(text)) // 2
    return (" " * left + text).ljust(20)


def start(players):
    for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT"):
        m.call(r)
    m.poke("SU_VAL", 10, 30, players, 2)
    m.call("GAME_NEW")


# every message, alone and with each prefix: centred, fits, keeps A, X, Y
for players, prefixes in ((2, ("P1 ", "P2 ")), (1, ("P1 ", "CPU "))):
    start(players)
    for name, n in NW.items():
        for x, pre in ((0xFF, ""), (0, prefixes[0]), (1, prefixes[1])):
            m.call("NEWS_OFF")
            a, rx, ry, _ = m.call("NEWS", a=n, x=x, y=0x3C)
            if (a, rx, ry) != (n, x, 0x3C):
                fail("NEWS %s changed registers: %02X %02X %02X" % (name, a, rx, ry))
            want = centred(pre + TEXT[name])
            if len(pre + TEXT[name]) > 20 or slot() != want:
                fail("NEWS %s, player %02X: %r, want %r" % (name, x, slot(), want))
    if line2()[:10] != "  @@ 1000 " or line2()[30:] != "   @@ 1000":
        fail("populations disturbed: %r" % line2())
print("line 2: %r" % line2())

# NEWSG keeps X and shows no prefix
start(2)
a, x, y, _ = m.call("NEWSG", a=NW["HURR"], x=0x77, y=0x11)
if (a, x, y) != (NW["HURR"], 0x77, 0x11) or slot() != centred("HURRICANE!"):
    fail("NEWSG: %02X %02X %02X %r" % (a, x, y, slot()))

# priority: a refusal does not hide a sunk boat; a sunk boat replaces a
# refusal; the slot clears after NW_TICS tics
m.call("NEWS_OFF")
m.call("NEWS", a=NW["SINK"], x=0)
m.call("NEWS", a=NW["GOLD"], x=1)
if slot() != centred("P1 BOAT SUNK"):
    fail("refusal replaced a sunk boat: %r" % slot())
for _ in range(NW_TICS - 1):
    m.call("NEWS_TIC")
if slot() != centred("P1 BOAT SUNK"):
    fail("cleared early: %r" % slot())
m.call("NEWS_TIC")
if slot() != " " * 20 or m.byte("NW_T"):
    fail("not cleared after %d tics: %r" % (NW_TICS, slot()))
m.call("NEWS", a=NW["GOLD"], x=1)
m.call("NEWS", a=NW["SINK"], x=0)
if slot() != centred("P1 BOAT SUNK"):
    fail("sunk boat did not replace a refusal: %r" % slot())

# refusals: shown for people, not for the CPU
for players, want in ((2, centred("P2 NOT YOUR LAND")), (1, " " * 20)):
    start(players)
    a, x, y, _ = m.call("NEWS_REF", a=NW["LAND"], x=1, y=5)
    if (a, x, y) != (NW["LAND"], 1, 5) or slot() != want:
        fail("NEWS_REF, %d players: %r (%02X %02X %02X)" % (players, slot(), a, x, y))
start(1)
m.call("NEWS_REF", a=NW["LAND"], x=0)
if slot() != centred("P1 NOT YOUR LAND"):
    fail("NEWS_REF player 1, 1 player: %r" % slot())

# ECO_BUY's refusal reason reaches the slot: a house on the sea
start(2)
m.poke(m.addr("CURCOL") + 0, 0)
m.poke(m.addr("CURROW") + 0, 0)
a, _, _, c = m.call("ECO_BUY", a=1, x=0)
if not c or slot() != centred("P1 NOT YOUR LAND"):
    fail("ECO_BUY on the sea: C=%d A=%d %r" % (c, a, slot()))

# game over leaves line 2 to the winner
start(2)
m.call("NEWS", a=NW["HURR"], x=0xFF)
m.call("GAME_OVER")
if "POP" in line2() or "HURRICANE" in line2():
    fail("game over line 2: %r" % line2())
print("game over: %r" % line2())

print("news: %d failed" % fails)
sys.exit(1 if fails else 0)
