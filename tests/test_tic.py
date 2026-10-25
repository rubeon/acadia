#!/usr/bin/env python3
"""T-SVC-3: 20 Hz tic and seconds from frames, NTSC and PAL (py65).

The VBI's FRAME counter is stepped by hand; TIC_POLL is called after
1-12 frames at random (slow main-loop passes), and every due tic is
taken with TIC_NEXT.  60 s of frames must give 1200 tics and 60 new
seconds on both standards, with tics spread 3 frames apart on NTSC
and 2/3 frames apart on PAL.
"""

import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def run(std, seconds, rng, max_gap=12):
    m = Machine()
    m.poke("PAL", 0x01 if std == "PAL" else 0x0F)
    m.poke("FRAME", rng.randrange(256))          # any start value
    m.call("TIC_INIT")
    fps = 50 if std == "PAL" else 60
    frames = fps * seconds
    tics, secs, tic_frames = 0, 0, []
    f = 0
    while f < frames:
        step = min(rng.randrange(1, max_gap + 1), frames - f)
        for _ in range(step):
            f += 1
            m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
        m.call("TIC_POLL")
        while True:
            a, _, _, c = m.call("TIC_NEXT")
            if not c:
                break
            tics += 1
            tic_frames.append(f)
            if a == 0:
                secs += 1
    return tics, secs, tic_frames


rng = random.Random(3)
for std in ("NTSC", "PAL"):
    tics, secs, _ = run(std, 60, rng)
    if (tics, secs) != (1200, 60):
        fail("%s: 60 s of frames gave %d tics, %d seconds" % (std, tics, secs))
    else:
        print("%s: 60 s of frames -> %d tics, %d seconds (slow passes of 1-12 frames)"
              % (std, tics, secs))
    # spacing, polling every frame
    _, _, tf = run(std, 3, rng, max_gap=1)
    gaps = sorted(set(b - a for a, b in zip(tf, tf[1:])))
    want = [3] if std == "NTSC" else [2, 3]
    if gaps != want:
        fail("%s: tic spacing %r, want %r" % (std, gaps, want))
    else:
        print("%s: tics every %s frames" % (std, "/".join(map(str, gaps))))

# TIC_SYNC drops the frames that passed (pause)
m = Machine()
m.poke("PAL", 0x0F)
m.call("TIC_INIT")
m.poke("FRAME", (m.byte("FRAME") + 30) & 0xFF)
m.call("TIC_SYNC")
m.call("TIC_POLL")
if m.call("TIC_NEXT")[3]:
    fail("TIC_SYNC did not drop the paused frames")
else:
    print("TIC_SYNC: paused frames dropped")

print("tic: %d failed" % fails)
sys.exit(1 if fails else 0)
