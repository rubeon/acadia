# Acadia — open questions

Design questions not yet decided. Add analysis, options and a
recommendation under each; the owner decides. When decided, move the
outcome to DECISIONS.md and mark the question **Closed (Dn)**.

## Q1. Map character mode and tile size — **Closed (D12): mode 5**

The original screen is 20 × 12 cards of 8 × 8 pixels on a 160 × 96
display (pixels are 2 scan lines tall). On the Atari:

- **Mode 4, 2 × 2 chars per square:** 40 × 24 chars covers the same
  20 × 12 grid exactly. Uses 4 chars per item graphic (more detail,
  more font space: 9 items × 2 owners × 4 = 72 chars + terrain).
  Status bar takes 2 char rows, so the map gets 22 rows = 11 squares
  tall; the original's islands fit in about 7-8 rows, so that is enough.
- **Mode 5, 2 × 1 chars per square:** same 4-pixel-wide chars at
  16 scan lines tall. Half the screen memory and font use, simpler
  addressing, closer to the original's chunky look.

Decided 2026-10-24: mode 5 (D12). The M0 test still uses mode 4 and
moves to mode 5 in T-DES-1.

## Q2. Sprite allocation — **Closed (D13, D14): option A**

### What has to move

The original has 8 hardware sprites (MOBs). From its sprite tables:

| Slots | Object | Size in map squares | Frames | Notes |
|---|---|---|---|---|
| 0, 1 | Weather: rain, tropical storm, hurricane | rain/storm 2 x 1, hurricane 2 x 4 | 5 (rain/storm), 6 (hurricane) | Tropical storm is rain's art in another colour. Both slots can be active at once |
| 2, 3 | Player sprite: cursor, or the boat being steered | 1 x 1 | cursor 1, boats 1, sinking 8 | One per player, needs that player's colour. Never cursor and boat at once |
| 4, 5 | Pirate ships | 1 x 1 | 1 + 8 sinking | Spawn at random, leave the screen |
| 6, 7 | Fish schools | 1 x 1 | 4 | Drift, leave the screen |

Buildings, parked boats and a parked boat sinking are background
tiles, not sprites.

Behaviour that matters for allocation (ROM addresses for checking):

