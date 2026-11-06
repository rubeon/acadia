#!/usr/bin/env python3
"""T-REL-1, T-REL-4: the title screen (py65).

GAME_FRAME is called once per simulated frame with the triggers, console
keys and keyboard faked, as the main loop would.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

GS_SETUP, GS_TITLE = 4, 5
START, OPTION = 1, 4
m = Machine()
rng = random.Random(7)
m.on_read("RANDOM", lambda: rng.randrange(256))   # POKEY's RANDOM
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


# the title screen: its display list, font, colours and tune (D70)
boot()
if m.byte("GSTATE") != GS_TITLE or m.byte("SDLSTL") != m.addr("TDLIST") & 0xFF:
    fail("TITLE_ENTER: state %d, display list %02X" % (m.byte("GSTATE"), m.byte("SDLSTL")))
if m.addr("TDLIST") >> 8 != m.addr("DLIST") >> 8:
    fail("TDLIST is not in DLIST's page")
if m.byte("CHBAS") != m.addr("TTFONT") >> 8 or m.addr("TTFONT") & 0x3FF:
    fail("title font: CHBAS %02X, TTFONT %04X" % (m.byte("CHBAS"), m.addr("TTFONT")))
pal = [m.byte("COLOR0", i) for i in range(5)]
want = [m.byte("TTP0"), m.byte("TTP1"), 0x00, 0x1E, m.byte("TTBK")]
if pal != want:
    fail("title colours %r, want %r" % (["%02X" % c for c in pal], ["%02X" % c for c in want]))
if not (m.byte("MZ_ON") and m.byte("MZ_LOOP")):
    fail("no title tune")
# the colour kernel: one DLI, on the last blank line, and ST_VBI points
# VDSLST at TT_DLI while the title is up
dl = m.addr("TDLIST")
if [m.mem[dl + i] for i in range(3)] != [0x70, 0x70, 0xF0]:
    fail("TDLIST starts %r" % [m.mem[dl + i] for i in range(3)])
m.call("ST_VBI")
if m.byte("VDSLST") | m.byte("VDSLST", 1) << 8 != m.addr("TT_DLI"):
    fail("ST_VBI: VDSLST %04X on the title" % (m.byte("VDSLST") | m.byte("VDSLST", 1) << 8))
# the generator's layout matches TITLE.ASM's equates
for name, want in (("TT_NL", 96), ("TT_WROWS", 3), ("TT_HORL", 144), ("TT_SCOL", 35)):
    if m.addr(name) != want:
        fail("%s = %d, mktitle.py makes %d" % (name, m.addr(name), want))
# the sun: 8 rows of player 3 from TT_SUN, cut at the horizon
p3, sun, hpm = m.addr("TT_P3"), m.byte("TT_SUN"), m.addr("TT_HPM")
rows = [i for i in range(128) if m.mem[p3 + i]]
if rows != list(range(sun, min(sun + 8, hpm))):
    fail("sun rows %r, TT_SUN %d" % (rows, sun))
# glitter on the water; no prompt yet
prs = m.addr("TT_PRSO")
water = [m.byte("MAPSCR", i) for i in range(prs)]
if not any(water) or any(m.byte("MAPSCR", prs + i) for i in range(20)):
    fail("water %d glints, prompt shown at once" % sum(1 for c in water if c))
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

# the tune carries on into the setup screen, in its own colours (D65)
boot()
for _ in range(100):
    frame()
pos = m.byte("MZ_POS")
frame(console=START)
if m.byte("GSTATE") != GS_SETUP or m.byte("SDLSTL") != m.addr("SUDLIST") & 0xFF:
    fail("START: state %d" % m.byte("GSTATE"))
if not m.byte("MZ_ON") or m.byte("MZ_POS") < pos:
    fail("the title tune restarted: position %d, was %d" % (m.byte("MZ_POS"), pos))
if [m.byte("COLOR1"), m.byte("COLOR2"), m.byte("COLOR4")] != [0x94, 0x1C, 0x00]:
    fail("setup screen colours not set (D65)")
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

# PRESS FIRE shows after 10 s with nothing touched, not before; a touch
# starts the count again; the sun stays where it is
m.poke("PAL", 0x0F)                       # NTSC: 60 frames a second
boot()
prs, sun0 = m.addr("TT_PRSO"), m.byte("TT_SUN")
for i in range(9 * 60):
    frame()
frame(stick=1)                            # touched at 9 s
for i in range(9 * 60):
    frame()
if any(m.byte("MAPSCR", prs + i) for i in range(20)):
    fail("PRESS FIRE before 10 idle seconds")
for i in range(2 * 60):
    frame()
shown = [m.byte("MAPSCR", prs + i) for i in range(20)]
if shown != [m.byte("TTPRS", i) for i in range(20)]:
    fail("no PRESS FIRE after 10 idle seconds: %r" % shown)
if m.byte("TT_SUN") != sun0:
    fail("the sun moved: %d, was %d" % (m.byte("TT_SUN"), sun0))
for i in range(4):                        # the glitter changes
    frame()
before = [m.byte("MAPSCR", i) for i in range(prs)]
for i in range(m.addr("TT_GRT") + 1):
    frame()
if before == [m.byte("MAPSCR", i) for i in range(prs)]:
    fail("the glitter did not change")
frame()                                   # armed
frame(fire0=True)
p3 = m.addr("TT_P3")
if m.byte("GSTATE") != GS_SETUP or any(m.mem[p3 + i] for i in range(128)):
    fail("leaving the title: state %d, sun left in player 3" % m.byte("GSTATE"))

print("title: %d failed" % fails)
sys.exit(1 if fails else 0)
