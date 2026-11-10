#!/usr/bin/env python3
"""T-INFRA-7 (D57, D81): the joined XEX loads the loader, its INITAD,
the loading bar's table, then the game in chunks of at most 1K, logo
first, each followed by an INITAD to LD_STEP, and the RUNAD last.
LDR_INIT clears the logo area and puts up a display list with the logo
where the title has it, LOADING and the bar; the steps fill the bar."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tools"))
from run6502 import Machine     # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
XEX = os.path.join(ROOT, "build", "acadia.xex")
LDR = os.path.join(ROOT, "build", "loader.xex")
LAB = os.path.join(ROOT, "build", "loader.lab")

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


g = Machine()
logo = g.addr("LOGO")
logo_end = logo + g.addr("LOGO_H") * 40 - 1
m = Machine(xex=LDR, labels=LAB)
LDR_INIT = m.addr("LDR_INIT")
STEP = m.addr("LD_STEP")
TAB = m.addr("LD_TAB")
BAR = m.addr("LD_BAR")
BW, BX = m.addr("LD_BW"), m.addr("LD_BX")
ldr = segments(open(LDR, "rb").read())
ldr_rng = [(s, e) for s, e, _ in ldr] + [(m.addr("LD_N"), m.addr("LD_END") - 1)]
segs = segments(open(XEX, "rb").read())
if segs[-1][0] == 0x0600:       # the D73 pad
    segs = segs[:-1]


def initad(s):
    return s[:2] == (0x02E2, 0x02E3) and s[2][0] | s[2][1] << 8


# order: the loader, INITAD = LDR_INIT, LD_TAB, chunks + steps, RUNAD
n = len(ldr)
if [s[:2] for s in segs[:n]] != [s[:2] for s in ldr]:
    fail("the file does not start with the loader's segments")
if LDR_INIT != 0x8730 or initad(segs[n]) != LDR_INIT:
    fail("the loader's INITAD is not next, or LDR_INIT is not at $8730")
if segs[n + 1][0] != TAB:
    fail("LD_TAB does not load next")
tab = list(segs[n + 1][2])
body = segs[n + 2:-1]
if segs[-1][:2] != (0x02E0, 0x02E1):
    fail("RUNAD is not last")
chunks = body[0::2]
steps = body[1::2]
if len(chunks) != len(steps) or any(initad(s) != STEP for s in steps):
    fail("not every chunk is followed by an INITAD to LD_STEP")
if len(tab) != len(chunks):
    fail("%d table entries for %d chunks" % (len(tab), len(chunks)))
if tab != sorted(tab) or not tab or tab[-1] != BW or max(tab) > BW:
    fail("LD_TAB %r does not grow to %d" % (tab, BW))
if not chunks or not (chunks[0][0] == logo and
                      chunks[0][1] >= min(logo_end, logo + 1023)):
    fail("the first chunk does not start with the logo")
for s, e, _ in chunks:
    if e - s >= 1024:
        fail("chunk $%04X-$%04X over 1K" % (s, e))
    for a, b in ldr_rng:
        if s <= b and e >= a:
            fail("chunk $%04X-$%04X loads over the loader" % (s, e))
if ldr[0][1] >= 0x8800:
    fail("loader ends at $%04X, into the font at $8800" % ldr[0][1])

# run LDR_INIT on the loader alone, with junk where the logo goes
for a in range(0x8000, 0x8500):
    m.mem[a] = 0x55
m.on_read("VCOUNT", lambda: 125)        # in vertical blank
m.call(LDR_INIT)
if any(m.mem[a] for a in range(logo, logo_end + 1)):
    fail("logo area not cleared")
if m.mem[m.addr("NMIEN")] != 0xC0:
    fail("VBI and DLI not on")
if m.mem[m.addr("PORTB")] & 2 == 0:
    fail("BASIC not switched out")
dl = m.mem[0x0230] | m.mem[0x0231] << 8
if (m.mem[m.addr("DLISTL")] | m.mem[m.addr("DLISTL") + 1] << 8) != dl:
    fail("DLISTL not set as SDLSTL")
if not any(s <= dl <= e for s, e, _ in ldr):
    fail("SDLSTL $%04X is not in the loader" % dl)
if (m.mem[0x0200] | m.mem[0x0201] << 8) != m.addr("LD_DLI"):
    fail("VDSLST is not LD_DLI")
want = [0] * BX + [0x55] * BW + [0] * (40 - BX - BW)
if [m.mem[BAR + i] for i in range(40)] != want:
    fail("bar not an empty track")
for i, v in enumerate(tab):
    m.mem[TAB + i] = v
for i in range(len(tab)):
    m.call(STEP)
    on = sum(1 for k in range(BW) if m.mem[BAR + BX + k] == 0xAA)
    if on != tab[i]:
        fail("step %d: %d bytes filled, want %d" % (i, on, tab[i]))
        break

# walk the display list
LINES = {2: 8, 4: 8, 5: 16, 6: 8, 7: 16, 0xA: 4, 0xD: 2}
pc, lines, lms, dlis = dl, 0, [], 0
for _ in range(100):
    op = m.mem[pc]
    if pc // 1024 != dl // 1024:
        fail("display list crosses a 1K boundary")
    if op & 0x80:
        dlis += 1
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
        lms.append((mode, None, lines))
        pc += 1
    lines += LINES[mode]
else:
    fail("no JVB")
if not lms or lms[0][:2] != (0xD, logo) or lms[0][2] != 28:
    fail("the logo does not start at LOGO on line 28 (the title's)")
nlogo = 0
for x in lms:
    if x[0] != 0xD or (x[1] is not None and x[1] != logo):
        break
    nlogo += 1
if nlogo != g.addr("LOGO_H"):
    fail("%d logo lines, want LOGO_H" % nlogo)
txt = [x for x in lms if x[0] == 6]
bar = [x for x in lms if x[1] == BAR]
if not txt or not bar or bar[0][2] < txt[0][2]:
    fail("no LOADING line with the bar under it")
else:
    t = txt[0][1]
    word = "".join(chr((m.mem[t + i] & 0x3F) + 0x20) for i in range(20))
    if word.strip() != "LOADING":
        fail("text reads %r" % word)
if dlis != 2:
    fail("%d DLIs, want 2 (LD_DLI's)" % dlis)
if lines > 216:
    fail("%d scan lines" % lines)

print("test_loader: DL $%04X, %d lines, %d chunks, %d fails"
      % (dl, lines, len(chunks), fails))
sys.exit(1 if fails else 0)
