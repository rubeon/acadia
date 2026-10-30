#!/usr/bin/env python3
"""T-MAP-2: map grid get/set, drawing and the fort-adjacency check (py65)."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

COLS, ROWS = 20, 11
MAPSCR = 0x3400
K_SEA, K_LAND, K_HARB, K_P1 = 0x00, 0x01, 0x03, 0x80

m = Machine()
m.call("VARS_INIT")
m.call("MAP_ROWS")
m.call("MAP_DRAW")
m.call("MAP_INIT")
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def get(col, row):
    a, x, y, c = m.call("MAP_GET", x=col, y=row)
    if (x, y) != (col & 0xFF, row & 0xFF):
        fail("MAP_GET changed X/Y")
    return a, m.byte("MKIND"), c


def put(item, col, row):
    return m.call("MAP_SET", a=item, x=col, y=row)


def chars(col, row):
    """The square's 4 characters: top left, top right, bottom left, right."""
    a = MAPSCR + row * 80 + col * 2
    return m.mem[a], m.mem[a + 1], m.mem[a + 40], m.mem[a + 41]


def tile_chars(t):
    return tuple(m.byte(n, t) for n in ("TILECH", "TILECTR", "TILECBL", "TILECBR"))


def near(col, row):
    a, x, y, c = m.call("FORT_NEAR", x=col, y=row)
    if (x, y) != (col, row):
        fail("FORT_NEAR changed X/Y")
    return (c, a if c else None)


islkind = [m.byte("ISLKIND", i) for i in range(COLS * ROWS)]
isltile = [m.byte("ISLTILE", i) for i in range(COLS * ROWS)]
if any(m.byte("MAPITEM", i) for i in range(COLS * ROWS)):
    fail("MAP_INIT left items")

# kinds and owners straight from the island data
for col, row, want in [(4, 5, K_LAND), (14, 5, K_LAND | K_P1), (9, 5, K_SEA),
                       (1, 4, K_HARB), (18, 4, K_HARB | K_P1), (0, 0, K_SEA)]:
    a, kind, c = get(col, row)
    if (a, kind, c) != (0, want, False):
        fail("MAP_GET(%d,%d) = %r, want kind $%02X" % (col, row, (a, kind, c), want))
for col, row in [(20, 0), (0, 11), (255, 255), (19, 200)]:
    if get(col, row) != (0, K_SEA, True):
        fail("MAP_GET(%d,%d) off the map not handled" % (col, row))

# set, draw, remove, redraw terrain
T_FORT = m.addr("T_FORT")
put(1, 4, 5)
if get(4, 5)[0] != 1 or chars(4, 5) != tile_chars(T_FORT):
    fail("fort not stored or drawn at 4,5")
put(4, 14, 5)                        # a school: inverse (white) tile
if chars(14, 5) != tile_chars(T_FORT + 3) or chars(14, 5)[0] & 0x80 == 0:
    fail("school not drawn with inverse characters")
put(0, 4, 5)
if get(4, 5)[0] != 0 or chars(4, 5) != tile_chars(isltile[5 * COLS + 4]):
    fail("removing the fort did not restore the terrain")
before = [m.byte("MAPITEM", i) for i in range(COLS * ROWS)]
for col, row in [(20, 3), (3, 11)]:
    if not put(1, col, row)[3]:
        fail("MAP_SET(%d,%d) off the map did not set C" % (col, row))
if [m.byte("MAPITEM", i) for i in range(COLS * ROWS)] != before:
    fail("MAP_SET off the map changed the grid")
put(0, 14, 5)

# fort adjacency: the 8 neighbours, not the square itself
put(1, 5, 5)
for dc, dr in [(1, 0), (-1, 1), (0, 1), (1, 1), (-1, 0), (1, -1), (0, -1), (-1, -1)]:
    if near(5 + dc, 5 + dr) != (True, 0):
        fail("fort at 5,5 not seen from %d,%d" % (5 + dc, 5 + dr))
for col, row in [(5, 5), (7, 5), (5, 7), (3, 3), (7, 7)]:
    if near(col, row)[0]:
        fail("fort at 5,5 wrongly seen from %d,%d" % (col, row))
put(0, 5, 5)
put(1, 16, 6)                        # player 1's fort (right island land)
if islkind[6 * COLS + 16] != K_LAND | K_P1:
    fail("test layout: 16,6 is not player 1's land")
if near(15, 5) != (True, 1):
    fail("player 1's fort owner not reported")
put(0, 16, 6)

# edges: no wrap from one row's end to the next row's start
# (19,3) is open sea, so this "fort" has no owner bit: owner 0)
put(1, 19, 3)
if near(0, 4)[0] or near(0, 3)[0]:
    fail("fort at 19,3 seen across the row wrap")
if near(18, 4) != (True, 0) or near(19, 2) != (True, 0):
    fail("fort at 19,3 not seen from its real neighbours")
put(0, 19, 3)
put(1, 0, 0)
if near(1, 1) != (True, 0) or near(19, 10)[0]:
    fail("corner fort at 0,0 handled wrongly")
if near(0, 0)[0]:
    fail("square itself counted")

print("map: %d failed" % fails)
sys.exit(1 if fails else 0)
