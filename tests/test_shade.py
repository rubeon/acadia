#!/usr/bin/env python3
"""T-GFX-1 (D51): per-row sea and grass shading (VD_SHADE) and the
moving waves (WAVE_ANI), on py65."""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
from run6502 import Machine  # noqa: E402

m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def signed(b):
    return b - 256 if b & 0x80 else b


def lum(c, d, sh=0, msk=0xFF):
    """VS_LUM in Python."""
    v = min(max((c & 0x0F) + d, 0), 0x0E) & 0x0E
    return ((c & 0xF0 | v) ^ sh) & msk


ROWS = 22
m.call("VARS_INIT")
for sea, grass, sh, msk in ((0x94, 0xC6, 0, 0xFF), (0x90, 0xCE, 0, 0xFF),
                            (0x94, 0xC6, 0x30, 0xF6)):
    m.poke("MAPPAL", sea, grass)
    m.poke("COLRSH", sh)
    m.poke("DRKMSK", msk)
    m.call("VD_SHADE")
    for r in range(ROWS):
        want = (lum(sea, signed(m.byte("SEADEL", r)), sh, msk),
                lum(grass, signed(m.byte("GRNDEL", r)), sh, msk))
        got = (m.byte("ROWBK", r), m.byte("ROWPF0", r))
        if got != want:
            fail("VD_SHADE %02X/%02X attract %02X/%02X row %d: %02X/%02X, want %02X/%02X"
                 % ((sea, grass, sh, msk, r) + got + want))
    if (m.byte("AP_BK"), m.byte("AP_GR"), m.byte("AP_SH"), m.byte("AP_MSK")) != (sea, grass, sh, msk):
        fail("VD_SHADE did not note what it was built from")
print("VD_SHADE ok" if not fails else "VD_SHADE: failures")

# the wave characters and their codes, from the generated FONT_MAP.ASM
codes = []
for line in open(os.path.join(HERE, "..", "src", "font_map.asm")):
    g = re.search(r"; phase 0, .* code \$([0-9A-F]{2})", line)
    if g:
        codes.append(int(g.group(1), 16))
n = m.addr("WV_N")
if len(codes) != n:
    fail("%d wave characters in FONT_MAP.ASM, WV_N %d" % (len(codes), n))
fonts = [m.addr("MAPFONT"), m.addr("MAPFNT1")]
wv = m.addr("WVDATA")
rate = m.addr("WV_RATE")
for frame in range(0, 8 * rate):
    before = [bytes(m.mem[f + c * 8 + i] for i in range(8)) for f in fonts for c in codes]
    m.poke("FRAME", frame & 0xFF)
    m.call("WAVE_ANI")
    after = [bytes(m.mem[f + c * 8 + i] for i in range(8)) for f in fonts for c in codes]
    if frame % rate:
        if after != before:
            fail("WAVE_ANI changed the font at frame %d" % frame)
        continue
    ph = (frame // rate) % m.addr("WV_PH")
    for k, c in enumerate(codes):
        want = bytes(m.mem[wv + (ph * n + k) * 8 + i] for i in range(8))
        for fi, f in enumerate(fonts):
            if after[fi * n + k] != want:
                fail("frame %d: font %d code $%02X is not phase %d" % (frame, fi, c, ph))
# the phases differ, so the waves do move
if len(set(bytes(m.mem[wv + i * 8 * n:wv + (i + 1) * 8 * n]) for i in range(4))) < 3:
    fail("the wave phases are not different")

print("shade: %d failed" % fails)
sys.exit(1 if fails else 0)
