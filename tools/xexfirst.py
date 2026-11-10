#!/usr/bin/env python3
"""Move one segment of an XEX to the front (D81).

    xexfirst.py IN OUT ADDR

ADDR is the start address (hex) of the segment to move, e.g. 8000 for
the title graphics, whose first part is the logo the loader's loading
screen shows.  ATasm writes a file's segments in address order, so it
can't do this itself.  Every segment keeps its $FFFF-free header form
except the first, which gets one.  Fails when no segment starts at ADDR
or the file does not parse."""

import sys


def segments(data):
    pos = 0
    out = []
    while pos < len(data):
        if data[pos:pos + 2] == b"\xff\xff":
            pos += 2
        if pos + 4 > len(data):
            sys.exit("xexfirst: header cut short at %d" % pos)
        start = data[pos] | data[pos + 1] << 8
        end = data[pos + 2] | data[pos + 3] << 8
        if end < start or pos + 4 + end - start + 1 > len(data):
            sys.exit("xexfirst: bad segment at %d" % pos)
        out.append((start, data[pos:pos + 4 + end - start + 1]))
        pos += 4 + end - start + 1
    return out


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    data = open(sys.argv[1], "rb").read()
    addr = int(sys.argv[3], 16)
    segs = segments(data)
    first = [s for s in segs if s[0] == addr]
    if not first:
        sys.exit("xexfirst: no segment starts at $%04X" % addr)
    rest = [s for s in segs if s[0] != addr]
    out = b"\xff\xff" + b"".join(s[1] for s in first + rest)
    open(sys.argv[2], "wb").write(out)


main()
