; =====================================================================
;  STATS2.ASM -- the stats screen, second part (T-SCR-5, D61): the
;  lines, the grid, the round numbers and the legend.  After TRAIL.ASM
;  (block 1 has no room for it); must end below $BC00 (CTBM1, D57).
; =====================================================================

; ---------------------------------------------------------------------
;  CT_LINE -- draw series CT_S in colour CT_C: straight lines from
;  round to round, filled in column by column.  Trashes A, X, Y, M_NUM.
; ---------------------------------------------------------------------
CT_LINE
        LDY #0          ; each round's line first
CQ_Y    STY CT_I
        LDX CT_S
        JSR CT_GET
        JSR CT_YOF
        LDY CT_I
        STA CTY,Y
        INY
        CPY CT_N
        BCC CQ_Y
        LDA #0          ; from round 1
        STA CT_I
        JSR CT_XOF
        STA CT_XA
        LDA CTY
        STA CT_YA
        STA CT_YC
CQ_SEG  LDX CT_N        ; to the next round
        DEX
        BNE CQ_NXT
        LDA #CT_X0+CT_W ; one round only: a flat line across
        STA CT_XB
        LDA CT_YA
        STA CT_YB
        BNE CQ_DRAW     ; (CT_YA is never 0)
CQ_NXT  INC CT_I
        JSR CT_XOF
        STA CT_XB
        LDY CT_I
        LDA CTY,Y
        STA CT_YB
CQ_DRAW LDA CT_XB       ; width and height, and which way
        SEC
        SBC CT_XA
        STA CT_DX
        LDA CT_YB
        SEC
        SBC CT_YA
        LDX #0
        BCS CQ_DY       ; down (or level)
        EOR #$FF        ; up: the height is minus that
        ADC #1
        INX
CQ_DY   STA CT_DY
        STX CT_SG
        LDA CT_XA
        STA CT_X
        LDA #1
        STA CT_KX
CQ_COL  LDA CT_DY       ; line at column CT_KX: |dy| x k / dx
        LDX CT_KX
        JSR MUL8
        LDA CT_DX
        JSR DIVN
        LDA CT_SG
        BNE CQ_UP
        LDA CT_YA
        CLC
        ADC M_NUM
        JMP CQ_YN
CQ_UP   LDA CT_YA
        SEC
        SBC M_NUM
CQ_YN   STA CT_YN
        JSR CT_SPAN     ; this column: from the last line to this one
        LDA CT_YN
        STA CT_YC
        INC CT_X
        INC CT_KX
        LDA CT_DX
        CMP CT_KX
        BCS CQ_COL      ; k up to dx
        LDA CT_XB       ; the next round from here
        STA CT_XA
        LDA CT_YB
        STA CT_YA
        LDX CT_I
        INX
        CPX CT_N
        BCS CQ_END
        JMP CQ_SEG
CQ_END  RTS

; ---------------------------------------------------------------------
;  CT_GRID -- the 6 grid lines with their values at the left.
;  Trashes A, X, Y, M_NUM, ZPTR.
; ---------------------------------------------------------------------
CT_GRID
        LDA CT_LO
        STA CT_V
        LDA CT_LO+1
        STA CT_V+1
        LDA #CT_YBOT
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
;  last (a 5th less than 12 pixels before the last is left out).  Trashes A, X, Y.
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
        LDA CT_N        ; a 5th: 12 pixels or more before the last?
        CLC             ; (N - r) x 11 >= N - 1, as CT_W = 132 = 12 x 11
        SBC CT_I        ; N - r (r = CT_I + 1)
        LDX #11
        JSR MUL8
        LDA M_NUM+1
        BNE CX_SHOW
        LDX CT_N
        DEX
        STX CT_T
        LDA M_NUM
        CMP CT_T
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
;  CT_LN2 -- (CT_ENTER) status line 2: the winner (TX_W1, TX_W2 or
;  TX_TIE, put at column 0 by the game-over screen) moved to the middle,
;  the rest blank; the hint "FIRE OR KEY: NEW GAME" on the bottom line.
;  Trashes A, Y.
; ---------------------------------------------------------------------
CT_LN2
        LDY #CT_WLEN-1  ; the winner, from the right end (they overlap)
CZ_WIN  LDA STATUS1+40,Y
        STA STATUS1+40+CT_WCOL,Y
        DEY
        BPL CZ_WIN
        LDA #0          ; blank left of it ...
        LDY #CT_WCOL-1
CZ_LFT  STA STATUS1+40,Y
        DEY
        BPL CZ_LFT
        LDY #40-CT_WCOL-CT_WLEN-1 ; ... and right of it
CZ_RGT  STA STATUS1+40+CT_WCOL+CT_WLEN,Y
        DEY
        BPL CZ_RGT
        LDY #CT_NGLN-1  ; the hint
CZ_HNT  LDA TX_NEWG,Y
        STA CT_HINT+CT_HCOL,Y
        DEY
        BPL CZ_HNT
        RTS

TX_NEWG .SBYTE "FIRE OR KEY: NEW GAME"  ; the hint (CT_NGLN characters)

; ---------------------------------------------------------------------
;  CT_LSUM -- (CT_LEGD) player CT_P's series on page CT_PG: CT_V = the
;  last value (income: the sum, 65535 at most), CT_MAX = the highest
;  value (people: the highest gain over the round before, the first
;  over the starting CT_POP0; losses count as 0).  Trashes A, X, Y.
; ---------------------------------------------------------------------
CT_LSUM
        LDA CT_PG
        ASL A
        ORA CT_P
        STA CT_S
        LDA #0
        STA CT_V
        STA CT_V+1
        STA CT_MAX
        STA CT_MAX+1
        LDA #<CT_POP0   ; people: the round before the first
        STA CT_MIN
        LDA #>CT_POP0
        STA CT_MIN+1
        LDY #0
CJ_LOOP STY CT_I
        LDX CT_S
        JSR CT_GET      ; A = low, X = high
        STA CT_R
        STX CT_R+1
        LDY CT_PG
        CPY #2
        BCC CJ_LAST
        CLC             ; income: add it up
        ADC CT_V
        STA CT_V
        TXA
        ADC CT_V+1
        STA CT_V+1
        BCC CJ_GAIN
        LDA #$FF        ; too much: 65535
        STA CT_V
        STA CT_V+1
        BNE CJ_GAIN
CJ_LAST STA CT_V        ; score, people: the last one
        STX CT_V+1
CJ_GAIN LDA CT_R
        DEY             ; Y = page - 1: people?
        BNE CJ_MAX
        SEC             ; people: the gain over the round before
        SBC CT_MIN
        PHA
        TXA
        SBC CT_MIN+1
        TAX
        LDA CT_R        ; this round is the next one's "before"
        STA CT_MIN
        LDA CT_R+1
        STA CT_MIN+1
        PLA
        BCC CJ_NEXT     ; a loss
CJ_MAX  CPX CT_MAX+1    ; A/X above the highest?
        BCC CJ_NEXT
        BNE CJ_SET
        CMP CT_MAX
        BCC CJ_NEXT
CJ_SET  STA CT_MAX
        STX CT_MAX+1
CJ_NEXT LDY CT_I
        INY
        CPY CT_N
        BCC CJ_LOOP
        RTS
