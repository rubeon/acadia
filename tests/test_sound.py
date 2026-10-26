#!/usr/bin/env python3
"""T-SND-1, T-SND-2: the sound driver and its effects (py65)."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

AUDF1, AUDCTL = 0xD200, 0xD208
HOOKS = ["SND_BUY", "SND_REFUSE", "SND_FISH", "SND_RAIN", "SND_SMITE",
         "SND_SINK", "SND_ROUND", "SND_REBEL", "SND_STORM"]
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


m = Machine()
m.call("VARS_INIT")
m.mem[AUDCTL] = 0xFF
m.call("SND_INIT")
if m.mem[AUDCTL]:
    fail("AUDCTL %02X after SND_INIT, want 0" % m.mem[AUDCTL])


def voices():
    return [(m.mem[AUDF1 + 2 * c], m.mem[AUDF1 + 2 * c + 1]) for c in range(4)]


def playing():
    return [m.byte("SN_ON", c) for c in range(4)]


def run(frames):
    """VBI frames; the voices written each frame."""
    out = []
    for _ in range(frames):
        m.call("SND_VBI")
        out.append(voices())
    return out


data = m.addr("SNDEND") - m.addr("SNDDAT")
if data > 256:
    fail("SNDDAT is %d bytes; SN_POS holds an 8-bit offset" % data)

# each hook keeps A, X, Y, plays its effect on one voice, and ends quiet
for n, hook in enumerate(HOOKS):
    m.call("SND_INIT")
    a, x, y, _ = m.call(hook, a=0x5A, x=0xA5, y=0x3C)
    if (a, x, y) != (0x5A, 0xA5, 0x3C):
        fail("%s changed registers: %02X %02X %02X" % (hook, a, x, y))
    if sum(playing()) != 1:
        fail("%s: channels %r" % (hook, playing()))
    ch = playing().index(1)
    frames = run(300)
    loud = [i for i, v in enumerate(frames) if v[ch][1] & 0x0F]
    if not loud:
        fail("%s made no sound" % hook)
        continue
    length = loud[-1] + 1
    print("%-10s %3d frames on voice %d" % (hook, length, ch + 1))
    if not 5 <= length <= 90:
        fail("%s lasts %d frames" % (hook, length))
    if any(playing()) or frames[-1][ch][1] & 0x0F:
        fail("%s still playing after 5 s" % hook)
    if any(v[c][1] for v in frames for c in range(4) if c != ch):
        fail("%s used another voice" % hook)

# four at once take all four voices; a fifth of lower priority is
# dropped, one of higher priority takes the lowest voice
m.call("SND_INIT")
for hook in ("SND_FISH", "SND_RAIN", "SND_BUY", "SND_REFUSE"):
    m.call(hook)
pri = [m.byte("SN_PRI", c) for c in range(4)]
if playing() != [1, 1, 1, 1]:
    fail("four effects: channels %r" % playing())
m.call("SND_ROUND")                     # priority 5: takes a 1
after = [m.byte("SN_PRI", c) for c in range(4)]
if 5 not in after or sorted(after)[-1] != 5 or after.count(2) != 2:
    fail("SND_ROUND over four: priorities %r -> %r" % (pri, after))
m.call("SND_INIT")
for hook in ("SND_ROUND", "SND_SMITE", "SND_SINK", "SND_ROUND"):
    m.call(hook)
before = [(m.byte("SN_PRI", c), m.byte("SN_POS", c)) for c in range(4)]
m.call("SND_FISH")                      # priority 1 under 4-5: dropped
if [(m.byte("SN_PRI", c), m.byte("SN_POS", c)) for c in range(4)] != before:
    fail("a low effect replaced a higher one")

# paused: nothing moves; on resume the voices are written again
m.call("SND_INIT")
m.call("SND_ROUND")
run(3)
state = [m.byte(v, c) for v in ("SN_POS", "SN_CNT") for c in range(4)]
m.poke("PAUSED", 1)
m.call("SND_OFF")
run(20)
if [m.byte(v, c) for v in ("SN_POS", "SN_CNT") for c in range(4)] != state or any(c for _, c in voices()):
    fail("the driver moved or sounded while paused")
m.poke("PAUSED", 0)
run(1)
if not any(c & 0x0F for _, c in voices()):
    fail("no sound after resume")

# the hooks are wired in where things happen
for r in ("VARS_INIT", "DISP_INIT", "TIC_INIT", "SETUP_INIT", "GAME_NEW"):
    m.call(r)
m.call("SND_INIT")
m.call("REB_ADD", x=0)
if 3 not in [m.byte("SN_PRI", c) for c in range(4) if playing()[c]]:
    fail("REB_ADD: no rebel sound")
WT_STRM, WT_HURR = 2, 3
for kind, roll in ((WT_STRM, 1), (WT_HURR, 0)):
    m.call("SND_INIT")
    for s in (0, 1):
        m.mem[m.addr("WACT") + s] = 0
    m.on_read("RANDOM", lambda: roll)
    m.call("WTH_NEW", x=0)
    if m.byte("WACT") != kind or not any(playing()):
        fail("weather %d: WACT %d, playing %r" % (kind, m.byte("WACT"), playing()))
m.call("SND_INIT")
for s in (0, 1):
    m.mem[m.addr("WACT") + s] = 0
m.on_read("RANDOM", lambda: 9)          # rain: no rumble
m.call("WTH_NEW", x=0)
if m.byte("WACT") != 1 or any(playing()):
    fail("rain: WACT %d, playing %r" % (m.byte("WACT"), playing()))

print("sound: %d failed" % fails)
sys.exit(1 if fails else 0)
