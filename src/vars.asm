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
PAUSEK  *= *+1          ; 1 when P was pressed this poll
HELPK   *= *+1          ; 1 when H or HELP was pressed this poll
CONKEY  *= *+1          ; console keys held: b0 START, b1 SELECT, b2 OPTION
KEYDOWN *= *+1          ; key held flag (edge detection)
KPMODE  *= *+1          ; 1: keypad controller in port 2 (D49)
KPROW   *= *+1          ; keypad row read next, 0-3
KPHIT   *= *+1          ; key found in this scan, 0-11, or $FF
KPDOWN  *= *+1          ; keypad key held flag (edge detection)

; ---------------------------------------------------------------------
;  Display (DISPLAY.ASM)
; ---------------------------------------------------------------------
FRAME   *= *+1          ; frame counter, incremented by the VBI
DLIROW  *= *+1          ; DLI_ROW: map row whose font is set next
MAPPAL  *= *+5          ; map colours (PAL_NORM / PAL_DIM)
MAPCOL  *= *+5          ; the same with attract mode applied (VBI_D, for the DLI)
ROWBK   *= *+22         ; sea colour per character row (VD_SHADE, D51)
ROWPF0  *= *+22         ; grass colour per character row
AP_SH   *= *+1          ; VD_SHADE: COLRSH, DRKMSK and MAPPAL sea / grass
AP_MSK  *= *+1          ;   it was built from
AP_BK   *= *+1
AP_GR   *= *+1
VS_C    *= *+1          ; VS_LUM: work
VS_D    *= *+1
DL_PF0  *= *+1          ; DLI_ROW: work
WA_F    *= *+1          ; WAVE_ANI: font index
PD_LUM  *= *+1          ; PAL_DIM: work byte
ROWLO   *= *+MAPROWS    ; map row addresses, low bytes
ROWHI   *= *+MAPROWS    ; map row addresses, high bytes
MROW    *= *+1          ; MAP_DRAW: current square row
GIDX    *= *+1          ; MAP_DRAW: index into the tile grid
MTILE   *= *+1          ; MAP_PUT: tile being drawn
MPINV   *= *+1          ; MAP_PUTI: ORed into every character ($80: inverse)
MP_X    *= *+1          ; MAP_PUT: column, kept
STATUS1 *= *+40         ; status bar line 1 (screen memory)
STATUS2 *= *+40         ; status bar line 2 (screen memory)

; ---------------------------------------------------------------------
;  Sprites (SPRITES.ASM) and cursors (CURSOR.ASM); 2 bytes = P0, P1
; ---------------------------------------------------------------------
SPRY    *= *+2          ; map line each player is drawn at ($FF = none)
SPRHP   *= *+2          ; horizontal position for SPR_VBI
SPRSHP  *= *+2          ; shape each player shows (SH_CUR, SH_PT, SH_FISH)
SP_P    *= *+1          ; SP_PAINT: player
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
EB_C    *= *+1          ; ECO_BUY: column of the square bought
EB_R    *= *+1          ; ECO_BUY: row of the square bought
RGOLD   *= *+4          ; gold earned this round, 16 bits per player
EC_P    *= *+1          ; ECO_INCOME etc.: player
EC_CI   *= *+1          ; ECO_INCOME etc.: player x 10, for COUNT
EC_P2   *= *+1          ; ECO_POP etc.: player x 2, for 16-bit values
CL_C    *= *+1          ; ECO_CROPS: square
CL_R    *= *+1
CL_I    *= *+1          ; ECO_CROPS: COUNT index of the crop's owner
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
;  Round loop and screens (SCREENS.ASM)
; ---------------------------------------------------------------------
GSTATE  *= *+1          ; GS_PLAY, GS_SUM1, GS_SUM2, GS_OVER
GTIMER  *= *+1          ; tics left on a summary page
INFOK   *= *+1          ; info page shown: 0 none, 1-3 START/SELECT/OPTION
GO_ARM  *= *+1          ; game over: 1 once fire and keys are let go
SV0     *= *+2          ; SHOW_PAIR: player 1's number
SV1     *= *+2          ; SHOW_PAIR: player 2's number (must follow SV0)

; ---------------------------------------------------------------------
;  Pause (PAUSE.ASM)
; ---------------------------------------------------------------------
PAUSED  *= *+1          ; 1 while the game is paused
PSAVE   *= *+40         ; status line 1 while PAUSED is shown

