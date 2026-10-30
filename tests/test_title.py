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


def frame(fire0=False, console=0, kb=None, stick=0):
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
if pal != [0xC6, 0x2C, 0xC0, 0x0E, 0x94]:
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
# left alone for 30 s the demo starts: 1 player against the CPU, player
# 1 scripted; it goes back to the title after 15 s, setup values kept
m.poke("PAL", 0x0F)                       # NTSC: 60 frames a second
boot()
m.poke("SU_VAL", 7, 45, 2, 1)
for i in range(29 * 60):
    frame()
    if m.byte("GSTATE") != GS_TITLE:
        fail("left the title after %d frames" % i)
        break
for i in range(90):
    frame()
    if m.byte("DEMO"):
        break
if not m.byte("DEMO") or m.byte("GSTATE") != 0 or m.byte("SDLSTL") != m.addr("DLIST") & 0xFF:
    fail("no demo after 30 s: state %d" % m.byte("GSTATE"))
if [m.byte("SU_VAL", i) for i in range(4)] != [1, 30, 1, 3]:
    fail("demo setup %r" % [m.byte("SU_VAL", i) for i in range(4)])
gold = m.byte("GOLD")
for i in range(16 * 60):
    frame()
    if not m.byte("DEMO"):
        break
print("demo: %d frames, player 1 spent %d gold" % (i + 1, gold - m.byte("GOLD")))
if not 14 * 60 <= i + 1 <= 16 * 60 or m.byte("GSTATE") != GS_TITLE:
    fail("demo ran %d frames, state %d" % (i + 1, m.byte("GSTATE")))
if gold - m.byte("GOLD") < 80:
    fail("the script bought little: %d gold spent" % (gold - m.byte("GOLD")))
if [m.byte("SU_VAL", i) for i in range(4)] != [7, 45, 2, 1]:
    fail("setup values not restored: %r" % [m.byte("SU_VAL", i) for i in range(4)])
if any(m.mem[0xD000 + i] for i in range(8)):
    fail("sprites left on the title: %r" % [m.mem[0xD000 + i] for i in range(8)])

# any touch ends the demo at once
for touch in ({"fire0": True}, {"console": START}, {"kb": 0x21}, {"stick": 1}):
    boot()
    m.call("DEMO_GO")
    for _ in range(60):
        frame()
    frame(**touch)
    if m.byte("DEMO") or m.byte("GSTATE") != GS_TITLE:
        fail("%r did not end the demo" % touch)
    frame(**touch)                        # still held: stays on the title
    if m.byte("GSTATE") != GS_TITLE:
        fail("%r held went on from the title" % touch)

print("title: %d failed" % fails)
sys.exit(1 if fails else 0)
