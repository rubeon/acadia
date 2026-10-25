; =====================================================================
;  ECONOMY.ASM -- buying items (T-ECO-1); income and scoring follow
;
;  A digit key 1-9 buys that item on the square under the buying
;  player's cursor (KEYPL, D17).  Prices are the original's
;  (utopia-rules.md, PRICES at $5910).  A purchase is refused if the
;  square is not free land on the player's own island, or if the
;  player has too little gold.
;
;  Not yet: 7 (a bought rebel, placed on the other island by T-ECO-5)
;  and 8/9 (boats, launched from the harbour by T-EVT-1) are refused
;  for now.  Key 0 (cursor/boat mode) is ignored until T-EVT-1.
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
        BEQ EK_DONE     ; key 0: cursor/boat mode, later (T-EVT-1)
        LDX KEYPL
        JMP ECO_BUY
EK_DONE RTS

; ---------------------------------------------------------------------
;  ECO_BUY -- player X buys item A at their cursor's square
;  In: A = item 1-9, X = player 0/1.
;  Out: C clear: bought (gold, COUNT, map and status bar updated).
;       C set: refused, A = R_ reason; the refusal sound is played.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
ECO_BUY
        STA EB_ITEM
        STX EB_P
        CMP #I_REBL     ; 7-9: not yet
        BCS EB_NOIT
        LDY CURROW,X    ; the square under this player's cursor
        LDA CURCOL,X
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
        LDA EB_P        ; X = player x 2, for GOLD
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
        LDA EB_P        ; put it on the map
        TAX
        LDY CURROW,X
        LDA CURCOL,X
        TAX
        LDA EB_ITEM
        JSR MAP_SET
        JSR STAT_DRAW
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
