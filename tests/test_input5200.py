#!/usr/bin/env python3
"""T-5200-2: the 5200 input layer (input5200.asm, D63) on a 6502 core.

Runs the cartridge's own INPUT_POLL (build/acadia5200.bin at $4000)
with the BIOS pot shadows, triggers, KBCODE, SKSTAT and CONSOL faked.
Each frame POKEY has scanned the controller CONSOL selected the frame
before; `pad` gives what each controller holds.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

m = Machine(cart=True)
fails = 0

# keypad codes, (KBCODE / 2) AND 15 (D63)
CODE = {"#": 1, "0": 2, "*": 3, "R": 4, "9": 5, "8": 6, "7": 7, "P": 8,
        "6": 9, "5": 10, "4": 11, "S": 12, "3": 13, "2": 14, "1": 15}
UP, DOWN, LEFT, RIGHT = 1, 2, 4, 8
CENTRE = 114
PLAY, SUM1, OVER, SETUP = 0, 1, 3, 4


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def check(what, got, want):
    if got != want:
        fail("%s: got %r, want %r" % (what, got, want))


def setup(players=2, gstate=PLAY):
    m.poke("SU_VAL", 5, 60, players, 2, 1)
    m.poke("GSTATE", gstate)
    m.poke("DEMO", 0)
    m.poke("POKMSK", 0xC0)
    m.call("IN_INIT")


def frame(pots=(CENTRE,) * 4, trig=(1, 1), pad=(None, None), bot=(False, False)):
    """One INPUT_POLL; pad[i] / bot[i]: the key / bottom button held on
    controller i, seen only when CONSOL selects it; trig[i]: its top
    button (TRIG, 0 = held), always seen."""
    m.poke("PADDL0", *pots)
    m.poke("TRIG0", trig[0])
    m.poke("TRIG1", trig[1])
    c = m.byte("CONSOL") & 3
    check("CONSOL pots on", m.byte("CONSOL") & 4, 4)
    sk = 0xFF
    if pad[c] is not None:
        sk &= ~0x04
        m.poke("KBCODE", 0x21 | CODE[pad[c]] << 1)    # bits 0, 5 set
    if bot[c]:
        sk &= ~0x08
    m.poke("SKSTAT", sk)
    m.call("INPUT_POLL")
    return c


def key():
    k, p = m.byte("KEY"), m.byte("KEYPL")
    return None if k == 0xFF else (k, p)


# --- set-up: pots on, the bottom button's IRQ off, the I flag kept ---
setup()
check("IN_INIT CONSOL", m.byte("CONSOL"), 0x04)
check("IN_INIT POKMSK", m.byte("POKMSK"), 0x40)
check("IN_INIT IRQEN", m.byte("IRQEN"), 0x40)

# --- sticks: dead zone, every direction and diagonal, both sticks ---
setup()
cases = [((114, 114), 0), ((74, 114), 0), ((73, 114), LEFT), ((154, 114), 0),
         ((155, 114), RIGHT), ((114, 73), UP), ((114, 155), DOWN),
         ((6, 6), UP | LEFT), ((220, 6), UP | RIGHT), ((6, 220), DOWN | LEFT),
         ((220, 220), DOWN | RIGHT), ((1, 114), LEFT), ((228, 114), RIGHT),
         ((228, 228), 0)]                       # 228, 228: no controller
for (x, y), want in cases:
    frame(pots=(x, y, CENTRE, CENTRE))
    check("JOY0 at %d,%d" % (x, y), m.byte("JOY0"), want)
    check("JOY1 still", m.byte("JOY1"), 0)
    frame(pots=(CENTRE, CENTRE, x, y))
    check("JOY1 at %d,%d" % (x, y), m.byte("JOY1"), want)
    check("JOY0 still", m.byte("JOY0"), 0)

# --- bottom buttons: FIRE0 / FIRE1, read when their controller is
#     scanned (D63: the bottom button fires, found on a real 5200) ---
setup(players=2)
while m.byte("CONSOL") & 3 != 0:
    frame()
frame(bot=(True, False))
check("FIRE0", (m.byte("FIRE0"), m.byte("FIRE1")), (1, 0))
frame(bot=(True, True))                          # controller 2's turn
check("FIRE0 and FIRE1", (m.byte("FIRE0"), m.byte("FIRE1")), (1, 1))
frame(bot=(False, True))                         # controller 1 let go
check("FIRE1", (m.byte("FIRE0"), m.byte("FIRE1")), (0, 1))
frame()
check("fire let go", (m.byte("FIRE0"), m.byte("FIRE1")), (0, 0))
setup(players=2)
while m.byte("CONSOL") & 3 != 0:
    frame()
frame(trig=(0, 0))
check("the top button is not fire", (m.byte("FIRE0"), m.byte("FIRE1")), (0, 0))

# --- 2 players in a round: the controllers take turns, digits per
#     controller, once per press ---
setup(players=2)
seen = [frame() for _ in range(4)]
check("2 players: controllers in turn", seen, [0, 1, 0, 1])
for d in "0123456789":
    for ctl in (0, 1):
        while m.byte("CONSOL") & 3 != ctl:
            frame()
        hold = (d, None) if ctl == 0 else (None, d)
        frame(pad=hold)
        check("key %s on controller %d" % (d, ctl + 1), key(), (int(d), ctl))
        for _ in range(4):                      # held: no more presses
            frame(pad=hold)
            check("key %s held" % d, key(), None)
            check("KEYDOWN while held", m.byte("KEYDOWN"), 1)
        for _ in range(4):                      # IN_DEB (2) reads each
            frame()
        check("KEYDOWN let go", m.byte("KEYDOWN"), 0)

# one key to another without letting go: a new press
setup(players=2)
frame(pad=("1", None))
check("1", key(), (1, 0))
frame(pad=("1", None))
frame(pad=("2", None))
check("1 then 2", key(), (2, 0))

# --- top button (TRIG): key 0 for its controller, on the press ---
setup(players=2)
frame(trig=(0, 1))
check("top button 1", key(), (0, 0))
check("KEYDOWN, top button held", m.byte("KEYDOWN"), 1)
frame(trig=(0, 1))
frame(trig=(0, 1))
check("top button 1 held", key(), None)
frame(trig=(1, 0))
check("top button 2", key(), (0, 1))
frame()
frame()
check("KEYDOWN, top buttons let go", m.byte("KEYDOWN"), 0)
setup(players=2)
while m.byte("CONSOL") & 3 != 0:
    frame()
frame(pad=("5", None), trig=(0, 1))
check("a digit and the top button: the digit", key(), (5, 0))
setup(players=1)
frame(trig=(1, 0))
check("1 player: controller 2's top button", key(), None)

# --- 1 player: controller 1 every frame, controller 2 not read ---
setup(players=1)
seen = [frame() for _ in range(3)]
check("1 player: controller 1 only", seen, [0, 0, 0])
frame(pad=("7", "3"))
check("1 player key", key(), (7, 0))
frame(pad=("7", "3"))
check("1 player key held", key(), None)
# setup screen, title, game over: controller 1 only, even with 2 players
for gs in (SETUP, OVER):
    setup(players=2, gstate=gs)
    check("GSTATE %d: controller 1 only" % gs, [frame() for _ in range(3)], [0, 0, 0])
# a 2-player game's round summary still takes turns
setup(players=2, gstate=SUM1)
check("round summary: in turn", [frame() for _ in range(2)], [0, 1])
# the demo: controller 1 only
setup(players=2)
m.poke("DEMO", 1)
check("demo: controller 1 only", [frame() for _ in range(3)], [0, 0, 0])

# --- * and PAUSE: once per press, shared by both controllers ---
for k, var in (("*", "HELPK"), ("P", "PAUSEK")):
    setup(players=2)
    frame(pad=(k, None))
    check(k + " pressed", m.byte(var), 1)
    frame(pad=(k, None))                         # controller 2 not holding it
    check(k + " held", m.byte(var), 0)
    frame(pad=(k, None))
    check(k + " still held", m.byte(var), 0)
    check(k + " is no digit", key(), None)
    check(k + " KEYDOWN", m.byte("KEYDOWN"), 1)
    frame()
    frame()
    check(k + " let go", m.byte(var), 0)
    # pressed on every controller at once (as atari800 does): one press
    setup(players=2)
    hits = 0
    for _ in range(6):
        frame(pad=(k, k))
        hits += m.byte(var)
    check(k + " on both controllers", hits, 1)
    # 1 player
    setup(players=1)
    frame(pad=(k, None))
    check(k + " 1 player", m.byte(var), 1)
    frame(pad=(k, None))
    check(k + " 1 player held", m.byte(var), 0)

# --- a key held that one read misses is still held (D86): no second
#     press; two reads without it let it go ---
for players in (1, 2):
    setup(players=players)
    while m.byte("CONSOL") & 3 != 0:
        frame()
    hits = 0
    for held in (1, 1, 0, 1, 1, 0, 1):          # reads of controller 1
        frame(pad=("*", None) if held else (None, None))
        hits += m.byte("HELPK")
        if players == 2:
            frame()                              # controller 2's read
            hits += m.byte("HELPK")
    check("* with 1-read dropouts, %d players: one press" % players, hits, 1)
    for _ in range(2 * players):
        frame()
    frame(pad=("*", None))
    check("* after 2 reads up, %d players: a new press" % players, m.byte("HELPK"), 1)

# --- START: CONKEY's START bit while held, on any screen ---
for gs in (PLAY, SETUP):
    setup(players=1, gstate=gs)
    frame(pad=("S", None))
    check("START held (GSTATE %d)" % gs, m.byte("CONKEY"), 1)
    frame(pad=("S", None))
    check("START still held", m.byte("CONKEY"), 1)
    frame()
    check("START one read up: still held", m.byte("CONKEY"), 1)
    frame()
    check("START let go", m.byte("CONKEY"), 0)
setup(players=2)
frame()                                          # controller 2 next
frame(pad=(None, "S"))
check("START on controller 2", m.byte("CONKEY"), 1)


# --- #: totals while held, the next page on each press soon after ---
def hash_press(gap=2, hold=2, players=1):
    for _ in range(hold):
        frame(pad=("#", None))
    page = m.byte("CONKEY")
    for _ in range(gap):
        frame()
    check("# let go: no page", m.byte("CONKEY"), 0)
    return page


setup(players=1)
pages = [hash_press() for _ in range(5)]
check("# pages", pages, [1, 2, 4, 1, 2])
for _ in range(91):                              # IN_PGTM frames: totals again
    frame()
check("# after a pause: totals", hash_press(), 1)
setup(players=1)
for _ in range(200):                             # held long: totals all along
    frame(pad=("#", None))
    if m.byte("CONKEY") != 1:
        fail("# held: CONKEY %d" % m.byte("CONKEY"))
        break
frame()
frame()
check("# held long, then the next press", (hash_press(hold=1), hash_press()), (2, 4))
# # in a 2-player round, pressed on both controllers at once: one step
setup(players=2)
pages = []
for _ in range(3):
    for _ in range(4):
        frame(pad=("#", "#"))
    pages.append(m.byte("CONKEY"))
    for _ in range(4):
        frame()
check("# on both controllers", pages, [1, 2, 4])
# not on the setup screen (# would begin the game there): no page
setup(players=1, gstate=SETUP)
frame(pad=("#", None))
check("# on the setup screen", m.byte("CONKEY"), 0)
check("# on the setup screen: a key held", m.byte("KEYDOWN"), 1)

# (RESET goes back to the title screen: tests/test_reset.py, D76)

# --- attract mode: any input zeroes ATRACT, nothing leaves it ---
setup(players=1)
for what, kw in (("stick", dict(pots=(6, CENTRE, CENTRE, CENTRE))),
                 ("stick 2", dict(pots=(CENTRE, CENTRE, CENTRE, 220))),
                 ("fire", dict(trig=(1, 0))), ("key", dict(pad=("4", None))),
                 ("bottom button", dict(bot=(True, False))), ("START", dict(pad=("S", None)))):
    frame()
    frame()
    m.poke("ATRACT", 0x55)
    frame(**kw)
    check("ATRACT after " + what, m.byte("ATRACT"), 0)
frame()
frame()
m.poke("ATRACT", 0x55)
frame()
check("ATRACT, nothing touched", m.byte("ATRACT"), 0x55)

# --- the 800 stubs stay RTSes on the 5200 ---
for r in ("FIRE_TAP", "KP_ON", "KP_OFF", "KP_AUTO"):
    check(r + " is an RTS", m.byte(r), 0x60)

if fails:
    print("test_input5200: %d failures" % fails)
    sys.exit(1)
print("test_input5200: ok")
