#!/usr/bin/env python3
"""T-CTL-4: a tap of a fire button is key 0 for its player (D60) (py65).

GAME_FRAME is called once per simulated frame with the sticks,
triggers and keyboard faked, as the main loop would.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

KC = {"1": 0x1F, "8": 0x35, "9": 0x30}
I_PTBT, I_FSBT, I_P1 = 8, 9, 0x80
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def frame(fire0=False, fire1=False, kb=None):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF)
    m.poke("TRIG0", 0 if fire0 else 1)
    m.poke("TRIG1", 0 if fire1 else 1)
    m.poke("CONSOL", 0x07)
    if kb is None:
        m.poke("SKSTAT", 0xFF)
    else:
        m.poke("SKSTAT", 0xFB)
        m.poke("KBCODE", kb)
    m.call("GAME_FRAME")


def tap(p, held=3):
    for _ in range(held):
        frame(fire0=(p == 0), fire1=(p == 1))
    frame()


def boatk(p):
    return m.byte("BOATK", p)


def item(col, row):
    return m.byte("MAPITEM", row * 20 + col)


def put_cursor(p, col, row):
    x = [m.byte("CURX"), m.byte("CURX", 1)]
    y = [m.byte("CURY"), m.byte("CURY", 1)]
    x[p], y[p] = col * 8, row * 8
    m.poke("CURX", *x)
    m.poke("CURY", *y)
    frame()


m.poke("PAL", 0x0F)
m.poke("RANDOM", 5)                      # no weather or fish events
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "GAME_NEW"):
    m.call(r)
frame()

harb = []
for p in (0, 1):
    _, x, y, _ = m.call("MAP_HARB", a=p)
    harb.append((x, y))
(h0c, h0r), (h1c, h1r) = harb

# boats in both harbours: player 1 by key, player 2 holding fire (D17)
frame(kb=KC["8"])
frame()
frame(fire1=True, kb=KC["9"])
frame(fire1=True)
frame()
if item(h0c, h0r) != I_PTBT or item(h1c, h1r) != I_FSBT | I_P1:
    fail("boats not bought: %02x %02x" % (item(h0c, h0r), item(h1c, h1r)))
if boatk(1) != 0:
    fail("fire held for a digit counted as a tap: BOATK+1 = %d" % boatk(1))

# a tap of player 1's fire lifts the boat under the cursor, like key 0
put_cursor(0, h0c, h0r)
tap(0)
if boatk(0) != I_PTBT or item(h0c, h0r) != 0:
    fail("fire tap did not lift P1's boat: BOATK %d item %d" % (boatk(0), item(h0c, h0r)))
if boatk(1) != 0:
    fail("P1's tap acted for P2")

# held, nothing happens until it is let go
for _ in range(10):
    frame(fire0=True)
if boatk(0) != I_PTBT:
    fail("boat parked while fire still held")
frame()
if boatk(0) != 0 or item(h0c, h0r) != I_PTBT:
    fail("fire tap did not park P1's boat: BOATK %d item %d" % (boatk(0), item(h0c, h0r)))

# player 2's fire is player 2's key 0
put_cursor(1, h1c, h1r)
tap(1)
if boatk(1) != I_FSBT or boatk(0) != 0:
    fail("P2 fire tap: BOATK %d %d" % (boatk(0), boatk(1)))
tap(1)
if boatk(1) != 0 or item(h1c, h1r) != I_FSBT | I_P1:
    fail("P2 fire tap did not park: BOATK+1 %d item %02x" % (boatk(1), item(h1c, h1r)))

# fire held with a digit: the digit, and no tap on release
frame(fire1=True)
frame(fire1=True, kb=KC["1"])
frame(fire1=True)
frame()
frame()
if boatk(1) != 0:
    fail("fire + digit also lifted the boat")

# while paused a tap does nothing
frame(kb=0x0A)                           # P
frame()
if not m.byte("PAUSED"):
    fail("P did not pause")
frame(fire0=True)
frame()
if boatk(0) != 0:
    fail("tap acted while paused")
frame(kb=0x0A)
frame()

# a fire still held from the setup screen is no tap
frame(fire1=True)
m.call("GAME_START")
frame(fire1=True)
frame()
if m.byte("KEY") == 0 or m.byte("FTAP", 1) != 0:
    fail("fire held into GAME_START counted as a tap: KEY %02x" % m.byte("KEY"))

if fails:
    print("test_fire_tap: %d failure(s)" % fails)
    sys.exit(1)
print("test_fire_tap: ok")
