#!/usr/bin/env python3
"""T-5200-2: the 5200 cartridge played with its controllers (py65).

The cartridge's start-up (MAIN_INIT's steps), then GAME_FRAME once per
simulated frame with the BIOS's pot shadows, the triggers, KBCODE,
SKSTAT and CONSOL faked: the title screen, the setup screen, a game
started with START, the stick, buying, the top button, *, PAUSE and
#; then a 2-player game's keys per controller.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

CODE = {"#": 1, "0": 2, "*": 3, "9": 5, "8": 6, "P": 8, "5": 10, "S": 12, "1": 15}
C, LO, HI = 114, 6, 220          # atari800's pot values for a digital stick
m = Machine(cart=True)
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def check(what, got, want):
    if got != want:
        fail("%s: got %r, want %r" % (what, got, want))


m.poke("PAL", 0x0F)                       # NTSC
m.poke("POKMSK", 0xC0)                    # as the BIOS leaves it
m.poke("VVBLKD", 0xB2, 0xFC)
for r in ("VARS_INIT", "PLAT_INIT", "SND_INIT", "DISP_INIT", "TIC_INIT",
          "SETUP_INIT", "TITLE_ENTER"):
    m.call(r)


def frame(n=1, pots=(C, C, C, C), trig=(1, 1), pad=(None, None), bot=(False, False)):
    for _ in range(n):
        m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
        m.poke("PADDL0", *pots)
        m.poke("TRIG0", trig[0])
        m.poke("TRIG1", trig[1])
        c = m.byte("CONSOL") & 3
        sk = 0xFF
        if pad[c] is not None:
            sk &= ~0x04
            m.poke("KBCODE", 0x21 | CODE[pad[c]] << 1)
        if bot[c]:
            sk &= ~0x08
        m.poke("SKSTAT", sk)
        m.call("GAME_FRAME", limit=2000000)


def press(k, ctl=0, hold=4, rest=6):
    pad = (k, None) if ctl == 0 else (None, k)
    frame(hold, pad=pad)
    frame(rest)


GS_TITLE, GS_SETUP = m.sym["GS_TITLE"], m.sym["GS_SETUP"]

# title: the bottom button (fire) goes on to the setup screen
frame(10)
check("title", m.byte("GSTATE"), GS_TITLE)
frame(3, bot=(True, False))
frame(5)
check("fire on the title: setup", m.byte("GSTATE"), GS_SETUP)

# setup: stick down twice to PLAYERS, left for 1 player, START begins
frame(10)
for pots in ((C, HI, C, C), (C, HI, C, C), (LO, C, C, C)):
    frame(2, pots=pots)
    frame(3)
check("1 player chosen", m.byte("SU_VAL", m.sym["SU_FPLY"]), 1)
press("#")                                   # # does not begin a game here
check("# on the setup screen", m.byte("GSTATE"), GS_SETUP)
press("S")
check("START begins the game", m.byte("GSTATE"), 0)

# the stick moves the cursor, diagonals too
x, y = m.byte("CURX"), m.byte("CURY")
frame(20, pots=(HI, HI, C, C))
check("stick down-right moves the cursor",
      (m.byte("CURX") > x, m.byte("CURY") > y), (True, True))
frame(5)

# 9 buys a fishing boat (the gold goes down); the top button is key 0
gold = m.word("GOLD")
press("9")
if m.word("GOLD") >= gold:
    fail("9 did not buy a boat: gold %d -> %d" % (gold, m.word("GOLD")))
frame(1, trig=(0, 1))                        # key 0 reaches the game
check("the top button in a game: key 0", (m.byte("KEY"), m.byte("KEYPL")), (0, 0))
frame(5)

# * opens and closes the help screen
press("*")
check("* opens help", m.byte("HELPON"), 1)
press("*")
check("* closes help", m.byte("HELPON"), 0)

# PAUSE pauses and resumes
press("P")
check("PAUSE pauses", m.byte("PAUSED"), 1)
press("P")
check("PAUSE resumes", m.byte("PAUSED"), 0)

# # held: totals, then populations, then last round; let go: none
pages = []
for _ in range(3):
    frame(4, pad=("#", None))
    pages.append(m.byte("INFOK"))
    frame(3)
    check("# let go", m.byte("INFOK"), 0)
check("# pages", pages, [1, 2, 3])
frame(4, pad=("S", None))
check("START held: totals", m.byte("INFOK"), 1)
frame(3)

# --- a 2-player game: each controller's keys are its player's ---
m.poke("SU_VAL", 5, 60, 2, 2, 1)
m.call("GAME_START")
frame(10)
g0, g1 = m.word("GOLD"), m.word(m.addr("GOLD") + 2)
while m.byte("CONSOL") & 3 != 1:
    frame()
frame(4, pad=(None, "9"))                    # controller 2's turn
frame(6)
check("controller 2's 9: player 1's gold", m.word("GOLD"), g0)
if m.word(m.addr("GOLD") + 2) >= g1:
    fail("controller 2's 9 did not buy for player 2")
g1 = m.word(m.addr("GOLD") + 2)
press("8", ctl=0)
if m.word("GOLD") >= g0:
    fail("controller 1's 8 did not buy for player 1")
check("controller 1's 8: player 2's gold", m.word(m.addr("GOLD") + 2), g1)
# both on PAUSE at once (atari800 presses every keypad): one toggle
frame(6, pad=("P", "P"))
frame(4)
check("PAUSE on both controllers", m.byte("PAUSED"), 1)

print("play5200: %d failed" % fails)
sys.exit(1 if fails else 0)
