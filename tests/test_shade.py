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
        gd = m.byte("GRNDEL", r)
        pf0 = (lum(sea, m.addr("SEA_LT"), sh, msk) if gd == m.addr("GR_SEA")   # D55
               else lum(grass, signed(gd), sh, msk))
        want = (lum(sea, signed(m.byte("SEADEL", r)), sh, msk), pf0)
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
fonts = sorted(set(m.byte("FONTPG", i) << 8 for i in range(m.addr("N_FONTS"))))
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

# rounded corners (D55): the top and bottom 3 character rows have PF0
# as the light sea, and their squares no waves; a boat or wreck drawn
# there is that row's variant, elsewhere the usual tile
GR_SEA = m.addr("GR_SEA")
corner = [r for r in range(ROWS) if m.byte("GRNDEL", r) == GR_SEA]
if corner != [0, 1, 2, 19, 20, 21]:
    fail("corner rows %r" % corner)
waves = {m.addr(n) for n in ("T_WAVE1", "T_WAVE2", "T_SPARK", "T_SEA")}
for sr in (0, 1, 9, 10):
    row = [m.byte("ISLTILE", sr * 20 + c) for c in range(20)]
    if waves & set(row):
        fail("square row %d has plain sea or wave tiles: %r" % (sr, row))
    if not m.byte("BNDVAR", sr):
        fail("square row %d has no boat variants" % sr)
T_PT = m.addr("T_PTBOAT")
for sr in range(11):
    for k in range(4):                   # PT boat, fishing boat, wreck, other
        m.poke("MTILE", T_PT + k)
        _, x, y, _ = m.call("BND_TILE", x=0x5A, y=sr)
        want = T_PT + k
        if k < 3 and m.byte("BNDVAR", sr):
            want = m.byte("BNDVAR", sr) + k
        if m.byte("MTILE") != want or (x, y) != (0x5A, sr):
            fail("BND_TILE row %d tile %d: %d, want %d" % (sr, T_PT + k, m.byte("MTILE"), want))
# a corner square's top left character: dark (00) in the very corner,
# light sea (01) further in
font0 = m.addr("MFNT00")
code = m.byte("TILECH", m.byte("ISLTILE", 0)) & 0x7F
top = m.mem[font0 + code * 8]
code = m.byte("TILECH", m.byte("ISLTILE", 9)) & 0x7F
mid = m.mem[font0 + code * 8]
if top != 0 or mid != 0x55:
    fail("corner character %02X, middle of the top row %02X" % (top, mid))

print("shade: %d failed" % fails)
sys.exit(1 if fails else 0)