; ---------------------------------------------------------------------
;  Sound driver (SOUND.ASM): per channel 0-3
; ---------------------------------------------------------------------
SN_ON   *= *+4          ; 1 while an effect plays
SN_PRI  *= *+4          ; its priority
SN_POS  *= *+4          ; next step, offset in SNDDAT
SN_CNT  *= *+4          ; frames left of this step
SN_F    *= *+4          ; AUDF now
SN_C    *= *+4          ; AUDC now
SN_D    *= *+4          ; slide per frame
SN_SX   *= *+1          ; SND_GO: X and Y kept
SN_SY   *= *+1
SN_T    *= *+1          ; SND_PLAY: channel chosen
SN_I    *= *+1          ; SND_PLAY: work
SN_LO   *= *+1          ; lowest voice effects may use (2 while music)

; ---------------------------------------------------------------------
;  Music (MUSIC.ASM): per voice 0-1
; ---------------------------------------------------------------------
MZ_ON   *= *+1          ; 1 while a tune plays
MZ_LOOP *= *+1          ; 1: the tune starts again at its end
MZ_N    *= *+1          ; MUS_VBI: the note
MZ_ACT  *= *+2          ; 1 while the voice has notes left
MZ_POS  *= *+2          ; next note, offset in MUSDAT
MZ_ST   *= *+2          ; first note, for looping
MZ_CNT  *= *+2          ; frames left of this note
MZ_F    *= *+2          ; AUDF now
MZ_VOL  *= *+2          ; volume now
MZ_DT   *= *+2          ; frames since the volume last fell

; ---------------------------------------------------------------------
;  Weather (WEATHER.ASM)
; ---------------------------------------------------------------------
WACT    *= *+2          ; per slot: 0 none, WT_RAIN, WT_STRM, WT_HURR
WXL     *= *+2          ; position, 8.8: WXH = map column + 8
WXH     *= *+2
WYL     *= *+2          ; WYH = map line + 8
WYH     *= *+2
WVX     *= *+2          ; speed, signed, -15..15
WVY     *= *+2
WDRAWN  *= *+2          ; missile line drawn at, $FF = none
WDH     *= *+2          ; height drawn
WRCNT   *= *+2          ; per player: rain-over-crop count (0-11)
WDMG    *= *+2          ; per player: storm damage (0-124)
WANIM   *= *+1          ; animation frame 0-3
WATIC   *= *+1          ; tics into the frame
HP2ROW  *= *+MAPROWS    ; player 2 position for each map row (DLIs)
WCROW   *= *+MAPROWS    ; player 2 colour for each map row (DLIs)
SNKT    *= *+1          ; tics the wreck still shows, 0 = none
SNKC    *= *+1          ; its square
SNKR    *= *+1
WT_I    *= *+1          ; WTH_TIC: slot
WN_S    *= *+1          ; WTH_NEW: slot
WN_T    *= *+1          ; WTH_NEW: work
WH_I    *= *+1          ; WTH_HIT: slot
WH_C    *= *+1          ; WTH_HIT: square
WH_R    *= *+1
WH_IT   *= *+1          ; WTH_HIT: item byte
WH_K    *= *+1          ; WTH_HIT: item 1-9
WH_P    *= *+1          ; WTH_HIT: owner 0/1
WS_N    *= *+1          ; WTH_SMITE / WTH_SHOW: work
WS_V    *= *+2          ; WTH_SHOW: show slot?
WS_I    *= *+1          ; WTH_SHOW: slot
WS_A0   *= *+1          ; WTH_SHOW: rows
WS_A1   *= *+1
WW_R0   *= *+1          ; WW_ROWS: first row

; ---------------------------------------------------------------------
;  Help screen (HELP.ASM)
; ---------------------------------------------------------------------
HELPON  *= *+1          ; 1 while the help screen is up
HL_K    *= *+1          ; HELP_DRAW: item 1-9
HL_T    *= *+1          ; HL_AT: column
HL_C    *= *+1          ; HL_STR: colour bit
HL_H    *= *+1          ; HL_NUM: hundreds
HL_D    *= *+1          ; HL_NUM: ones

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
TBUF    *= *+5          ; TXT_DEC: the digits, before they go on screen

