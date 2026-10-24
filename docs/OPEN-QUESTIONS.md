# Acadia — open questions

Design questions not yet decided. Add analysis, options and a
recommendation under each; the owner decides. When decided, move the
outcome to DECISIONS.md and mark the question **Closed (Dn)**.

## Q1. Map character mode and tile size

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

Initial lean: mode 5 for simplicity, unless item art needs the extra
vertical detail. The M0 test uses mode 4.

## Q2. Sprite allocation

The original uses 8 hardware sprites: 2 weather, 2 cursors/boats,
2 pirates, 2 fish. The Atari has 4 players + 4 missiles (or a fifth
player from missiles).

Options: players for cursors/boats and pirates, missiles (or the fifth
player) for fish; weather drawn as playfield or as wide players
multiplexed by DLI when vertically separated; or vertical
multiplexing generally. Needs a decision before M4.

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
