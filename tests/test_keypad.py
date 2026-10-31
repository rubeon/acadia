#!/usr/bin/env python3
"""T-CTL-2: keypad controller in port 2 (D49), with the PIA, pots and
trigger of port 2 faked on py65."""

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
PORTA, PACTL = m.addr("PORTA"), m.addr("PACTL")
pia = {"ddr": 0, "out": 0xFF}
held = {"key": None, "plugged": True, "stick2": 0xF0}   # key: (row, column)
vcount = [0]
LAYOUT = ["123", "456", "789", "*0#"]


def porta_write(address, value):
    if m.mem[PACTL] & 0x04:
        pia["out"] = value
    else:
        pia["ddr"] = value


def row():
    """The row whose line is driven low, or None."""
    for r in range(4):
        bit = 0x10 << r
        if pia["ddr"] & bit and not pia["out"] & bit:
            return r
    return None


def low(col):
    """Is this column line held low?"""
    if not held["plugged"]:
        return col < 2              # pots never charge, trigger floats high
    return held["key"] is not None and held["key"] == (row(), col)


def allpot(address):
    # left column on pot 3, middle on pot 2, as Atari's CX21 reader (D58)
    return (0x08 if low(0) else 0) | (0x04 if low(1) else 0)


def trig1(address):
    return 0 if low(2) else 1


def porta_read(address):
    hi = (pia["out"] & pia["ddr"] | held["stick2"] & ~pia["ddr"]) & 0xF0
    return hi | 0x0F                # stick 1 centred


def vc(address):
    vcount[0] = (vcount[0] + 1) & 0x7F
    return vcount[0]


m.mem.subscribe_to_write([PORTA], porta_write)
m.mem.subscribe_to_read([PORTA], porta_read)
m.mem.subscribe_to_read([m.addr("ALLPOT")], allpot)
m.mem.subscribe_to_read([m.addr("TRIG1")], trig1)
m.mem.subscribe_to_read([m.addr("VCOUNT")], vc)
m.poke("PACTL", 0x3C)
m.poke("TRIG0", 1)
m.poke("CONSOL", 7)
m.poke("SKSTAT", 0xFF)             # no keyboard key


def scan(key=None):
    """One full keypad scan (4 polls) with key (a character) held."""
    held["key"] = None
    for r, line in enumerate(LAYOUT):
        if key and key in line:
            held["key"] = (r, line.index(key))
    got = []
    for _ in range(4):
        m.call("INPUT_POLL")
        got.append((m.byte("KEY"), m.byte("KEYPL"), m.byte("PAUSEK"), m.byte("HELPK")))
    return got


m.call("VARS_INIT")
m.call("KP_ON")
if pia["ddr"] != 0xF0 or not m.mem[PACTL] & 0x04 or m.byte("KPMODE") != 1:
    fail("KP_ON: DDR %02X PACTL %02X KPMODE %d" % (pia["ddr"], m.mem[PACTL], m.byte("KPMODE")))

# every key: reported once, on the last poll of the scan that sees it
NONE = (0xFF, 0xFF, 0, 0)
for line in LAYOUT:
    for k in line:
        got = scan(k)
        if k == "*":
            want = (0xFF, 0xFF, 1, 0)
        elif k == "#":
            want = (0xFF, 0xFF, 0, 1)
        else:
            want = (int(k), 0, 0, 0)
        if got != [NONE, NONE, NONE, want]:
            fail("key %s: %r" % (k, got))
        if scan(k) != [NONE] * 4:
            fail("key %s held: repeated" % k)
        if scan() != [NONE] * 4:
            fail("key %s let go: %r" % (k, scan()))
print("keys 0-9, *, # ok" if not fails else "keys: failures")

# the attract timer is reset while a key is held
m.poke("ATRACT", 0x50)
scan("5")
if m.byte("ATRACT"):
    fail("ATRACT not reset by a keypad key")
scan()

# no stick 2 while the keypad is in: rows and the trigger don't show
held["key"] = (0, 2)
m.call("INPUT_POLL")
if m.byte("JOY1") or m.byte("FIRE1"):
    fail("keypad mode: JOY1 %02X FIRE1 %d" % (m.byte("JOY1"), m.byte("FIRE1")))
scan()

# a keyboard key in the same poll wins
held["key"] = (2, 0)
for i in range(4):
    if i == 3:
        m.poke("KBCODE", m.byte("KEYTAB", 4))
        m.poke("SKSTAT", 0xFB)
        m.poke("KEYDOWN", 0)
    m.call("INPUT_POLL")
if m.byte("KEY") != 4:
    fail("keyboard 4 with keypad 7: KEY %d" % m.byte("KEY"))
m.poke("SKSTAT", 0xFF)
scan()

# no controller in port 2: nothing
held["plugged"] = False
if any(g != NONE for _ in range(3) for g in scan()):
    fail("unplugged keypad gave a key")
held["plugged"] = True

# KP_OFF: port 2 is a stick again
m.call("KP_OFF")
held["stick2"] = 0xE0               # stick 2 up
m.call("INPUT_POLL")
if pia["ddr"] or m.byte("KPMODE") or m.byte("JOY1") != 1:
    fail("KP_OFF: DDR %02X KPMODE %d JOY1 %02X" % (pia["ddr"], m.byte("KPMODE"), m.byte("JOY1")))
held["stick2"] = 0xF0

# GAME_START finds a keypad in port 2 by itself (D58): only in a
# 1-player game, and not with a stick or nothing in the port; the setup
# screen turns it off
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT"):
    m.call(r)
held["key"] = None
for players, plugged, want in ((1, True, 1), (1, False, 0), (2, True, 0)):
    held["plugged"] = plugged
    m.poke("SU_VAL", 10, 30, players, 2)
    m.call("GAME_START")
    if m.byte("KPMODE") != want or pia["ddr"] != (0xF0 if want else 0):
        fail("GAME_START %d players, keypad %s: KPMODE %d DDR %02X"
             % (players, plugged, m.byte("KPMODE"), pia["ddr"]))
    m.call("SETUP_ENTER")
    if m.byte("KPMODE") or pia["ddr"]:
        fail("SETUP_ENTER left the keypad on")
held["plugged"] = True

# a key held while the game starts doesn't hide the keypad: no row is
# driven low yet, so every column still charges
held["key"] = (1, 1)
m.poke("SU_VAL", 10, 30, 1, 2)
m.call("GAME_START")
if m.byte("KPMODE") != 1:
    fail("GAME_START with 5 held: no keypad")
m.call("SETUP_ENTER")
held["key"] = None

# one pot charging (a paddle) is not a keypad
allpot_one = [0x08]
m.mem.subscribe_to_read([m.addr("ALLPOT")], lambda a: allpot_one[0])
m.call("GAME_START")
if m.byte("KPMODE"):
    fail("GAME_START with one pot charged: keypad on")
m.call("SETUP_ENTER")

print("keypad: %d failed" % fails)
sys.exit(1 if fails else 0)
