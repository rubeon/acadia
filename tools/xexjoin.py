#!/usr/bin/env python3
"""Join the loader and the game into build/acadia.xex (D57, D81).

    xexjoin.py OUT LOADER.XEX LDRINIT.XEX GAME.XEX LOADER.LAB LOADER.ASM

The file loads in this order:
  1. the loader's segments (LOADER.ASM: LDR_INIT at $8730, LD_STEP ...)
  2. its INITAD (LDRINIT.ASM): LDR_INIT switches BASIC out and puts up
     the loading screen
  3. LD_TAB: the loading bar's length (bytes of fill, 0-LD_BW) after
     each chunk of the game
  4. the game's segments, the title graphics ($8000, the logo first)
     first, then the rest in address order, cut into chunks of at most
     CHUNK bytes, each followed by an INITAD to LD_STEP, which grows the
     bar to its LD_TAB entry
  5. the game's RUNAD.
ATasm writes a file's segments in address order, so it can't do this
itself.  Fails when a file does not parse, there is no segment at
$8000, there are more chunks than LD_TAB has room for, or a segment
loads at $9C00-$9FFF or $BC00-$BFFF: the OS's screen while the file
loads, and again after a warm RESET, which would overwrite it (D57)."""

import re
import sys

CHUNK = 1024            # bytes of the game between two bar steps
FIRST = 0x8000          # TITLEGFX: the logo, loaded first
RUNAD = 0x02E0
INITAD = 0x02E2
OS_SCR = ((0x9C00, 0x9FFF), (0xBC00, 0xBFFF))   # never loaded (D57)


def segments(data, name):
    pos, out = 0, []
    while pos < len(data):
        if data[pos:pos + 2] == b"\xff\xff":
            pos += 2
        if pos + 4 > len(data):
            sys.exit("xexjoin: %s: header cut short at %d" % (name, pos))
        start = data[pos] | data[pos + 1] << 8
        end = data[pos + 2] | data[pos + 3] << 8
        if end < start or pos + 5 + end - start > len(data):
            sys.exit("xexjoin: %s: bad segment at %d" % (name, pos))
        out.append((start, data[pos + 4:pos + 5 + end - start]))
        pos += 5 + end - start
    return out


def seg(start, body):
    end = start + len(body) - 1
    return bytes([start & 255, start >> 8, end & 255, end >> 8]) + bytes(body)


def word(w):
    return [w & 255, w >> 8]


def main():
    if len(sys.argv) != 7:
        sys.exit(__doc__)
    out, ldr, ini, game, lab, asm = sys.argv[1:]
    sym = {}
    for line in open(lab):
        p = line.split()
        if len(p) == 2:
            sym[p[1].upper()] = int(p[0], 16)
    m = re.search(r"^LD_BW\s*=\s*(\d+)", open(asm).read(), re.M)
    if not m or not all(k in sym for k in ("LD_STEP", "LD_TAB", "LD_END")):
        sys.exit("xexjoin: LD_BW, LD_STEP, LD_TAB or LD_END missing")
    width = int(m.group(1))
    room = sym["LD_END"] - sym["LD_TAB"]

    gsegs = segments(open(game, "rb").read(), game)
    runad = [s for s in gsegs if s[0] == RUNAD]
    data = [s for s in gsegs if s[0] != RUNAD]
    for start, body in data:
        end = start + len(body) - 1
        for lo, hi in OS_SCR:
            if start <= hi and end >= lo:
                sys.exit("xexjoin: segment $%04X-$%04X loads into the OS screen at "
                         "$%04X-$%04X (D57)" % (start, end, lo, hi))
    first = [s for s in data if s[0] == FIRST]
    if not first or not runad:
        sys.exit("xexjoin: no segment at $%04X or no RUNAD" % FIRST)
    data = first + sorted((s for s in data if s[0] != FIRST),
                          key=lambda s: s[0])
    chunks = []
    for start, body in data:
        for i in range(0, len(body), CHUNK):
            chunks.append((start + i, body[i:i + CHUNK]))
    if len(chunks) > room:
        sys.exit("xexjoin: %d chunks, LD_TAB has room for %d"
                 % (len(chunks), room))
    total = sum(len(b) for _, b in chunks)
    tab, done = [], 0
    for _, body in chunks:
        done += len(body)
        tab.append((done * width + total // 2) // total)

    f = b"\xff\xff"
    for start, body in segments(open(ldr, "rb").read(), ldr):
        f += seg(start, body)
    for start, body in segments(open(ini, "rb").read(), ini):
        f += seg(start, body)
    f += seg(sym["LD_TAB"], tab)
    step = seg(INITAD, word(sym["LD_STEP"]))
    for start, body in chunks:
        f += seg(start, body) + step
    for start, body in runad:
        f += seg(start, body)
    open(out, "wb").write(f)
    print("%s: %d bytes, %d chunks" % (out, len(f), len(chunks)))


main()
