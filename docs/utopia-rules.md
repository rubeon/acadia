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

Buying in the original takes two keys (`$57B4-$57D0`): a digit only
selects the item, ENTER buys it, CLEAR cancels (Acadia buys on the
digit, D17).

- **Buying a boat** (`$587F`, `$5924`, `$58CA-$58FC`): the cursor
  position doesn't matter; the player's harbour must be empty, then
  gold is checked and paid. The harbour card becomes the boat in the
  owner's colour. There is no limit on the number of boats, but the
  harbour must be cleared before the next one.
- **Key 0, cursor mode** (`UNPARK_BOAT`, `$57D8-$580E`): the player's
  own boat on the card under the cursor's centre is lifted off the
  background and the cursor sprite becomes that boat. Anything else
  is refused. Any of the player's parked boats can be picked up.
- **Key 0, boat mode** (`PARK_BOAT`, `$5821-$5875`): the card under
  the boat's centre must be empty sea (not land, coast, a building or
  a boat, and not the status bar); the boat is drawn there and the
  sprite is the cursor again. Refused while the boat is sinking.
- **Steering** (`$5774-$579F`): the disc sets the velocity (boat speed
  10, cursor 15); releasing it stops the boat dead. Boats stay on
  screen. While steering, items 1-6 are refused (the square under the
  boat is sea), boats can still be bought.
- Nothing parks a steered boat at the end of a round.


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

Gold earned during the round (fish caught, rain on crops, `INC_GOLD`
`$54D2`) also counts as earned. Earned gold is added by `AWARD_GOLD`
(`$5A0E`), kept in one byte per player, and reset after scoring
(`$5B6C`). Gold itself is a 16-bit total with **no cap** (D26 caps it
at 9999 in Acadia).

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
- Fertility has no lower limit in the original: with many schools it
  goes below 0, and the multiply at `$5A75` would then work on a
  negative number. Acadia stops it at 0 (no births; D27).

`round()` is the EXEC's divide-with-rounding (`X_DIVR`), which is not
in the cartridge, so its exact rule is assumed to be the usual round
half up (`MATH.ASM` `DIVNR`). A test against the real game would
confirm it.

The disassembly comments say the fertility baseline is 50 and call the
clamp a "min of 40"; the code says baseline 40 and a maximum of 64.
Trust the code.

## Round score  [`$5ABD`]

`p100 = pop / 100`, **truncated** (the plain divide `X_DIV`, `$5AC6`),
from the population after this round's update. A population under 100
gives `p100 = 0`, which the original divides by; Acadia uses 1 (D28).
Every other division here **rounds** (`X_DIVR`):

- Housing: `min(30, round(round(houses * 500 / p100) / 3))` [`$5AD8`, `$5ADE`]
- GDP: `min(30, round(round(gold earned this round * 100 / p100) / 12))` [`$5AF6`, `$5AFC`]
- Food: `min(30, round(round((crops + fishing boats) * 500 / p100) / 3))` [`$5B1A`, `$5B20`]
- General welfare: +1 per school, +1 per hospital.
- Round score = sum, capped at 100. It is added to the running total;
  the previous round score is kept for the rebel check.

Overflow notes from the original: earned gold over 255 or
crops + fishing boats over 65 overflow. A clone may fix these.

After scoring (and the reset of earned gold), a crop destruction pass
runs once per round over both islands (`$5B6B-$5BB0`): each crop is
destroyed when `rand(3) == 0`, so 1 in 3 is lost, with no limit. The
square gets its island graphic back and the owner's crop count drops.
No fort protects crops; no sound; population and gold don't change.
There is no other crop loss during play (only weather and rebels).

## Rebels  [`$5BB2`]

Checked per player (player 1, then 2) after scoring and the crop
loss, at most one change each. With d = previous round score − this
round score (signed), in this order (`$5BC2-$5BD3`):

1. d ≥ 10: a rebel appears.
2. Else d ≤ −10: a rebel is removed.
3. Else score < 30: a rebel appears.
4. Else score ≥ 70: a rebel is removed.

So a score that rose by 10 or more removes a rebel even if it is still
under 30. In round 1 the previous score is 0.

- Placement (`$5BE8-$5C48`): up to about 250 tries (`RBLTRY`, gives up
  above 250), each `rand(29)` into the player's island square table.
  A square holding a rebel or a fort, or with a fort of either player
  on one of its 8 neighbours (`FORT_NEAR_CARD` `$568D`), is skipped.
  **Any other item there is destroyed** (count −1, "smite" sound
  `$5FB6`) and the rebel takes the square. All tries failing: nothing.
- Removal (`$5C50-$5C83`): the first rebel in island table order goes;
  the square shows the island again. No sound.
- Rebels are never counted (`REBL_0/1` unused) and affect nothing but
  their square: nothing can be built on it. Weather damage can destroy
  a rebel like any item. A fort built next to a rebel doesn't remove it.
- A bought (mercenary) rebel, key 7, 30 gold, cursor anywhere: the gold
  is deducted first, then the same placement runs on the opponent's
  island (`$58B3`, `$594C-$5957`); no refund if it finds no square.

