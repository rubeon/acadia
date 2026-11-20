#!/usr/bin/env python3
"""Make the bootable ATR disk (T-INFRA-4, D94).

    mkatr.py OUT.ATR BOOT.XEX BOOT.LAB BOOTATR.ASM GAME.XEX

BOOT.XEX is SRC/BOOTATR.ASM assembled: one segment at BA_BASE, the
boot sectors.  The disk is a 90K single density image (720 sectors of
128 bytes): the boot sectors from sector 1 on, with the game XEX's
length written at BA_LEN, then the XEX, byte for byte, from sector
BA_FIRST on; the rest zeros.  Fails when the boot code's header does
not match its size, the XEX does not parse, does not fit, or loads a
segment over the boot loader's memory (it would overwrite itself)."""

import re
import sys

SECSZ = 128
NSECS = 720             # a 90K single density disk
BA_ZP = (0x43, 0x46)    # BA_PTR, BA_END


def segments(data, name):
    pos, out = 0, []
    while pos < len(data):
        if data[pos:pos + 2] == b"\xff\xff":
            pos += 2
        if pos + 4 > len(data):
            sys.exit("mkatr: %s: header cut short at %d" % (name, pos))
        start = data[pos] | data[pos + 1] << 8
        end = data[pos + 2] | data[pos + 3] << 8
        if end < start or pos + 5 + end - start > len(data):
            sys.exit("mkatr: %s: bad segment at %d" % (name, pos))
        out.append((start, data[pos + 4:pos + 5 + end - start]))
        pos += 5 + end - start
    return out


def main():
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    out, boot, lab, asm, game = sys.argv[1:]
    sym = {}
    for m in re.finditer(r"^(BA_\w+)\s*=\s*\$([0-9A-F]+)\b", open(asm).read(),
                         re.M | re.I):
        sym[m.group(1).upper()] = int(m.group(2), 16)
    for line in open(lab):
        p = line.split()
        if len(p) == 2:
            sym[p[1].upper()] = int(p[0], 16)
    for k in ("BA_BASE", "BA_LEN", "BA_BUF", "BA_POS", "BA_EOC"):
        if k not in sym:
            sys.exit("mkatr: %s missing from %s" % (k, lab))

    bsegs = segments(open(boot, "rb").read(), boot)
    if len(bsegs) != 1 or bsegs[0][0] != sym["BA_BASE"]:
        sys.exit("mkatr: %s must be one segment at BA_BASE" % boot)
    code = bytearray(bsegs[0][1])
    nsec = (len(code) + SECSZ - 1) // SECSZ
    if code[1] != nsec or code[2] | code[3] << 8 != sym["BA_BASE"]:
        sys.exit("mkatr: the boot header does not match the code")

    xex = open(game, "rb").read()
    used = [(sym["BA_BASE"], sym["BA_EOC"] - 1),
            (sym["BA_BUF"], sym["BA_POS"]), BA_ZP]
    for start, body in segments(xex, game):
        end = start + len(body) - 1
        for lo, hi in used:
            if start <= hi and end >= lo:
                sys.exit("mkatr: %s loads $%04X-$%04X over the boot "
                         "loader's $%04X-$%04X" % (game, start, end, lo, hi))
    if len(xex) > 0xFFFF:
        sys.exit("mkatr: %s is too long for BA_LEN" % game)
    i = sym["BA_LEN"] - sym["BA_BASE"]
    code[i], code[i + 1] = len(xex) & 255, len(xex) >> 8

    disk = bytes(code) + bytes(nsec * SECSZ - len(code)) + xex
    if len(disk) > NSECS * SECSZ:
        sys.exit("mkatr: %d bytes do not fit on %d sectors"
                 % (len(disk), NSECS))
    disk += bytes(NSECS * SECSZ - len(disk))
    para = len(disk) // 16
    head = bytes([0x96, 0x02, para & 255, para >> 8 & 255, SECSZ & 255,
                  SECSZ >> 8, para >> 16]) + bytes(9)
    open(out, "wb").write(head + disk)
    xsec = (len(xex) + SECSZ - 1) // SECSZ
    print("%s: %d boot sectors, the XEX on sectors %d-%d, %d of %d free"
          % (out, nsec, nsec + 1, nsec + xsec, NSECS - nsec - xsec, NSECS))


main()
