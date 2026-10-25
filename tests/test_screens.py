#!/usr/bin/env python3
"""T-SCR-2: round loop, summary pages, info displays, game over (py65).

A whole 2-round game of 2-second rounds is played through GAME_FRAME,
one call per simulated NTSC frame, with the hardware faked as the
main loop would see it after each VBI.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

KC_6 = 0x1B                               # 6: house
START, SELECT, OPTION = 1, 2, 4
GS_PLAY, GS_SUM1, GS_SUM2, GS_OVER, GS_SETUP = 0, 1, 2, 3, 4
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def frame(kb=None, fire0=False, console=0):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF)
    m.poke("TRIG0", 0 if fire0 else 1)
    m.poke("TRIG1", 1)
    m.poke("CONSOL", 0x07 ^ console)      # active low
    if kb is None:
        m.poke("SKSTAT", 0xFF)
    else:
        m.poke("SKSTAT", 0xFB)
        m.poke("KBCODE", kb)
    m.call("GAME_FRAME")


def line(n):
    base = "STATUS1" if n == 1 else "STATUS2"
    return "".join(chr(m.byte(base, i) + 0x20) for i in range(40))


def frames_until(cond, limit):
    for i in range(limit):
        if cond():
            return i
        frame()
    return None


m.poke("PAL", 0x0F)                       # NTSC: 60 frames a second
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "GAME_NEW"):
    m.call(r)
if (m.byte("NUMTRN"), m.byte("TRNLEN"), m.byte("GSTATE")) != (10, 30, GS_PLAY):
    fail("GAME_NEW defaults %r" % [m.byte("NUMTRN"), m.byte("TRNLEN"), m.byte("GSTATE")])
m.poke("NUMTRN", 2)
m.poke("TRNLEN", 2)
m.call("GAME_START")
if "TURNS  2  TIME   2" not in line(1):
    fail("start of game: %r" % line(1))

# player 1 builds a house in round 1 so the scores differ
frame(kb=KC_6)
frame()
if m.word("GOLD") >= 100:
    fail("house not bought (gold %d)" % m.word("GOLD"))

# info pages while the key is held, the status line back when let go
for key, title, src in ((START, "TOTAL SCORE", "SCORE"), (SELECT, "POPULATION", "POP"),
                        (OPTION, "LAST ROUND", None)):
    frame(console=key)
    if title not in line(1):
        fail("console %d: %r" % (key, line(1)))
    if src == "POP" and ("%4d" % m.word("POP")) not in line(1)[:8]:
        fail("population page %r, pop %d" % (line(1), m.word("POP")))
frame()
if "GOLD" not in line(1) or "TURNS" not in line(1):
    fail("status line not restored: %r" % line(1))

# round 1 ends after 2 s: round scores for 3 s, then totals for 3 s
n = frames_until(lambda: m.byte("GSTATE") == GS_SUM1, 200)
if n is None or not 100 <= n <= 125:
    fail("round 1 did not end after about 2 s (%r frames)" % n)
if "ROUND SCORES" not in line(1):
    fail("round summary: %r" % line(1))
r1 = (m.byte("RSCORE"), m.byte("RSCORE", 1))
print("round 1 scores %r: %r" % (r1, line(1)))
if r1[0] <= r1[1]:
    fail("player 1 built a fort but scored %r" % (r1,))
gold = m.word("GOLD")
frame(kb=KC_6)                            # keys do nothing in a summary
frame(console=START)
if m.word("GOLD") != gold or "ROUND SCORES" not in line(1):
    fail("a key acted during the summary: %r" % line(1))
n = frames_until(lambda: m.byte("GSTATE") == GS_SUM2, 400)
if n is None or not 170 <= n <= 185:
    fail("round page lasted %r frames, want 180" % n)
if "TOTAL SCORES" not in line(1):
    fail("totals page: %r" % line(1))
n = frames_until(lambda: m.byte("GSTATE") == GS_PLAY, 400)
if n is None or not 175 <= n <= 185:
    fail("totals page lasted %r frames, want 180" % n)
if "TURNS  1  TIME   2" not in line(1):
    fail("round 2 status line: %r" % line(1))

# round 2, then game over
n = frames_until(lambda: m.byte("GSTATE") == GS_OVER, 1000)
if n is None:
    fail("no game over after round 2")
if "FINAL SCORES" not in line(1) or "PLAYER 1 WINS" not in line(2):
    fail("game over: %r / %r" % (line(1), line(2)))
print("game over: %r" % line(1))
print("           %r" % line(2))
if m.byte("CURTRN") != 2:
    fail("CURTRN %d after the game" % m.byte("CURTRN"))

# nothing runs on the game-over screen; fire held over does not restart
for _ in range(120):
    frame(fire0=True)
if m.byte("GSTATE") != GS_OVER:
    fail("fire held over from the round restarted the game")
frame()
frame(fire0=True)
if m.byte("GSTATE") != GS_SETUP:
    fail("fire did not go back to the setup screen (state %d)" % m.byte("GSTATE"))
for _ in range(10):                       # fire still held: setup waits
    frame(fire0=True)
frame()
frame(fire0=True)                         # fire on the setup screen
if m.byte("GSTATE") != GS_PLAY or m.word("GOLD") != 100 or m.word("SCORE") != 0:
    fail("fire did not start a new game (state %d gold %d)" % (m.byte("GSTATE"), m.word("GOLD")))
if m.byte("NUMTRN") != 10 or "TURNS 10  TIME  30" not in line(1):
    fail("new game status line %r" % line(1))

for _ in range(61):                       # the clock starts afresh
    frame()
if m.byte("REMSEC") != 29:
    fail("1 s into the new game, TIME %d" % m.byte("REMSEC"))

# a draw: equal totals
m.call("GAME_START")
m.poke("SCORE", 7, 1, 7, 1)
m.call("GAME_OVER")
if "DRAW" not in line(2):
    fail("equal totals: %r" % line(2))
m.poke("SCORE", 7, 1, 8, 1)
m.call("GAME_OVER")
if "PLAYER 2 WINS" not in line(2):
    fail("player 2 ahead: %r" % line(2))

print("screens: %d failed" % fails)
sys.exit(1 if fails else 0)
