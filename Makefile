# Acadia -- Atari 8-bit build
#
#   make         build build/acadia.xex
#   make run     build and run in atari800 (800XL, BASIC off)
#   make clean   remove build output

ATASM    ?= atasm
ATARI800 ?= atari800
EMUFLAGS ?= -xl -nobasic

SRC      := $(wildcard src/*.asm)
XEX      := build/acadia.xex

.PHONY: all run clean

all: $(XEX)

$(XEX): $(SRC) | build
	$(ATASM) -Isrc -o$@ src/acadia.asm

build:
	mkdir -p build

run: $(XEX)
	$(ATARI800) $(EMUFLAGS) -run $(XEX)

clean:
	rm -rf build
