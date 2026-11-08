#!/usr/bin/env python3
"""T-CTL-5: RESET goes back to the title screen (D76), py65.

800: PLAT_INIT points DOSINI at RESTART, sets BOOT? bit 0 and COLDST = 0
(so the OS's warm start calls it), and puts map 1 back in the live
tables.  RESTART, entered as the OS would after a game on the RANDOM
map, runs the start-up again to the main loop: title screen, our VBI
chained to the OS's, map 1 in the tables.

5200: started at START as the BIOS jumps there (D77); the keypad's RESET
key, in a game, jumps to PLAT_RST, which waits while it is held and then
restarts: title screen, BT_XIT (the VBI's end) kept at the end of the chain (not our own VBIs chained to
themselves).
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

fails = 0
OS_XITVBV = 0xE462              # the 800 OS's deferred VBI exit


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def check(what, got, want):
    if got != want:
        fail("%s: got %r, want %r" % (what, got, want))


def run_to(m, target, limit=3000000):
    """Step from the current PC until it reaches the label target."""
    stop = m.addr(target)
    for _ in range(limit):
        if m.mpu.pc == stop:
            return
        m.mpu.step()
    raise RuntimeError("did not reach %s" % target)


def table(m, name, i):
    return m.byte(name, i)


def map_ok(m, what, cart=False):
    """The live tables hold map 1's block (MAPS0).  On the 5200,
    PLAT_MAP points FONTPG and ROWFONT at the fonts' RAM copies, so
    those bytes differ on purpose: skipped."""
    live = m.addr("TILECH")
    n = m.addr("MAPEND") - live
    src = table(m, "MAPSL", 0) | table(m, "MAPSH", 0) << 8
    skip = set()
    if cart:
        for name, k in (("FONTPG", 3), ("ROWFONT", 22)):
            skip.update(range(m.addr(name) - live, m.addr(name) - live + k))
    bad = [i for i in range(n) if i not in skip and m.mem[live + i] != m.mem[src + i]]
    if bad:
        fail(what + ": the live tables are not map 1's (%d bytes)" % len(bad))


# ---------------------------------------------------------------- 800
m = Machine()
m.poke("PAL", 0x0F)                               # NTSC
m.poke("DOSINI", 0, 0)
m.poke("BOOTQ", 0)
m.poke("COLDST", 0xFF)                            # a loader left it so
m.call("PLAT_INIT")
check("DOSINI", m.word("DOSINI"), m.addr("RESTART"))
check("BOOT? bit 0", m.byte("BOOTQ") & 1, 1)
check("COLDST", m.byte("COLDST"), 0)
check("MAPLD after PLAT_INIT", m.byte("MAPLD"), 0)
map_ok(m, "PLAT_INIT")

# as after a game on the RANDOM map, then RESET: the OS's warm start has
# put its own VBI exit back and calls DOSINI from deep in its stack
m.poke("MAPLD", m.sym["MAP_RND"])
live = m.addr("TILECH")
for i in range(m.addr("MAPEND") - live):
    m.mem[live + i] = 0x5A
m.poke("GSTATE", 0)
m.poke("VVBLKD", OS_XITVBV & 0xFF, OS_XITVBV >> 8)
m.mpu.sp = 0x80
m.mpu.p |= m.mpu.INTERRUPT
m.mpu.pc = m.word("DOSINI")
run_to(m, "MAIN")
check("800 RESET: title", m.byte("GSTATE"), m.sym["GS_TITLE"])
check("800 RESET: a fresh stack", m.mpu.sp, 0xFF)
check("800 RESET: IRQs on", m.mpu.p & m.mpu.INTERRUPT, 0)
check("800 RESET: our VBI", m.word("VVBLKD"), m.addr("VBI_D"))
check("800 RESET: then the OS's", m.word("OLDVBD"), OS_XITVBV)
check("800 RESET: MAPLD", m.byte("MAPLD"), 0)
check("800 RESET: DOSINI kept", m.word("DOSINI"), m.addr("RESTART"))
map_ok(m, "800 RESET")

# --------------------------------------------------------------- 5200
CODE = {"R": 4, "S": 12}
C = 114
m = Machine(cart=True)
m.on_read("PAL", lambda: 0x0F)                   # NTSC (BT_INIT clears GTIA)
m.mpu.pc = m.addr("START")                       # as the BIOS jumps (D77)
run_to(m, "MAIN")
VBI_END = m.addr("BT_XIT")                       # our VBI's end (D77)
check("5200 start: PLAT_VBI", m.word("VVBLKD"), m.addr("VBI_D"))
check("5200 start: our VBI's end last", m.word("PV_OLD"), VBI_END)


def frame(n=1, pad=None, bot=False):
    for _ in range(n):
        m.poke("FRAME", (m.byte("FRAME") + 1) & 0xFF)
        m.poke("PADDL0", C, C, C, C)
        m.poke("TRIG0", 1)
        m.poke("TRIG1", 1)
        sk = 0xFF
        if pad is not None and m.byte("CONSOL") & 3 == 0:
            sk &= ~0x04
            m.poke("KBCODE", 0x21 | CODE[pad] << 1)
        if bot:
            sk &= ~0x08
        m.poke("SKSTAT", sk)
        m.call("GAME_FRAME", limit=2000000)


# title -> setup (bottom button) -> a game (START)
frame(10)
frame(3, bot=True)
frame(5)
check("5200 setup", m.byte("GSTATE"), m.sym["GS_SETUP"])
frame(10)
frame(4, pad="S")
frame(6)
check("5200 in a game", m.byte("GSTATE"), 0)

# RESET pressed on controller 1: INPUT_POLL goes to PLAT_RST
while m.byte("CONSOL") & 3 != 0:
    frame()
m.poke("SKSTAT", 0xFB)
m.poke("KBCODE", 0x21 | CODE["R"] << 1)
m.mpu.sp = 0xF0
m.mpu.pc = m.addr("INPUT_POLL")
run_to(m, "PLAT_RST", limit=20000)
# held: it waits, and does not restart
stop = m.addr("RESTART")
for _ in range(50000):
    m.mpu.step()
    if m.mpu.pc == stop:
        fail("5200 RESET held: restarted while held")
        break
check("5200 RESET held: NMIs off", m.byte("NMIEN"), 0)
check("5200 RESET held: screen off", (m.byte("DMACTL"), m.byte("SDMCTL")), (0, 0))
check("5200 RESET held: the VBI's end back", m.word("VVBLKD"), VBI_END)
m.poke("SKSTAT", 0xFF)                            # let go
run_to(m, "MAIN")
check("5200 RESET: title", m.byte("GSTATE"), m.sym["GS_TITLE"])
check("5200 RESET: a fresh stack", m.mpu.sp, 0xFF)
check("5200 RESET: VBI_D first", m.word("VVBLKD"), m.addr("VBI_D"))
check("5200 RESET: then PLAT_VBI", m.word("OLDVBD"), m.addr("PLAT_VBI"))
check("5200 RESET: then our VBI's end", m.word("PV_OLD"), VBI_END)
check("5200 RESET: NMIs on", m.byte("NMIEN") & 0x40, 0x40)
check("5200 RESET: MAPLD", m.byte("MAPLD"), 0)
map_ok(m, "5200 RESET", cart=True)

# and the title still works: fire goes on to setup
frame(10)
frame(3, bot=True)
frame(5)
check("5200 after RESET: fire on the title", m.byte("GSTATE"), m.sym["GS_SETUP"])

if fails:
    print("test_reset: %d failures" % fails)
    sys.exit(1)
print("test_reset: ok")
