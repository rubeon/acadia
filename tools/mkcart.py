#!/usr/bin/env python3
"""Make the Atari 5200 cartridge images from ATasm's output (D62).

    mkcart.py build/acadia5200.obj build/acadia5200.lab build/acadia5200

reads the assembled segments (ATasm's default binary-load format),
checks that every byte lands in the cartridge ($4000-$BFFF), that no
two segments overlap and that code block 2 ends below the logo, and
writes

    <out>.bin   the raw 32K ROM, unused bytes $FF
    <out>.car   the same with a CART header (type 4: 5200 32K)

then prints the free ROM and RAM bytes (from the label file).  Exits
with status 1 if anything does not fit.
"""

import os
import re
import sys

ROM, ROMSIZE = 0x4000, 0x8000
HDR = 0xBFE8                    # the cartridge header (MEM_5200.ASM)
CART_TYPE = 4                   # atari800 / Altirra: 5200 32K


def segments(data):
    i, out = 0, []
    while i < len(data):
        if data[i:i + 2] == b"\xff\xff":
            i += 2
        a = data[i] | data[i + 1] << 8
        b = data[i + 2] | data[i + 3] << 8
        i += 4
        out.append((a, data[i:i + b - a + 1]))
        i += b - a + 1
    return out


def labels(path):
    sym = {}
    for line in open(path):
        p = line.split()
        if len(p) == 2:
            sym[p[1].upper()] = int(p[0], 16)
    return sym


def equates(path, sym):
    """NAME = $xxxx, NAME = OTHER or NAME = OTHER+n from MEM_5200.ASM
    (the label file has only labels)."""
    for line in open(path):
        m = re.match(r"^([A-Z_][A-Z0-9_]*)\s*=\s*([$0-9A-Z_]+)(\+\$?[0-9A-F]+)?\s*(;|$)", line, re.I)
        if m:
            v = m.group(2).upper()
            v = int(v[1:], 16) if v.startswith("$") else int(v) if v.isdigit() else sym[v]
            if m.group(3):
                n = m.group(3)[1:]
                v += int(n[1:], 16) if n.startswith("$") else int(n)
            sym[m.group(1).upper()] = v


def main():
    obj, lab, out = sys.argv[1:4]
    sym = labels(lab)
    equates(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "mem_5200.asm"), sym)
    rom = bytearray(b"\xff" * ROMSIZE)
    used = bytearray(ROMSIZE)
    bad = False
    for a, bs in segments(open(obj, "rb").read()):
        if a < ROM or a + len(bs) > ROM + ROMSIZE:
            print("mkcart: segment $%04X-$%04X is outside the cartridge"
                  % (a, a + len(bs) - 1))
            bad = True
            continue
        for k, v in enumerate(bs):
            o = a - ROM + k
            if used[o]:
                print("mkcart: $%04X written twice (segments overlap)" % (a + k))
                bad = True
                break
            used[o] = 1
            rom[o] = v
    if sym["ROMEND"] > sym["TITLEGFX"]:
        print("mkcart: code block 2 ends at $%04X, past the logo at $%04X"
              % (sym["ROMEND"], sym["TITLEGFX"]))
        bad = True
    if bad:
        sys.exit(1)

    open(out + ".bin", "wb").write(rom)
    car = b"CART" + CART_TYPE.to_bytes(4, "big") + (sum(rom) & 0xFFFFFFFF).to_bytes(4, "big")
    open(out + ".car", "wb").write(car + bytes(4) + rom)

    free = HDR - ROM - sum(used[:HDR - ROM])
    print("ROM: %d bytes free of %d ($%04X-$%04X: %d, code block 2 to the logo)"
          % (free, HDR - ROM, sym["ROMEND"], sym["TITLEGFX"] - 1,
             sym["TITLEGFX"] - sym["ROMEND"]))
    # RAM: what MEM_5200.ASM's blocks leave between them
    ram = [(sym["PLATRAM"] + sym["PLATSZ"], sym["PMAREA"]),
           # the map (928 bytes, D67), then the setup screen's display
           # list (SU_DL, D71)
           (sym["MAPSCR"] + 928 + sym["SU_DLE"] - sym["SUDLIST"], sym["HELPSCR"]),
           (sym["HELPSCR"] + 11 * 40, sym["ISLDATA"]),
           (sym["AI_DN"] + 220, sym["VARBASE"]),
           (sym["VAREND"], sym["CTBM0"]),
           (sym["CTBM1"] + 0x400, sym["RAMEND"])]
    for a, b in ram:
        if b < a:
            print("mkcart: RAM blocks overlap at $%04X" % b)
            sys.exit(1)
    print("RAM: %d bytes free (%s)" % (sum(b - a for a, b in ram),
          ", ".join("$%04X-$%04X" % (a, b - 1) for a, b in ram if b > a)))


main()
