# Acadia

An island-building strategy game for the Atari 8-bit computers (800XL
first), inspired by classics like Mattel's *Utopia* (Intellivision,
1981). Two rulers, two islands, a set number of timed rounds: build
forts, farms, factories, schools and houses, send out fishing boats,
and keep your people fed and happy through storms, pirates and rebels.

![Title screen](docs/images/title.png)

![A game in progress](docs/images/gameplay.png)

## Goals

- Gameplay inspired by Utopia's rules: two islands, buildings bought
  with gold bars, timed rounds, weather, fish, pirates, rebels, and the
  same style of round scoring (see [docs/utopia-rules.md](docs/utopia-rules.md)).
- A single-player mode against a CPU opponent, alongside the
  two-player game.
- POKEY sound effects and music.
- Mixed ANTIC modes: a mode 2 text status bar over a mode 4
  multicolour map, split with display list interrupts.
- Menus and item selection on the keyboard; this is a computer. A tap of
  the fire button does what 0 does (lift or park a boat). In a 1-player game an Atari Video Touch Pad (or CX50 keypad) in port 2 works too: plug it in and it is found when the game starts.
- On the Atari 5200 (D63): the analog stick moves the cursor and the
  bottom side button is fire. Keypad 1-9 buy items for that
  controller's player; 0 or the top side button lifts or parks a
  boat; `*` shows the price list; `PAUSE` pauses; `START` begins a game
  and, held during a round, shows the total scores; `#` held shows the
  info pages (totals, then populations, then last round on each press
  soon after). In atari800 `-5200`: numpad stick, Right Ctrl the top
  button (key 0), Shift the bottom button (fire), `0`-`9`, `=` for `#`, numpad `*`, `P`
  pause, F4 START (`#` and `*` typed with Shift also press the bottom
  button).

Acadia is an independent project, not affiliated with or endorsed by
Mattel. All code, graphics, sound and music are new.

## Contributing

Humans and coding agents: start with [AGENTS.md](AGENTS.md). Planning docs:
[SPEC](docs/SPEC.md), [ARCHITECTURE](docs/ARCHITECTURE.md), [PLAN](docs/PLAN.md),
[DECISIONS](docs/DECISIONS.md), [OPEN-QUESTIONS](docs/OPEN-QUESTIONS.md).

## Building

