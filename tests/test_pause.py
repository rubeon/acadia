#!/usr/bin/env python3
"""T-CTL-1: pause and resume freeze the game (py65).

GAME_FRAME is called once per simulated frame with the joystick and
keyboard hardware faked, as the main loop would after each VBI.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

KC_P, KC_1 = 0x0A, 0x1F
RIGHT = 0x08
m = Machine()
fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


m.poke("PAL", 0x0F)                       # NTSC
for r in ("VARS_INIT", "MAP_INIT", "DISP_INIT", "CUR_INIT", "TIC_INIT", "DEMO_INIT"):
    m.call(r)


def frame(stick=0, kb=None, fire0=False):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF ^ stick)         # active low; player 1 in the low nibble
    m.poke("TRIG0", 0 if fire0 else 1)
    m.poke("TRIG1", 1)
    if kb is None:
        m.poke("SKSTAT", 0xFF)            # no key held
    else:
        m.poke("SKSTAT", 0xFB)
        m.poke("KBCODE", kb)
    m.call("GAME_FRAME")


def tap(kb, **kw):
    frame(kb=kb, **kw)
    frame(**{k: v for k, v in kw.items() if k != "kb"})   # release


def line1():
    return "".join(chr(m.byte("STATUS1", i) + 0x20) for i in range(40))


def state():
    return dict(remsec=m.byte("REMSEC"), ticsec=m.byte("TICSEC"), gold=m.word("GOLD"),
                curx=m.byte("CURX"), cury=m.byte("CURY"),
                items=bytes(m.byte("MAPITEM", i) for i in range(220)),
                curtrn=m.byte("CURTRN"))


for _ in range(90):                       # 1.5 s of play
    frame()
before_line = line1()
m.poke("AUDC1", 0xAF)
tap(KC_P)
if m.byte("PAUSED") != 1:
    fail("P did not pause")
if "PAUSED" not in line1():
    fail("status line 1 does not say PAUSED: %r" % line1())
if m.byte("AUDC1") != 0:
    fail("sound not silenced")
norm = [m.byte("PALTAB", i) for i in range(5)]
dim = [m.byte("MAPPAL", i) for i in range(5)]
if dim == norm or any((d & 0xF0) != (n & 0xF0) or (d & 0x0F) > (n & 0x0F) for d, n in zip(dim, norm)):
    fail("map not dimmed: %r vs %r" % (dim, norm))
frozen = state()

# 10 s of pushing the stick and pressing 1 (would buy a fort)
for i in range(600):
    if i % 20 == 0:
        tap(KC_1, stick=RIGHT)
    else:
        frame(stick=RIGHT)
if state() != frozen:
    changed = [k for k in frozen if state()[k] != frozen[k]]
    fail("game state changed while paused: %s" % changed)
if "PAUSED" not in line1():
    fail("PAUSED overwritten while paused")

tap(KC_P)
if m.byte("PAUSED") != 0:
    fail("P did not resume")
if line1() != before_line:
    fail("status line 1 not restored: %r" % line1())
if [m.byte("MAPPAL", i) for i in range(5)] != norm:
    fail("map colours not restored")

# time goes on from where it stopped: no paused frames are counted
start = state()
for _ in range(60):
    frame()
after = state()
if (start["remsec"] - after["remsec"]) not in (1,) or after["ticsec"] != start["ticsec"]:
    fail("after resume, 60 frames moved the clock %d s (tic %d -> %d)"
         % (start["remsec"] - after["remsec"], start["ticsec"], after["ticsec"]))
for _ in range(16):
    frame(stick=RIGHT)
if m.byte("CURX") <= start["curx"]:
    fail("cursor does not move after resume")

print("pause: %d failed" % fails)
sys.exit(1 if fails else 0)
