; =====================================================================
;  ECONOMY.ASM -- buying items (T-ECO-1) and the end of a round
;  (T-ECO-2 income, T-ECO-3 population, T-ECO-4 round score)
;
;  A digit key 1-9 buys that item on the square under the buying
;  player's cursor (KEYPL, D17).  Prices are the original's
;  (utopia-rules.md, PRICES at $5910).  A purchase is refused if the
;  square is not free land on the player's own island, or if the
;  player has too little gold.
;
;  Boats (8 PT, 9 fishing) appear in the player's harbour wherever
;  the cursor is, as in the original ($5924); the harbour must be
;  empty.  Key 0 picks a boat up or parks it (BOATS.ASM).
;  Not yet: 7 (a bought rebel, placed on the other island by T-ECO-5)
;  is refused for now.
;
;  COUNT holds how many of each item each player owns: COUNT+k for
;  player 1's item k, COUNT+10+k for player 2's (COUNT+0 and +10 are
;  unused).
; =====================================================================

; Refusal reasons (ECO_BUY returns them in A with C set)
R_ITEM  =  1            ; item can't be bought this way (yet)
R_LAND  =  2            ; square is not the player's own land
R_TAKEN =  3            ; something already stands there
R_GOLD  =  4            ; not enough gold

; ---------------------------------------------------------------------
;  ECO_KEY -- act on this frame's key, if any
;  Call once per frame after INPUT_POLL.  Trashes A, X, Y.
; ---------------------------------------------------------------------
ECO_KEY
        LDA KEY
        BMI EK_DONE     ; no key (or both players held fire)
        LDX KEYPL
        CMP #0          ; (KEY's flags were tested before LDX)
        BNE EK_BUY
        JMP BOAT_KEY    ; key 0: pick up / park a boat (BOATS.ASM)
EK_BUY  JMP ECO_BUY
EK_DONE RTS

; ---------------------------------------------------------------------
;  ECO_BUY -- player X buys item A at their cursor's square (a boat:
;  in their harbour)
;  In: A = item 1-9, X = player 0/1.
;  Out: C clear: bought (gold, COUNT, map and status bar updated).
;       C set: refused, A = R_ reason; the refusal sound is played.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
ECO_BUY
        STA EB_ITEM
        STX EB_P
        CMP #I_REBL
        BCC EB_LND      ; 1-6: on land
        BNE EB_BOAT     ; 8, 9: boats
        JMP EB_NOIT     ; 7: not yet
EB_BOAT TXA             ; a boat: into this player's harbour
        JSR MAP_HARB
        STX EB_C
        STY EB_R
        JSR MAP_GET
        CMP #0
        BEQ EB_PAY
        JMP EB_TAKEN    ; harbour occupied
EB_LND  LDA CURROW,X    ; the square under this player's cursor
        STA EB_R
        LDA CURCOL,X
        STA EB_C
        LDY EB_R
        TAX
        JSR MAP_GET     ; A = item there, MKIND = kind
        BCS EB_LAND     ; off the map
        CMP #0          ; (MAP_GET's flags are not A's)
        BNE EB_TAKEN    ; something stands there
        LDA MKIND
        AND #K_KIND
        CMP #K_LAND
        BNE EB_LAND
        LDA MKIND       ; owner bit 7 must match the player
        ASL A
        LDA #0
        ROL A
        CMP EB_P
        BNE EB_LAND
EB_PAY  LDA EB_P        ; X = player x 2, for GOLD
        ASL A
        TAX
        LDY EB_ITEM
        LDA GOLD,X      ; gold - price
        SEC
        SBC PRICES,Y
        STA EB_LO
        LDA GOLD+1,X
        SBC #0
        BCC EB_GOLD     ; borrow: too little gold
        STA GOLD+1,X    ; pay
        LDA EB_LO
        STA GOLD,X
        LDA EB_P        ; COUNT + player x 10 + item
        BEQ EB_CNT
        LDA #10
EB_CNT  CLC
        ADC EB_ITEM
        TAX
        INC COUNT,X
        LDY EB_R        ; put it on the map
        LDX EB_C
        LDA EB_ITEM
        CMP #I_PTBT     ; a boat of player 2's carries I_P1
        BCC EB_SET
        LDY EB_P
        BEQ EB_SETR
        ORA #I_P1
EB_SETR LDY EB_R
EB_SET  JSR MAP_SET
        JSR STAT_SHOW     ; gold, unless an info page is up
        JSR SND_BUY
        CLC
        RTS