- **Weather** [`$51C6`]: type roll `rand(12)`: 0 hurricane, 1-3 and
  4-11 the two rain-art colours (most likely 1-3 tropical storm, 4-11
  rain; the disassembly's comments disagree). Starts at the top of the
  screen. Each tic, a 1 in 10 chance of a +/-1 kick to X or Y velocity,
  with no limit, so it random-walks. Removed off screen.
- **Pirates and fish** [`$526A`]: spawn in one of **two bands**, near
  the top or near the bottom of the screen (50/50), entering from the
  left or right edge (50/50) and moving horizontally. Same 1 in 10
  velocity kick as weather [`$52E5`]. Pirates can't cross land. Two of
  each can exist at once.
- **Speeds** (original units): cursor 15, steered boat 10, fish and
  pirates start at 3, weather at (4, 5). Fish and pirates move at
  about a third of boat speed.
- **Priority:** fish are drawn behind background cards.

### Atari sizes (mode 5 map, D12)

A map square is 8 pixels of 160-resolution. In mode 5 one pixel is
one colour clock, so a square is 8 colour clocks wide and 16 scan
lines tall.

- A **player** at normal width is 8 bits x 1 colour clock =
  8 colour clocks: exactly one square, at the same pixel width as the
  map. With double-line P/M resolution its pixels are also 2 scan
  lines tall, like the map's.
- A player at **double width** is two squares wide, with pixels twice
  as wide as the map's.
- A **missile** is 2 bits. At double width it covers half a square.
  The four missiles side by side as a **fifth player** make 8 bits:
  at double width (`SIZEM` = `$55`, missiles 4 colour clocks apart),
  two squares wide, in one colour (`COLPF3`).
- **Vertical reuse:** a DLI can move a player to a new horizontal
  position partway down the screen. Mode 5 rows are 16 lines, so the
  DLI on each map row has plenty of time. Two objects can share one
  player only if their vertical extents don't overlap, with about one
  row of gap for the DLI to reposition.

### Option A: fifth player for weather (recommended)

| Hardware | Use |
|---|---|
| P0, P1 | Player 1 and player 2 sprite (cursor or boat), own colours |
| P2 | Both pirate ships, reused vertically by DLI |
| P3 | Both fish schools, reused vertically by DLI |
| M0-M3 as fifth player, double width | Weather, both storms reused vertically by DLI |

- **For:** all eight objects are hardware sprites with smooth
  movement and no software drawing. The cursors never share or flicker.
  Weather comes out exactly 2 squares wide: 8 P/M lines tall for rain
  and storms, 32 for a hurricane. With `PRIOR` = `$02` the cursors are
  above the map and P2/P3 below it, so fish and pirates go behind
  background cards as fish do in the original; the fifth player sits
  at playfield priority, above pirates and fish and below the cursors. The original's weather is
  white, and `COLPF3` = white also suits schools, which are white in the
  original, if those use inverse characters (see Q3).
- **Against:** weather is one colour, so rain and tropical storm must
  differ by shape or animation rather than colour, unless a DLI changes
  `COLPF3` between storms. That also changes the inverse-character
  colour on those rows. Weather pixels are coarser than the map's.
  Two pirates, two fish or two storms in the same band of rows can't
  both show (see "Sharing rule" below).

### Option B: weather on players, small objects on missiles

| Hardware | Use |
|---|---|
| P0, P1 | Player sprites |
| P2, P3 at double width | One storm each |
| M0+M1, M2+M3 at double width | Pirates and fish, two missiles side by side per object, reused vertically |

- **For:** two storms can be anywhere, each in its own colour, so
  rain and tropical storm can keep different colours as in the
  original.
- **Against:** pirates and fish become 4 coarse pixels wide and take
  the colour of P2/P3, so they look like blobs in the weather's colour.
  Fitting four small objects onto two missile pairs still needs the
  same vertical sharing as option A. This is worse where it matters
  most, because pirates and fish are what players watch closely.

### Option C: weather drawn into the playfield

| Hardware | Use |
|---|---|
| P0, P1 | Player sprites |
| P2 | Pirates, reused vertically |
| P3 | Fish, reused vertically |
| Missiles | Spare: sinking splash, cursor marker, fish sparkle |
| Characters | Weather, as a block of cloud characters drawn over the map |

- **For:** weather can be big, detailed and multicoloured, and the
  missiles stay free for effects.
- **Against:** weather moves in whole-character steps unless we
  software-shift it into dedicated characters each frame. That costs
  CPU time and about 16+ font characters per storm, and the map cells
  underneath must be saved and restored. It also makes the "is the
  storm over this square" logic depend on drawing code. It's the most
  work and the least like the original, where the storms glide.

### Sharing rule (options A and B)

When two objects need the same player in overlapping rows:

1. **Spawn rule (proposed):** pirates and fish already pick the top
   or bottom band at random. If the band is taken by the other object
   of the same kind, use the other band instead. The odds of each band
   are 50/50 anyway, so this is barely visible; record it in
   DECISIONS.md as a deviation. Weather always starts at the top, so a
   second storm waits until the first has drifted at least a row clear
   (or spawns on a later tic).
2. **Movement:** if two drifting objects come to overlap vertically,
   show them in alternate frames (30 Hz flicker) while they overlap.
   That should be rare and brief.

### Collisions

Detect collisions in software on the logical grid, not with GTIA's
collision registers. A reused player can't tell which of its two
objects was hit, and the rules care about squares (fort adjacency,
crops under rain) anyway. The original checks these pairs:

- player fishing boat with weather, the other player's boat, pirates, fish
- player PT boat with weather, pirates, land
- pirates with weather, land
- fish and weather with the background (parked boats, crops, items)

### Recommendation

**Option A** with the sharing rule: double-line P/M graphics (1K),
cursors on P0/P1, pirates on P2, fish on P3, weather as the white
fifth player. Things to decide with it:

- Is the spawn rule acceptable as a small deviation, or do you want
  flicker only?
- The hurricane already differs by size. Should rain and tropical
  storm differ by shape or animation only, or should a DLI recolour
  `COLPF3` to keep the original's two colours?

## Q7. Rain and tropical storm colours

From Q2. With weather on the single-colour fifth player (D13), rain
and tropical storm can't keep the original's two colours for free; the
hurricane already differs by size. Options: tell rain and storm apart
by shape or animation only, or have a DLI recolour `COLPF3` on the
storm's rows, which also recolours inverse-character tiles there
(see Q3). Undecided.

## Q3. Item visuals and colours

Mode 4/5 gives background + 3 colours per char (+1 via inverse chars),
the same for the whole line unless changed by DLI. The original gives
each item its own colour (black, dark green, white, red, yellow) and
shows ownership by island.

Options: items differ by shape, using a shared palette (sand, grass,
dark, light); ownership is implicit (left/right island) except for
boats and rebels, which are sprites or use the inverse-char colour.
Needs a tile mock-up.

## Q4. Two-player keyboard controls

Both players share one keyboard to buy items. Options:

- A key buys for the player whose fire button is held.
- Split keys: player 1 uses 1-9 on the top row, player 2 uses another
  block (e.g. QWE/ASD/ZXC).
- The key goes to whichever cursor moved last.

Also: which keys show score / population / last round (original: side
buttons) — console keys START/SELECT/OPTION are a natural fit.
For the 5200: each controller has its own keypad, so this goes away.

## Q5. PAL timing

20 Hz from 50 Hz needs a 2-3 frame pattern; random-event rates per tic
stay the same. Confirm that's acceptable vs. scaling to 25 Hz tics on
PAL.

## Q6. Island shapes

The originals' exact shapes would be copied data. Plan: draw new
islands of similar size and harbour placement so gameplay balance
holds. Confirm the owner is happy with that.
