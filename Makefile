# Acadia -- Atari 8-bit build
#
#   make         build build/acadia.xex
#   make run     build and run in atari800 (800XL, BASIC off)
#   make test    build, then run the unit tests in tests/ on a 6502
#                core (needs py65: pip install py65)
#   make clean   remove build output

ATASM    ?= atasm
ATARI800 ?= atari800
EMUFLAGS ?= -xl -nobasic
PYTHON   ?= python3

SRC      := $(wildcard src/*.asm)
XEX      := build/acadia.xex
LAB      := build/acadia.lab
TESTS    := $(wildcard tests/test_*.py)

.PHONY: all run test clean

all: $(XEX)

# the loader (D57) first, then its INITAD, then the game: ATasm sorts a
# file's segments by address, so it can't put them in this order itself
$(XEX): $(SRC) | build
	$(ATASM) -Isrc -obuild/loader.xex src/loader.asm
	$(ATASM) -Isrc -obuild/ldrinit.xex src/ldrinit.asm
	$(ATASM) -Isrc -obuild/game.xex -l$(LAB) src/acadia.asm
	cat build/loader.xex build/ldrinit.xex build/game.xex > $@

build:
	mkdir -p build

run: $(XEX)
	$(ATARI800) $(EMUFLAGS) -run $(XEX)

test: $(XEX)
	@for t in $(TESTS); do $(PYTHON) $$t || exit 1; done

clean:
	rm -rf build
