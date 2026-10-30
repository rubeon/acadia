#!/usr/bin/env python3
"""T-GFX-3 (D54): the status bar's font, colours and DLIs (py65)."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

m = Machine()
fails = 0
DL_DLI, DL_LMS = 0x80, 0x40


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def vdslst():
    return m.byte("VDSLST") | m.byte("VDSLST", 1) << 8


stfont = m.addr("STFONT") >> 8
if m.addr("STFONT") & 0x3FF:
    fail("STFONT at %04X is not 1K aligned" % m.addr("STFONT"))

# the game's font and palette
for r in ("VARS_INIT", "DISP_INIT"):
    m.call(r)
pal = [m.byte("COLOR0", i) for i in range(5)]
if m.byte("CHBAS") != stfont or pal != [0x2C, 0x48, 0x0C, 0xAC, 0x00]:
    fail("DISP_INIT: CHBAS %02X, palette %r" % (m.byte("CHBAS"), ["%02X" % c for c in pal]))

# both display lists: 2 blank lines, a third with a DLI, then two mode 4
# status lines from STATUS1, each with a DLI
for name in ("DLIST", "HDLIST"):
    dl = m.addr(name)
    got = [m.mem[dl + i] for i in range(7)]
    st = m.addr("STATUS1")
    if got != [0x70, 0x70, 0xF0, DL_DLI + DL_LMS + 4, st & 0xFF, st >> 8, DL_DLI + 4]:
        fail("%s starts %r" % (name, ["%02X" % c for c in got]))

# each frame: the backgrounds (attract mode applied), then the DLI chain
# DLI_ST -> DLI_ST2 -> DLI_MAP
for sh, msk in ((0, 0xFF), (0x30, 0xF6)):
    m.poke("COLRSH", sh)
    m.poke("DRKMSK", msk)
    m.poke("VDSLST", 0, 0)
    m.call("ST_VBI")
    want = [(c ^ sh) & msk for c in (0x84, 0x80, 0x26, 0x48)]
    got = [m.byte("STBK", i) for i in range(4)]
    if got != want or vdslst() != m.addr("DLI_ST"):
        fail("ST_VBI attract %02X/%02X: %r, VDSLST %04X" % (sh, msk, got, vdslst()))
    m.interrupt("DLI_ST")
    if (m.byte("COLBK"), m.byte("COLPF1")) != (want[0], want[2]) or vdslst() != m.addr("DLI_ST2"):
        fail("DLI_ST: COLBK %02X PF1 %02X, VDSLST %04X" % (m.byte("COLBK"), m.byte("COLPF1"), vdslst()))
    m.interrupt("DLI_ST2")
    if (m.byte("COLBK"), m.byte("COLPF1")) != (want[1], want[3]) or vdslst() != m.addr("DLI_MAP"):
        fail("DLI_ST2: COLBK %02X PF1 %02X, VDSLST %04X" % (m.byte("COLBK"), m.byte("COLPF1"), vdslst()))
m.poke("COLRSH", 0)
m.poke("DRKMSK", 0xFF)
for r in ("TIC_INIT", "SETUP_INIT"):
    m.call(r)
m.mem[0x0600] = 0x60                    # RTS: the OS's deferred VBI
m.poke("OLDVBD", 0x00, 0x06)
m.call("VBI_D")
if vdslst() != m.addr("DLI_ST"):
    fail("VBI_D: VDSLST %04X" % vdslst())

# the font: white glyphs at their screen codes, the same in red at +$40,
# 2-character icons with gold in them
font = m.addr("STFONT")
glyph = [m.mem[font + 8 * 0x10 + i] for i in range(8)]          # "0"
red = [m.mem[font + 8 * 0x50 + i] for i in range(8)]
if not any(glyph) or any(b & 0x55 != (b & 0xAA) >> 1 for b in glyph):
    fail("the white 0 is not all PF2 pixels: %r" % glyph)
if any(b != (g & 0xAA) for b, g in zip(red, glyph)):
    fail("the red 0 is not the white one in PF1: %r %r" % (red, glyph))
for code in range(0x60, 0x66):
    bs = [m.mem[font + 8 * code + i] for i in range(8)]
    pix = {(b >> s) & 3 for b in bs for s in (0, 2, 4, 6)}
    if 1 not in pix:
        fail("icon character %02X has no gold" % code)

# the title and setup screens use the ROM font, a game the status font
m.call("TITLE_ENTER")
if m.byte("CHBAS") != m.addr("ROMFONT"):
    fail("TITLE_ENTER: CHBAS %02X" % m.byte("CHBAS"))
m.call("ST_COLS")
m.call("SETUP_ENTER")
if m.byte("CHBAS") != m.addr("ROMFONT") or [m.byte("COLOR1"), m.byte("COLOR2"), m.byte("COLOR4")] != [0x0E, 0x82, 0x00]:
    fail("SETUP_ENTER: CHBAS %02X" % m.byte("CHBAS"))
m.poke("SU_VAL", 10, 30, 2, 2)
m.call("SU_GO")
if m.byte("CHBAS") != stfont or m.byte("COLOR1") != 0x48:
    fail("SU_GO: CHBAS %02X, COLOR1 %02X" % (m.byte("CHBAS"), m.byte("COLOR1")))
m.call("TITLE_ENTER")
m.call("DEMO_GO")
if m.byte("CHBAS") != stfont:
    fail("DEMO_GO: CHBAS %02X" % m.byte("CHBAS"))

print("status: %d failed" % fails)
sys.exit(1 if fails else 0)
