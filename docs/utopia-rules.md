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
- `births = round(pop/10 * fertility / 100)`
- `deaths = round(pop/10 * mortality / 100)`
- `pop = min(9999, pop + births - deaths)`

The disassembly comments say the fertility baseline is 50 and call the
clamp a "min of 40"; the code says baseline 40 and a maximum of 64.
Trust the code.

## Round score  [`$5ABD`]

All divisions are integer. `p100 = pop / 100`.

- Housing: `min(30, (houses * 500 / p100) / 3)`
- GDP: `min(30, (gold earned this round * 100 / p100) / 12)`
- Food: `min(30, ((crops + fishing boats) * 500 / p100) / 3)`
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
  adjacent squares.
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
