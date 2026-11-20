#!/usr/bin/env python3
"""T-INFRA-4 (D94): build/acadia.atr is a 90K single density disk whose
boot sectors (src/bootatr.asm) load build/acadia.xex, stored as it is
from the next sector on.  Runs the boot loader as the OS would (boot
sectors at BA_BASE, JSR BA_GO) with DSKINV served from the image (one
read fails first, to check it tries again), INITAD calls recorded and
returned at once: every segment must land at its address, INITAD be
called after each segment that sets it, in order, and the RUNAD taken
at the end, with POKEY's SKCTL and AUDCTL reset first (D95)."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tools"))
from run6502 import Machine     # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ATR = os.path.join(ROOT, "build", "acadia.atr")
XEX = os.path.join(ROOT, "build", "acadia.xex")
BOOT = os.path.join(ROOT, "build", "bootatr.xex")
LAB = os.path.join(ROOT, "build", "bootatr.lab")
SECSZ, NSECS = 128, 720
INITAD, RUNAD = 0x02E2, 0x02E0
BAD_SEC = 10            # the first read of this sector fails

fails = 0


def fail(msg):
    global fails
    fails += 1
    print("FAIL " + msg)


def segments(data):
    pos, out = 0, []
    while pos < len(data):
        if data[pos:pos + 2] == b"\xff\xff":
            pos += 2
        start = data[pos] | data[pos + 1] << 8
        end = data[pos + 2] | data[pos + 3] << 8
        out.append((start, data[pos + 4:pos + 5 + end - start]))
        pos += 5 + end - start
    return out


atr = open(ATR, "rb").read()
xex = open(XEX, "rb").read()
if atr[:2] != b"\x96\x02":
    fail("no ATR signature")
para = atr[2] | atr[3] << 8 | atr[6] << 16
if para * 16 != len(atr) - 16 or para * 16 != NSECS * SECSZ:
    fail("ATR size %d, header says %d" % (len(atr) - 16, para * 16))
if atr[4] | atr[5] << 8 != SECSZ:
    fail("sector size is not %d" % SECSZ)
disk = atr[16:]


def sector(n):
    return disk[(n - 1) * SECSZ:n * SECSZ]


m = Machine(xex=BOOT, labels=LAB)
base = m.addr("BA_BASE")
nsec = disk[1]
if disk[0] != 0 or disk[2] | disk[3] << 8 != base:
    fail("boot header: flags %d, load $%04X" % (disk[0], disk[2] | disk[3] << 8))
if nsec != m.addr("BA_NSEC"):
    fail("boot header says %d sectors, BA_NSEC is %d" % (nsec, m.addr("BA_NSEC")))
first = m.addr("BA_FIRST")
if disk[(first - 1) * SECSZ:(first - 1) * SECSZ + len(xex)] != xex:
    fail("the XEX is not stored as it is from sector %d" % first)
if any(disk[(first - 1) * SECSZ + len(xex):]):
    fail("the rest of the disk is not empty")

# the OS: the boot sectors to BA_BASE, DOSINI from the header, JSR BA_GO
for i in range(nsec):
    m.mem[base + i * SECSZ:base + (i + 1) * SECSZ] = list(sector(i + 1))
if m.word("BA_LEN") != len(xex):
    fail("BA_LEN %d, the XEX is %d bytes" % (m.word("BA_LEN"), len(xex)))
m.poke("SOUNDR", 3)
m.poke("SDMCTL", 0)

DSKINV, JINI, RUN = m.addr("DSKINV"), m.addr("BA_JINI"), m.addr("BA_JRUN")
skctl = []
m.mem.subscribe_to_write([m.addr("SKCTL")], lambda a, v: skctl.append(v))
inits, reads, failed = [], [], [False]


def rts():
    lo = m.mem[0x100 + ((m.mpu.sp + 1) & 255)]
    hi = m.mem[0x100 + ((m.mpu.sp + 2) & 255)]
    m.mpu.sp = (m.mpu.sp + 2) & 255
    m.mpu.pc = (lo | hi << 8) + 1


m.mpu.sp = 0xF0
m.mpu.pc = m.addr("BA_GO")
steps = 0
while True:
    pc = m.mpu.pc
    if pc == DSKINV:
        n = m.byte("DAUX1") | m.byte("DAUX2") << 8
        if m.byte("DUNIT") != 1 or m.byte("DCOMND") != 0x52:
            fail("DSKINV called with unit %d, command $%02X"
                 % (m.byte("DUNIT"), m.byte("DCOMND")))
            break
        if n == BAD_SEC and not failed[0]:
            failed[0] = True
            m.poke("DSTATS", 0x8A)          # timeout
        else:
            buf = m.word("DBUFLO")
            m.mem[buf:buf + SECSZ] = list(sector(n))
            m.poke("DSTATS", 1)
            reads.append(n)
        rts()
        continue
    if pc == JINI:
        inits.append(m.word("INITAD"))
        if m.byte("SDMCTL") == 0 and len(inits) > 1:
            fail("DMA still off after the first INITAD call")
        rts()
        continue
    if pc == RUN:
        break
    m.mpu.step()
    steps += 1
    if steps > 5000000:
        fail("the boot loader never got to RUNAD")
        break

segs = segments(xex)
want_inits = [b[0] | b[1] << 8 for s, b in segs if s == INITAD]
want_run = [b[0] | b[1] << 8 for s, b in segs if s == RUNAD][-1]
if inits != want_inits:
    fail("INITAD calls %s, want %s" % ([hex(i) for i in inits[:5]],
                                       [hex(i) for i in want_inits[:5]]))
if m.word("RUNAD") != want_run:
    fail("RUNAD $%04X, want $%04X" % (m.word("RUNAD"), want_run))
last = first + (len(xex) - 1) // SECSZ
if reads != list(range(first, last + 1)):
    fail("sectors read %d-%d (%d), want %d-%d"
         % (reads[0], reads[-1], len(reads), first, last))
if not failed[0]:
    fail("no failed read was tried again")
bad = 0
for start, body in segs:
    if start in (INITAD, RUNAD):
        continue
    if list(m.mem[start:start + len(body)]) != list(body):
        bad += 1
        if bad <= 3:
            fail("segment $%04X-$%04X not loaded as in the XEX"
                 % (start, start + len(body) - 1))
if skctl[-2:] != [0, 3] or m.byte("SSKCTL") != 3 or m.byte("AUDCTL") != 0:
    fail("POKEY not reset for the game: SKCTL writes %s, SSKCTL $%02X, "
         "AUDCTL $%02X (D95)" % (skctl[-4:], m.byte("SSKCTL"), m.byte("AUDCTL")))
if m.byte("SOUNDR") != 0:
    fail("SOUNDR not 0: the load beeps")
if m.byte("SDMCTL") != m.addr("DMA_NORM"):
    fail("SDMCTL $%02X at the end" % m.byte("SDMCTL"))

print("test_atr: %d sectors read, %d segments, %d INITAD calls, %d steps, "
      "%d fails" % (len(reads), len(segs), len(inits), steps, fails))
sys.exit(1 if fails else 0)
