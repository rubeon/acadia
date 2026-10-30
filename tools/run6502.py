#!/usr/bin/env python3
"""Run routines from build/acadia.xex on a 6502 core (py65), for tests.

Loads every XEX segment into a flat 64K memory, reads label addresses
from the ATasm label file and equates from src/ (NAME = $xx, NAME = 123,
or sums of those and other symbols, such as NAME = MAPSCR+20),
and calls a routine by name with A/X/Y set, returning when it RTSes.
No Atari hardware is emulated: use it for pure routines (math, tables,
map logic), not for display or interrupt code.

    from run6502 import Machine
    m = Machine()                       # build/acadia.xex + .lab
    m.call("MUL8", a=12, x=34)
    m.word("M_NUM")                     # read 16 bits
    m.on_read("RANDOM", lambda: 42)     # fake a hardware register
"""

import glob
import os
import re

from py65.devices.mpu6502 import MPU
from py65.memory import ObservableMemory

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Machine:
    def __init__(self, xex=None, labels=None):
        xex = xex or os.path.join(ROOT, "build", "acadia.xex")
        labels = labels or os.path.join(ROOT, "build", "acadia.lab")
        self.mem = ObservableMemory()
        self.mpu = MPU(memory=self.mem)
        self.sym = {}
        self._load_xex(open(xex, "rb").read())
        for line in open(labels):
            parts = line.split()
            if len(parts) == 2:
                self.sym[parts[1].upper()] = int(parts[0], 16)
        equ = re.compile(r"^([A-Z_][A-Z0-9_]*)\s*=\s*([$0-9A-Z_+\-]+)\s*(;|$)", re.I)
        todo = {}
        for path in glob.glob(os.path.join(ROOT, "src", "*.asm")):
            for line in open(path):
                m = equ.match(line)
                if m:
                    todo.setdefault(m.group(1).upper(), m.group(2).upper())
        while todo:             # an equate may use one defined later
            done = [n for n, e in todo.items() if self._expr(e) is not None]
            if not done:
                break
            for n in done:
                self.sym.setdefault(n, self._expr(todo.pop(n)))

    def _expr(self, e):
        """Value of a sum like MAPSCR+20 or $D000-1, None if a symbol in
        it is not known (yet)."""
        v = 0
        for sign, t in re.findall(r"([+-]?)([^+-]+)", e):
            if t.startswith("$"):
                t = int(t[1:], 16)
            elif t.isdigit():
                t = int(t)
            elif t in self.sym:
                t = self.sym[t]
            else:
                return None
            v += -t if sign == "-" else t
        return v & 0xFFFF

    def _load_xex(self, data):
        i = 0
        while i < len(data):
            start = data[i] | data[i + 1] << 8
            if start == 0xFFFF:
                i += 2
                continue
            end = data[i + 2] | data[i + 3] << 8
            i += 4
            n = end - start + 1
            self.mem[start:start + n] = list(data[i:i + n])
            i += n

    def on_read(self, name, func):
        """Make reads of an address return func() (e.g. POKEY RANDOM)."""
        a = self.addr(name)
        self.mem.subscribe_to_read([a], lambda address: func() & 0xFF)

    def addr(self, name):
        return self.sym[name.upper()] if isinstance(name, str) else name

    def call(self, name, a=0, x=0, y=0, carry=False, limit=200000):
        """JSR to a routine; return (A, X, Y, carry) after its RTS."""
        sentinel = 0xFFF0
        self.mpu.sp = 0xFF
        ret = sentinel - 1                     # RTS adds one
        self.mem[0x01FF] = ret >> 8
        self.mem[0x01FE] = ret & 0xFF
        self.mpu.sp = 0xFD
        self.mpu.a, self.mpu.x, self.mpu.y = a & 0xFF, x & 0xFF, y & 0xFF
        self.mpu.p = (self.mpu.p & ~self.mpu.CARRY) | (self.mpu.CARRY if carry else 0)
        self.mpu.pc = self.addr(name)
        steps = 0
        while self.mpu.pc != sentinel:
            self.mpu.step()
            steps += 1
            if steps > limit:
                raise RuntimeError("%s did not return" % name)
        self.cycles_last = steps
        return self.mpu.a, self.mpu.x, self.mpu.y, bool(self.mpu.p & self.mpu.CARRY)

    def interrupt(self, name, limit=200000):
        """Run an interrupt handler (DLI, VBI) up to its RTI."""
        sentinel = 0xFFF0
        self.mem[0x01FF] = sentinel >> 8       # RTI pulls P, then the address
        self.mem[0x01FE] = sentinel & 0xFF
        self.mem[0x01FD] = self.mpu.p
        self.mpu.sp = 0xFC
        self.mpu.pc = self.addr(name)
        steps = 0
        while self.mpu.pc != sentinel:
            self.mpu.step()
            steps += 1
            if steps > limit:
                raise RuntimeError("%s did not return" % name)

    def byte(self, name, offset=0):
        return self.mem[self.addr(name) + offset]

    def word(self, name):
        a = self.addr(name)
        return self.mem[a] | self.mem[a + 1] << 8

    def long(self, name):
        a = self.addr(name)
        return self.mem[a] | self.mem[a + 1] << 8 | self.mem[a + 2] << 16

    def poke(self, name, *values):
        a = self.addr(name)
        for i, v in enumerate(values):
            self.mem[a + i] = v & 0xFF

    def set_long(self, name, value):
        self.poke(name, value, value >> 8, value >> 16)

    def status(self, start=0, n=80):
        """The status lines (STATUS1, then STATUS2) as ASCII, colour bits
        dropped: the gold bar shows as "$$", a person as "@@" (STFONT, D54)."""
        out = ""
        for i in range(n):
            c = self.byte("STATUS1", start + i) & 0x7F
            if 0x60 <= c <= 0x65:
                out += "$" if c < 0x62 else "@"
            else:
                out += chr((c & 0x3F) + 0x20)
        return out
