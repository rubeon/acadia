#!/usr/bin/env python3
"""T-SND-1 to -3: the sound driver, its effects and the music (py65)."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

AUDF1, AUDCTL = 0xD200, 0xD208
HOOKS = ["SND_BUY", "SND_REFUSE", "SND_FISH", "SND_RAIN", "SND_SMITE",
         "SND_SINK", "SND_REBEL", "SND_STORM"]
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
m.call("SND_SMITE")                     # priority 4: takes a 1
after = [m.byte("SN_PRI", c) for c in range(4)]
if sorted(after) != [1, 2, 2, 4]:
    fail("SND_SMITE over four: priorities %r -> %r" % (pri, after))
m.call("SND_INIT")
for hook in ("SND_SMITE", "SND_SMITE", "SND_SINK", "SND_SINK"):
    m.call(hook)
before = [(m.byte("SN_PRI", c), m.byte("SN_POS", c)) for c in range(4)]
m.call("SND_FISH")                      # priority 1 under 4-5: dropped
if [(m.byte("SN_PRI", c), m.byte("SN_POS", c)) for c in range(4)] != before:
    fail("a low effect replaced a higher one")

# paused: nothing moves; on resume the voices are written again
m.call("SND_INIT")
m.call("SND_SINK")
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

# music: the title tune on voices 1 and 2, looping; effects on 3 and 4
NOTES = {}
for i, (o, n) in enumerate([(o, n) for o in (3, 4, 5) for n in range(12)]):
    NOTES[i + 1] = round(63921 / (2 * 440 * 2 ** ((o - 4) + (n - 9) / 12)) - 1)
C4, D4, E4, G4, A4, C5 = 121, 108, 96, 81, 72, 60


def starts(frames, voice):
    """AUDF of each note start (a silent frame before it) on a voice."""
    out, quiet = [], True
    for v in frames:
        f, c = v[voice]
        if c & 0x0F and quiet:
            out.append(f)
        quiet = not c & 0x0F
    return out


m.call("SND_INIT")
m.call("SND_FISH")
m.call("SND_FISH")
m.call("SND_FISH")
m.call("SND_FISH")
a, x, y, _ = m.call("MUS_TITLE", a=1, x=2, y=3)
if (a, x, y) != (1, 2, 3):
    fail("MUS_TITLE changed registers")
if playing()[:2] != [0, 0] or m.byte("SN_LO") != 2:
    fail("title: effects left on voices 1-2: %r" % playing())
frames = run(1400)
mel = starts(frames, 0)
if mel[:6] != [E4, G4, A4, C5, A4, G4]:
    fail("title melody starts %r" % mel[:6])
if not m.byte("MZ_ON") or len(mel) < 50:
    fail("title tune did not loop: %d notes, on %d" % (len(mel), m.byte("MZ_ON")))
if not starts(frames, 1):
    fail("title: no bass")
m.call("SND_BUY")
if playing()[:2] != [0, 0] or not any(playing()[2:]):
    fail("an effect during music: channels %r" % playing())
m.call("MUS_STOP")
if m.byte("MZ_ON") or m.byte("SN_LO") or m.mem[AUDF1 + 1] or m.mem[AUDF1 + 3]:
    fail("MUS_STOP left music on")

# the fanfare plays once, then effects get all four voices back
m.call("SND_INIT")
m.call("SND_ROUND")
frames = run(200)
loud = [i for i, v in enumerate(frames) if v[0][1] & 0x0F or v[1][1] & 0x0F]
print("fanfare    %3d frames" % (loud[-1] + 1))
if not 60 <= loud[-1] + 1 <= 90 or m.byte("MZ_ON") or m.byte("SN_LO"):
    fail("fanfare: %d frames, on %d" % (loud[-1] + 1, m.byte("MZ_ON")))
if starts(frames, 0)[:4] != [G4, C5, NOTES[29], NOTES[32]]:
    fail("fanfare notes %r" % starts(frames, 0))

# paused: the music stands still
m.call("MUS_TITLE")
run(50)
st = [m.byte(v, c) for v in ("MZ_POS", "MZ_CNT") for c in range(2)]
m.poke("PAUSED", 1)
run(30)
if [m.byte(v, c) for v in ("MZ_POS", "MZ_CNT") for c in range(2)] != st:
    fail("the music moved while paused")
m.poke("PAUSED", 0)
m.call("MUS_STOP")

data = m.addr("MUSEND") - m.addr("MUSDAT")
if data > 256:
    fail("MUSDAT is %d bytes" % data)

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

for r in ("SND_INIT", "SETUP_ENTER"):
    m.call(r)
if not m.byte("MZ_ON") or not m.byte("MZ_LOOP"):
    fail("SETUP_ENTER: no title tune")
m.poke("SU_VAL", 10, 30, 2, 2)
m.call("SU_GO")
if m.byte("MZ_ON"):
    fail("a game started with the title tune on")
m.call("ROUND_END")
if not m.byte("MZ_ON") or m.byte("MZ_LOOP"):
    fail("ROUND_END: no fanfare")

print("sound: %d failed" % fails)
sys.exit(1 if fails else 0)