; ---------------------------------------------------------------------
;  Game state (ARCHITECTURE section 7 names).  For now only the test
;  build's demo clock in ACADIA.ASM drives these.
; ---------------------------------------------------------------------
GOLD    *= *+4          ; gold, 16 bits per player: P0 at GOLD, P1 at GOLD+2
NUMTRN  *= *+1          ; number of rounds in the game
CURTRN  *= *+1          ; rounds played so far
TRNLEN  *= *+1          ; round length in seconds
REMSEC  *= *+1          ; seconds left in this round

; ---------------------------------------------------------------------
;  Boats (BOATS.ASM, T-EVT-1)
; ---------------------------------------------------------------------
BOATK   *= *+2          ; per player: boat being steered (8, 9), 0 = cursor
BOATPH  *= *+2          ; per player: speed phase, 0-2
BK_P    *= *+1          ; BOAT_KEY: player
BK_ITEM *= *+1          ; BOAT_KEY: item on the square
BM_P    *= *+1          ; BOAT_MOVE: player
BM_X    *= *+1          ; BOAT_MOVE: column pixel being tried
BM_Y    *= *+1          ; BOAT_MOVE: line being tried
BM_T    *= *+1          ; BM_FREE: work
BM_C0   *= *+1          ; BM_FREE: first, last column and row covered
BM_C1   *= *+1
BM_R0   *= *+1
BM_R1   *= *+1

; ---------------------------------------------------------------------
;  Fish (FISH.ASM, T-EVT-2)
; ---------------------------------------------------------------------
; Slots 0-1 are the schools; slots 2-3 are the pirates (PIRATES.ASM),
; which use the same movement code.
FACT    *= *+4          ; per slot: 1 while it is out
FXL     *= *+4          ; per slot: position, 8.8 (FXH = column + 8)
FXH     *= *+4
FYL     *= *+4          ; per slot: FYH = line + 8
FYH     *= *+4
FVX     *= *+4          ; per slot: signed speed (FV_LO units)
FVY     *= *+4
FDRAWN  *= *+4          ; per slot: P3 / missile line drawn at, $FF = none
FCNT    *= *+2          ; per player: touches towards the next gold
FANIM   *= *+1          ; animation frame 0-3
FATIC   *= *+1          ; tics in this frame
HP3ROW  *= *+MAPROWS    ; player 3 horizontal position per map row (DLI)
FT_I    *= *+1          ; FISH_TIC: school
FN_T    *= *+1          ; FISH_NEW: band
FM_L    *= *+1          ; FISH_MOVE: new position
FM_H    *= *+1
FB_X    *= *+1          ; FISH_BLK2: saved X
FB_C    *= *+1          ; FISH_BLK2: column
FB_H    *= *+1          ; FISH_BLK2: school FXH
FB_V    *= *+1          ; FISH_BLK2: school FYH
FB_K    *= *+1          ; FISH_BLK2: corner 3-0
FM_S    *= *+1          ; FISH_MOVE: 1 if blocked before moving
FC_I    *= *+1          ; FISH_CATCH: school
FC_P    *= *+1          ; FISH_CATCH: player
FC_T    *= *+1          ; FISH_CATCH: work
FS_V    *= *+2          ; FISH_SHOW: show school 0 / 1 this frame
FS_I    *= *+1          ; FISH_SHOW: school
FS_A0   *= *+1          ; FISH_SHOW: school 0's rows
FS_A1   *= *+1
FS_N    *= *+1          ; FISH_SHOW: bytes left
FW_R0   *= *+1          ; FW_ROWS: first row

; ---------------------------------------------------------------------
;  Pirates (PIRATES.ASM, T-EVT-3)
; ---------------------------------------------------------------------
PTCH    *= *+2          ; per player: attacks on a parked fishing boat
HMROW   *= *+MAPROWS    ; fifth player (missiles) position per map row
PT_I    *= *+1          ; PIR_TIC: slot
PH_I    *= *+1          ; PIR_HIT: slot
PH_P    *= *+1          ; PIR_HIT / PT_TIC: player
PA_C    *= *+1          ; PIR_ATK: square
PA_R    *= *+1
PA_O    *= *+1          ; PIR_ATK: the boat's owner
PS_V    *= *+2          ; PIR_SHOW: show pirate 2 / 3 this frame
PS_I    *= *+1          ; PIR_SHOW: slot
PS_A0   *= *+1          ; PIR_SHOW: pirate 2's rows
PS_A1   *= *+1
PS_N    *= *+1          ; PIR_SHOW: bytes left