EB_NOIT LDA #R_ITEM
        BNE EB_NO

EB_LAND LDA #R_LAND
        BNE EB_NO
EB_TAKEN LDA #R_TAKEN
        BNE EB_NO
EB_GOLD LDA #R_GOLD
EB_NO   JSR SND_REFUSE
        SEC
        RTS

; ---------------------------------------------------------------------
;  ECO_ROUND -- end of a round, as the original's $59CD: income for both
;  players, then (T-ECO-3/4) population and score.  Redraws the status
;  bar.  Trashes A, X, Y.
; ---------------------------------------------------------------------
ECO_ROUND
        LDX #0
        JSR ECO_INCOME
        LDX #1
        JSR ECO_INCOME
        LDX #0
        JSR ECO_POP
        LDX #1
        JSR ECO_POP
        LDX #0
        JSR ECO_SCORE
        LDX #1
        JSR ECO_SCORE
        LDA #0          ; earned gold starts again ($5B6C)
        LDX #3
ER_RG   STA RGOLD,X
        DEX
        BPL ER_RG
        JMP STAT_DRAW

; ---------------------------------------------------------------------
;  ECO_INIT -- start of a game: 1000 people and 100 gold each ($50F9,
;  $510D).  Trashes A, X.
; ---------------------------------------------------------------------
ECO_INIT
        LDX #2
EN_LOOP LDA #<1000
        STA POP,X
        LDA #>1000
        STA POP+1,X
        LDA #100
        STA GOLD,X
        LDA #0
        STA GOLD+1,X
        DEX
        DEX
        BPL EN_LOOP
        RTS

; ---------------------------------------------------------------------
;  ECO_POP -- player X's population for the round ($5A32-$5AAD)
;    p10       = round(pop / 10)
;    fertility = 40 + 3 x crops + 3 x hospitals + houses - 3 x schools,
;                at most 64 (and at least 0, D27)
;    mortality = 11 - 3 x hospitals, at least 2; then + factories
;    pop       = min(9999, pop + round(p10 x fertility / 100)
;                              - round(p10 x mortality / 100))
;  Rates are per 1000 people.  Trashes A, X, Y.
; ---------------------------------------------------------------------
ECO_POP
        STX EC_P
        TXA
        ASL A
        STA EC_P2       ; player x 2, for 16-bit values
        LDA EC_P        ; player x 10, for COUNT
        BEQ EP_P0
        LDA #10
EP_P0   STA EC_CI
        LDY EC_P2       ; p10 = round(pop / 10)
        LDA POP,Y
        LDX POP+1,Y
        JSR NUM16
        LDA #10
        JSR DIVNR
        LDA M_NUM
        STA EP_P10
        LDA M_NUM+1
        STA EP_P10+1

        LDY EC_CI       ; fertility
        LDA COUNT+I_CROP,Y
        CLC
        ADC COUNT+I_HOSP,Y
        LDX #3
        JSR MUL8        ; 3 x (crops + hospitals); keeps Y
        LDA M_NUM
        CLC
        ADC #40
        STA EP_POS
        LDA M_NUM+1
        ADC #0
        STA EP_POS+1
        LDA EP_POS      ; + houses
        CLC
        ADC COUNT+I_HOUS,Y
        STA EP_POS
        BCC EP_F1
        INC EP_POS+1
EP_F1   LDA COUNT+I_SCHL,Y
        LDX #3
        JSR MUL8        ; 3 x schools
        LDA EP_POS      ; fertility = EP_POS - 3 x schools
        SEC
        SBC M_NUM
        STA EP_FERT
        LDA EP_POS+1
        SBC M_NUM+1
        BCC EP_F0       ; below 0: no births (D27)
        BNE EP_F64      ; 256 or more
        LDA EP_FERT
        CMP #64+1
        BCC EP_MRT
EP_F64  LDA #64         ; at most 64 ($5A6C)
        BNE EP_FS
EP_F0   LDA #0
EP_FS   STA EP_FERT

EP_MRT  LDY EC_CI       ; mortality
        LDA COUNT+I_HOSP,Y
        LDX #3
        JSR MUL8        ; 3 x hospitals
        LDA M_NUM+1
        BNE EP_M2
        LDA M_NUM
        CMP #9+1        ; 11 - 3h < 2 when 3h > 9
        BCS EP_M2
        LDA #11
        SEC
        SBC M_NUM
        BNE EP_MS       ; always taken (11 - 3h >= 2)
EP_M2   LDA #2          ; at least 2 ($5A4F)
EP_MS   CLC             ; + 1 per factory, after the minimum
        ADC COUNT+I_FACT,Y
        BCC EP_MOK
        LDA #255
