# Acadia — implementation plan

Milestones in order. Each task has an ID, the requirements it covers
(SPEC.md), dependencies, and acceptance criteria. Claim a task by
setting **Status** to `in progress (<who>)` and committing that first.

Status values: `todo`, `in progress (<who>)`, `review`, `done`,
`blocked (<why>)`.

## M0 — Skeleton ✓

| ID | Task | Status |
|---|---|---|
| T-INFRA-1 | Repo, Makefile, ATasm build, XEX, `make run` | done |
| T-INFRA-2 | Display list test: mode 2 status + mode 4 map, DLI split, VBI hook, input echo | done |

## M1 — Foundations

| ID | Task | Reqs | Deps | Acceptance | Status |
|---|---|---|---|---|---|
| T-INFRA-3 | Headless test harness: run XEX in atari800 for N frames, dump screen/RAM, compare | — | — | `make test` runs at least one check without a display | todo |
| T-INFRA-4 | ATR build target (`make atr`) with a boot loader or DOS + autorun | — | — | ATR boots in atari800 and MiSTer | todo |
| T-INFRA-5 | Move all variables out of code into one RAM block (`src/vars.asm`); no inline `.BYTE` variables | — | — | `grep` finds no variable storage in code modules; build and display test unchanged | done |
| T-SVC-1 | `math.asm`: 8×8→16 multiply, 16÷8 divide with rounding | R-RULE-2 | — | Unit check against table of known results | done |
| T-SVC-2 | `rand.asm`: `RAND_N` uniform 0..N−1 | R-RULE-4 | — | Histogram over 10,000 calls within ±5% | done |
| T-SVC-3 | `tic.asm`: 20 Hz tic + seconds, NTSC and PAL | R-TIME-1..3 | — | 60 s of game clock = 60 s real on both (`-ntsc`/`-pal`) | done |
| T-SVC-4 | `text.asm`: print string / 1-4 digit decimal into status lines | R-SCR-1 | — | Status bar shows rounds, seconds, gold | done |
| T-DES-1 | Switch the map to mode 5 (D12) and draw the final tile set with the D16 palette; start from the art in branch `mockup/q3-palette` (`tools/mkmock.py`) | R-SCR-2, R-SCR-5 | — | Font with all terrain and 9 items in main; Q3 closed (D16) | done |

## M2 — Map and building (playable sandbox)

| ID | Task | Reqs | Deps | Acceptance | Status |
|---|---|---|---|---|---|
| T-MAP-1 | Island layout data (own design, Utopia-like shape and size), harbours | R-SCR-2 | T-DES-1 | Two islands drawn from data; grid ↔ screen mapping routines | done |
| T-MAP-2 | Tile get/set with owner; "fort adjacent" check | R-RULE-5,7 | T-MAP-1 | Check routine verified on test layouts | done |
| T-SPR-1 | P/M setup, two cursors moved by joysticks, snap to grid | R-CTL-1, R-SCR-4 | T-MAP-1 | Both cursors move smoothly, stay on screen | done |
| T-ECO-1 | Purchase: key 1-9 at cursor, price check, refusal sound stub, item counts | R-RULE-1,7, R-CTL-2 | T-MAP-2, T-SPR-1 | Items appear, gold decreases, illegal squares refused | done (keys 1-6, 8/9 since T-EVT-1, 7 since T-ECO-5) |
| T-CTL-1 | Pause: `PAUSEK` edge flag in `input.asm`, freeze tic/clock/sprites/AI, mute and restore POKEY, PAUSED on status bar | R-CTL-6 | T-SVC-3, T-SVC-4 | Pausing mid-round and resuming changes nothing in game state; no keys or stick act while paused | done |
| T-CTL-2 | Keypad controller in port 2 for 1-player games (D49) | R-CTL-8 | T-SCR-1 | Keys 0-9, * and # act as the number keys, P and H; setup line to switch it on | done (emulated; real keypad untested) |
| T-SCR-1 | Setup screen: rounds, round length, mode | R-MODE-3 | T-SVC-4 | Values validated to original ranges | done (D31; CPU from T-AI-1) |
| T-MAP-3 | Choice of map on the setup screen: three island pairs and RANDOM (D56) | R-MODE-3 | T-MAP-1, T-SCR-1 | Each map plays with equal islands; the CPU finds its way on each | in review (Claude) |

## M3 — Rounds and scoring (the economic game)

