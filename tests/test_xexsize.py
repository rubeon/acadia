#!/usr/bin/env python3
"""T-INFRA-6 (D73): the MiSTer's disk-boot XEX loader serves the file
125 bytes a sector and reads stale bytes after a last sector that is
exactly full, so build/acadia.xex must not be a multiple of 125 bytes
long; its segments must still parse to the end of the file."""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
XEX = os.path.join(HERE, "..", "build", "acadia.xex")

data = open(XEX, "rb").read()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


if len(data) % 125 == 0:
    fail("%d bytes is a multiple of 125 (D73)" % len(data))

pos = 0
segs = 0
while pos < len(data):
    if data[pos:pos + 2] == b"\xff\xff":
        pos += 2
    if pos + 4 > len(data):
        fail("header cut short at %d" % pos)
        break
    start = data[pos] | data[pos + 1] << 8
    end = data[pos + 2] | data[pos + 3] << 8
    if end < start:
        fail("segment at %d ends before it starts" % pos)
        break
    pos += 4 + end - start + 1
    segs += 1
if pos != len(data):
    fail("last segment runs past the end of the file")

print("test_xexsize: %d bytes, %d segments, %d fails"
      % (len(data), segs, fails))
sys.exit(1 if fails else 0)