EP_MOK  STA EP_MORT

        LDA EP_P10      ; births = round(p10 x fertility / 100)
        LDX EP_P10+1
        JSR NUM16
        LDA EP_FERT
        JSR MULN
        LDA #100
        JSR DIVNR
        LDY EC_P2       ; pop + births
        CLC
        LDA POP,Y
        ADC M_NUM
        STA EP_POS
        LDA POP+1,Y
        ADC M_NUM+1
        STA EP_POS+1

        LDA EP_P10      ; deaths = round(p10 x mortality / 100)
        LDX EP_P10+1
        JSR NUM16
        LDA EP_MORT
        JSR MULN
        LDA #100
        JSR DIVNR
        LDY EC_P2
        LDA EP_POS      ; - deaths, not below 0
        SEC
        SBC M_NUM
        STA POP,Y
        LDA EP_POS+1
        SBC M_NUM+1
        STA POP+1,Y
        BCS EP_CAP
        LDA #0
        STA POP,Y
        STA POP+1,Y
        RTS
EP_CAP  CMP #>9999      ; at most 9999 ($5A97)
        BCC EP_DONE
        BNE EP_MAX
        LDA POP,Y
        CMP #<9999+1
        BCC EP_DONE
EP_MAX  LDA #<9999
        STA POP,Y
        LDA #>9999
        STA POP+1,Y
EP_DONE RTS

; ---------------------------------------------------------------------
;  ECO_INCOME -- player X's income for the round ($59CD-$5A0C)
;    earned = 4 x factories + fishing boats
;           + min(30, factories x (schools + hospitals) + hospitals)
;  "earned" goes to GOLD and RGOLD; then 10 more go to GOLD only.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
ECO_INCOME
        STX EC_P
        TXA             ; Y = player x 10, for COUNT
        BEQ EI_P0
        LDA #10
EI_P0   STA EC_CI
        TAY
        LDA COUNT+I_FACT,Y
        LDX #4
        JSR MUL8        ; 4 per factory (MUL8 keeps Y)
        LDA M_NUM       ; + 1 per fishing boat
        CLC
        ADC COUNT+I_FSBT,Y
        STA EG_AMT
        LDA M_NUM+1
        ADC #0
        STA EG_AMT+1
        LDA COUNT+I_SCHL,Y      ; productivity bonus
        CLC
        ADC COUNT+I_HOSP,Y
        TAX
        LDA COUNT+I_FACT,Y
        JSR MUL8        ; factories x (schools + hospitals)
        LDA M_NUM
        CLC
        ADC COUNT+I_HOSP,Y      ; + hospitals
        STA M_NUM
        LDA M_NUM+1
        ADC #0
        BNE EI_CAP      ; 256 or more
        LDA M_NUM
        CMP #30
        BCC EI_BON
EI_CAP  LDA #30         ; capped at 30
EI_BON  CLC
        ADC EG_AMT
        STA EG_AMT
        LDA EG_AMT+1
        ADC #0
        STA EG_AMT+1
        LDX EC_P
        JSR ECO_EARN
        LDA #10         ; flat 10, not counted as earned ($5A24)
        STA EG_AMT
        LDA #0
        STA EG_AMT+1
        LDX EC_P
        JMP ECO_GIVE

; ---------------------------------------------------------------------
;  ECO_EARN -- player X earns EG_AMT gold: added to GOLD and to RGOLD
;  (gold earned this round, used by the GDP score), like the original's
;  AWARD_GOLD ($5A0E).  RGOLD is 16 bits (D11) and stops at $FFFF.
;  ECO_GIVE -- add EG_AMT to GOLD only.
;  GOLD stops at 9999 (D26).  Trash A, Y; X kept.
; ---------------------------------------------------------------------
ECO_EARN
        TXA
        ASL A
        TAY
        CLC
        LDA RGOLD,Y
        ADC EG_AMT
        STA RGOLD,Y
        LDA RGOLD+1,Y
        ADC EG_AMT+1
        STA RGOLD+1,Y
        BCC ECO_GIVE
        LDA #$FF
        STA RGOLD,Y
        STA RGOLD+1,Y
ECO_GIVE
        TXA
        ASL A
        TAY
        CLC
        LDA GOLD,Y
        ADC EG_AMT
        STA GOLD,Y
        LDA GOLD+1,Y
        ADC EG_AMT+1
        STA GOLD+1,Y
        BCS EG_CAP
        CMP #>9999      ; over 9999 ($270F)?
        BCC EG_DONE
        BNE EG_CAP
        LDA GOLD,Y
        CMP #<9999+1
        BCC EG_DONE
