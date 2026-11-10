#!/usr/bin/env python3
"""T-SCR-1, T-SCR-6: the setup screen (py65; D31, D65).

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
ROUNDS, SECS, PLAYERS, LEVEL, MAP = range(5)
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
    """Value line n (a field) as text: help font code = ASCII (D65)."""
    base = m.addr("MAPSCR") + 40 + 40 * n
    return "".join(chr(m.mem[base + i] & 0x7F) if m.mem[base + i] else " " for i in range(40))


def white(n):
    """1 for each non-blank character of line n that is white."""
    base = m.addr("MAPSCR") + 40 + 40 * n
    return {m.mem[base + i] >> 7 for i in range(40) if m.mem[base + i]}


def minimap():
    base = m.addr("MAPSCR") + 240
    return [m.mem[base + 20 * r + 7 + i] for r in range(11) for i in range(6)]


def check(want, what):
    if vals() != want:
        fail("%s: values %r, want %r" % (what, vals(), want))


m.poke("PAL", 0x0F)
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "SETUP_ENTER"):
    m.call(r)
# its display list: SUDLIST copied to SU_DL, past the map, inside 1K (D71)
sudl = m.addr("SU_DL")
dl = m.byte("SDLSTL") | m.byte("SDLSTH") << 8
if m.byte("GSTATE") != GS_SETUP or dl != sudl:
    fail("setup screen not shown (display list %04X)" % dl)
n = m.addr("SU_DLE") - m.addr("SUDLIST")
if m.mem[sudl:sudl + n] != m.mem[m.addr("SUDLIST"):m.addr("SUDLIST") + n]:
    fail("display list not copied")
if sudl < m.addr("MAPSCR") + 928 or (sudl ^ (sudl + n - 1)) & 0xFC00:
    fail("display list at %04X-%04X" % (sudl, sudl + n - 1))
if m.mem[sudl + n - 2] | m.mem[sudl + n - 1] << 8 != sudl:
    fail("display list does not loop to itself")
if m.mem[sudl + 4] | m.mem[sudl + 5] << 8 != m.addr("LOGO") + 40:
    fail("logo not shown")
if m.byte("CHBAS") != m.addr("HLPFONT") >> 8 or m.byte("COLOR4") != m.byte("TTBK"):
    fail("not the help font under the title's sky")
# the title's clouds within the logo rows, SU_SKY0 P/M lines higher (D71)
pmc = m.addr("TT_PMC") - m.addr("SU_SKY0")
ncp = m.addr("SU_NCP")
for pl, shp in enumerate(("TCP0", "TCP1", "TCP2")):
    base = pmc + pl * m.addr("PM_LEN")
    if m.mem[base:base + ncp] != m.mem[m.addr(shp):m.addr(shp) + ncp] or m.mem[base + ncp]:
        fail("cloud shapes in player %d" % pl)
cx0 = m.byte("TT_CX")
if any(m.mem[m.addr("MAPSCR"):m.addr("MAPSCR") + 40]):
    fail("first line not empty (no GAME SETUP under the logo)")
prompt = "".join(chr(c & 0x7F) if c else " "
                 for c in m.mem[m.addr("MAPSCR") + 460:m.addr("MAPSCR") + 500])
if prompt.strip() != "PRESS START OR FIRE TO BEGIN":
    fail("prompt %r" % prompt)
check([10, 30, 2, 2], "defaults")
for _ in range(20):
    frame(fire0=True)                     # held: nothing begins
if m.byte("TT_CX") == cx0:
    fail("the clouds do not drift")
if "ROUNDS" not in row(0) or row(0)[3] != ">" or row(0)[33:36] != " 10":
    fail("rounds line %r" % row(0))
if white(0) != {1} or white(1) != {0}:
    fail("current line not white, or another line white")
if "SECONDS PER ROUND" not in row(1) or row(1)[33:36] != " 30":
    fail("seconds line %r" % row(1))
if row(3)[35] != "-":
    fail("CPU level with 2 players %r" % row(3))
if row(4)[28:36] != "STANDARD":
    fail("map line %r" % row(4))
mm = [m.byte("MMAP0", i) for i in range(66)]
if minimap() != mm or mm[2 * 6 + 1] != 0x6A:
    fail("STANDARD's minimap not shown")
print("setup: %r" % row(0))

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
for _ in range(10):                      # 70 to 120
    tap(stick=RIGHT)
check([50, 120, 2, 2], "right to 120")
tap(stick=RIGHT)
check([50, 30, 2, 2], "right from 120 goes round to 30")
tap(stick=LEFT)
check([50, 120, 2, 2], "left from 30 goes round to 120")
typ("47")
check([50, 47, 2, 2], "typed 47")
typ("200")
tap(stick=UP)
check([50, 120, 2, 2], "typed 200 clamped on leaving")
tap(stick=RIGHT)
check([1, 120, 2, 2], "right from 50 rounds goes round to 1")
tap(stick=LEFT)
check([50, 120, 2, 2], "left from 1 round goes round to 50")
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
if row(2)[3] != ">" or white(2) != {1} or white(0) != {0}:
    fail("marker not on PLAYERS: %r" % row(2))

# 1 player: CPU LEVEL can be chosen; digits out of range are ignored
tap(stick=RIGHT)                          # 2 goes round to 1
check([1, 120, 1, 2], "1 player")
typ("7")
check([1, 120, 1, 2], "7 players ignored")
tap(stick=DOWN)
if m.byte("SU_FLD") != LEVEL or row(3)[30:36] != "MEDIUM":
    fail("CPU level line: field %d, %r" % (m.byte("SU_FLD"), row(3)))
typ("3")
typ("9")
check([1, 120, 1, 3], "CPU level 3, 9 ignored")
if row(3)[30:36] != "  HARD":
    fail("CPU level 3: %r" % row(3))
tap(stick=RIGHT)
if row(3)[30:36] != "  EASY":
    fail("CPU level right from HARD: %r" % row(3))
tap(stick=LEFT)
check([1, 120, 1, 3], "CPU level left from EASY goes round to HARD")
tap(stick=DOWN)
if m.byte("SU_FLD") != MAP or row(4)[28:36] != "STANDARD":
    fail("1 player: down from CPU LEVEL: field %d, %r" % (m.byte("SU_FLD"), row(4)))
# the map line: names and minimaps, digits 1-3, going round
for d, name, mp in (("2", "  RANDOM", 1), ("3", " SANDBOX", 2), ("4", " SANDBOX", 2),
                    ("1", "STANDARD", 0)):
    typ(d)
    if row(4)[28:36] != name:
        fail("map %s: %r" % (d, row(4)))
    if minimap() != [m.byte("MMAP%d" % mp, i) for i in range(66)]:
        fail("map %s: minimap not map %d's" % (d, mp + 1))
for n, want in ((1, 2), (2, 3), (3, 1)):
    tap(stick=RIGHT)
    if m.byte("SU_VAL", MAP) != want:
        fail("map right x %d: %d" % (n, m.byte("SU_VAL", MAP)))
tap(stick=LEFT)
tap(stick=LEFT)
if m.byte("SU_VAL", MAP) != 2:
    fail("map left x 2 from STANDARD: %d" % m.byte("SU_VAL", MAP))
tap(stick=LEFT)
if m.byte("SU_VAL", MAP) != 1:
    fail("map left: %d" % m.byte("SU_VAL", MAP))
# SANDBOX (D87): ROUNDS, PLAYERS and CPU LEVEL show "-" and are skipped
typ("3")
if [row(i)[35] for i in (0, 2, 3)] != ["-"] * 3 or row(1)[33:36] != "120":
    fail("SANDBOX lines: %r" % [row(i) for i in range(4)])
tap(stick=DOWN)
if m.byte("SU_FLD") != 1:
    fail("SANDBOX: down from MAP went to %d" % m.byte("SU_FLD"))
tap(stick=UP)
if m.byte("SU_FLD") != MAP:
    fail("SANDBOX: up from SECONDS went to %d" % m.byte("SU_FLD"))
typ("1")
if row(0)[35] == "-" or m.byte("SU_VAL", MAP) != 1:
    fail("STANDARD again: %r" % row(0))
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
tap(stick=RIGHT)                          # back to 2 players
check([3, 120, 2, 3], "2 players")

# START begins with these values
tap(console=START)
if m.byte("GSTATE") != GS_PLAY:
    fail("START did not begin (state %d)" % m.byte("GSTATE"))
if (m.byte("NUMTRN"), m.byte("TRNLEN"), m.byte("REMSEC")) != (3, 120, 120):
    fail("game settings %r" % [m.byte("NUMTRN"), m.byte("TRNLEN"), m.byte("REMSEC")])
if m.byte("SDLSTL") | m.byte("SDLSTH") << 8 != m.addr("DLIST"):
    fail("map display list not back")
if any(m.mem[pmc:pmc + ncp]):
    fail("clouds still in P/M memory in the game")
if [m.byte("SIZEP%d" % k) for k in range(3)] != [0, 0, 1] or m.byte("GPRIOR") != 0x11:
    fail("player sizes or priority not the game's")
line1 = "".join(chr(m.byte("STATUS1", i) + 0x20) for i in range(40))
if "TURNS  3  TIME 120" not in line1:
    fail("status line %r" % line1)
print("game:  %r" % line1)

# after game over, the setup screen comes back with the same values
m.call("GAME_OVER")
frame()
tap(fire0=True)                 # the stats screen (D61), then setup
tap(fire0=True)
if m.byte("GSTATE") != GS_SETUP:
    fail("no setup screen after game over (state %d)" % m.byte("GSTATE"))
check([3, 120, 2, 3], "values kept for the next game")
if m.byte("SU_FLD") != ROUNDS or row(0)[33:36] != "  3":
    fail("setup after game over %r" % row(0))

print("setup: %d failed" % fails)
sys.exit(1 if fails else 0)
