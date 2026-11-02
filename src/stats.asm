; =====================================================================
;  STATS.ASM -- the stats screen at the end of a game (T-SCR-5, D61)
;
;  Each round, CT_REC keeps both players' round score, population and
;  gold (up to CT_MAXR rounds).  After the final scores, fire or a key
;  shows this screen: the status bar (final scores and the winner), the
;  page names, a line chart of one value over the rounds and, under it,
;  the round numbers and each player's total and best round.  The stick
;  flips the page: SCORE (each round's score, 0-100), PEOPLE, GOLD.
;  Fire or a key goes on to the setup screen.
;
;  The chart is 64 lines of ANTIC mode D (160 x 2-line pixels, 4
;  colours, 40 bytes a line) in three pieces of memory that are free
;  after a game, joined by LMS: CTBM0, CTBM1 (both outside the XEX, D57)
;  and the map's screen, which GAME_START draws again.  Pixel colours:
;  01 grid and its labels, 10 player 1 (red), 11 player 2 (turquoise).
;  The text lines are mode 4 in the status font, in the help screen's
;  memory.  Its display list, CTDLIST, is in DLIST's page; a DLI per
;  zone sets the colours from the CTBK ... CTPF3 tables (ST_VBI points
;  VDSLST at CT_DLI while CT_ON is set).
;
;  Scale: the score page always runs 0-100 in steps of 20; the others
;  pick the smallest step (CTSTPL/H) whose five steps from the lowest
;  value, rounded down to a step, reach the highest.  Grid lines every
;  CT_GAP lines, labelled with 3 x 5 digits drawn into the bitmap.
;
;  Placed after TRAIL.ASM, which fills the rest of $B72C-$BBFF.
; =====================================================================

CT_X0   =  24           ; chart: x of round 1 (mode D pixels)
CT_W    =  132          ; the last round is CT_W further right
CT_YB   =  60           ; chart line of the lowest grid line
CT_GAP  =  11           ; lines from one grid line to the next (5 steps)
CT_LCOL =  5            ; y labels end before this byte column
CT_GCOL =  6            ; grid lines start at this byte column
CT_DOTS =  $44          ; a byte of grid line: a PF0 dot every 2 pixels
CT_COL1 =  $AA          ; a byte of 10 pixels: player 1's line
CT_COL2 =  $FF          ; a byte of 11 pixels: player 2's line
CT_NPGS =  3            ; pages: score, people, gold
CT_NDLI =  6            ; DLIs in CTDLIST
CT_WLEN =  17           ; the winner's part of status line 2 (TX_W1)

CTBM0   =  $9C00        ; chart lines 0-24 (not loaded, D57)
CTBM1   =  $BC00        ; lines 25-49 (not loaded, D57)
CTBM2   =  MAPSCR       ; lines 50-63 (the map, drawn again later)
CTTXT   =  HELPSCR      ; three mode 4 lines (the help screen's memory)
CT_TAB  =  CTTXT        ; the page names
CT_XL   =  CTTXT+40     ; the round numbers
CT_LEG  =  CTTXT+80     ; the legend: pawns, totals, best rounds
CT_TAB0 =  5            ; column of the first page name

; colours (status bar colours: STATUS.ASM)
C_CTBK  =  $82          ; the chart's background
C_CTGRD =  $86          ; grid lines and their labels
C_CTDIM =  $86          ; the other pages' names
C_CTSEL =  $0E          ; this page's name (inverse: PF3)
C_CTXL  =  $88          ; the round numbers

; ---------------------------------------------------------------------
;  CT_REC -- at the end of a round (ROUND_END, before CURTRN counts
;  it): keep each player's round score, population and gold.
;  Trashes A, Y.
; ---------------------------------------------------------------------
CT_REC
        LDY CURTRN
        CPY #CT_MAXR
        BCS CR_DONE     ; the setup allows no more (D31)
        LDA RSCORE
        STA HSC,Y
        LDA RSCORE+1
        STA HSC+CT_MAXR,Y
        LDA POP
        STA HPOPL,Y
        LDA POP+1
        STA HPOPH,Y
        LDA POP+2
        STA HPOPL+CT_MAXR,Y
        LDA POP+3
        STA HPOPH+CT_MAXR,Y
        LDA GOLD
        STA HGLDL,Y
        LDA GOLD+1
        STA HGLDH,Y
        LDA GOLD+2
        STA HGLDL+CT_MAXR,Y
        LDA GOLD+3
        STA HGLDH+CT_MAXR,Y
CR_DONE RTS

; ---------------------------------------------------------------------
;  CT_ENTER -- show the stats screen (OVER_FRAME).  Trashes A, X, Y.
; ---------------------------------------------------------------------
CT_ENTER
        JSR PM_HIDE     ; no cursors or boats
        LDA #0
        STA CT_PG       ; the score page first
        STA CT_ARM
        LDX #119        ; blank text lines
CE_TXT  STA CTTXT,X
        DEX
        BPL CE_TXT
        LDA CURTRN      ; rounds recorded
        CMP #CT_MAXR
        BCC CE_N
        LDA #CT_MAXR
CE_N    STA CT_N
        LDX #40+CT_WLEN ; line 2: the winner, then the new prompt
        LDA #<TX_NEWG
        LDY #>TX_NEWG
        JSR TXT_STR
        JSR CT_XLAB
        JSR CT_LEGD
        JSR CT_CLR      ; no old map in the chart's first frame
        LDA JOY0        ; a stick still held flips nothing
        ORA JOY1
        STA CT_J
        LDA #1          ; the stats DLIs from the next frame (ST_VBI)
        STA CT_ON
        LDA #<CTDLIST
        STA SDLSTL
        LDA #>CTDLIST
        STA SDLSTH
        ; fall through: draw the page

; ---------------------------------------------------------------------
;  CT_DRAW -- draw page CT_PG: its name lit, the grid, both lines.
;  Takes a few frames.  Trashes A, X, Y.
; ---------------------------------------------------------------------
CT_DRAW
        JSR CT_TABS
        JSR CT_CLR
        JSR CT_SCALE
        JSR CT_GRID
        LDA CT_PG       ; series: 2 per page, player 1's first
        ASL A
        ORA #1
        STA CT_S        ; player 2 first, so player 1 is on top
        LDA #CT_COL2
        STA CT_C
        JSR CT_LINE
        DEC CT_S
        LDA #CT_COL1
        STA CT_C
        JMP CT_LINE

; ---------------------------------------------------------------------
;  CT_FRAME -- each frame of the stats screen (OVER_FRAME while CT_ON):
;  the stick left / right flips the page; once everything is let go,
;  fire or a key goes on to the setup screen.  Trashes A, X, Y.
; ---------------------------------------------------------------------
CT_FRAME
        LDA JOY0
        ORA JOY1
        AND #J_LEFT+J_RIGHT
        TAY
        EOR CT_J        ; changed since the last frame
        STY CT_J
        AND CT_J        ; and pushed now
        BEQ CF_KEYS
        LDX CT_PG
        AND #J_RIGHT
        BEQ CF_LEFT
        INX             ; right: the next page, round to the first
        CPX #CT_NPGS
        BCC CF_GO
        LDX #0
        BEQ CF_GO
CF_LEFT DEX             ; left: the page before, round to the last
        BPL CF_GO
        LDX #CT_NPGS-1
CF_GO   STX CT_PG
        JMP CT_DRAW
CF_KEYS LDA FIRE0
        ORA FIRE1
        ORA KEYDOWN
        LDX CT_ARM
        BNE CF_ARMD
        CMP #0
        BNE CF_DONE     ; still held from the game-over screen
        INC CT_ARM
CF_DONE RTS
CF_ARMD CMP #0
        BEQ CF_DONE
        LDA #0          ; the status bar's DLIs again
        STA CT_ON
        LDA #>DLIST     ; setup switches by the low byte only
        STA SDLSTH
        JMP SETUP_ENTER ; back to the setup screen (R-MODE-4)

; ---------------------------------------------------------------------
;  CT_TABS -- the page names, this page's lit.  Trashes A, X, Y, CT_T.
; ---------------------------------------------------------------------
CT_TABS
        LDX #CT_TABL-1
CB_COPY LDA TX_TABS,X
        STA CT_TAB+CT_TAB0,X
        DEX
        BPL CB_COPY
        LDX CT_PG
        LDA CTTABS,X    ; its first column
        STA CT_T
        LDY CTTABE,X    ; its last
CB_INV  LDA CT_TAB,Y
        ORA #$80        ; inverse: PF3, bright
        STA CT_TAB,Y
        DEY
        CPY CT_T
        BCS CB_INV
        RTS

; ---------------------------------------------------------------------
;  CT_CLR -- clear the chart's bitmap.  Trashes A, Y, ZPTR, CT_T.
; ---------------------------------------------------------------------
CT_CLR
        LDY #CT_NBMP-1
CC_PAGE LDA CTPAGES,Y
        STA ZPTR+1
        STY CT_T
        LDA #0
        STA ZPTR
        TAY
CC_BYTE STA (ZPTR),Y
        INY
        BNE CC_BYTE
        LDY CT_T
        DEY
        BPL CC_PAGE
        RTS

; ---------------------------------------------------------------------
;  CT_SCALE -- the chart's scale for page CT_PG: CT_LO, the value of
;  the lowest grid line, and CT_D, the step from one to the next.
;  Trashes A, X, Y, M_NUM, CT_S.
; ---------------------------------------------------------------------
CT_SCALE
        LDA CT_PG
        BNE CS_FIND
        STA CT_LO       ; scores: 0-100 in steps of 20
        STA CT_LO+1
        STA CT_D+1
        LDA #20
        STA CT_D
        RTS
CS_FIND LDA #$FF        ; the lowest and highest values on the page
        STA CT_MIN
        STA CT_MIN+1
        LDA #0
        STA CT_MAX
        STA CT_MAX+1
        LDA CT_PG
        ASL A
        STA CT_S
        JSR CT_MM       ; player 1
        INC CT_S
        JSR CT_MM       ; player 2
        LDX #0
CS_STEP STX CT_SI       ; try each step, smallest first
        LDA CTSTPL,X
        STA CT_D
        LDA CTSTPH,X
        STA CT_D+1
        LDA CT_MIN      ; lowest line: the lowest value rounded down
        LDX CT_MIN+1
        JSR NUM16
        JSR CT_DIV
        LDA CT_MIN
        SEC
        SBC CT_R
        STA CT_LO
        LDA CT_MIN+1
        SBC CT_R+1
        STA CT_LO+1
        LDA CT_D        ; 5 steps up from there
        LDX CT_D+1
        JSR NUM16
        LDA #5
        JSR MULN
        LDA CT_MAX      ; reach the highest value?
        SEC
        SBC CT_LO
        TAY
        LDA CT_MAX+1
        SBC CT_LO+1     ; A:Y = highest - lowest line
        CMP M_NUM+1
        BCC CS_OK
        BNE CS_NEXT
        CPY M_NUM
        BCC CS_OK
        BEQ CS_OK
CS_NEXT LDX CT_SI
        INX
        CPX #CT_NSTP
        BCC CS_STEP
CS_OK   RTS

; CT_MM -- CT_MIN / CT_MAX take in series CT_S.  Trashes A, X, Y, CT_T.
CT_MM
        LDY #0
CM_LOOP STY CT_I
        LDX CT_S
        JSR CT_GET      ; A = low, X = high
        STA CT_T
        CPX CT_MAX+1
        BCC CM_MIN
        BNE CM_SMAX
        CMP CT_MAX
        BCC CM_MIN
CM_SMAX STA CT_MAX
        STX CT_MAX+1
CM_MIN  LDA CT_T
        CPX CT_MIN+1
        BCC CM_SMIN
        BNE CM_NEXT
        CMP CT_MIN
        BCS CM_NEXT
CM_SMIN STA CT_MIN
        STX CT_MIN+1
CM_NEXT LDY CT_I
        INY
        CPY CT_N
        BCC CM_LOOP
        RTS

; ---------------------------------------------------------------------
;  CT_GET -- a recorded value
;  In: X = series (0-1 score, 2-3 population, 4-5 gold; even: player
;      1), Y = round (0 up).  Out: A = low byte, X = high byte.
;  Trashes Y.
; ---------------------------------------------------------------------
CT_GET
        TXA
        LSR A           ; A = page, C = player 2
        TAX
        TYA
        BCC CG_P1
        ADC #CT_MAXR-1  ; player 2's half (C is set: + CT_MAXR)
CG_P1   TAY
        CPX #1
        BEQ CG_POP
        BCS CG_GLD
        LDA HSC,Y
        LDX #0
        RTS
CG_POP  LDA HPOPL,Y
        LDX HPOPH,Y
        RTS
CG_GLD  LDA HGLDL,Y
        LDX HGLDH,Y
        RTS

; ---------------------------------------------------------------------
;  CT_DIV -- 24 / 16 bit divide, truncating
;  In: M_NUM = dividend, CT_D = divisor (1-$7FFF).
;  Out: M_NUM = quotient, CT_R = remainder.  Trashes A, X, Y.
; ---------------------------------------------------------------------
CT_DIV
        LDA #0
        STA CT_R
        STA CT_R+1
        LDX #24
CD_LOOP ASL M_NUM       ; the next dividend bit into the remainder
        ROL M_NUM+1
        ROL M_NUM+2
        ROL CT_R
        ROL CT_R+1
        LDA CT_R        ; remainder - divisor
        SEC
        SBC CT_D
        TAY
        LDA CT_R+1
        SBC CT_D+1
        BCC CD_NEXT     ; doesn't go
        STA CT_R+1
        STY CT_R
        INC M_NUM       ; quotient bit = 1
CD_NEXT DEX
        BNE CD_LOOP
        RTS

; ---------------------------------------------------------------------
;  CT_YOF -- the chart line of a value
;  In: A = low byte, X = high byte (CT_LO up to CT_LO + 5 x CT_D).
;  Out: A = line (CT_YB for CT_LO, CT_YB - 5 x CT_GAP at the top).
;  Trashes X, Y, M_NUM.
; ---------------------------------------------------------------------
CT_YOF
        SEC
        SBC CT_LO
        STA M_NUM
        TXA
        SBC CT_LO+1
        STA M_NUM+1
        LDA #0
        STA M_NUM+2
        LDA #CT_GAP     ; (value - lowest line) x CT_GAP / step
        JSR MULN
        JSR CT_DIV
        LDA #CT_YB
        SEC
        SBC M_NUM
        RTS

; ---------------------------------------------------------------------
;  CT_XOF -- A = x of round CT_I (0 up) of CT_N.  Trashes X, M_NUM, CT_T.
; ---------------------------------------------------------------------
CT_XOF
        LDA #0
        LDX CT_N
        DEX
        BEQ CX_ADD      ; one round: at the left
        STX CT_T
        LDA CT_I        ; CT_I x CT_W / (CT_N - 1)
        LDX #CT_W
        JSR MUL8
        LDA CT_T
        JSR DIVN
        LDA M_NUM
CX_ADD  CLC
        ADC #CT_X0
        RTS

; ---------------------------------------------------------------------
;  CT_ROW -- ZPTR = address of chart line A (0-63).  Trashes A, X, CT_T.
; ---------------------------------------------------------------------
CT_ROW
        LDX #>CTBM0     ; three blocks of 25, 25 and 14 lines, each on
        CMP #25         ; a page boundary
        BCC CW_BASE
        LDX #>CTBM1
        SBC #25         ; C is set
        CMP #25
        BCC CW_BASE
        LDX #>CTBM2
        SBC #25
CW_BASE STX ZPTR+1
        ASL A           ; line x 8 (at most 192)
        ASL A
        ASL A
        STA ZPTR
        LDX #0
        STX CT_T
        ASL A           ; line x 32, high byte in CT_T
        ROL CT_T
        ASL A
        ROL CT_T
        CLC             ; x 40 = x 32 + x 8
        ADC ZPTR
        STA ZPTR
        LDA CT_T
        ADC ZPTR+1
        STA ZPTR+1
        RTS

; ---------------------------------------------------------------------
;  CT_PLOT -- set pixel CT_X of line A to colour CT_C (a byte of it).
;  Trashes A, X, Y, ZPTR, CT_T.
; ---------------------------------------------------------------------
CT_PLOT
        JSR CT_ROW
        LDA CT_X
        LSR A           ; 4 pixels a byte
        LSR A
        TAY
        LDA CT_X
        AND #3
        TAX
        LDA CTMASK,X
        AND CT_C        ; the colour's bits for this pixel
        STA CT_T
        LDA CTMASK,X
        EOR #$FF
        AND (ZPTR),Y
        ORA CT_T
        STA (ZPTR),Y
        RTS

; ---------------------------------------------------------------------
;  CT_SPAN -- pixels CT_X and CT_X+1 of each line from CT_YC to CT_YN
;  (either way round).  Trashes A, X, Y, ZPTR, CT_T, CT_YS.
; ---------------------------------------------------------------------
CT_SPAN
        LDA CT_YC       ; from the higher of the two (smaller line)
        CMP CT_YN
        BCC CN_TOP
        LDA CT_YN
CN_TOP  STA CT_YS
CN_LOOP LDA CT_YS
        JSR CT_PLOT
        INC CT_X        ; two pixels wide
        LDA CT_YS
        JSR CT_PLOT
        DEC CT_X
        LDA CT_YS       ; to the lower of the two
        CMP CT_YC
        BCC CN_MORE
        CMP CT_YN
        BCS CN_DONE
CN_MORE INC CT_YS
        BNE CN_LOOP
CN_DONE RTS

; ---------------------------------------------------------------------
;  CT_LINE -- draw series CT_S in colour CT_C: straight lines from
;  round to round, filled in column by column.  Trashes A, X, Y, M_NUM.
; ---------------------------------------------------------------------
CT_LINE
        LDY #0          ; each round's line first
CL_Y    STY CT_I
        LDX CT_S
        JSR CT_GET
        JSR CT_YOF
        LDY CT_I
        STA CTY,Y
        INY
        CPY CT_N
        BCC CL_Y
        LDA #0          ; from round 1
        STA CT_I
        JSR CT_XOF
        STA CT_XA
        LDA CTY
        STA CT_YA
        STA CT_YC
CL_SEG  LDX CT_N        ; to the next round
        DEX
        BNE CL_NXT
        LDA #CT_X0+CT_W ; one round only: a flat line across
        STA CT_XB
        LDA CT_YA
        STA CT_YB
        BNE CL_DRAW     ; (CT_YA is never 0)
CL_NXT  INC CT_I
        JSR CT_XOF
        STA CT_XB
        LDY CT_I
        LDA CTY,Y
        STA CT_YB
CL_DRAW LDA CT_XB       ; width and height, and which way
        SEC
        SBC CT_XA
        STA CT_DX
        LDA CT_YB
        SEC
        SBC CT_YA
        LDX #0
        BCS CL_DY       ; down (or level)
        EOR #$FF        ; up: the height is minus that
        ADC #1
        INX
CL_DY   STA CT_DY
        STX CT_SG
        LDA CT_XA
        STA CT_X
        LDA #1
        STA CT_KX
CL_COL  LDA CT_DY       ; line at column CT_KX: |dy| x k / dx
        LDX CT_KX
        JSR MUL8
        LDA CT_DX
        JSR DIVN
        LDA CT_SG
        BNE CL_UP
        LDA CT_YA
        CLC
        ADC M_NUM
        JMP CL_YN
CL_UP   LDA CT_YA
        SEC
        SBC M_NUM
CL_YN   STA CT_YN
        JSR CT_SPAN     ; this column: from the last line to this one
        LDA CT_YN
        STA CT_YC
        INC CT_X
        INC CT_KX
        LDA CT_DX
        CMP CT_KX
        BCS CL_COL      ; k up to dx
        LDA CT_XB       ; the next round from here
        STA CT_XA
        LDA CT_YB
        STA CT_YA
        LDX CT_I
        INX
        CPX CT_N
        BCS CL_END
        JMP CL_SEG
CL_END  RTS

; ---------------------------------------------------------------------
;  CT_GRID -- the 6 grid lines with their values at the left.
;  Trashes A, X, Y, M_NUM, ZPTR.
; ---------------------------------------------------------------------
CT_GRID
        LDA CT_LO
        STA CT_V
        LDA CT_LO+1
        STA CT_V+1
        LDA #CT_YB
        STA CT_Y
CG_LINE LDA CT_Y        ; a dotted line
        JSR CT_ROW
        LDA #CT_DOTS
        LDY #CT_GCOL
CG_DOT  STA (ZPTR),Y
        INY
        CPY #40
        BCC CG_DOT
        LDA CT_V        ; its value, right-aligned before CT_LCOL
        LDX CT_V+1
        JSR NUM16
        JSR CT_DIGS
        LDA #CT_LCOL
        SEC
        SBC CT_K
        STA CT_COL
        LDX #0
CG_DIG  STX CT_JD       ; each digit: 5 lines from 2 above the grid line
        LDA CTDB,X
        ASL A
        ASL A
        ADC CTDB,X      ; x 5 (C clear)
        STA CT_G
        LDA CT_Y
        SEC
        SBC #2
        STA CT_RW
        LDA #5
        STA CT_RC
CG_ROWS LDA CT_RW
        JSR CT_ROW
        LDX CT_G
        LDA CTGLY,X
        LDY CT_COL
        STA (ZPTR),Y
        INC CT_G
        INC CT_RW
        DEC CT_RC
        BNE CG_ROWS
        INC CT_COL
        LDX CT_JD
        INX
        CPX CT_K
        BCC CG_DIG
        LDA CT_V        ; the next line up: a step more
        CLC
        ADC CT_D
        STA CT_V
        LDA CT_V+1
        ADC CT_D+1
        STA CT_V+1
        LDA CT_Y
        SEC
        SBC #CT_GAP
        STA CT_Y
        BCC CG_END      ; past the top one
        JMP CG_LINE
CG_END  RTS

; ---------------------------------------------------------------------
;  CT_DIGS -- the decimal digits of M_NUM into CTDB, the first first;
;  CT_K = how many.  Trashes A, X, Y, M_NUM.
; ---------------------------------------------------------------------
CT_DIGS
        LDY #0
CD_DIG  LDA #10
        JSR DIVN        ; A = the last digit
        PHA
        INY
        LDA M_NUM
        ORA M_NUM+1
        ORA M_NUM+2
        BNE CD_DIG
        STY CT_K
        LDX #0
CD_POP  PLA
        STA CTDB,X
        INX
        DEY
        BNE CD_POP
        RTS

; ---------------------------------------------------------------------
;  CT_TNUM -- print M_NUM on the text lines (CTTXT + X), digits ORed
;  with CT_TC.  Out: X = offset after it.  Trashes A, Y, M_NUM.
; ---------------------------------------------------------------------
CT_TNUM
        STX CT_TX
        JSR CT_DIGS
        LDX CT_TX
        LDY #0
CT_TDIG LDA CTDB,Y
        ORA #SC_0
        ORA CT_TC
        STA CTTXT,X
        INX
        INY
        CPY CT_K
        BCC CT_TDIG
        RTS

; ---------------------------------------------------------------------
;  CT_XLAB -- the round numbers under the chart: 1, every 5th and the
;  last (a 5th close before the last is left out).  Trashes A, X, Y.
; ---------------------------------------------------------------------
CT_XLAB
        LDA #0
        STA CT_TC
        STA CT_I
        LDA #1
        STA CT_M5       ; round number mod 5, 1-5
CX_LOOP LDA CT_I
        BEQ CX_SHOW     ; round 1
        LDX CT_I
        INX
        CPX CT_N
        BEQ CX_SHOW     ; the last round
        LDA CT_M5
        CMP #5
        BNE CX_NEXT
        LDA CT_N        ; a 5th: 3 or more before the last?
        SEC
        SBC CT_I
        CMP #4
        BCC CX_NEXT
CX_SHOW JSR CT_XOF      ; centred under its x
        LDX CT_I
        CPX #9
        BCC CX_ONE
        SBC #2          ; two digits (C set)
CX_ONE  LSR A
        LSR A
        CLC
        ADC #CT_XL-CTTXT
        STA CT_TX2
        LDA CT_I
        CLC
        ADC #1
        LDX #0
        JSR NUM16
        LDX CT_TX2
        JSR CT_TNUM
CX_NEXT INC CT_M5
        LDA CT_M5
        CMP #6
        BCC CX_M5
        LDA #1
        STA CT_M5
CX_M5   INC CT_I
        LDA CT_I
        CMP CT_N
        BCC CX_LOOP
        RTS

; ---------------------------------------------------------------------
;  CT_LEGD -- the legend: per player a pawn, the total score in the
;  player's colour, BEST and the best round score.  Trashes A, X, Y.
; ---------------------------------------------------------------------
CT_LEGD
        LDX #0
CY_PL   STX CT_P
        LDY CTLGC,X     ; the pawn, 2 characters
        LDA CTPWN,X
        STA CT_LEG,Y
        CLC
        ADC #1
        STA CT_LEG+1,Y
        TYA
        CLC
        ADC #CT_LEG-CTTXT+3
        STA CT_TX2
        LDA CTPCOL,X
        STA CT_TC
        TXA             ; the total score
        ASL A
        TAX
        LDA SCORE,X
        PHA
        LDA SCORE+1,X
        TAX
        PLA
        JSR NUM16
        LDX CT_TX2
        JSR CT_TNUM
        INX             ; a space, then BEST in white
        LDY #0
CY_BST  LDA TX_BEST,Y
        STA CTTXT,X
        INX
        INY
        CPY #5
        BCC CY_BST
        STX CT_TX2
        LDA #0          ; the best round score
        STA CT_T
        LDY CT_P
        BEQ CY_B0
        LDY #CT_MAXR
CY_B0   LDX CT_N
CY_MAX  LDA HSC,Y
        CMP CT_T
        BCC CY_LOW
        STA CT_T
CY_LOW  INY
        DEX
        BNE CY_MAX
        LDA CT_T
        LDX #0
        JSR NUM16
        LDX CT_TX2
        JSR CT_TNUM
        LDX CT_P
        INX
        CPX #2
        BCS CY_END
        JMP CY_PL
CY_END  RTS

; ---------------------------------------------------------------------
;  CT_DLI -- the colours of the next zone of the stats screen, from
;  the tables at CT_DI (ST_VBI sets it to 0), attract mode applied.
;  Keeps all registers.
; ---------------------------------------------------------------------
CT_DLI
        PHA
        TXA
        PHA
        TYA
        PHA
        LDX CT_DI
        CPX #CT_NDLI
        BCS CI_OUT      ; not this screen's display list (yet)
        LDA CTPF0,X
        EOR COLRSH
        AND DRKMSK
        TAY
        LDA CTBK,X
        EOR COLRSH
        AND DRKMSK
        STA WSYNC
        STA COLBK
        STY COLPF0
        LDA CTPF1,X
        EOR COLRSH
        AND DRKMSK
        STA COLPF1
        LDA CTPF2,X
        EOR COLRSH
        AND DRKMSK
        STA COLPF2
        LDA CTPF3,X
        EOR COLRSH
        AND DRKMSK
        STA COLPF3
        INC CT_DI
CI_OUT  PLA
        TAY
        PLA
        TAX
        PLA
        RTI

; ---------------------------------------------------------------------
;  Tables
; ---------------------------------------------------------------------
; per DLI: status line 1, line 2, page names, chart, round numbers, legend
CTBK    .BYTE C_SBK1,C_SBK2,C_SBK2,C_CTBK,C_SBK2,C_SBK2
CTPF0   .BYTE C_SGOLD,C_SGOLD,C_SGOLD,C_CTGRD,C_SGOLD,C_SGOLD
CTPF1   .BYTE C_SRED,C_SRED,C_SRED,C_SRED,C_SRED,C_SRED
CTPF2   .BYTE C_SWHT,C_SWHT,C_CTDIM,C_STURQ,C_CTXL,C_SWHT
CTPF3   .BYTE C_STURQ,C_STURQ,C_CTSEL,C_STURQ,C_STURQ,C_STURQ

CTMASK  .BYTE $C0,$30,$0C,$03   ; a pixel's bits in its byte

CTPAGES .BYTE $9C,$9D,$9E,$9F   ; the bitmap's pages: CTBM0,
        .BYTE $BC,$BD,$BE,$BF   ; CTBM1 and CTBM2 (14 lines)
        .BYTE $34,$35,$36
CT_NBMP =  11

; the steps a grid can have, smallest first
CTSTPL  .BYTE 1,2,5,10,20,50,100,200,$F4,$E8,$D0   ; ... 500, 1000, 2000
CTSTPH  .BYTE 0,0,0,0,0,0,0,0,$01,$03,$07
CT_NSTP =  11

; 3 x 5 digits for the grid labels, in colour 01 (4 pixels a byte)
CTGLY   .BYTE $54,$44,$44,$44,$54   ; 0
        .BYTE $10,$50,$10,$10,$54   ; 1
        .BYTE $50,$04,$10,$40,$54   ; 2
        .BYTE $50,$04,$10,$04,$50   ; 3
        .BYTE $44,$44,$54,$04,$04   ; 4
        .BYTE $54,$40,$50,$04,$50   ; 5
        .BYTE $14,$40,$54,$44,$54   ; 6
        .BYTE $54,$04,$10,$10,$10   ; 7
        .BYTE $54,$44,$54,$44,$54   ; 8
        .BYTE $54,$44,$54,$04,$50   ; 9

; page names, from column CT_TAB0; each page's first and last column
TX_TABS .SBYTE "SCORE        PEOPLE        GOLD"
CT_TABL =  31
CTTABS  .BYTE 5,18,32
CTTABE  .BYTE 9,23,35

; legend: each player's pawn (STFONT icons), its column, its colour
CTPWN   .BYTE $62,$E4
CTLGC   .BYTE 1,21
CTPCOL  .BYTE TX_RED,TX_TURQ
TX_BEST .SBYTE "BEST "

; status line 2 on this screen, after the winner (TX_W1 ...)
TX_NEWG .SBYTE "FIRE OR KEY: NEW GAME  "
        .BYTE TX_END
