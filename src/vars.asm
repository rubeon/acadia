; =====================================================================
;  VARS.ASM -- all RAM variables, in one block.  No code, no data.
;
;  Storage is reserved with *= *+n only; nothing is loaded here, so
;  no variable relies on a value from the loader.  VARS_INIT (in
;  ACADIA.ASM) clears the whole block at start-up and then sets the
;  few variables whose start value is not zero.
;
;  The block sits at $3900-$3FFF: RAM on the 800 (between the display
;  list page and P/M graphics at $4000) and inside the 5200's 16K of
;  RAM, so the same addresses work from a 5200 cartridge.
; =====================================================================

VARBASE =  $3900
VARPAGES = 7            ; $3900-$3FFF, cleared by VARS_INIT

        *= VARBASE

; ---------------------------------------------------------------------
;  Input layer (INPUT.ASM)
; ---------------------------------------------------------------------
JOY0    *= *+1          ; directions, 1 = pressed: b0 up b1 down b2 left b3 right
JOY1    *= *+1
FIRE0   *= *+1          ; 1 = trigger held
FIRE1   *= *+1
KEY     *= *+1          ; item key 0-9 pressed this poll, else $FF
KEYPL   *= *+1          ; player the key belongs to (0/1), else $FF
KEYDOWN *= *+1          ; key held flag (edge detection)

; ---------------------------------------------------------------------
;  Display (DISPLAY.ASM)
; ---------------------------------------------------------------------
FRAME   *= *+1          ; frame counter, incremented by the VBI
DLIROW  *= *+1          ; DLI_ROW: map row whose font is set next
ROWLO   *= *+MAPROWS    ; map row addresses, low bytes
ROWHI   *= *+MAPROWS    ; map row addresses, high bytes
MROW    *= *+1          ; MAP_DRAW: current square row
GIDX    *= *+1          ; MAP_DRAW: index into the tile grid
MTILE   *= *+1          ; MAP_PUT: tile being drawn
STATUS1 *= *+40         ; status bar line 1 (screen memory)
STATUS2 *= *+40         ; status bar line 2 (screen memory)

; ---------------------------------------------------------------------
;  Sprites (SPRITES.ASM) and cursors (CURSOR.ASM); 2 bytes = P0, P1
; ---------------------------------------------------------------------
SPRY    *= *+2          ; map line each player is drawn at ($FF = none)
SPRHP   *= *+2          ; horizontal position for SPR_VBI
CURX    *= *+2          ; cursor map pixel column, 0-152
CURY    *= *+2          ; cursor map pixel line, 0-80
CURCOL  *= *+2          ; square under each cursor: column 0-19
CURROW  *= *+2          ;   and row 0-10
CUJOY   *= *+1          ; CUR_MOVE: joystick bits being handled

; ---------------------------------------------------------------------
;  Map grid (MAP.ASM)
; ---------------------------------------------------------------------
MAPITEM *= *+220        ; item on each square, 0 = none (20 x 11)
MKIND   *= *+1          ; MAP_GET: kind of the square
MG_X    *= *+1          ; MAP_GET / MAP_SET: saved column
MS_ITEM *= *+1          ; MAP_SET: item being placed
FN_COL  *= *+1          ; FORT_NEAR: square asked about
FN_ROW  *= *+1
FN_I    *= *+1          ; FORT_NEAR: neighbour 0-7
FN_C    *= *+1          ; FORT_NEAR: neighbour column

; ---------------------------------------------------------------------
;  Economy (ECONOMY.ASM)
; ---------------------------------------------------------------------
COUNT   *= *+20         ; items owned: COUNT+k player 1, COUNT+10+k player 2
EB_ITEM *= *+1          ; ECO_BUY: item being bought
EB_P    *= *+1          ; ECO_BUY: buying player
EB_LO   *= *+1          ; ECO_BUY: gold after paying, low byte
RGOLD   *= *+4          ; gold earned this round, 16 bits per player
EC_P    *= *+1          ; ECO_INCOME etc.: player
EC_CI   *= *+1          ; ECO_INCOME etc.: player x 10, for COUNT
EC_P2   *= *+1          ; ECO_POP etc.: player x 2, for 16-bit values
POP     *= *+4          ; population, 16 bits per player
EP_P10  *= *+2          ; ECO_POP: round(pop / 10)
EP_POS  *= *+2          ; ECO_POP: work value
EP_FERT *= *+1          ; ECO_POP: fertility per 1000
EP_MORT *= *+1          ; ECO_POP: mortality per 1000
SCORE   *= *+4          ; total score, 16 bits per player
RSCORE  *= *+2          ; this round's score, per player
PRSCORE *= *+2          ; the round before's score, per player
ES_P100 *= *+1          ; ECO_SCORE: pop / 100
ES_DIV  *= *+1          ; ECO_SCORE: second divisor (3 or 12)
ES_SUM  *= *+1          ; ECO_SCORE: score so far
EG_AMT  *= *+2          ; ECO_EARN / ECO_GIVE: amount

; ---------------------------------------------------------------------
;  Services (RAND.ASM)
; ---------------------------------------------------------------------
RN_N    *= *+1          ; RAND_N: range
RN_M    *= *+1          ; RAND_N: bit mask

; ---------------------------------------------------------------------
;  Game tic (TIC.ASM)
; ---------------------------------------------------------------------
LASTFR  *= *+1          ; FRAME at the last TIC_POLL
TICDUE  *= *+1          ; tics due, not yet taken by TIC_NEXT
TICPH   *= *+1          ; phase in the frame pattern
TICOFS  *= *+1          ; pattern start in TICPAT (NTSC or PAL)
TICLEN  *= *+1          ; pattern length (3 NTSC, 5 PAL)
TICSEC  *= *+1          ; tic within the second, 0-19

; ---------------------------------------------------------------------
;  Text (TEXT.ASM)
; ---------------------------------------------------------------------
TCNT    *= *+1          ; TXT_DEC: field width
TOFS    *= *+1          ; TXT_DEC: field start
TPOS    *= *+1          ; TXT_DEC: current digit position
TLAST   *= *+1          ; TXT_DEC: last character of the field

; ---------------------------------------------------------------------
;  Game state (ARCHITECTURE section 7 names).  For now only the test
;  build's demo clock in ACADIA.ASM drives these.
; ---------------------------------------------------------------------
GOLD    *= *+4          ; gold, 16 bits per player: P0 at GOLD, P1 at GOLD+2
NUMTRN  *= *+1          ; number of rounds in the game
CURTRN  *= *+1          ; rounds played so far
TRNLEN  *= *+1          ; round length in seconds
REMSEC  *= *+1          ; seconds left in this round

VAREND
