#!/usr/bin/env python3
"""T-5200-4: the 5200 cartridge starts without the BIOS screen (D77), py65.

The header's $BFFD is $FF, so the BIOS jumps to START with nothing set
up.  From START, with RAM full of junk: BT_INIT clears RAM and the zero
page, sets the vectors to the cartridge's own handlers and the keypad
scan, and MAIN_INIT reaches the main loop on the title screen.  Then
BT_VBI on its own (VVBLKD = BT_XIT): the clock, the shadows to the
hardware, attract colours, the pots, and A, X, Y kept.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))
from run6502 import Machine  # noqa: E402

fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def check(what, got, want):
    if got != want:
        fail("%s: got %r, want %r" % (what, got, want))


def run_to(m, target, limit=5000000):
    stop = m.addr(target)
    for _ in range(limit):
        if m.mpu.pc == stop:
            return
        m.mpu.step()
    raise RuntimeError("did not reach %s" % target)


m = Machine(cart=True)
rom = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build",
                        "acadia5200.bin"), "rb").read()
check("header $BFFD", rom[0xBFFD - 0x4000], 0xFF)
check("header start vector", rom[0xBFFE - 0x4000] | rom[0xBFFF - 0x4000] << 8, m.addr("START"))

for a in range(0x0000, 0x4000):             # power-on junk in all RAM
    m.mem[a] = (a * 7 + 0x5A) & 0xFF
m.on_read("PAL", lambda: 0x0F)              # NTSC
m.mpu.sp = 0xFF                             # as the BIOS leaves it
m.mpu.p |= m.mpu.INTERRUPT
m.mpu.pc = m.addr("START")
run_to(m, "MAIN")
check("title", m.byte("GSTATE"), m.sym["GS_TITLE"])
check("VIMIRQ", m.word("VIMIRQ"), m.addr("BT_IRQ"))
check("VVBLKI", m.word("VVBLKI"), m.addr("BT_VBI"))
check("VVBLKD: our VBI", m.word("VVBLKD"), m.addr("VBI_D"))
check("PV_OLD: the VBI's end", m.word("PV_OLD"), m.addr("BT_XIT"))
check("VKYBDI", m.word("VKYBDI"), m.addr("BT_RTI"))
check("SKCTL: keypad scan", m.byte("SKCTL"), 2)
check("NMIEN: VBI on", m.byte("NMIEN") & 0x40, 0x40)
check("POKMSK: no IRQs", m.byte("POKMSK"), 0)
check("CRITIC", m.byte("CRITIC"), 0)
check("free RAM cleared", [a for a in range(0x3000, 0x4000) if m.mem[a]], [])
check("chart RAM cleared", [a for a in range(m.addr("CTBM0"), m.addr("CTBM0") + 0x800)
                            if m.mem[a]], [])

# BT_VBI alone: the deferred VBI is just its end
m.poke("VVBLKD", m.addr("BT_XIT") & 0xFF, m.addr("BT_XIT") >> 8)
m.poke("RTCLOK", 0x12, 0xFF)                # high, low: the low byte wraps
m.poke("ATRACT", 0x7F)                      # to $80: attract mode
m.poke("SDLSTL", 0x34, 0x56, 0x22)          # DL, DMACTL
for i in range(9):
    m.poke(m.addr("PCOLR0") + i, 0x90 + i)
for i in range(8):
    m.poke(m.addr("POT0") + i, 100 + i)
m.mpu.a, m.mpu.x, m.mpu.y = 0x11, 0x22, 0x33
m.interrupt("BT_VBI")
check("A, X, Y kept", (m.mpu.a, m.mpu.x, m.mpu.y), (0x11, 0x22, 0x33))
check("RTCLOK", (m.byte("RTCLOK"), m.byte("RTCLOK", 1)), (0x13, 0x00))
check("ATRACT", m.byte("ATRACT"), 0x80)
check("DLIST", (m.byte("DLISTL"), m.byte("DLISTH")), (0x34, 0x56))
check("DMACTL", m.byte("DMACTL"), 0x22)
check("attract colours", [m.byte("COLPM0", i) for i in range(9)],
      [((0x90 + i) ^ 0x13) & 0xF6 for i in range(9)])
check("pots", [m.byte("PADDL0", i) for i in range(8)], [100 + i for i in range(8)])

# not in attract mode, and CRITIC: nothing copied
m.poke("ATRACT", 0)
m.mpu.a, m.mpu.x, m.mpu.y = 0x44, 0x55, 0x66
m.interrupt("BT_VBI")
check("plain colours", [m.byte("COLPM0", i) for i in range(9)], [0x90 + i for i in range(9)])
check("A, X, Y kept again", (m.mpu.a, m.mpu.x, m.mpu.y), (0x44, 0x55, 0x66))
m.poke("CRITIC", 1)
m.poke("SDMCTL", 0x00)
m.interrupt("BT_VBI")
check("CRITIC: DMACTL kept", m.byte("DMACTL"), 0x22)
check("CRITIC: the clock still counts", m.byte("RTCLOK", 1), 0x02)

if fails:
    print("test_boot5200: %d failures" % fails)
    sys.exit(1)
print("test_boot5200: ok")
