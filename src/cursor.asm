; =====================================================================
;  CURSOR.ASM -- the two players' cursors (R-CTL-1)
;
;  Each player's joystick (JOY0 / JOY1 from the input layer) moves a
;  square cursor smoothly, CUR_SPD map pixels per frame.  When the
;  stick lets go of an axis, the cursor glides on to the nearest
;  square on that axis.  The cursor stays on the map (columns 0-19,
;  rows 0-10).  CURCOL / CURROW give the square under each cursor,
;  for buying (T-ECO-1).  While a player steers a boat (BOATS.ASM),
;  the boat takes the cursor's place and position.
;
;  Positions are map pixels: CURX 0-152 (8 per column), CURY 0-80
;  (8 P/M lines per row, i.e. 16 scan lines).
; =====================================================================

CUR_SPD =  1            ; map pixels (colour clocks / P/M lines) per frame
CUR_MAXX = 152          ; left edge of column 19: (MAPSQ-1) x 8
CUR_MAXY = 80           ; top of row 10: (MAPROWS-1) x 8

; Start squares: middle of each island
CUR0COL =  4
CUR0ROW =  5
CUR1COL =  14
CUR1ROW =  5

J_UP    =  1            ; JOY bits (input layer, 1 = pressed)
J_DOWN  =  2
J_LEFT  =  4
J_RIGHT =  8

; ---------------------------------------------------------------------
;  CUR_INIT -- put both cursors on their start squares
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
CUR_INIT
        LDA #0          ; cursors again, no boat in hand
        STA BOATK
        STA BOATK+1
        LDX #0
        JSR SPR_SHAPE   ; A = SH_CUR = 0
        LDX #1
        LDA #SH_CUR
        JSR SPR_SHAPE
        LDA #CUR0COL*8
        STA CURX
        LDA #CUR0ROW*8
        STA CURY
        LDA #CUR1COL*8
        STA CURX+1
        LDA #CUR1ROW*8
        STA CURY+1
        LDX #0
        JSR CU_SHOW
        LDX #1
        JMP CU_SHOW

; ---------------------------------------------------------------------
;  CUR_MOVE -- move both cursors one frame's worth
;  Call once per frame after INPUT_POLL.  Trashes A, X, Y.
; ---------------------------------------------------------------------
CUR_MOVE
        LDA JOY0
        LDX #0
        JSR CU_PL
        LDA JOY1
        LDX #1
CU_PL   LDY BOATK,X     ; steering a boat? (T-EVT-1)
        BEQ CU_ONE
        JMP BOAT_MOVE

; CU_ONE -- move cursor X by joystick bits A, then show it
CU_ONE  STA CUJOY
        ; horizontal
        AND #J_LEFT+J_RIGHT
        CMP #J_LEFT
        BEQ CU_LEFT
        CMP #J_RIGHT
        BEQ CU_RIGHT
        LDA CURX,X      ; no (or both) horizontal: snap
        AND #7
        BEQ CU_VERT
        CMP #4
        BCC CU_LEFT     ; 1-3 past a column: back to it
CU_RIGHT
        LDA CURX,X
        CMP #CUR_MAXX
        BCS CU_VERT
        CLC
        ADC #CUR_SPD
        STA CURX,X
        JMP CU_VERT
CU_LEFT LDA CURX,X
        BEQ CU_VERT
        SEC
        SBC #CUR_SPD
        STA CURX,X
        ; vertical
CU_VERT LDA CUJOY
        AND #J_UP+J_DOWN
        CMP #J_UP
        BEQ CU_UP
        CMP #J_DOWN
        BEQ CU_DOWN
        LDA CURY,X
        AND #7
        BEQ CU_SHOW
        CMP #4
        BCC CU_UP
CU_DOWN LDA CURY,X
        CMP #CUR_MAXY
        BCS CU_SHOW
        CLC
        ADC #CUR_SPD
        STA CURY,X
        JMP CU_SHOW
CU_UP   LDA CURY,X
        BEQ CU_SHOW
        SEC
        SBC #CUR_SPD
        STA CURY,X
        ; fall through

; CU_SHOW -- update the square under cursor X and draw it
CU_SHOW LDA CURX,X      ; column of the cursor's centre
        CLC
        ADC #4
        LSR A
        LSR A
        LSR A
        STA CURCOL,X
        LDA CURY,X
        CLC
        ADC #4
        LSR A
        LSR A
        LSR A
        STA CURROW,X
        LDY CURY,X
        LDA CURX,X
        JMP SPR_PUT