; ---------------------------------------------------------------------
;  Rebels (REBELS.ASM, T-ECO-5)
; ---------------------------------------------------------------------
RBCOL   *= *+64         ; RB_LAND: a player's land squares, row by row
RBROW   *= *+64
RB_N    *= *+1          ; RB_LAND: how many
RB_P    *= *+1          ; RB_LAND: player
RB_K    *= *+1          ; RB_LAND: the player's owner bit
RB_C    *= *+1          ; work: square
RB_R    *= *+1
RB_T    *= *+1          ; REB_ADD: tries left; REB_DEL: list index
RB_I    *= *+1          ; REB_ADD: item on the square

; ---------------------------------------------------------------------
;  CPU governor (AI.ASM, T-AI-1)
; ---------------------------------------------------------------------
AIST    *= *+1          ; what is under way: 0 nothing, AS_BUY ... AS_PARK
AI_TX   *= *+1          ; AI_STEER: target pixel (top left)
AI_TY   *= *+1
AI_LX   *= *+1          ; AI_TIC: the boat's place at the last decision
AI_LY   *= *+1
AI_STK  *= *+1          ; AI_TIC: decisions it hasn't moved
AITMR   *= *+1          ; tics to the next decision
AI_IT   *= *+1          ; item being bought
AI_C    *= *+1          ; its square
AI_R    *= *+1
AI_N    *= *+1          ; AI_PICK: crops and houses wanted
AI_I    *= *+1          ; AI_SPOT: list index
AI_V    *= *+1          ; AI_SPOT: this square's value
AI_BV   *= *+1          ; AI_SPOT: best value + 1 so far
AN_C    *= *+1          ; AI_NBR: square
AN_R    *= *+1
AN_N    *= *+1          ; AI_NBR: count
AN_I    *= *+1          ; AI_NBR: neighbour 7-0
AN_T    *= *+1          ; AI_NBR: neighbour column
AI_FJ   *= *+1          ; AI_FLEE: the way away
AI_FL   *= *+1          ; AI_FLEE: frames left to keep it
AI_TB   *= *+1          ; AI_WAY: 0 home, 1 above, 2 below the islands

; ---------------------------------------------------------------------
;  News line (NEWS.ASM, D44)
; ---------------------------------------------------------------------
NW_T    *= *+1          ; tics until the message clears; 0: none
NW_PR   *= *+1          ; priority of the message showing
NW_P    *= *+1          ; NEWS: player ($FF none); X kept here
NW_SA   *= *+1          ; NEWS: message number; A kept here
NW_SY   *= *+1          ; NEWS: Y kept
NW_SY2  *= *+1          ; NW_SLEN: Y kept
NW_N    *= *+1          ; NEWS: length, then the column
NW_GX   *= *+1          ; NEWSG: X kept

; ---------------------------------------------------------------------
;  Setup screen (SETUP.ASM)
; ---------------------------------------------------------------------
SU_VAL  *= *+5          ; rounds, seconds per round, players, CPU level, keypad
SU_FLD  *= *+1          ; current line, 0-4
SU_TYPD *= *+1          ; 1 while digits are being typed on this line
SU_RPT  *= *+1          ; frames until a held left/right repeats
SU_ARM  *= *+1          ; 1 once everything has been let go
TI_ARM  *= *+1          ; title screen: 1 once everything is let go
TI_SEC  *= *+1          ; title screen: seconds with nothing touched
DEMO    *= *+1          ; 1 while the demo plays (DEMO.ASM)
DM_SAV  *= *+5          ; the setup values (SU_VAL) during the demo
DM_POS  *= *+1          ; next step in DEMOSCR
DM_CNT  *= *+1          ; frames left in this step
DM_J    *= *+1          ; this step's stick
SU_J    *= *+1          ; this frame: both sticks
SU_F    *= *+1          ; this frame: either fire button
SU_NEW  *= *+1          ; directions newly pressed this frame
SU_OLDJ *= *+1          ; last frame's SU_J
SU_OLDF *= *+1          ; last frame's SU_F
SU_OLDC *= *+1          ; last frame's CONKEY
SU_I    *= *+1          ; work: line index
SU_T    *= *+1          ; work
SU_D    *= *+1          ; SU_DIGIT: the digit

; ---------------------------------------------------------------------
VAREND