EG_CAP  LDA #<9999
        STA GOLD,Y
        LDA #>9999
        STA GOLD+1,Y
EG_DONE RTS

; ---------------------------------------------------------------------
;  ECO_SCORE -- player X's round score ($5ABD-$5B5F), using the
;  population after this round's update (as the original):
;    p100     = pop / 100, truncated ($5AC6); at least 1 (D28)
;    housing  = min(30, round(round(houses x 500 / p100) / 3))
;    GDP      = min(30, round(round(earned gold x 100 / p100) / 12))
;    food     = min(30, round(round((crops + fishing boats) x 500
;                                    / p100) / 3))
;    welfare  = schools + hospitals
;    score    = min(100, sum)
;  The products are 24 bits, so the original's overflows (earned gold
;  over 255, crops + boats over 65) can't happen (D11).
;  RSCORE moves to PRSCORE, the new score goes to RSCORE and is added
;  to SCORE.  Trashes A, X, Y.
; ---------------------------------------------------------------------
ECO_SCORE
        STX EC_P
        TXA
        ASL A
        STA EC_P2
        LDA EC_P
        BEQ ES_P0
        LDA #10
ES_P0   STA EC_CI
        LDY EC_P2       ; p100 = pop / 100, truncated
        LDA POP,Y
        LDX POP+1,Y
        JSR NUM16
        LDA #100
        JSR DIVN
        LDA M_NUM
        BNE ES_PS
        LDA #1          ; under 100 people: count as 100 (D28)
ES_PS   STA ES_P100

        LDY EC_CI       ; housing: houses x 500
        LDA COUNT+I_HOUS,Y
        LDX #250
        JSR MUL8
        LDA #2
        JSR MULN
        LDA #3
        JSR ES_PART
        STA ES_SUM

        LDY EC_P2       ; GDP: earned gold x 100
        LDA RGOLD,Y
        LDX RGOLD+1,Y
        JSR NUM16
        LDA #100
        JSR MULN
        LDA #12
        JSR ES_PART
        CLC
        ADC ES_SUM
        STA ES_SUM

        LDY EC_CI       ; food: (crops + fishing boats) x 500
        LDA COUNT+I_CROP,Y
        CLC
        ADC COUNT+I_FSBT,Y
        PHA             ; low byte
        LDA #0
        ROL A           ; high byte: the carry
        TAX
        PLA
        JSR NUM16
        LDA #250
        JSR MULN
        LDA #2
        JSR MULN
        LDA #3
        JSR ES_PART
        CLC
        ADC ES_SUM
        STA ES_SUM

        LDY EC_CI       ; welfare: schools + hospitals
        LDA COUNT+I_SCHL,Y
        CLC
        ADC COUNT+I_HOSP,Y
        BCS ES_100
        CLC
        ADC ES_SUM
        BCS ES_100
        CMP #100+1
        BCC ES_TOT
ES_100  LDA #100        ; at most 100 ($5B3E)
ES_TOT  STA ES_SUM
        LDX EC_P
        LDA RSCORE,X    ; last round's score becomes the previous one
        STA PRSCORE,X
        LDA ES_SUM
        STA RSCORE,X
        LDY EC_P2       ; add to the total
        CLC
        ADC SCORE,Y
        STA SCORE,Y
        LDA SCORE+1,Y
        ADC #0
        STA SCORE+1,Y
        RTS

; ES_PART -- one score part: min(30, round(round(M_NUM / p100) / A))
ES_PART STA ES_DIV
        LDA ES_P100
        JSR DIVNR
        LDA ES_DIV
        JSR DIVNR
        LDA M_NUM+2
        ORA M_NUM+1
        BNE EP_30
        LDA M_NUM
        CMP #30+1
        BCC EP_OK
EP_30   LDA #30
EP_OK   RTS

; Prices in gold bars, by item key (the original's PRICES, $5910)
PRICES  .BYTE 0         ; 0: unused
        .BYTE 50        ; 1 fort
        .BYTE 40        ; 2 factory
        .BYTE 3         ; 3 crop
        .BYTE 35        ; 4 school
        .BYTE 75        ; 5 hospital
        .BYTE 60        ; 6 house
        .BYTE 30        ; 7 rebel (bought: on the other island)
        .BYTE 40        ; 8 PT boat
        .BYTE 25        ; 9 fishing boat
