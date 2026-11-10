# Acadia -- Atari 8-bit build
#
#   make         build build/acadia.xex
#   make run     build and run in atari800 (800XL, BASIC off)
#   make test    build both, then run the unit tests in tests/ on a 6502
#                core (needs py65: pip install py65)
#   make 5200    build the Atari 5200 cartridge: build/acadia5200.car
#                (CART header, type 4) and build/acadia5200.bin (raw 32K)
#   make run5200 build it and run it in atari800 (-5200)
#   make clean   remove build output

ATASM    ?= atasm
ATARI800 ?= atari800
EMUFLAGS ?= -xl -nobasic
PYTHON   ?= python3

SRC      := $(wildcard src/*.asm)
XEX      := build/acadia.xex
LAB      := build/acadia.lab
TESTS    := $(wildcard tests/test_*.py)
CAR      := build/acadia5200.car
LAB5200  := build/acadia5200.lab

.PHONY: all run test clean 5200 run5200

all: $(XEX)

# the loader (D57) first, then its INITAD, then the game with its title
# graphics (the logo, $8000) first, so the loader's loading screen
# fills in at once (D81): ATasm sorts a file's segments by address, so
# it can't put them in this order itself
$(XEX): $(SRC) tools/xexfirst.py | build
	$(ATASM) -Isrc -obuild/loader.xex src/loader.asm
	$(ATASM) -Isrc -obuild/ldrinit.xex src/ldrinit.asm
	$(ATASM) -Isrc -obuild/game.xex -l$(LAB) src/acadia.asm
	$(PYTHON) tools/xexfirst.py build/game.xex build/game1.xex 8000
	cat build/loader.xex build/ldrinit.xex build/game1.xex > $@
	@# MiSTer's disk-boot XEX loader hangs (black screen) on a file whose
	@# size is a multiple of 125 bytes (D73): then add a 1-byte segment
	@# at $$0600 (5 bytes: start, end, one $$00), which nothing loads at
	@size=`wc -c < $@`; if [ `expr $$size % 125` -eq 0 ]; then \
	  printf '\000\006\000\006\000' >> $@; \
	  echo "$@: $$size bytes is a multiple of 125, padded by 5 (D73)"; fi

# the 5200 cartridge (D62): ATasm's segments, made into a 32K image by
# tools/mkcart.py, which also checks the fit and prints the free bytes
5200: $(CAR)

$(CAR): $(SRC) tools/mkcart.py | build
	$(ATASM) -Isrc -obuild/acadia5200.obj -l$(LAB5200) src/acadia5200.asm
	$(PYTHON) tools/mkcart.py build/acadia5200.obj $(LAB5200) build/acadia5200

build:
	mkdir -p build

run: $(XEX)
	$(ATARI800) $(EMUFLAGS) -run $(XEX)

run5200: $(CAR)
	$(ATARI800) -5200 -cart $(CAR)

test: $(XEX) $(CAR)
	@for t in $(TESTS); do $(PYTHON) $$t || exit 1; done

clean:
	rm -rf build
