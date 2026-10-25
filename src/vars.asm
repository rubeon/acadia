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
;  Services (RAND.ASM)
; ---------------------------------------------------------------------
RN_N    *= *+1          ; RAND_N: range
RN_M    *= *+1          ; RAND_N: bit mask

VAREND
