; =====================================================================
;  STATS.ASM -- the stats screen at the end of a game (T-SCR-5, D61)
;
;  Each round, CT_REC keeps both players' round score, population and
;  income, the gold earned in the round (up to CT_MAXR rounds).  After the final scores, fire or a key
;  shows this screen: the status bar (final scores and the winner), the
;  page names, a line chart of one value over the rounds and, under it,
;  the round numbers and each player's total and best round.  The stick
;  flips the page: SCORE (each round's score, 0-100), PEOPLE, INCOME.
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
;  This part sits in the first code block; STATS2.ASM (the lines, grid,
;  round numbers and legend) after TRAIL.ASM, below $BC00.
; =====================================================================

CT_X0   =  24           ; chart: x of round 1 (mode D pixels)
CT_W    =  132          ; the last round is CT_W further right
CT_YBOT =  60             ; chart line of the lowest grid line
CT_GAP  =  11           ; lines from one grid line to the next (5 steps)
CT_LCOL =  5            ; y labels end before this byte column
CT_GCOL =  6            ; grid lines start at this byte column
CT_DOTS =  $44          ; a byte of grid line: a PF0 dot every 2 pixels
CT_COL1 =  $AA          ; a byte of 10 pixels: player 1's line
CT_COL2 =  $FF          ; a byte of 11 pixels: player 2's line
CT_NPGS =  3            ; pages: score, people, income
CT_NDLI =  6            ; DLIs in CTDLIST
CT_WLEN =  17           ; the winner's part of status line 2 (TX_W1)

                        ; CTBM0-CTBM2 (bitmap), CTTXT: MEM_A800.ASM
CT_TAB  =  CTTXT        ; the page names
CT_XL   =  CTTXT+40     ; the round numbers
CT_LEG  =  CTTXT+80     ; the legend: pawns, totals, best rounds
CT_TAB0 =  4            ; column of the first page name

; colours: the status lines keep the status bar's (STATUS.ASM); below
; them the setup screen's (D78): black, yellow text, the current page
; white, the grid dark yellow; the players' red and turquoise as before
C_CTSBK =  $00          ; background under the status lines: black
C_CTTXT =  $1C          ; text: the setup screen's yellow (C_TITLE)
C_CTBK  =  $00          ; the chart's background: black
C_CTGRD =  $16          ; grid lines and their labels: dark yellow
C_CTDIM =  $16          ; the other pages' names: dark yellow
C_CTSEL =  $0E          ; this page's name (inverse: PF3): white
C_CTXL  =  $18          ; the round numbers

; ---------------------------------------------------------------------
;  CT_REC -- at the end of a round (ROUND_END, before CURTRN counts
;  it; from ECO_ROUND, before RGOLD is cleared): keep each player's round
;  score, population and income (RGOLD: gold earned, D66).
;  Trashes A, X, Y.
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
        LDX #0          ; income: the gold each earned this round
        JSR CT_RINC
        STA HINCL,Y
        TXA
        STA HINCH,Y
        LDX #2
        JSR CT_RINC
        STA HINCL+CT_MAXR,Y
        TXA
        STA HINCH+CT_MAXR,Y
CR_DONE RTS

; CT_RINC -- A = low, X = high byte of RGOLD,X (X = player x 2), 9999
; for $2700 up, so the chart's steps (up to 2000) reach it.  Keeps Y.
CT_RINC LDA RGOLD+1,X
        CMP #$27
        BCS CI_MAX
        LDA RGOLD,X
        PHA
        LDA RGOLD+1,X
        TAX
        PLA
        RTS
CI_MAX  LDA #$0F        ; 9999
        LDX #$27
        RTS

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
;  In: X = series (0-1 score, 2-3 population, 4-5 income; even: player
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
CG_GLD  LDA HINCL,Y
        LDX HINCH,Y
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
;  Out: A = line (CT_YBOT for CT_LO, CT_YBOT - 5 x CT_GAP at the top).
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
        LDA #CT_YBOT
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
CTBK    .BYTE C_SBK1,C_SBK2,C_CTSBK,C_CTBK,C_CTSBK,C_CTSBK
CTPF0   .BYTE C_SGOLD,C_SGOLD,C_SGOLD,C_CTGRD,C_SGOLD,C_SGOLD
CTPF1   .BYTE C_SRED,C_SRED,C_SRED,C_SRED,C_SRED,C_SRED
CTPF2   .BYTE C_SWHT,C_SWHT,C_CTDIM,C_STURQ,C_CTXL,C_CTTXT
CTPF3   .BYTE C_STURQ,C_STURQ,C_CTSEL,C_STURQ,C_STURQ,C_STURQ

CTMASK  .BYTE $C0,$30,$0C,$03   ; a pixel's bits in its byte

CTPAGES .BYTE >CTBM0,>[CTBM0+$100],>[CTBM0+$200],>[CTBM0+$300] ; the
        .BYTE >CTBM1,>[CTBM1+$100],>[CTBM1+$200],>[CTBM1+$300] ; bitmap's
        .BYTE >CTBM2,>[CTBM2+$100],>[CTBM2+$200]     ; pages: CTBM0, CTBM1
                                ; and CTBM2 (14 lines)
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
TX_TABS .SBYTE "SCORE        PEOPLE        INCOME"
CT_TABL =  33
CTTABS  .BYTE 4,17,31
CTTABE  .BYTE 8,22,36

; legend: each player's pawn (STFONT icons), its column, its colour
CTPWN   .BYTE $62,$E4
CTLGC   .BYTE 1,21
CTPCOL  .BYTE TX_RED,TX_TURQ
TX_BEST .SBYTE "BEST "

; status line 2 on this screen, after the winner (TX_W1 ...)
TX_NEWG .SBYTE "FIRE OR KEY: NEW GAME  "
        .BYTE TX_END
