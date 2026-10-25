# AGENTS.md — working on Acadia

Instructions for any coding agent (or human) picking up work here.
Read this file first, then the docs it points to.

## What this is

Acadia is a clone of Mattel's *Utopia* (Intellivision, 1981) for the
Atari 8-bit computers, 800XL first. Written in 6502 assembly, MAC/65
syntax, built with ATasm into an XEX.

## Read before you change anything

| Doc | Use it for |
|---|---|
| [docs/SPEC.md](docs/SPEC.md) | What the game must do (the "what") |
| [docs/utopia-rules.md](docs/utopia-rules.md) | Original rules and numbers, with ROM addresses |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Modules, memory map, frame loop, conventions (the "how") |
| [docs/PLAN.md](docs/PLAN.md) | Milestones and tasks; pick work from here |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Settled decisions; don't reopen without a reason |
| [docs/OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md) | Undecided design questions; add your analysis here |

## Build and run

```sh
make            # build/acadia.xex
make run        # atari800 -xl -nobasic -run build/acadia.xex
make clean
```

Toolchain: ATasm 1.07+ and atari800 (`brew install atasm atari800`).
A change is not done until `make` succeeds with **0 warnings**.

## Hard rules

1. **No Mattel material in the repo.** Never commit the Utopia ROM, the
   disassembly (`utopia.asm`), or graphics/sound data copied from it.
   Rules and numbers (in `docs/utopia-rules.md`) are fine; re-draw all
   art and re-compose all sound.
2. **MAC/65-compatible source.** No `?local` labels, `.DS`, `.ALIGN`,
   `.LOCAL`, macros, or ATasm-only directives. Reserve storage with
   `*= *+n`. The only allowed ATasm-ism is `.INCLUDE "file.asm"`.
   If you need another one, add it to DECISIONS.md and README.md.
3. **No OS ROM calls from game code.** No `JSR` into `$C000-$FFFF`, no
   CIO, no SETVBV. Write vectors and shadow registers only, with NMIs
   disabled while patching vectors. This keeps the 5200 port possible.
4. **Hardware access only through the platform layer.** Hardware
   addresses live in `src/hw_a800.asm`. Joystick/keyboard reads live
   only in `src/input.asm`. Game logic reads `JOY0/JOY1/FIRE0/FIRE1/KEY`.
5. **Labels are global, so prefix them.** Every routine's internal
   labels use a short module prefix (`IP_`, `MB_`, `FR_`, ...). Check for
   collisions with `atasm -s` before committing.
6. **Zero page is allocated in one place** (`src/acadia.asm`, see
   ARCHITECTURE.md). Don't grab ZP bytes ad hoc.
7. **Follow the original's numbers** from `docs/utopia-rules.md` unless a
   decision in DECISIONS.md says otherwise. If you deviate, record it.
8. **Keep code ROM-safe.** The 5200 port runs code from cartridge ROM,
   so: no self-modifying code, and no variables stored inline after
   code (`FOO .BYTE 0` next to a routine). Variables go in the RAM
   variables block (see ARCHITECTURE.md § 3). Constant tables may sit
   with the code.

## Workflow

- One task per branch: `task/<ID>-short-name` (IDs from PLAN.md).
- Before starting, set the task's status in PLAN.md to `in progress`
  with your name/agent id, and commit that, so others don't collide.
- Keep commits small; message format: `<ID>: what changed`.
- Open a PR against `main`. Describe what you tested and how
  (emulator, screenshot, MiSTer, real hardware).
- When done, mark the task `done` in PLAN.md in the same PR.
- New design questions go to OPEN-QUESTIONS.md, not into code comments.

## Testing

`make test` runs the unit tests in `tests/` on a 6502 core
(`tools/run6502.py`, needs py65): use it for pure routines such as math
and map logic. There is no display/emulator test harness yet (task
T-INFRA-3), so every PR also states:
- `make` output (0 warnings),
- what was run in atari800 and what was seen,
- for display work, a screenshot (`atari800 -screenshots "shot###.png"`,
  F10 in the emulator).

## Style

- Upper-case mnemonics and labels; comment every non-obvious line.
- Routine header: name, purpose, inputs, outputs, registers trashed.
- Equates for every magic number (colours, tile numbers, limits).
- Data tables close to the code that uses them, except fixed-address
  blocks (fonts, display lists, screens), which go at the end of a
  module with their own `*=`.
