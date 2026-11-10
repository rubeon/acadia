#!/usr/bin/env python3
"""T-MODE-1 (D87): the SANDBOX map (py65).

MAP_LOAD draws SANDBOX's one big island (SBLAND) on RANDOM's sea; the
setup screen skips ROUNDS, PLAYERS and CPU LEVEL with it; a sandbox
game has no CPU and no player 2 on the status bar, counts rounds up
and never ends by itself; pause, then START ends it; key 7 is refused.
Played through GAME_FRAME as in test_screens.py.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

K_SEA, K_LAND, K_HARB, K_KIND, K_P1 = 0, 1, 3, 0x7F, 0x80
ROWS, COLS = 11, 20
LONG = 5000000
KC_P, KC_7 = 0x0A, 0x33
START = 1
GS_PLAY, GS_SUM1, GS_SUM2, GS_OVER, GS_SETUP = 0, 1, 2, 3, 4
R_LAND = 2
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def table(name):
    return [m.byte(name, i) for i in range(ROWS * COLS)]


def frame(kb=None, console=0):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF)
    m.poke("TRIG0", 1)
    m.poke("TRIG1", 1)
    m.poke("CONSOL", 0x07 ^ console)      # active low
    if kb is None:
        m.poke("SKSTAT", 0xFF)
    else:
        m.poke("SKSTAT", 0xFB)
        m.poke("KBCODE", kb)
    m.call("GAME_FRAME", limit=LONG)


def tap(kb=None, console=0):
    frame(kb=kb, console=console)
    frame()


def line(n):
    return m.status(0 if n == 1 else 40, 40)


m.poke("PAL", 0x0F)                       # NTSC
m.poke("COLRSH", 0)
m.poke("DRKMSK", 0xFF)
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT"):
    m.call(r)
SBX = m.addr("MAP_SBX")
if m.addr("N_MAPS") != SBX + 1:
    fail("SANDBOX is not the last map")
name = "".join(chr((m.byte("MAPNAME", 8 * SBX + i) & 0x3F) + 0x20) for i in range(8))
if name != " SANDBOX":
    fail("map name %r" % name)

# the island: SBLAND's bits in rows 2-8, player 1's, one harbour,
# RANDOM's coast pieces, no sea shut in
m.call("MAP_LOAD", a=SBX, limit=LONG)
kinds, tiles = table("ISLKIND"), table("ISLTILE")
bits = []
for i in range((m.addr("SB_NSQ") + 7) // 8):
    b = m.byte("SBLAND", i)
    bits += [(b >> (7 - k)) & 1 for k in range(8)]
want = [K_SEA] * (ROWS * COLS)
for i in range(m.addr("SB_NSQ")):
    if bits[i]:
        want[m.addr("SB_SQ0") + i] = K_LAND
want[m.addr("SB_HSQ")] = K_HARB
if kinds != want:
    bad = [i for i in range(ROWS * COLS) if kinds[i] != want[i]]
    fail("ISLKIND differs from SBLAND at %d squares, first %d" % (len(bad), bad[0]))
land = [i for i, k in enumerate(kinds) if k == K_LAND]
if not 58 <= len(land) <= 70:
    fail("SANDBOX has %d land squares, want about two islands' (58)" % len(land))
if any(k & K_P1 for k in kinds):
    fail("SANDBOX has squares of player 2")
if tiles[m.addr("SB_HSQ")] != m.addr("SB_HTL"):
    fail("harbour tile %d" % tiles[m.addr("SB_HSQ")])
for i in land:
    mask = sum(b for b, d in ((1, -COLS), (2, 1), (4, COLS), (8, -1))
               if kinds[i + d] & K_KIND == K_LAND)
    r, c = divmod(i, COLS)
    t = m.byte("GRSTL", (r & 3) * 4 + (c & 3)) if mask == 15 else m.byte("RNDTILE", mask)
    if tiles[i] != t:
        fail("square %d, %d tile %d, want %d" % (r, c, tiles[i], t))
        break
up = table("AI_UP")
if any(k & K_KIND != K_LAND and up[i] == 255 for i, k in enumerate(kinds)):
    fail("sea shut in by land")
seen, todo = set(), [land[0]]
while todo:
    i = todo.pop()
    if i in land and i not in seen:
        seen.add(i)
        todo += [i - 1, i + 1, i - COLS, i + COLS]
if len(seen) != len(land):
    fail("the island is in pieces")
m.call("MAP_LOAD", a=0, limit=LONG)       # STANDARD again, then SANDBOX
m.call("MAP_LOAD", a=SBX, limit=LONG)
if table("ISLKIND") != kinds:
    fail("SANDBOX after STANDARD differs")

# setup: with SANDBOX only SECONDS and MAP can be chosen; "-" for the rest
fmap = m.addr("SU_FMAP")
m.poke("SU_VAL", 10, 30, 2, 2, SBX + 1)
m.poke("SU_FLD", fmap)
seq = []
for _ in range(4):
    m.call("SU_NEXT")
    seq.append(m.byte("SU_FLD"))
if seq != [1, fmap, 1, fmap]:
    fail("SANDBOX: SU_NEXT goes %r" % seq)
seq = []
for _ in range(2):
    m.call("SU_PREV")
    seq.append(m.byte("SU_FLD"))
if seq != [1, fmap]:
    fail("SANDBOX: SU_PREV goes %r" % seq)
m.poke("SU_VAL", 10, 30, 1, 2, 1)         # STANDARD, 1 player: every line
m.poke("SU_FLD", 0)
seq = []
for _ in range(5):
    m.call("SU_NEXT")
    seq.append(m.byte("SU_FLD"))
if seq != [1, 2, 3, 4, 0]:
    fail("STANDARD, 1 player: SU_NEXT goes %r" % seq)
m.poke("SU_VAL", 10, 30, 2, 2, 1)         # 2 players: no CPU level
m.poke("SU_FLD", 2)
m.call("SU_NEXT")
if m.byte("SU_FLD") != fmap:
    fail("2 players: SU_NEXT from PLAYERS to %d" % m.byte("SU_FLD"))

# a sandbox game: 2 rounds set, 2-second rounds
m.poke("SU_VAL", 2, 30, 2, 2, SBX + 1)
m.call("SU_GO", limit=LONG)
m.poke("TRNLEN", 2)
m.poke("REMSEC", 2)
if m.byte("MAPNO") != SBX or m.byte("MAPLD") != SBX:
    fail("SU_GO: MAPNO %d, loaded %d" % (m.byte("MAPNO"), m.byte("MAPLD")))
frame()
l1, l2 = line(1), line(2)
print("status: %r / %r" % (l1, l2))
if "ROUND  1" not in l1 or "TURNS" in l1:
    fail("round number: %r" % l1)
if l1[33:].strip() or l2[33:].strip():
    fail("player 2 on the status bar: %r / %r" % (l1, l2))
if m.byte("SPRHP", 1):
    fail("player 2's cursor shown at %d" % m.byte("SPRHP", 1))

# key 7 is refused: no other island
gold = m.word("GOLD")
a, _, _, c = m.call("ECO_BUY", a=7, x=0, limit=LONG)
if not c or a != R_LAND or m.word("GOLD") != gold:
    fail("key 7 in SANDBOX: carry %r, A %d, gold %d -> %d" % (c, a, gold, m.word("GOLD")))

# rounds go on past NUMTRN; the CPU never acts
for want in (2, 3, 4):
    n = 0
    while m.byte("GSTATE") != GS_PLAY or m.byte("CURTRN") < want - 1:
        frame()
        n += 1
        if m.byte("GSTATE") == GS_OVER or n > 1500:
            fail("round %d: game over or stuck (GSTATE %d)" % (want, m.byte("GSTATE")))
            break
    frame()
    if ("ROUND%3d" % want) not in line(1):
        fail("round %d: %r" % (want, line(1)))
if m.byte("COUNT", 10 + 8) or m.byte("COUNT", 10 + 9) or m.byte("AIST"):
    fail("the CPU acted: AIST %d" % m.byte("AIST"))

# SB_RND stops at 255
m.poke("CURTRN", 254)
m.call("SB_RND")
m.call("SB_RND")
if m.byte("CURTRN") != 255:
    fail("CURTRN after 255: %d" % m.byte("CURTRN"))
m.poke("CURTRN", 3)

# START does nothing special while running; pause, START ends the game
frame(console=START)
frame()
if m.byte("GSTATE") == GS_OVER:
    fail("START without pause ended the game")
tap(kb=KC_P)
if not m.byte("PAUSED"):
    fail("P did not pause")
frame()
if "START: END GAME" not in line(2):
    fail("pause hint: %r" % line(2))
frame(console=START)
if m.byte("GSTATE") != GS_OVER or m.byte("PAUSED"):
    fail("pause + START: GSTATE %d, PAUSED %d" % (m.byte("GSTATE"), m.byte("PAUSED")))
if "SANDBOX FINISHED" not in line(2):
    fail("game over line 2: %r" % line(2))
if "P2" in line(1):
    fail("game over line 1 shows player 2: %r" % line(1))

# not SANDBOX: pause + START does nothing
m.poke("SU_VAL", 2, 30, 2, 2, 1)
m.call("SU_GO", limit=LONG)
frame()
tap(kb=KC_P)
frame(console=START)
frame()
if m.byte("GSTATE") == GS_OVER or not m.byte("PAUSED"):
    fail("STANDARD: pause + START: GSTATE %d, PAUSED %d" % (m.byte("GSTATE"), m.byte("PAUSED")))
if "START: END GAME" in line(2):
    fail("STANDARD shows the sandbox hint: %r" % line(2))

print("sandbox: %d failed" % fails)
sys.exit(1 if fails else 0)
