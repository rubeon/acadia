#!/usr/bin/env python3
"""T-SCR-1: the setup screen (py65).

GAME_FRAME is called once per simulated frame with the sticks,
triggers, console keys and keyboard faked, as the main loop would.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

UP, DOWN, LEFT, RIGHT = 1, 2, 4, 8
START, SELECT = 1, 2
GS_PLAY, GS_OVER, GS_SETUP = 0, 3, 4
KC = {"0": 0x32, "1": 0x1F, "2": 0x1E, "3": 0x1A, "4": 0x18,
      "5": 0x1D, "6": 0x1B, "7": 0x33, "8": 0x35, "9": 0x30}
ROUNDS, SECS, PLAYERS, LEVEL, KEYPAD, MAP = range(6)
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def frame(stick=0, fire0=False, console=0, kb=None):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF ^ stick)
    m.poke("TRIG0", 0 if fire0 else 1)
    m.poke("TRIG1", 1)
    m.poke("CONSOL", 0x07 ^ console)
    if kb is None:
        m.poke("SKSTAT", 0xFF)
    else:
        m.poke("SKSTAT", 0xFB)
        m.poke("KBCODE", kb)
    m.call("GAME_FRAME")


def tap(**kw):
    frame(**kw)
    frame()


def typ(digits):
    for d in digits:
        tap(kb=KC[d])


def vals():
    return [m.byte("SU_VAL", i) for i in range(4)]


def row(n):
    base = m.addr("MAPSCR") + 20 + 40 * n
    return "".join(chr((m.mem[base + i] & 0x7F) + 0x20) for i in range(40))


def check(want, what):
    if vals() != want:
        fail("%s: values %r, want %r" % (what, vals(), want))


m.poke("PAL", 0x0F)
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "SETUP_ENTER"):
    m.call(r)
if m.byte("GSTATE") != GS_SETUP or m.byte("SDLSTL") != m.addr("SUDLIST") & 0xFF:
    fail("setup screen not shown")
if (m.addr("SUDLIST") ^ m.addr("DLIST")) & 0xFF00:
    fail("SUDLIST and DLIST are not in the same page")
title = "".join(chr(m.mem[m.addr("MAPSCR") + i] + 0x20) for i in range(20))
if title.strip() != "ACADIA":
    fail("title %r" % title)
check([10, 30, 2, 2], "defaults")
if "ROUNDS" not in row(3) or not row(3).startswith("  >") or row(3)[32:35] != " 10":
    fail("rounds line %r" % row(3))
if "SECONDS PER ROUND" not in row(5) or row(5)[32:35] != " 30":
    fail("seconds line %r" % row(5))
if row(9)[34] != "-":
    fail("CPU level with 2 players %r" % row(9))
print("setup: %r" % row(3))

# fire held from the game before does nothing until let go
for _ in range(5):
    frame(fire0=True)
if m.byte("GSTATE") != GS_SETUP:
    fail("held fire started the game")
frame()

# typing rounds: "25", then "99" brought into range on leaving
typ("25")
check([25, 30, 2, 2], "typed 25")
typ("99")
check([99, 30, 2, 2], "typed 99 (shown as typed)")
tap(stick=DOWN)
check([50, 30, 2, 2], "99 rounds clamped on leaving")
if m.byte("SU_FLD") != SECS:
    fail("down did not move to seconds")

# seconds: right steps 5, held right repeats after 20 frames, then every 5
tap(stick=RIGHT)
check([50, 35, 2, 2], "right")
for i in range(46):                      # 1 + 20 + 5 x 5 frames held
    frame(stick=RIGHT)
frame()
if vals()[SECS] != 35 + 5 * 7:         # now, at 21, then 26 31 36 41 46
    fail("held right: %d seconds, want %d" % (vals()[SECS], 35 + 35))
for _ in range(100):
    frame(stick=RIGHT)
frame()
check([50, 120, 2, 2], "right stops at 120")
for _ in range(200):
    frame(stick=LEFT)
frame()
check([50, 30, 2, 2], "left stops at 30")
typ("47")
check([50, 47, 2, 2], "typed 47")
typ("200")
tap(stick=UP)
check([50, 120, 2, 2], "typed 200 clamped on leaving")
typ("0")
tap(console=SELECT)
check([1, 120, 2, 2], "typed 0 rounds clamped to 1")

# lines: with 2 players CPU LEVEL is skipped both ways
if m.byte("SU_FLD") != SECS:
    fail("SELECT did not move to the next line")
tap(stick=DOWN)
tap(stick=DOWN)
if m.byte("SU_FLD") != MAP:
    fail("2 players: down from PLAYERS went to %d" % m.byte("SU_FLD"))
tap(stick=DOWN)
if m.byte("SU_FLD") != ROUNDS:
    fail("2 players: down from MAP went to %d" % m.byte("SU_FLD"))
tap(stick=UP)
if m.byte("SU_FLD") != MAP:
    fail("2 players: up from ROUNDS went to %d" % m.byte("SU_FLD"))
tap(stick=UP)
if m.byte("SU_FLD") != PLAYERS:
    fail("2 players: up from MAP went to %d" % m.byte("SU_FLD"))
if not row(7).startswith("  >"):
    fail("marker not on PLAYERS: %r" % row(7))

# 1 player: CPU LEVEL can be chosen; digits out of range are ignored
tap(stick=LEFT)
check([1, 120, 1, 2], "1 player")
typ("7")
check([1, 120, 1, 2], "7 players ignored")
tap(stick=DOWN)
if m.byte("SU_FLD") != LEVEL or row(9)[32:35] != "  2":
    fail("CPU level line: field %d, %r" % (m.byte("SU_FLD"), row(9)))
typ("3")
typ("9")
check([1, 120, 1, 3], "CPU level 3, 9 ignored")
tap(stick=DOWN)
if m.byte("SU_FLD") != KEYPAD or row(11)[32:35] != " NO":
    fail("1 player: down from CPU LEVEL: field %d, %r" % (m.byte("SU_FLD"), row(11)))
typ("5")
typ("1")
if m.byte("SU_VAL", KEYPAD) != 1 or row(11)[32:35] != "YES":
    fail("keypad 1 (5 ignored): %d, %r" % (m.byte("SU_VAL", KEYPAD), row(11)))
tap(stick=DOWN)
if m.byte("SU_FLD") != MAP or row(13)[29:35] != "ACADIA":
    fail("1 player: down from KEYPAD: field %d, %r" % (m.byte("SU_FLD"), row(13)))
box = m.addr("MAPSCR") + 20 + 40 * 13
if [m.mem[box + i] >> 7 for i in range(27, 37)] != [0, 1, 1, 1, 1, 1, 1, 1, 1, 0]:
    fail("map line: inverse box not over columns 28-35")
# the map line: names, digits 1-4, RANDOM last
for d, name in (("2", " ISLES"), ("3", "LAGOON"), ("4", "RANDOM"), ("7", "RANDOM"), ("1", "ACADIA")):
    typ(d)
    if row(13)[29:35] != name:
        fail("map %s: %r" % (d, row(13)))
tap(stick=RIGHT)
tap(stick=RIGHT)
tap(stick=RIGHT)
tap(stick=RIGHT)
if m.byte("SU_VAL", MAP) != 4:
    fail("map right x 4: %d" % m.byte("SU_VAL", MAP))
tap(stick=LEFT)
tap(stick=LEFT)
tap(stick=LEFT)
tap(stick=LEFT)
if m.byte("SU_VAL", MAP) != 1:
    fail("map left x 4: %d" % m.byte("SU_VAL", MAP))
tap(stick=DOWN)
if m.byte("SU_FLD") != ROUNDS:
    fail("1 player: down from MAP went to %d" % m.byte("SU_FLD"))
tap(stick=RIGHT)
tap(stick=RIGHT)
check([3, 120, 1, 3], "rounds 3")
tap(stick=UP)                             # 1 player: up from ROUNDS
if m.byte("SU_FLD") != MAP:
    fail("1 player: up from ROUNDS went to %d" % m.byte("SU_FLD"))
tap(stick=UP)
tap(stick=UP)
tap(stick=UP)
tap(stick=RIGHT)                          # back to 2 players
tap(stick=RIGHT)                          # stays at 2
check([3, 120, 2, 3], "2 players")
if row(11)[32:35] != "  -":
    fail("2 players: keypad line %r" % row(11))

# START begins with these values
tap(console=START)
if m.byte("GSTATE") != GS_PLAY:
    fail("START did not begin (state %d)" % m.byte("GSTATE"))
if (m.byte("NUMTRN"), m.byte("TRNLEN"), m.byte("REMSEC")) != (3, 120, 120):
    fail("game settings %r" % [m.byte("NUMTRN"), m.byte("TRNLEN"), m.byte("REMSEC")])
if m.byte("SDLSTL") != m.addr("DLIST") & 0xFF:
    fail("map display list not back")
if m.byte("KPMODE"):
    fail("keypad on in a 2-player game")
line1 = "".join(chr(m.byte("STATUS1", i) + 0x20) for i in range(40))
if "TURNS  3  TIME 120" not in line1:
    fail("status line %r" % line1)
print("game:  %r" % line1)

# after game over, the setup screen comes back with the same values
m.call("GAME_OVER")
frame()
tap(fire0=True)
if m.byte("GSTATE") != GS_SETUP:
    fail("no setup screen after game over (state %d)" % m.byte("GSTATE"))
check([3, 120, 2, 3], "values kept for the next game")
if m.byte("SU_VAL", KEYPAD) != 1:
    fail("keypad setting not kept")
if m.byte("SU_FLD") != ROUNDS or row(3)[32:35] != "  3":
    fail("setup after game over %r" % row(3))

print("setup: %d failed" % fails)
sys.exit(1 if fails else 0)
