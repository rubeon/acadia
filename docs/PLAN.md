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
| T-INFRA-6 | XEX boots on the MiSTer's disk-boot loader: never a multiple of 125 bytes long (D73) | — | — | `make` pads the XEX when needed; `tests/test_xexsize.py` passes; main's build boots on MiSTer | done |
| T-INFRA-7 | Loading screen: the logo, LOADING and a loading bar as soon as the XEX starts loading (D81) | — | T-REL-4 | Logo shows a few seconds after power-on on a real-speed load; `tests/test_loader.py` passes; boots with BASIC in and out, on MiSTer | done (Claude) |
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
| T-CTL-3 | CX21 Video Touch Pad: found by itself in port 2 in 1-player games; column order and settle time from Atari's own reader (D58) | R-CTL-8 | T-CTL-2 | A pad plugged into port 2 works with no setup; each key gives its own number | done (per Atari's reader; real pad untested) |
| T-CTL-4 | Fire button tap acts as key 0 for its player (D60) | R-CTL-3 | T-EVT-1 | Tapping fire lifts and parks boats like 0; fire held for a digit (D17) still buys and does not also toggle | done (Claude) |
| T-CTL-5 | RESET goes back to the title screen: the 800's warm start through `DOSINI`, the 5200's keypad RESET key (D76) | R-CTL-9 | T-REL-4, T-5200-2 | RESET at any point lands on the title as at power-on; the next game plays normally, on any map; BASIC stays out (D57) | done (Claude) |
| T-SCR-1 | Setup screen: rounds, round length, mode | R-MODE-3 | T-SVC-4 | Values validated to original ranges | done (D31; CPU from T-AI-1) |
| T-MAP-3 | Choice of map on the setup screen: STANDARD, CLASSIC (the original's layout), RANDOM (D56) | R-MODE-3 | T-MAP-1, T-SCR-1 | Each map plays with equal islands; the CPU finds its way on each | done (Claude; CLASSIC is STANDARD since D65) |
| T-SCR-6 | Setup screen redrawn: help font on black, CPU level by name, values go round, a minimap of the chosen map; the original's layout is STANDARD and the default, the old STANDARD gone (D65) | R-MODE-3 | T-MAP-3 | Both maps' minimaps shown; every line goes round both ways; 800 and 5200 builds | done (Claude) |

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
| T-SCR-5 | End-of-game stats screen: line charts over the rounds of each player's score, population and gold | R-SCR-7 | T-SCR-2 | Every round of a game up to 50 rounds is recorded and charted; the chart scales to the values; fire goes on to the setup screen | done (D61) |
| T-SCR-7 | Stats screen: the GOLD page becomes INCOME, the gold each player earned in each round (D66) | R-SCR-7 | T-SCR-5 | Income recorded before the round's earned gold is cleared; the page is called INCOME | done (Claude) |
| T-SCR-8 | Setup screen with the title's "Acadia" logo and sunset sky at the top left, the options under it (D71) | R-MODE-3 | T-SCR-6, T-REL-4 | Logo and sky as on the title; every line, the minimap and the prompt visible; 800 and 5200 builds | done |
| T-SCR-9 | Stats screen's chart area in the setup screen's colours: black, yellow text, the current page white; status lines stay blue (D78); the winner centred, the fire hint at the bottom (D79); the legend's totals and best round follow the page (D80) | R-SCR-7 | T-SCR-7, T-SCR-8 | Every zone of the stats screen in the new colours; both players' lines and the grid readable; 800 and 5200 builds | done (Claude) |
| T-SCR-10 | Help screen in the setup screen's colours: black background, yellow text, white keys and names; status lines unchanged (D83) | R-CTL-2 | T-SCR-3, T-SCR-8 | Help screen black with the setup's yellow, every tile readable on black; 800 and 5200 builds, 0 warnings | done (Claude) |
| T-SCR-11 | Stats screen: a SUMMARY page first, per player the items bought, the gold from fishing, crops and factories, and the boats lost to weather, pirates and PT boats (D84) | R-SCR-7 | T-SCR-9 | Counts kept during play and cleared at a new game; the three gold sources add up to the INCOME page's total; the stick reaches every page both ways; 800 and 5200 builds, 0 warnings | in progress (Claude) |

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
| T-GFX-5 | Boats leave a trail of waves on the squares they pass (D59) | T-GFX-1 | done (no wakes in rows 0 and 10: no font room) |
| T-GFX-7 | Schools of fish in a darker green, to stand out from the sea on a CRT (D64) | T-GFX-4 | done |
| T-GFX-8 | Pirates show in the corner rows (the band sea becomes COLBK); the pirate ship redrawn as a 10-line galleon with a flying flag (D67) | T-GFX-4 | done |
| T-GFX-9 | Crop tile redrawn as two ears of wheat on tall stalks, map and help icon (D68) | T-GFX-1 | done |
| T-GFX-10 | Pause: no map glitch on pause/resume; PAUSED in a black band across the bottom of the map, status bar kept (D69) | T-GFX-8 | done |
| T-GFX-11 | Rebel tile redrawn as a dark banner with a gold X on a pole, map and help icon (D72) | T-GFX-1 | done |
| T-GFX-12 | Nothing jumps between screens: the setup screen's logo, sky bands and clouds on the title's scan lines; the status bar on the help and stats screens on the map's (D75) | T-SCR-8 | done |
| T-GFX-13 | Clouds on the title and setup screens move from the VBI, so every step lands on its frame and no cloud shears (D82) | T-GFX-12 | done |
| T-REL-4 | Sunset title screen after Rube's reference: banded sky by DLI, hand-drawn logo at the top left, island with the fort, the sun low over the horizon, calm glitter on the water, REBUILD at the bottom right, PRESS FIRE after 10 idle seconds (D70) | T-REL-1 | done |
| T-REL-2 | Test on MiSTer and real 800XL; PAL check | M6 | todo |
| T-REL-3 | ATR + XEX release build, README play instructions | T-INFRA-4 | todo |
| T-DOC-1 | README for players: fresh screenshots, how to play, controls (800, touch pad, 5200), supported platforms | T-REL-4 | done |
| T-DOC-2 | Printable keypad overlays: Atari 5200 controller and Video Touch Pad (CX21), SVG/PDF/PNG at real size (`docs/overlays/`) | T-DOC-1 | done |

## M8 — Atari 5200 port (later)

| ID | Task | Status |
|---|---|---|
| T-5200-0 | Memory map in one file (`mem_a800.asm`): no fixed addresses left in modules or generated files; the XEX stays byte-identical | done |
| T-5200-1 | `hw_5200.asm`, cartridge build target (`make 5200`): boots to the title and runs the demo; input stubbed (D62) | done |
| T-5200-2 | 5200 input layer: analog sticks, keypad, second fire button (Q4, D63) | done |
| T-5200-3 | Replace any remaining 800-only assumptions (memory map, interrupts via 5200 BIOS vectors) | todo |
| T-5200-4 | No BIOS title screen ("COPYRIGHT 19..", Atari logo): header `$BFFD` = `$FF`, the cartridge's own start-up and VBI (D77) | done |
