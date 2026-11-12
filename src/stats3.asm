; =====================================================================
;  STATS3.ASM -- the stats screen's legend (T-SCR-9, D80): CT_LEGD
;  (CT_LSUM is in STATS2.ASM).  Own file so each build can put it where
;  there is room: on the 800 in the first code block after STATS.ASM
;  (the $AC00 block must end below $BC00), on the 5200 in code block 2
;  after STATS2.ASM.
; =====================================================================

; ---------------------------------------------------------------------
;  CT_LEGD -- the legend for page CT_PG (D80): per player a pawn, a
;  total in the player's colour, BEST and the best round.  SCORE: the
;  total score, the best round score; PEOPLE: the last population, the
;  biggest growth in a round (+N; +0 if it never grew); INCOME: all the
;  gold earned (65535 at most), the best round's (+N).  From CT_DRAW,
;  before CT_SCALE (it uses CT_MIN, CT_MAX, CT_V, CT_R, CT_S).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
CT_LEGD
        LDA #0          ; the line blank: totals change length
        LDX #39
CY_CLR  STA CT_LEG,X
        DEX
        BPL CY_CLR
        INX             ; X = 0: player 1
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
        JSR CT_LSUM     ; CT_V = the total, CT_MAX = the best round
        LDA CT_PG
        BNE CY_TOT      ; the score page: the total score
        LDA CT_P
        ASL A
        TAX
        LDA SCORE,X
        STA CT_V
        LDA SCORE+1,X
        STA CT_V+1
CY_TOT  LDA CT_V
        LDX CT_V+1
        JSR NUM16
        LDX CT_TX2
        JSR CT_TNUM
        INX             ; a space, then BEST
        LDY #0
CY_BST  LDA TX_BEST,Y
        STA CTTXT,X
        INX
        INY
        CPY #5
        BCC CY_BST
        LDA CT_PG       ; people and income: a gain, "+"
        BEQ CY_BNUM
        LDA #SC_PLUS
        ORA CT_TC
        STA CTTXT,X
        INX
CY_BNUM STX CT_TX2
        LDA CT_MAX
        LDX CT_MAX+1
        JSR NUM16
        LDX CT_TX2
        JSR CT_TNUM
        LDX CT_P
        INX
        JSR SB_NPL      ; CPX #2 (SANDBOX: #1, D87)
        BCC CY_PL
        RTS
