# Acadia — game specification

What the finished game must do. Numbers and formulas come from
[utopia-rules.md](utopia-rules.md); this document says how they appear
on the Atari. Requirement IDs (`R-...`) are referenced from PLAN.md.

## 1. Scope

- **Platform:** Atari 800XL with 64K (must also run on 800/XE with
  48K+). NTSC first; PAL must be playable (see R-TIME-2).
- **Media:** XEX load file; ATR boot disk later.
- **Later:** Atari 5200 port (separate build, same game code).

## 2. Game modes

| ID | Requirement |
|---|---|
| R-MODE-1 | Two players, one joystick each, sharing the keyboard. Matches the original. |
| R-MODE-2 | One player against a CPU governor on the other island. |
| R-MODE-3 | Setup screen: number of rounds (1-50), round length (30-120 s), mode (1P/2P), CPU difficulty (1P only), map (standard, the original's layout, or a random pair, D56). Keyboard driven. |
| R-MODE-4 | End-of-game screen showing final scores and winner; any key/fire returns to setup. |

## 3. Rules

| ID | Requirement |
|---|---|
| R-RULE-1 | Item prices, starting gold (100) and population (1000) as in utopia-rules.md. |
| R-RULE-2 | End-of-round income, population, and round score formulas exactly as in utopia-rules.md, including the 30/30/30 caps and the 100 cap. |
| R-RULE-3 | Rebel creation/removal thresholds (fell 10 / rose 10 / <30 / ≥70, in that order) and placement rules (not on or next to a fort; destroys what it lands on). Buying a rebel puts it on the opponent's island (D38). |
| R-RULE-4 | Random events at the original rates per 20 Hz tic: weather 1/100, fish 1/20, pirates 1/100. |
| R-RULE-5 | Weather effects: rain on crops pays gold, storms and hurricanes damage items, kill population and sink parked boats, hurricanes sink moving boats; forts give no protection from weather (D35). |
| R-RULE-6 | Boats: fishing boats earn gold over fish; PT boats stop pirates and attack the other player's fishing boats; pirates sink unprotected fishing boats (D36). |
| R-RULE-7 | Items can only be built on the player's own island on a free land square (boats: in the harbour). Not enough gold = refusal sound. |
| R-RULE-8 | Known overflow bugs in the original (gold earned >255, crops+boats >65) are **fixed**, not reproduced. |

## 4. Screen

| ID | Requirement |
|---|---|
| R-SCR-1 | Status bar in ANTIC mode 2 text: rounds left, seconds left, each player's gold. Score/population shown on demand (R-CTL-4). Line 2: each player's population and a short news line (D44). |
| R-SCR-2 | Map in a multicolour character mode (ANTIC mode 4, 2 × 2 characters per square; DECISIONS D12, D50) with sea, two islands, harbours and all items drawn as tiles. |
| R-SCR-3 | DLIs split colours/fonts between the status bar and the map. |
| R-SCR-4 | Moving objects (cursors, boats, fish, pirates, weather) as player/missile graphics, with multiplexing if needed (Q2). |
| R-SCR-5 | Each item recognisable by shape, not only colour; each player's items distinguishable (Q3). |
| R-SCR-6 | End-of-round summary screen with each player's round score, as in the original. |

## 5. Controls

| ID | Requirement |
|---|---|
| R-CTL-1 | Joystick moves the player's cursor (or a held boat). |
| R-CTL-2 | Keys 1-9 buy item 1-9 at the cursor. In 2P mode both players use the keyboard; the key buys for the player whose fire button is held; neither → player 1; both → ignored (D17). |
| R-CTL-3 | Key 0 toggles cursor mode / picks up and drops boats, as in the original. |
| R-CTL-4 | Info displays (total score, population, last round score) while START (total scores), SELECT (populations) or OPTION (previous round scores) is held (D18). |
| R-CTL-6 | P toggles pause (5200: keypad PAUSE); either player can pause or unpause. Paused: tic, clock, events, AI and sprites frozen, sound muted, item keys and joystick ignored, PAUSED on the status bar; map colours may dim (D19). |
| R-CTL-7 | H (or HELP on an XL/XE) during a round shows a price list over the map: each item's key, its map tile, name and price. H or HELP again returns; the game stands still while it is up (D34). |
| R-CTL-8 | 1-player games can use an Atari keypad controller (CX21 Video Touch Pad or CX50) in port 2, found by itself when the game starts (Atari computers only): 0-9 as the number keys, * pause, # help (D49, D58). |
| R-CTL-5 | All input goes through the input layer (ARCHITECTURE §4). |

## 6. Timing

| ID | Requirement |
|---|---|
| R-TIME-1 | Game logic runs on a 20 Hz tic, like the original. |
| R-TIME-2 | Tic rate derived correctly on NTSC (60 Hz: every 3 frames) and PAL (50 Hz: 2-3-2-3 pattern). |
| R-TIME-3 | Round clock counts real seconds on both standards. |

## 7. Sound

| ID | Requirement |
|---|---|
| R-SND-1 | POKEY sound effects for: purchase, refusal, fish caught, rain on crops, boat sunk, rebel, storm, end of round. |
| R-SND-2 | Title / end-of-round music on POKEY. |
| R-SND-3 | Sound driver runs in the VBI and never stalls game logic. |
| R-SND-4 | All sound composed new; nothing copied from the original. |

## 8. CPU governor (1P mode)

| ID | Requirement |
|---|---|
| R-AI-1 | Plays by the same rules and prices; no hidden bonuses at normal difficulty. |
| R-AI-2 | Decides purchases at least once per second of game time, using a priority scheme over the scoring formulas (housing, GDP, food, welfare, defence). |
| R-AI-3 | Uses boats: sends fishing boats toward fish, PT boats toward pirates. (Fishing boats done, PT boats not steered: D40.) |
| R-AI-4 | Difficulty levels change decision rate and quality, not the rules. |
| R-AI-5 | Fits the per-tic CPU budget (ARCHITECTURE §6). |

## 9. Non-goals (for now)

- Cycle-exact reproduction of the Intellivision version.
- Online or multi-machine play.
- Saving games.
