#!/usr/bin/env python3
"""T-REL-1: the title screen (py65).

GAME_FRAME is called once per simulated frame with the triggers, console
keys and keyboard faked, as the main loop would.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

GS_SETUP, GS_TITLE = 4, 5
START, OPTION = 1, 4
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def frame(fire0=False, console=0, kb=None):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF)
    m.poke("TRIG0", 0 if fire0 else 1)
    m.poke("TRIG1", 1)
    m.poke("CONSOL", 0x07 ^ console)
    if kb is None:
        m.poke("SKSTAT", 0xFF)
    else:
        m.poke("SKSTAT", 0xFB)
        m.poke("KBCODE", kb)
    m.call("GAME_FRAME")
    m.call("SND_VBI")


def text(offset, colour):
    out = ""
    for i in range(20):
        c = m.byte("MAPSCR", offset + i)
        if c & 0xC0 != colour:
            return None
        out += chr((c & 0x3F) + 0x20)
    return out


def boot():
    for r in ("VARS_INIT", "SND_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "TITLE_ENTER"):
        m.call(r)


# the title screen: its display list, text, palette and tune
boot()
if m.byte("GSTATE") != GS_TITLE or m.byte("SDLSTL") != m.addr("TDLIST") & 0xFF:
    fail("TITLE_ENTER: state %d, display list %02X" % (m.byte("GSTATE"), m.byte("SDLSTL")))
if m.addr("TDLIST") >> 8 != m.addr("DLIST") >> 8:
    fail("TDLIST is not in DLIST's page")
if text(0, 0xC0) != " REBUILD YOUR WORLD ":
    fail("subtitle %r" % text(0, 0xC0))
if text(20, 0x40) != " PRESS FIRE TO PLAY ":
    fail("prompt %r" % text(20, 0x40))
pal = [m.byte("COLOR0", i) for i in range(5)]
if pal != [0xC6, 0x1C, 0x00, 0x0E, 0x84]:
    fail("title palette %r" % ["%02X" % c for c in pal])
if not (m.byte("MZ_ON") and m.byte("MZ_LOOP")):
    fail("no title tune")

# the display list shows LOGO_H lines of the logo, starting at LOGO
dl, n = m.addr("TDLIST"), 0
while m.mem[dl] & 0x0F != 0x0D:
    dl += 1
if m.mem[dl] != 0x4D or m.mem[dl + 1] | m.mem[dl + 2] << 8 != m.addr("LOGO"):
    fail("logo line: %02X" % m.mem[dl])
dl += 3
n = 1
while m.mem[dl] == 0x0D:
    n += 1
    dl += 1
if n != m.addr("LOGO_H"):
    fail("%d logo lines, want %d" % (n, m.addr("LOGO_H")))
if (m.addr("LOGO") & 0xF000) != ((m.addr("LOGO") + 40 * n - 1) & 0xF000):
    fail("the logo crosses a 4K boundary")

# fire held since power-on (or OPTION held to boot without BASIC)
# does nothing until it is let go; then fire goes on to the setup screen
for held in ({"fire0": True}, {"console": OPTION}, {"kb": 0x21}):
    boot()
    for _ in range(30):
        frame(**held)
    if m.byte("GSTATE") != GS_TITLE:
        fail("left the title with %r held" % held)
    frame()
    frame(**held)
    if m.byte("GSTATE") != GS_SETUP:
        fail("%r did not go on to the setup screen" % held)

# the tune carries on into the setup screen; colours are the status bar's
boot()
for _ in range(100):
    frame()
pos = m.byte("MZ_POS")
frame(console=START)
if m.byte("GSTATE") != GS_SETUP or m.byte("SDLSTL") != m.addr("SUDLIST") & 0xFF:
    fail("START: state %d" % m.byte("GSTATE"))
if not m.byte("MZ_ON") or m.byte("MZ_POS") < pos:
    fail("the title tune restarted: position %d, was %d" % (m.byte("MZ_POS"), pos))
if [m.byte("COLOR1"), m.byte("COLOR2"), m.byte("COLOR4")] != [0x0E, 0x82, 0x00]:
    fail("status bar colours not restored")
print("title: %d failed" % fails)
sys.exit(1 if fails else 0)
