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
m.poke("COLRSH", 0)                       # no attract mode
m.poke("DRKMSK", 0xFF)
for r in ("VARS_INIT", "MAP_INIT", "DISP_INIT", "CUR_INIT", "TIC_INIT", "GAME_NEW"):
    m.call(r)


def frame(stick=0, kb=None, fire0=False):
    m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
    m.poke("PORTA", 0xFF ^ stick)         # active low; player 1 in the low nibble
    m.poke("TRIG0", 0 if fire0 else 1)
    m.poke("TRIG1", 1)
    m.poke("CONSOL", 0x07)                # no console key held
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


PB_ROW, PB_COL = m.sym["PB_ROW"], m.sym["PB_COL"]
PB_ADDR = m.sym["MAPSCR"] + 3 * 48 + (PB_ROW - 3) * 40   # rows 0-2 are wide (D67)


def band():
    return bytes(m.byte(PB_ADDR + i) for i in range(80))


def vbi():
    """What VBI_D does for the band (PB_VBI and the shades after it)."""
    m.call("PB_VBI")


def state():
    return dict(remsec=m.byte("REMSEC"), ticsec=m.byte("TICSEC"), gold=m.word("GOLD"),
                curx=m.byte("CURX"), cury=m.byte("CURY"),
                items=bytes(m.byte("MAPITEM", i) for i in range(220)),
                curtrn=m.byte("CURTRN"))


for _ in range(90):                       # 1.5 s of play
    frame()
before_line = line1()
before_band = band()
before_font = m.byte("ROWFONT", PB_ROW)
m.poke("AUDC1", 0xAF)
tap(KC_P)
if m.byte("PAUSED") != 1:
    fail("P did not pause")
if line1() != before_line:
    fail("status line 1 changed on pause (D69): %r" % line1())
vbi()
want = bytearray(80)
for n in range(6):                         # P A U S E D: top 1+2n, bottom 2+2n
    want[PB_COL + n] = 1 + 2 * n
    want[40 + PB_COL + n] = 2 + 2 * n
if band() != bytes(want):
    fail("band rows do not say PAUSED: %r" % band())
if m.byte("ROWFONT", PB_ROW) != m.sym["PSFONT"] >> 8:
    fail("band row not in the pause font")
bk = [m.byte("ROWBK", PB_ROW + i) for i in (0, 1)]
pf = [m.byte("ROWPF0", PB_ROW + i) for i in (0, 1)]
if bk != [m.sym["C_PBK"]] * 2 or pf != [m.sym["C_PTX"]] * 2:
    fail("band colours %r %r" % (bk, pf))
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
if band() != bytes(want) or line1() != before_line:
    fail("band or status line changed while paused")

tap(KC_P)
if m.byte("PAUSED") != 0:
    fail("P did not resume")
held = state()
frame(stick=RIGHT)                         # no VBI yet: the band is up,
if state() != held:                        # so the game still waits
    fail("game ran before the band was taken down")
vbi()
if band() != before_band or m.byte("ROWFONT", PB_ROW) != before_font:
    fail("map rows or font not restored")
m.call("TIC_SYNC")
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
