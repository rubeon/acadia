#!/usr/bin/env python3
"""T-REL-1: the title screen (py65).

The screen is shown at start-up, before the setup screen.  It has a
mode 7 name and mode 2 lines of credits; START or fire goes on to the
setup screen.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

UP, DOWN, LEFT, RIGHT = 1, 2, 4, 8
START, SELECT = 1, 2
GS_PLAY, GS_OVER, GS_SETUP, GS_TITLE = 0, 3, 4, 5

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


def name_line():
    """The mode 7 band: 20 characters at the start of the screen."""
    base = m.addr("MAPSCR")     # TI_SCR: the mode 7 band
    return "".join(chr(m.mem[base + i] + 0x20) for i in range(20))


def m2_line(n):
    """Mode 2 line n of the title screen: 40 characters."""
    base = m.addr("MAPSCR") + 20 + 40 * n    # TI_TXT
    return "".join(chr((m.mem[base + i] & 0x7F) + 0x20) for i in range(40))


# the credits, as they must appear: the line number and the text
CREDITS = [
    (1, "AN ISLAND-BUILDING GAME FOR ATARI 8-BIT"),
    (3, "BY ERIC WILLIAMS AND CLAUDE"),
    (5, "AFTER UTOPIA (1981) BY MATTEL, INC."),
    (6, "NOT AFFILIATED WITH MATTEL, INC."),
    (8, "ALL GRAPHICS, CODE AND MUSIC ARE NEW."),
    (10, "KEYS 1-9 BUY ITEMS, 0 BOATS"),
    (11, "P PAUSES, H SHOWS THE PRICE LIST"),
    (17, "PRESS START OR FIRE TO BEGIN"),
]


def centred(text, width=40):
    left = (width - len(text)) // 2
    return (" " * left + text).ljust(width)


# ---------------------------------------------------------------------
# the screen itself
# ---------------------------------------------------------------------
m.poke("PAL", 0x0F)
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT"):
    m.call(r)
m.call("TITLE_ENTER")

if m.byte("GSTATE") != GS_TITLE:
    fail("title screen not shown (state %d)" % m.byte("GSTATE"))
if m.byte("SDLSTL") != m.addr("TDLIST") & 0xFF:
    fail("title display list not selected")
if (m.addr("TDLIST") ^ m.addr("DLIST")) & 0xFF00:
    fail("TDLIST and DLIST are not in the same page")
if m.byte("CHBAS") != 0xE0:
    fail("the OS font is not loaded (CHBAS $%02X)" % m.byte("CHBAS"))

if name_line() != "       ACADIA       ":
    fail("name %r" % name_line())

for row, text in CREDITS:
    want = centred(text)
    got = m2_line(row)
    if got != want:
        fail("line %d: %r, want %r" % (row, got, want))

# every other mode 2 line is blank
for row in range(18):
    if row in [r for r, _ in CREDITS]:
        continue
    if m2_line(row) != " " * 40:
        fail("line %d is not blank: %r" % (row, m2_line(row)))

# the screen memory is cleared: nothing left over from an earlier screen
for row in range(18):
    if row in [r for r, _ in CREDITS]:
        continue
    base = m.addr("MAPSCR") + 20 + 40 * row
    for i in range(40):
        if m.mem[base + i] != 0:
            fail("screen memory not cleared on line %d" % row)
            break
    else:
        continue
    break

print("title: %r" % name_line())
for row, _ in CREDITS:
    print("  %2d |%s|" % (row, m2_line(row)))

# ---------------------------------------------------------------------
# the title tune starts, and carries on into the setup screen
# ---------------------------------------------------------------------
if m.byte("MZ_ON") != 1:
    fail("the title tune is not playing")

# ---------------------------------------------------------------------
# nothing acts until everything has been let go
# ---------------------------------------------------------------------
for _ in range(5):
    frame(fire0=True)
if m.byte("GSTATE") != GS_TITLE:
    fail("held fire left the title screen")
frame()

# ---------------------------------------------------------------------
# START goes on to the setup screen
# ---------------------------------------------------------------------
m.call("TITLE_ENTER")
frame()
tap(console=START)
if m.byte("GSTATE") != GS_SETUP:
    fail("START did not go to the setup screen (state %d)" % m.byte("GSTATE"))
if m.byte("SDLSTL") != m.addr("SUDLIST") & 0xFF:
    fail("the setup display list is not selected")
if m.byte("MZ_ON") != 1:
    fail("the title tune stopped in the setup screen")

# the setup screen shows its own title, not the credits
setup_title = "".join(chr(m.mem[m.addr("MAPSCR") + i] + 0x20) for i in range(20))
if setup_title.strip() != "ACADIA":
    fail("the setup screen's title %r" % setup_title)

# ---------------------------------------------------------------------
# fire goes on to the setup screen as well
# ---------------------------------------------------------------------
m.call("TITLE_ENTER")
frame()
tap(fire0=True)
if m.byte("GSTATE") != GS_SETUP:
    fail("fire did not go to the setup screen (state %d)" % m.byte("GSTATE"))

# ---------------------------------------------------------------------
# a digit key does nothing on the title screen
# ---------------------------------------------------------------------
m.call("TITLE_ENTER")
frame()
tap(kb=0x1F)          # "1"
if m.byte("GSTATE") != GS_TITLE:
    fail("a digit key left the title screen (state %d)" % m.byte("GSTATE"))

print("title: %d failed" % fails)
sys.exit(1 if fails else 0)
