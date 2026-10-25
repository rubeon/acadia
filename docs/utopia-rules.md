# Utopia rules and constants

Extracted from a commented disassembly of the original **Intellivision**
cartridge (Mattel, 1981; CP1610 code at `$5000-$5FFF`). Addresses in
brackets are ROM addresses in that disassembly, for cross-checking.
Nothing here comes from the Aquarius version; if that port differs,
check it separately.

## Items

Item numbers match the keypad keys and are used throughout the game.

| Key | Item | Cost (gold bars) | Colour |
|---|---|---|---|
| 1 | Fort | 50 | black |
| 2 | Factory | 40 | black |
| 3 | Crop | 3 | dark green |
| 4 | School | 35 | white |
| 5 | Hospital | 75 | red |
| 6 | House | 60 | yellow |
| 7 | Rebel (bought: placed on the opponent's island) | 30 | black |
| 8 | PT boat | 40 | player colour |
| 9 | Fishing boat | 25 | player colour |

Key 0 toggles the cursor between "place item" and "move boat" modes.
Boats are bought into the player's harbour and moved with the disc.

## Game setup  [`$504C`, `$50F3`]

- "TERM OF OFFICE": number of rounds, 1-50.
- "TURN LENGTH": seconds per round, 30-120.
- Each player starts with population 1000 and 100 gold bars.
- The timer task runs at 20 tics per second; the round clock counts
  seconds.

## Display

- The playfield is a 20 x 12 grid of 8 x 8 cards. Each island is drawn
  from a fixed list of card positions (left island for player 0, right
  for player 1).
- Status bar: rounds left, seconds left, gold for each player.
- Side buttons: top shows total score, lower left island population,
  lower right previous round score.

## Islands and harbours  [`$512F-$51A2`, `$5924`]

Numbers only; the shapes are not reproduced here (D4, D21).

- Each island is a list of 29 card positions (left `$512F`, right
  `$514C`), so each island has **29 land squares**. Of these, 6 (left)
  and 7 (right) are full-land cards; the rest are coastline-shaped
  cards. Islands occupy card rows 2-8 of 12; rows 0-1 and 9-11 are sea.
- Each player has **one harbour**, a single sea square next to the
  island on its **outer** side, where bought boats appear
  (`$5924`): player 0 at BACKTAB offset `$7A` (row 6, column 2, west of
  the left island), player 1 at `$62` (row 4, column 18, east of the
  right island). A purchase is refused if the harbour is occupied.
- Fish and pirates enter in the top band (card row 1) or bottom band
  (card row 10), so the islands keep a sea row between them and each
  band.

## End-of-round income  [`$59CD`]

Per player:

1. 4 gold per factory.
2. 1 gold per fishing boat.
3. Productivity bonus: `min(30, factories * (schools + hospitals) + hospitals)`.
4. 10 gold flat. This does **not** count toward "gold earned this
   round" (used by the GDP score); items 1-3 do.

## Population  [`$5A32`]

Rates are per 1000 (tenths of a percent).

- Fertility starts at 40.
  - +3 per crop, +3 per hospital, +1 per house, -3 per school.
  - Then capped at a **maximum** of 64.
- Mortality starts at 11.
  - -3 per hospital, with a minimum of 2.
  - Then +1 per factory (applied after the hospital minimum).
- `p10 = round(pop / 10)` [`$5A3B`]
- `births = round(p10 * fertility / 100)` [`$5A83`]
- `deaths = round(p10 * mortality / 100)` [`$5A8A`]
- `pop = min(9999, pop + births - deaths)`

`round()` is the EXEC's divide-with-rounding (`X_DIVR`), which is not
in the cartridge, so its exact rule is assumed to be the usual round
half up (`MATH.ASM` `DIVNR`). A test against the real game would
confirm it.

The disassembly comments say the fertility baseline is 50 and call the
clamp a "min of 40"; the code says baseline 40 and a maximum of 64.
Trust the code.

## Round score  [`$5ABD`]

`p100 = pop / 100`, **truncated** (the plain divide `X_DIV`, `$5AC6`).
Every other division here **rounds** (`X_DIVR`):

- Housing: `min(30, round(round(houses * 500 / p100) / 3))` [`$5AD8`, `$5ADE`]
- GDP: `min(30, round(round(gold earned this round * 100 / p100) / 12))` [`$5AF6`, `$5AFC`]
- Food: `min(30, round(round((crops + fishing boats) * 500 / p100) / 3))` [`$5B1A`, `$5B20`]
- General welfare: +1 per school, +1 per hospital.
- Round score = sum, capped at 100. It is added to the running total;
  the previous round score is kept for the rebel check.

Overflow notes from the original: earned gold over 255 or
crops + fishing boats over 65 overflow. A clone may fix these.

After scoring, a random crop destruction pass runs, removing crops.

## Rebels  [`$5BB2`]

Checked per player after scoring:

- A rebel appears if the score fell by 10 or more since last round, or
  the score is below 30.
- Otherwise a rebel is removed if the score rose by 10 or more, or the
  score is 70 or higher.
- Placement: up to 250 tries at a random island square. It must be an
  empty land square and not next to a fort.
- A bought (mercenary) rebel uses the same placement on the opponent's
  island.

## Random events  (checked every tic, 20 Hz)

- Weather: `rand(100) == 0` starts weather (rain, tropical storm or
  hurricane) if a weather sprite is free. Existing weather has a 1-in-10
  chance per tic to change velocity by one step N/S/E/W.
- Fish: `rand(20) == 0` spawns a school of fish.
- Pirates: `rand(100) == 0` spawns a pirate ship.

## Weather effects  [`$5691`, `$573E`]

- Damage rate: hurricane 5, tropical storm 1, rain 0.
- Storm damage accumulates per player; once over 125 an item under the
  storm can be destroyed and 0-101 population killed. Forts protect
  adjacent squares: "adjacent" is the 8 squares around a square, not
  the square itself, and a fort of either player counts
  (`FORT_NEAR_MOB` `$564A`, `NBR_TBL` `$5689`; see D25).
- Storms can sink boats, parked or moving (`$5591`, `$55BF`); fort protection here not yet verified.
- Rain over crops: every 12 tic-overlaps award 1 gold (with sound).

## Boats

- A fishing boat over a school of fish earns 1 gold per 50
  tic-overlaps (with the "pling" sound). This works parked or moving.
- PT boats sink pirates.
- Pirates sink fishing boats unless a fort is adjacent.
- A fishing boat can be sunk by the other player's boat (routine at `$55BF`; exact rule not yet verified).
- Boats cannot run aground; the island edge blocks them.

## Sprite allocation in the original

| Sprites | Use |
|---|---|
| 0, 1 | Weather |
| 2, 3 | Player cursors / boats |
| 4, 5 | Pirates |
| 6, 7 | Fish |

## End of game  [`$547E`]

After the last round, controllers are disabled, "FINAL SCORE" is shown,
and the winner is the player with the higher total score.

## Worked example (for tests)

One player, start of round: population 1000, 2 factories, 4 crops,
1 school, 1 hospital, 1 house, 1 fishing boat, no forts or rebels.

- Income: 2 x 4 + 1 = 9; bonus `min(30, 2 * (1 + 1) + 1)` = 5;
  earned = **14**; gold rises by 14 + 10 = **24**.
- Fertility: 40 + 4x3 + 3 + 1 - 3 = **53** (under the 64 cap).
- Mortality: 11 - 3 = 8 (not below 2), + 2 factories = **10**.
- `p10` = round(1000 / 10) = 100. Births round(100 * 53 / 100) = 53;
  deaths round(100 * 10 / 100) = 10; population **1043**.
- Score, using the updated population (`p100` = 1043 / 100 = 10,
  truncated):
  housing round(round(1 * 500 / 10) / 3) = round(50 / 3) = **17**;
  GDP round(round(14 * 100 / 10) / 12) = round(140 / 12) = **12**;
  food round(round((4 + 1) * 500 / 10) / 3) = 83, capped at **30**;
  welfare **2**; round score **61**.

(An earlier version of this example truncated every division and got
housing 16, GDP 11 and score 59; the original rounds them.)

Not yet verified: whether the score routine `[$5ABD]` uses the
population before or after this round's update. With the old
population (`p100` = 10 here as well) this example gives the same
result; a test case with a population near a multiple of 100 will
tell them apart.
