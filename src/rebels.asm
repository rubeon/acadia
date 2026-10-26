; =====================================================================
;  REBELS.ASM -- rebels (T-ECO-5: R-RULE-3; the original's $5BB2-$5C83,
;  $594C-$5957; D38)
;
;  At the end of each round, after the score and the crop loss, each
;  player (1, then 2) may get or lose one rebel, by the change in the
;  round score (d = previous round's - this round's), in this order:
;    d >= 10            a rebel appears
;    d <= -10           one goes
;    score < 30         a rebel appears
;    score >= 70        one goes
;  A new rebel lands on a random land square of the player's island,
;  up to 251 tries: never on a rebel, a fort or a square next to a fort
;  (either player's).  Whatever stands where it lands is destroyed
;  (one fewer, "smite" sound).  If every try fails, no rebel.  The rebel
;  that goes is the first one found, row by row.
;  A rebel only takes its square: nothing can be built there.  It
;  isn't counted anywhere; weather can destroy it like any item.
;  Key 7 buys one (30 gold, cursor anywhere) for the other player's
;  island, placed the same way; the gold is spent even if it finds no
;  square (ECONOMY.ASM).
; =====================================================================

RB_DROP =  10           ; score change that adds or removes a rebel
RB_LOW  =  30           ; below: a rebel appears
RB_HIGH =  70           ; at or above: one goes
RB_TRY  =  251          ; tries to place one

; ---------------------------------------------------------------------
;  REB_ROUND -- end of a round: a rebel more or less for each player.
;  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
REB_ROUND
        LDX #0
        JSR REB_TURN
        LDX #1
        ; fall through

; REB_TURN -- player X's rebel for this round.  Trashes A, X, Y, ZPTR.
REB_TURN
        LDA PRSCORE,X   ; d = previous - this round's (0-100 each)
        SEC
        SBC RSCORE,X
        BMI RT_UP
        CMP #RB_DROP
        BCS REB_ADD     ; fell by 10 or more
        BCC RT_LVL      ; always
RT_UP   CMP #256-RB_DROP+1
        BCC REB_DEL     ; rose by 10 or more (d <= -10)
RT_LVL  LDA RSCORE,X
        CMP #RB_LOW
        BCC REB_ADD
        CMP #RB_HIGH
        BCS REB_DEL
        RTS

; ---------------------------------------------------------------------
;  REB_ADD -- a rebel on player X's island (see above).
;  Out: C clear if placed, C set if no square was found.
;  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
REB_ADD
        JSR RB_LAND     ; RB_N land squares in RBCOL / RBROW
        LDA #RB_TRY
        STA RB_T
RA_TRY  LDA RB_N
        JSR RAND_N      ; a random one of them
        TAY
        LDX RBCOL,Y
        STX RB_C
        LDA RBROW,Y
        STA RB_R
        TAY
        JSR MAP_GET
        CMP #I_REBL     ; not on a rebel or a fort
        BEQ RA_NEXT
        CMP #I_FORT
        BEQ RA_NEXT
        STA RB_I
        JSR FORT_NEAR   ; nor next to a fort
        BCC RA_PUT
RA_NEXT DEC RB_T
        BNE RA_TRY
        SEC             ; no square found
        RTS
RA_PUT  LDA RB_I        ; an item there is destroyed
        BEQ RA_SET
        LDA RB_P        ; one fewer: COUNT + player x 10 + item
        BEQ RA_P0
        LDA #10
RA_P0   CLC
        ADC RB_I
        TAX
        LDA COUNT,X
        BEQ RA_SND
        DEC COUNT,X
RA_SND  JSR SND_SMITE
RA_SET  JSR SND_REBEL
        LDA #I_REBL
        LDX RB_C
        LDY RB_R
        JSR MAP_SET
        CLC
        RTS

; ---------------------------------------------------------------------
;  REB_DEL -- the first of player X's rebels (row by row) goes.
;  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
REB_DEL
        JSR RB_LAND
        LDY #0
RD_SQ   STY RB_T
        LDX RBCOL,Y
        LDA RBROW,Y
        TAY
        JSR MAP_GET
        CMP #I_REBL
        BEQ RD_GO
        LDY RB_T
        INY
        CPY RB_N
        BCC RD_SQ
        RTS             ; none
RD_GO   LDA #0          ; the island again (X, Y kept by MAP_GET)
        JMP MAP_SET

; ---------------------------------------------------------------------
;  RB_LAND -- list player X's land squares, row by row: RB_N of them
;  in RBCOL / RBROW; RB_P = X.  Trashes A, X, Y.
; ---------------------------------------------------------------------
RB_LAND
        STX RB_P
        LDA #0          ; the owner bit of player X's squares
        CPX #0
        BEQ RL_OWN
        LDA #K_P1
RL_OWN  STA RB_K
        LDA #0
        STA RB_N
        STA RB_C
        STA RB_R
        LDX #0          ; square index, row-major
RL_SQ   LDA ISLKIND,X
        AND #K_KIND
        CMP #K_LAND
        BNE RL_NEXT
        LDA ISLKIND,X
        AND #K_P1
        CMP RB_K
        BNE RL_NEXT
        LDY RB_N
        LDA RB_C
        STA RBCOL,Y
        LDA RB_R
        STA RBROW,Y
        INC RB_N
RL_NEXT INC RB_C        ; next column / row
        LDA RB_C
        CMP #MAPSQ
        BCC RL_IDX
        LDA #0
        STA RB_C
        INC RB_R
RL_IDX  INX
        CPX #MAPSIZE
        BCC RL_SQ
        RTS
