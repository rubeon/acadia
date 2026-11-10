#!/usr/bin/env python3
"""T-INFRA-7 (D57, D81): the joined XEX starts with the loader, its
INITAD, then the title graphics with the logo; LDR_INIT clears the logo
area and puts up a display list showing the logo where the title has
it, and LOADING, from memory nothing else loads over."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tools"))
from run6502 import Machine     # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
XEX = os.path.join(ROOT, "build", "acadia.xex")
LDR = os.path.join(ROOT, "build", "loader.xex")

fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def segments(data):
    pos, out = 0, []
    while pos < len(data):
        if data[pos:pos + 2] == b"\xff\xff":
            pos += 2
        start = data[pos] | data[pos + 1] << 8
        end = data[pos + 2] | data[pos + 3] << 8
        out.append((start, end, data[pos + 4:pos + 5 + end - start]))
        pos += 5 + end - start
    return out


m = Machine()
LDR_INIT = 0x8730
logo = m.addr("LOGO")
logo_end = logo + m.addr("LOGO_H") * 40 - 1
segs = segments(open(XEX, "rb").read())
ldr_start, ldr_end = segs[0][0], segs[0][1]

# order: loader, its INITAD, then the segment holding the logo
if ldr_start != LDR_INIT:
    fail("first segment starts at $%04X, want $%04X" % (ldr_start, LDR_INIT))
if ldr_end >= 0x8800:
    fail("loader ends at $%04X, into the font at $8800" % ldr_end)
if segs[1][:2] != (0x02E2, 0x02E3) or \
        segs[1][2][0] | segs[1][2][1] << 8 != LDR_INIT:
    fail("second segment is not INITAD = LDR_INIT")
if not (segs[2][0] <= logo and segs[2][1] >= logo_end):
    fail("third segment $%04X-$%04X does not hold the logo $%04X-$%04X"
         % (segs[2][0], segs[2][1], logo, logo_end))
for s, e, _ in segs[1:]:
    if s <= ldr_end and e >= ldr_start:
        fail("segment $%04X-$%04X loads over the loader" % (s, e))

# run LDR_INIT on the loader alone, with junk where the logo goes
m = Machine(xex=LDR)
for a in range(0x8000, 0x8500):
    m.mem[a] = 0x55
m.call(LDR_INIT)
if any(m.mem[a] for a in range(logo, logo_end + 1)):
    fail("logo area not cleared")
if m.mem[m.addr("NMIEN")] != m.addr("NMI_VBI"):
    fail("VBI not back on")
if m.mem[m.addr("PORTB")] & 2 == 0:
    fail("BASIC not switched out")
dl = m.mem[0x0230] | m.mem[0x0231] << 8
if not ldr_start <= dl <= ldr_end:
    fail("SDLSTL $%04X is not in the loader" % dl)

# walk the display list
LINES = {2: 8, 4: 8, 5: 16, 6: 8, 7: 16, 0xA: 4, 0xD: 2}
pc, lines, moded, lms = dl, 0, 0, []
for _ in range(100):
    op = m.mem[pc]
    if pc // 1024 != dl // 1024:
        fail("display list crosses a 1K boundary")
    if op == 0x41:
        if (m.mem[pc + 1] | m.mem[pc + 2] << 8) != dl:
            fail("JVB does not loop to the list")
        break
    mode = op & 0x0F
    if mode == 0:
        lines += ((op >> 4) & 7) + 1
        pc += 1
        continue
    if op & 0x40:
        lms.append((mode, m.mem[pc + 1] | m.mem[pc + 2] << 8, lines))
        pc += 3
    else:
        pc += 1
    lines += LINES[mode]
    if mode == 0xD:
        moded += 1
else:
    fail("no JVB")
if not lms or lms[0][:2] != (0xD, logo):
    fail("first LMS is not mode D at LOGO")
elif lms[0][2] != 28:
    fail("logo starts on line %d, the title's on 28" % lms[0][2])
if moded != m.addr("LOGO_H"):
    fail("%d mode D lines, want LOGO_H" % moded)
if lines > 240:
    fail("%d scan lines" % lines)
txt = [x for x in lms if x[0] == 6]
if not txt:
    fail("no LOADING line")
else:
    t = txt[0][1]
    if not (ldr_start <= t and t + 19 <= ldr_end):
        fail("LOADING text outside the loader")
    word = "".join(chr((m.mem[t + i] & 0x3F) + 0x20) for i in range(20))
    if word.strip() != "LOADING":
        fail("text reads %r" % word)

print("test_loader: DL $%04X, %d lines, %d fails" % (dl, lines, fails))
sys.exit(1 if fails else 0)