Requires [ATasm](https://github.com/CycoPH/atasm) (MAC/65 compatible) and,
for `make run`, the [atari800](https://atari800.github.io/) emulator.
On macOS: `brew install atasm atari800`. `make test` also needs Python 3
with [py65](https://github.com/mnaberez/py65) (`pip install py65`);
pass `PYTHON=/path/to/python` if it lives in a virtualenv.

```sh
make            # build build/acadia.xex
make run        # build and run in atari800 (800XL, BASIC off)
make test       # build, then run the unit tests (needs py65)
make 5200       # build the Atari 5200 cartridge: build/acadia5200.car (+ .bin)
make run5200    # build it and run it in atari800 -5200
make clean      # remove build/
```

Use a different assembler or emulator binary with
`make ATASM=/path/to/atasm` or `make ATARI800=/path/to/atari800`.

Output is an XEX load file for now; an ATR disk image will follow.
`make 5200` builds an Atari 5200 cartridge (32K) from the same source.

## Source layout

| File | Contents |
|---|---|
| `src/acadia.asm` | 800 build's main file: entry point, memory layout; includes the rest |
| `src/acadia5200.asm` | Atari 5200 cartridge's main file (D62) |
| `src/main.asm` | Start-up, main loop and zero page, shared by both builds |
| `src/hw_a800.asm`, `src/hw_5200.asm` | GTIA, POKEY, PIA, ANTIC equates and OS / BIOS shadow registers |
| `src/mem_a800.asm`, `src/mem_5200.asm` | Each build's memory map |
| `src/plat_a800.asm`, `src/plat_5200.asm` | Each build's platform hooks (`PLAT_INIT`, `PLAT_MAP`) |
| `src/input.asm` | Input layer: joysticks, triggers, console keys, keyboard |
| `src/input5200.asm` | 5200 input layer: analog sticks, side buttons, keypads (D63) |
| `src/math.asm` | 24 × 8 multiply, 24 ÷ 8 divide (truncating and rounded) |
| `src/rand.asm` | `RAND_N`: random number 0..N−1 |
| `src/tic.asm` | 20 Hz game tic and seconds, NTSC and PAL |
| `src/text.asm` | Status bar text and decimal numbers |
| `src/sprites.asm` | Player/missile graphics |
| `src/cursor.asm` | The players' cursors |
| `src/map.asm` | Map grid: items on squares, fort-adjacency check |
| `src/display.asm` | Display lists, DLI, VBI, map drawing (mode 4) |
| `src/economy.asm` | Buying, income, population, score, crops |
| `src/boats.asm` | Steering and parking boats |
| `src/fish.asm`, `src/weather.asm`, `src/pirates.asm`, `src/rebels.asm` | Schools of fish, rain and storms, pirates, rebels |
| `src/ai.asm` | The CPU opponent |
| `src/sound.asm`, `src/music.asm` | POKEY sound effects and music |
| `src/pause.asm`, `src/help.asm` | Pause (P) and the price list (H) |
| `src/screens.asm`, `src/news.asm` | Rounds, summaries, game over, status line |
| `src/setup.asm` | The game setup screen |
| `src/title.asm`, `src/demo.asm` | Title screen and the attract-mode demo |
| `src/vars.asm` | All RAM variables, one block at `$3900` |
| `src/tiles.asm`, `src/font_map.asm`, `src/isl_live.asm`, `src/isl_live5200.asm`, `src/islands.asm` | Tiles, map fonts, island data (generated by `tools/mkfont.py`) |
| `src/title_gfx.asm` | The title screen's graphics, font and colours (generated by `tools/mktitle.py`) |
| `src/font_stat.asm` | The status bar font (generated by `tools/mkstat.py`) |
| `tools/run6502.py` | Test helper: runs routines from the XEX on a 6502 core |
| `tools/mkcart.py` | Makes the 5200 cartridge images from ATasm's output |
| `tests/` | Unit tests, run by `make test` |
| `tools/mkfont.py` | Tile art and island outlines; generates the tile, font and island files (`--preview DIR` renders PNG previews of the islands) |
| `tools/mktitle.py` | Draws the sunset title screen (`--preview FILE` renders it) |
| `tools/mkstat.py` | Status bar letters and icons; generates the status font (`--preview FILE` renders a PNG) |
| `docs/utopia-rules.md` | Rules and constants taken from the original game |

## Assembler compatibility

Source is kept MAC/65 compatible. Deliberate exceptions, which are
ATasm conveniences:

- `.INCLUDE "file.asm"` uses ATasm's quoted filename form. On a real
  MAC/65 setup this becomes `.INCLUDE #D:FILE.M65`.
- Lower-case file names and `.asm` extensions.

No `?local` labels, `.DS`, `.ALIGN` or macros are used; storage is
reserved with `*= *+n`.

## Test targets

1. atari800 emulator (`make run`)
2. MiSTer Atari800 core
3. A real 800XL

## Atari 5200 plan

The 5200 cartridge (`make 5200`, D62, D63) shares the source. To keep
it cheap:

- All hardware addresses live in `src/hw_a800.asm`; a 5200 build will
  provide `hw_5200.asm` with the same symbol names (GTIA at `$C000`,
  POKEY at `$E800`, ANTIC at `$D400`, different shadow locations).
- Game code never calls Atari OS ROM routines. It only writes the DLI
  and VBI vectors and the shadow registers, which the 5200 BIOS also
  provides.
- All input goes through `src/input.asm`, which exposes `JOY0/JOY1`,
  `FIRE0/FIRE1` and `KEY`. The 5200's `src/input5200.asm` maps the
  analog sticks, the keypads (items 0-9, a natural fit for the
  original's keypad controls) and both side buttons (D63).
