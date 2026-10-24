# Acadia -- Atari 8-bit build
#
#   make         build build/acadia.xex
#   make run     build and run in atari800 (800XL, BASIC off)
#   make clean   remove build output
#
#   ISLANDS=A or B picks the candidate island pair (default A);
#   pair B builds to build/acadia-B.xex.

ATASM    ?= atasm
ATARI800 ?= atari800
EMUFLAGS ?= -xl -nobasic

ISLANDS  ?= A
ISL_B    := $(if $(filter B b,$(ISLANDS)),1,0)

SRC      := $(wildcard src/*.asm)
XEX      := build/acadia$(if $(filter 1,$(ISL_B)),-B,).xex

.PHONY: all run clean

all: $(XEX)

$(XEX): $(SRC) | build
	$(ATASM) -Isrc -dISL_B=$(ISL_B) -o$@ src/acadia.asm

build:
	mkdir -p build

run: $(XEX)
	$(ATARI800) $(EMUFLAGS) -run $(XEX)

clean:
	rm -rf build