## Random events  (checked every tic, 20 Hz)

- Weather: `rand(100) == 0` starts weather in the first free of 2
  slots (`$51AA`): `rand(12)` 0 hurricane, 1-3 tropical storm, 4-11
  rain. It starts at X 27, Y 0 moving +4, +5 (template `$5C85`). Each
  tic, 1 in 10 a ±1 kick N/S/E/W, no limit (`$51F8`). Not blocked by
  land; removed when it leaves the screen; no lifetime, no change of
  type. Rain and storm are 16 × 8 pixels (storm black, rain grey),
  the hurricane 16 × 32.
- Fish: `rand(20) == 0` spawns a school of fish into one of 2 slots
  (`$520D`): band top or bottom 50/50, X = 0 heading east at 3 or
  X = 167 heading west at -3. Each tic, 1 in 10 a ±1 kick to vx or
  vy, with no limit. Blocked like pirates (land, buildings and parked
  PT boats; parked fishing boats are passed). A school that leaves the
  screen is removed. Green dot sprite, 4 animation frames, behind the
  playfield.
- Pirates: `rand(100) == 0` spawns a pirate ship into one of 2 slots,
  placed like fish (top or bottom band, X = 0 heading east at 3 or
  X = 167 heading west at -3). Each tic, 1 in 10 a ±1 kick, no limit;
  blocked like fish; removed off the screen. No homing; nothing
  scales with the round. One black ship sprite; only a sinking sound.

## Weather effects  [`$5691`, `$573E`]

- Only the card under the weather sprite's centre counts (`$56AF`),
  and only when it holds an item or a parked boat; open sea and bare
  land do nothing.
- Damage rate: hurricane 5, tropical storm 1, rain 0, added to the
  card owner's total (`TDMG`) once per interaction. At 125 (`$56C4`)
  the item is destroyed, whatever it is (forts and rebels too): its
  count drops by 1; a parked boat sinks (`$5591`, one sinking
  animation at a time); any other item also kills `rand(101)` people,
  with no check for going below 0 (`$56E1`). The square shows its
  island graphic again ("smite" sound `$5FB6`) and the total resets to
  0, except after a boat, where it is left as it was.
- **Forts do not protect against weather**: `WTHR_V_LAND`
  (`$5691-$570B`) never calls `FORT_NEAR_MOB`. Forts protect boats
  from pirates only.
- Moving boats: only a hurricane sinks them, on contact, with no fort
  check or chance roll (`$559A`); the fishing boat count drops
  (`$55FC`), the PT count doesn't. Rain and storms pass over moving
  boats. A hurricane also sinks pirates.
- Rain over crops: any weather over a crop counts for the crop's
  owner (`RCRP`, `$573E`); every 12 counts award 1 gold (`INC_GOLD`,
  sound `$5F97`). Counts carry over between rounds.
- Weather carries on through round changes and does nothing to
  rebels.

## Boats

- A fishing boat over a school of fish earns 1 gold per 50
  tic-overlaps (with the "pling" sound). This works parked or moving.
  Parked: the boat on the card under the school's centre; moving: the
  boat sprite touching the school (`$549F-$54D2`). The count is per
  player and is not reset at round end; schools are never used up.
- **PT boats do not sink pirates.** A moving PT boat touching a pirate
  only halts it (its velocity is zeroed). Only a hurricane sinks
  pirates.
- Pirate over a parked fishing boat (the boat on the card under the
  pirate's centre): nothing while a sinking is showing; nothing if the
  fort found next to the boat (`FORT_NEAR_MOB`) belongs to the boat's
  owner; otherwise a per-owner counter goes up, and at 20 the boat
  sinks (count -1, sinking animation) and the counter resets. The
  pirate survives.
- Pirate touching a moving fishing boat: sunk at once (count -1, back
  to the cursor) unless a fort of either player is next to it.
- A moving PT boat over the other player's parked fishing boat: the
  same handler as a pirate (owner's fort protects; sinks at 20).
- A moving fishing boat touching the other player's moving PT boat:
  sunk unless a fort of its own player is next to it.
- Boats cannot run aground; the island edge blocks them. Blocking test
  `$5320-$53CD`: the card one step ahead on each axis (X, then Y) is
  checked; a blank GROM card is open sea, any GRAM card (island, coast,
  building, parked boat) blocks, and the mover is nudged back 1 pixel
  with that axis's velocity zeroed (`$538A-$53B4`). The status bar is
  also kept out.
  - Player boats pass parked PT and fishing boats (`$5382`, `$5386`);
    pirates treat parked PT boats as land and pass only fishing boats
    (`$537A-$5388`).
  - It runs for player boats (not cursors), both pirates and both fish
    schools (`$52FC-$531C`); weather passes over land.
  - There are no rocks or other sea obstacles: only the islands and
    what is on them block movement (see D30).

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

The score uses the population **after** this round's update: the
population routine (`$5A32`) runs for both players and stores the new
values before the score routine (`$5ABA`) reads them back (`$5ABD`,
commented "updated" in the disassembly).