| ID | Task | Reqs | Deps | Acceptance | Status |
|---|---|---|---|---|---|
| T-ECO-2 | End-of-round income | R-RULE-2 | T-SVC-1, T-ECO-1 | Matches hand-calculated cases from utopia-rules.md | done |
| T-ECO-3 | Population update | R-RULE-2 | T-ECO-2 | Same | done |
| T-ECO-4 | Round score (housing, GDP, food, welfare, caps) | R-RULE-2,8 | T-ECO-3 | Same, incl. overflow cases fixed | done |
| T-ECO-5 | Rebels: create/remove/placement, bought rebels (D38) | R-RULE-3 | T-ECO-4, T-MAP-2 | Thresholds behave as specified | done |
| T-ECO-6 | Random crop destruction (D37) | R-RULE-2 | T-ECO-4 | Verify against original routine `$5B6B` first | done |
| T-SCR-2 | Round summary and game-over screens; info displays | R-SCR-6, R-MODE-4, R-CTL-4 | T-ECO-4 | Full game of N rounds completes | done |
| T-SCR-3 | Purchase help screen: one line per item with its key number, its map icon (the same tile as on the map) its name and its price, e.g. `1 [fort] FORT 50` | R-CTL-2 | T-SCR-2, T-EVT-1 | All 9 items shown with the right icon; leaving it returns to the game unchanged (clock paused while up) | done (D34) |
| T-SCR-4 | Status line 2 in play: the input debug echo replaced by each player's population and a news slot (hurricane, boat sunk, storm damage, rebels, refused keys) | R-SCR-1 | T-SCR-2 | Populations shown and kept current; each message centred, cleared after 3 s, never hidden by a lower priority; no refusals shown for the CPU | done (D44) |

## M4 — Moving things

| ID | Task | Reqs | Deps | Acceptance | Status |
|---|---|---|---|---|---|
| T-DES-2 | Resolve Q2 (P/M allocation, multiplexing) | R-SCR-4 | T-SPR-1 | Decision recorded | done (D13, D14; colour detail D29) |
| T-EVT-1 | Boats: buy into harbour, pick up/drop (key 0), move, island collision | R-RULE-6, R-CTL-3 | T-DES-2 | Boats can't cross land | done (D32) |
| T-EVT-2 | Fish schools: spawn, drift, fishing income | R-RULE-4,6 | T-EVT-1 | 1 gold per 50 tic-overlaps | done (D33) |
| T-EVT-3 | Pirates: spawn, move, sink fishing boats, stopped by PT boats, fort protection, PT boats against fishing boats; drawn with the missiles as a fifth player (D36) | R-RULE-6 | T-EVT-1 | Verify sinking rules against original `$54F8-$5600` first | done |
| T-EVT-4 | Weather: rain/storm/hurricane, movement, crop gold, damage, boat sinking | R-RULE-5 | T-EVT-1, T-MAP-2 | Damage rates and thresholds as specified | done (D35) |

## M5 — Sound

| ID | Task | Reqs | Deps | Acceptance | Status |
|---|---|---|---|---|---|
| T-SND-1 | VBI sound driver: SFX priority, 4 channels | R-SND-3 | — | No audible glitches under load | done (D41) |
| T-SND-2 | All SFX | R-SND-1,4 | T-SND-1 | Every event in R-SND-1 has a sound | done (D41) |
| T-SND-3 | Music: title and end of round | R-SND-2,4 | T-SND-1 | Plays without stalling the game | done (D42; tunes replaced D45) |

## M6 — CPU governor

| ID | Task | Reqs | Deps | Acceptance | Status |
|---|---|---|---|---|---|
| T-AI-1 | Purchase strategy over the scoring formulas | R-AI-1,2 | M3 | Beats a do-nothing player; scores ≥ 50/round on average after round 5 | done (D39) |
| T-AI-2 | Boat handling | R-AI-3 | M4, T-AI-1 | Catches fish, intercepts pirates | done (D40; fishing boat fishes and flees pirates, PT boats not steered) |
| T-AI-3 | Difficulty levels | R-AI-4 | T-AI-1 | 3 levels, visibly different | done (D39) |

## M7 — Release

| ID | Task | Deps | Status |
|---|---|---|---|
| T-REL-1 | Title screen, credits (no Mattel trademarks in a way that implies affiliation) | M6 | title screen and demo done (D46, D47); credits open |
| T-GFX-1 | Map in ANTIC mode 4: 8 × 16 tiles, new art (D50) | M6 | done (colour per row and moving waves added, D51) |
| T-GFX-2 | Weather sprites redrawn: rain and storm clouds with falling rain, storm lightning, a turning hurricane spiral (D52) | T-GFX-1 | done |
| T-GFX-3 | Status bar in mode 4: own 3 × 7 font, isometric gold bar and two-colour person icons, a background per line (D54) | T-GFX-1 | done |
| T-GFX-4 | Sea in one light blue with rounded dark corners instead of bands (D55) | T-GFX-1 | done |
| T-REL-2 | Test on MiSTer and real 800XL; PAL check | M6 | todo |
| T-REL-3 | ATR + XEX release build, README play instructions | T-INFRA-4 | todo |

## M8 — Atari 5200 port (later)

| ID | Task | Status |
|---|---|---|
| T-5200-1 | `hw_5200.asm`, cartridge build target | todo |
| T-5200-2 | 5200 input layer: analog sticks, keypad, second fire button (Q4) | todo |
| T-5200-3 | Replace any remaining 800-only assumptions (memory map, interrupts via 5200 BIOS vectors) | todo |
