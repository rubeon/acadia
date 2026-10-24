# Acadia — architecture

How the code is organised. Update this file in the same PR as any
change to module boundaries, the memory map or zero page.

## 1. Layers

```
+---------------------------------------------------------+
| game logic   rules, economy, events, AI, screens        |  platform-independent
+---------------------------------------------------------+
| services     tiles/map, sprites, sound driver, text     |  uses only equates
+---------------------------------------------------------+
| platform     hw_a800.asm, input.asm, interrupt setup    |  swapped for 5200
+---------------------------------------------------------+
```

Game logic never touches hardware registers or OS variables directly.

## 2. Modules

Current files are marked ✓; the rest are planned (see PLAN.md).

| File | Layer | Contents |
|---|---|---|
| `src/acadia.asm` ✓ | — | Entry, ZP allocation, main loop, `.INCLUDE`s |
| `src/hw_a800.asm` ✓ | platform | Hardware and OS shadow equates |
| `src/input.asm` ✓ | platform | `INPUT_POLL` → `JOY0/1`, `FIRE0/1`, `KEY`, console keys |
| `src/display.asm` ✓ | services | Display list, DLI, VBI hook, fonts, map drawing |
| `src/tic.asm` | services | Frame → 20 Hz tic and seconds (NTSC/PAL) |
| `src/rand.asm` | services | `RAND_N` (0..N−1) on POKEY `RANDOM` |
| `src/text.asm` | services | Print strings/numbers into mode 2 lines |
| `src/sprites.asm` | services | Player/missile objects, movement, multiplexing |
| `src/sound.asm` | services | POKEY SFX and music driver (VBI) |
| `src/map.asm` | game | Island layout, ownership, tile get/set, adjacency (fort) checks |
| `src/economy.asm` | game | Purchases, end-of-round income, population, score |
| `src/events.asm` | game | Weather, fish, pirates, boats, collisions, rebels |
| `src/ai.asm` | game | CPU governor |
| `src/screens.asm` | game | Setup, round summary, game over |
| `src/math.asm` | services | 8×8 and 16×8 multiply, 16÷8 divide with rounding |
| `src/hw_5200.asm` | platform | 5200 equivalents (later) |

## 3. Memory map (800XL, XEX)

| Range | Use |
|---|---|
| `$0080-$00CA` | Free while BASIC is off; reserved for game ZP (allocate in `acadia.asm`) |
| `$00CB-$00CE` | `ZPTR` (2), `OLDVBD` (2) — in use |
| `$2000-$2FFF` | Code and variables |
| `$3000-$33FF` | Map font (1K aligned) |
| `$3400-$37FF` | Map screen memory |
| `$3800-$38FF` | Display list(s) |
| `$4000-$47FF` | (planned) P/M graphics, double-line resolution, 2K aligned |
| `$4800-$BFFF` | Free: more code, fonts, music, screens |

Variables: all RAM variables live in one block (planned `src/vars.asm`),
never inline after code, so the same source can run from a 5200
cartridge (AGENTS.md rule 8). Today `input.asm` and `display.asm` still
keep variables inline; T-INFRA-5 moves them.

5200 budget: the 5200 has only 16K of RAM (`$0000-$3FFF`), with code
and constant data in cartridge ROM. Screen, display list, P/M graphics,
any RAM-resident font and all variables must fit in roughly 14K. Keep
that in mind before growing RAM buffers.

Constraints: fonts 1K aligned (modes 2/4/5); screen memory must not
cross a 4K boundary without a new LMS; display lists must not cross a
1K boundary; P/M base 1K (double-line) or 2K (single-line) aligned.

## 4. Platform interface

Everything the game needs from the machine, so a 5200 build can
provide the same symbols.

**Input** (`input.asm`, call `INPUT_POLL` once per frame):

| Symbol | Meaning |
|---|---|
| `JOY0`, `JOY1` | Direction bits, 1 = pressed: b0 up, b1 down, b2 left, b3 right |
| `FIRE0`, `FIRE1` | 1 = fire held |
| `KEY` | Item key 0-9 pressed this poll (edge), else `$FF` |
| `KEYPL` | Player the key belongs to: 0 or 1 (D17: fire held picks the player; neither → 0); `$FF` if both held, and then `KEY` is `$FF` too |
| `CONKEY` | (planned) START/SELECT/OPTION held bits, for the D18 info displays |
| `PAUSEK` | (planned) 1 on the poll where the pause key was pressed (P on the 800, PAUSE on a 5200 keypad), D19 |

5200 mapping (later): analog sticks thresholded into `JOY*`; keypad
0-9 → `KEY` (per controller); second fire button → mode toggle (key 0)
or info display. See OPEN-QUESTIONS Q4.

**Interrupts:** the game installs a deferred VBI (`VVBLKD`) and a DLI
(`VDSLST`) by writing the RAM vectors with `NMIEN = 0`, then
re-enabling NMIs. The deferred VBI chains to the previous handler via
the saved pointer `OLDVBD`. No OS routine is ever called.

## 5. Frame loop

```
VBI (every frame):   FRAME++, ATRACT=0, sound driver step, sprite positions
Main loop:           wait for FRAME change
                     INPUT_POLL
                     cursor/boat movement from input
                     if tic due (20 Hz): run TIC tasks
                       weather, fish, pirates, collisions, timers
                       once per second: clock, AI decision
                       end of round: economy, population, score, rebels
                     redraw changed tiles / status fields
```

Rule: anything that writes screen memory or colour registers mid-frame
must be safe against the DLI (only the DLI writes hardware colours; game
code writes RAM copies).

## 6. CPU budget

NTSC frame ≈ 29,800 cycles; with mode 5 + mode 2 DMA and P/M DMA,
assume ~18,000 usable per frame. Targets:

- VBI (sound + sprites): ≤ 2,500 cycles
- Per-tic logic: ≤ 8,000 cycles
- AI decision: ≤ 10,000 cycles, spread over frames if needed
- End-of-round scoring may take several frames (the clock is stopped)

## 7. Data model (game state)

Indexed by player `P` = 0 (left island) or 1 (right island). Keep the
original's layout so the formulas port directly:

| Variable | Size | Notes |
|---|---|---|
| `GOLD[P]` | 16-bit | current gold |
| `POP[P]` | 16-bit | population, cap 9999 |
| `SCORE[P]` | 16-bit | total score |
| `RSCORE[P]`, `PRSCORE[P]` | 8-bit | this / previous round score |
| `RGOLD[P]` | 16-bit | gold earned this round (8-bit in original; widened, R-RULE-8) |
| `COUNT[P][1..9]` | 8-bit | number of each item |
| `TILE[y][x]` | 8-bit | map grid: terrain + item + owner |
| timers | 8-bit | `REMSEC`, `TICSEC`, `CURTRN`, `NUMTRN`, `TRNLEN` |
| event counters | 8-bit | fishing, rain-on-crop, weather damage per player |

The logical grid is the original's 20 × 12 cards (each card = one
island square). On screen each square is 2 × 1 mode 5 characters
(D12); 11 of the 12 rows are visible under the status bar, which is
enough because the islands use about 7-8 rows.

## 8. Naming conventions

- Routines: `MODULE_VERB` (e.g. `MAP_BUILD`, `ECO_INCOME`).
- Internal labels: 2-3 letter module prefix + `_` (e.g. `EC_LOOP`).
- Equates: hardware as in Atari docs; game constants `C_` colours,
  `T_` tiles, `I_` items (1-9 as the original), `MAX_`/`MIN_` limits.
