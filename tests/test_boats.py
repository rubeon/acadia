#!/usr/bin/env python3
"""T-EVT-1: buying, picking up, steering and parking boats (py65).

GAME_FRAME is called once per simulated frame with the sticks,
triggers and keyboard faked, as the main loop would.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

UP, DOWN, LEFT, RIGHT = 1, 2, 4, 8
KC = {"0": 0x32, "1": 0x1F, "8": 0x35, "9": 0x30}
I_PTBT, I_FSBT, I_P1 = 8, 9, 0x80
K_LAND, K_HARB, K_KIND = 1, 3, 0x7F
SH_CUR, SH_PT, SH_FISH = 0, 1, 2
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def frame(s0=0, s1=0, fire1=False, kb=None):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF ^ (s0 | (s1 << 4)))
    m.poke("TRIG0", 1)
    m.poke("TRIG1", 0 if fire1 else 1)
    m.poke("CONSOL", 0x07)
    if kb is None:
        m.poke("SKSTAT", 0xFF)
    else:
        m.poke("SKSTAT", 0xFB)
        m.poke("KBCODE", kb)
    m.call("GAME_FRAME")


def key(k, p=0):
    frame(kb=KC[k], fire1=(p == 1))
    frame()


def idx(col, row):
    return row * 20 + col


def item(col, row):
    return m.byte("MAPITEM", idx(col, row))


def kind(col, row):
    return m.byte("ISLKIND", idx(col, row))


def gold(p):
    return m.word("GOLD") if p == 0 else m.byte("GOLD", 2) | m.byte("GOLD", 3) << 8


def chars(col, row):
    a = m.addr("MAPSCR") + row * 80 + col * 2
    return m.mem[a], m.mem[a + 1]


def tilech(t):
    return m.byte("TILECH", t)


def pos(p):
    return m.byte("CURX", p), m.byte("CURY", p)


def put_cursor(p, col, row):
    m.poke("CURX", *([col * 8] if p == 0 else [m.byte("CURX"), col * 8]))
    m.poke("CURY", *([row * 8] if p == 0 else [m.byte("CURY"), row * 8]))
    frame()


def box_on_land(x, y):
    for c in {x // 8, (x + 7) // 8}:
        for r in {y // 8, (y + 7) // 8}:
            if kind(c, r) & K_KIND == K_LAND:
                return True
    return False


m.poke("PAL", 0x0F)
m.poke("RANDOM", 5)                      # no weather or fish events (1-in-N rolls fail)
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "GAME_NEW"):
    m.call(r)

# harbours: MAP_HARB finds each player's
harb = []
for p in (0, 1):
    _, x, y, _ = m.call("MAP_HARB", a=p)
    harb.append((x, y))
    if kind(x, y) != K_HARB | (p << 7):
        fail("MAP_HARB(%d) = %r, kind %02x" % (p, (x, y), kind(x, y)))
print("harbours %r" % harb)
(h0c, h0r), (h1c, h1r) = harb
pier0 = chars(h0c, h0r)

# buying: into the harbour wherever the cursor is
key("8")
if item(h0c, h0r) != I_PTBT or gold(0) != 60 or m.byte("COUNT", I_PTBT) != 1:
    fail("P1 PT boat: item %d gold %d" % (item(h0c, h0r), gold(0)))
if chars(h0c, h0r) != (tilech(9), tilech(9) + 1):
    fail("P1 PT boat drawn %r" % (chars(h0c, h0r),))
key("9")
if item(h0c, h0r) != I_PTBT or gold(0) != 60:
    fail("bought into an occupied harbour (gold %d)" % gold(0))
key("9", p=1)
if item(h1c, h1r) != I_FSBT | I_P1 or gold(1) != 75 or m.byte("COUNT", 10 + I_FSBT) != 1:
    fail("P2 fishing boat: item %02x gold %d" % (item(h1c, h1r), gold(1)))
if chars(h1c, h1r) != (tilech(10) | 0x80, (tilech(10) + 1) | 0x80):
    fail("P2 boat not drawn inverse: %r" % (chars(h1c, h1r),))

# key 0 away from a boat: refused
key("0")
if m.byte("BOATK") != 0:
    fail("picked up a boat from an island square")

# pick up the PT boat in the harbour
put_cursor(0, h0c, h0r)
key("0")
if m.byte("BOATK") != I_PTBT or item(h0c, h0r) != 0 or m.byte("SPRSHP") != SH_PT:
    fail("pick-up: BOATK %d item %d shape %d" % (m.byte("BOATK"), item(h0c, h0r), m.byte("SPRSHP")))
if chars(h0c, h0r) != pier0:
    fail("harbour not redrawn as terrain")
if m.byte("COUNT", I_PTBT) != 1:
    fail("picking up changed COUNT")

# speed: 2 pixels every 3 frames, stops dead when let go
x0, y0 = pos(0)
for _ in range(15):
    frame(s0=UP)
x1, y1 = pos(0)
if (x1, y0 - y1) != (x0, 10):
    fail("15 frames up: %r -> %r, want 10 lines" % ((x0, y0), (x1, y1)))
for _ in range(10):
    frame()
if pos(0) != (x1, y1):
    fail("boat drifted after letting go: %r -> %r" % ((x1, y1), pos(0)))

# a long random voyage: never on land, never off the map
rnd = random.Random(1)
stick = 0
for i in range(3000):
    if i % 25 == 0:
        stick = rnd.choice([UP, DOWN, LEFT, RIGHT, UP | LEFT, UP | RIGHT, DOWN | LEFT,
                            DOWN | RIGHT, RIGHT, RIGHT, LEFT, LEFT])
    frame(s0=stick)
    x, y = pos(0)
    if x > 152 or y > 80 or box_on_land(x, y):
        fail("boat at %r: off the map or on land" % ((x, y),))
        break
print("after the voyage the boat is at %r" % (pos(0),))

# against the island: holding right from the harbour stops at the coast
put_cursor(0, h0c, h0r)
for _ in range(60):
    frame(s0=RIGHT)
x, y = pos(0)
if box_on_land(x, y) or not box_on_land(x + 1, y):
    fail("east of the harbour the boat stopped at %r" % ((x, y),))

# buying land items while steering: the square is sea, refused
g = gold(0)
key("1")
if gold(0) != g:
    fail("bought a fort while steering")

# parking: open sea square in row 0
put_cursor(0, 9, 0)
key("0")
if item(9, 0) != I_PTBT or m.byte("BOATK") != 0 or m.byte("SPRSHP") != SH_CUR:
    fail("park: item %d BOATK %d" % (item(9, 0), m.byte("BOATK")))

# P2 can't pick up P1's boat; P1 can again
put_cursor(1, 9, 0)
key("0", p=1)
if m.byte("BOATK", 1) != 0 or item(9, 0) != I_PTBT:
    fail("P2 picked up P1's boat")
put_cursor(0, 9, 0)
key("0")
if m.byte("BOATK") != I_PTBT:
    fail("P1 could not pick up its parked boat")

# parking on a square with a boat on it: refused
m.call("MAP_SET", a=I_FSBT | I_P1, x=9, y=0)
key("0")
if m.byte("BOATK") != I_PTBT or item(9, 0) != I_FSBT | I_P1:
    fail("parked on top of another boat")

# P2 picks up its fishing boat from its harbour (fire held + 0)
put_cursor(1, h1c, h1r)
key("0", p=1)
if m.byte("BOATK", 1) != I_FSBT or m.byte("SPRSHP", 1) != SH_FISH:
    fail("P2 fishing boat pick-up: %d" % m.byte("BOATK", 1))
x, y = pos(1)
for _ in range(30):
    frame(s1=LEFT)
if pos(1)[0] != x or box_on_land(*pos(1)):
    fail("P2 boat went west into its island: %r -> %r" % ((x, y), pos(1)))

# a new game: cursors again
m.call("GAME_START")
if m.byte("BOATK") or m.byte("BOATK", 1) or m.byte("SPRSHP") or m.byte("SPRSHP", 1):
    fail("GAME_START left a boat in hand")

print("boats: %d failed" % fails)
sys.exit(1 if fails else 0)
