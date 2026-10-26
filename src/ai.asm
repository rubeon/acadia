; =====================================================================
;  AI.ASM -- the CPU governor of 1-player games (T-AI-1, T-AI-3:
;  R-AI-1, -2, -4, -5; D39)
;
;  In a 1-player game the CPU plays player 2 (the right island) by the
;  same rules as a person: it steers player 2's cursor with a virtual
;  stick (JOY1) and buys on the square under it with ECO_BUY, which
;  checks the land and the gold as for anyone.  Boats and bought
;  rebels need no cursor, as for a person.  Digit keys then always
;  belong to player 1.
;
;  Every AI_RATE tics (by level) it thinks, unless it is still on its
;  way to a square:
;    - the plan (AIPLAN, AI_PICK): enough crops for full food points,
;      a factory, enough houses for full housing points (crops and
;      houses: p100 / 6 + 1 at its population), a school, factories,
;      hospital, fort, fishing boat, then more of each.  The first
;      item short of its number is the one; if it can't pay for it,
;      it saves up (it doesn't skip to something cheaper).  The order
;      was tuned in simulated games (tests/test_ai.py);
;    - where (AI_SPOT): a fort on the free square with the most of its
;      buildings around it; anything else on a free square next to a
;      fort if there is one (rebels never land there), else any.
;  Levels: 1 thinks every 3 s and 1 time in 3 buys a random building
;  instead; 2 thinks every 2 s; 3 thinks every second, keeps one crop
;  and one house ahead, and with the plan done and 150 gold or more
;  sends a rebel to player 1's island.
; =====================================================================

AI_P    =  1            ; the CPU's player
AI_REB  =  150          ; level 3: gold that sends a rebel
AI_RNDL =  3            ; level 1: 1 in 3 decisions is random

; ---------------------------------------------------------------------
;  AI_INIT -- start of a game: nothing under way.  Trashes A.
; ---------------------------------------------------------------------
AI_INIT
        LDA #0
        STA AIST
        LDA #1          ; think on the first tic
        STA AITMR
        RTS

; ---------------------------------------------------------------------
;  AI_ON -- Z clear (A = 1) in a 1-player game.  Trashes A.
; ---------------------------------------------------------------------
AI_ON   LDA SU_VAL+SU_FPLY
        CMP #1
        BEQ AO_YES
        LDA #0
        RTS
AO_YES  LDA #1
        RTS

; ---------------------------------------------------------------------
;  AI_FRAME -- each frame of a round, before CUR_MOVE: in a 1-player
;  game the keys go to player 1 and JOY1 is the CPU's stick; it buys
;  when its cursor is on the square.  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
AI_FRAME
        JSR AI_ON
        BEQ AF_DONE
        LDA KEY         ; a key is always player 1's
        BMI AF_KEY
        LDA #0
        STA KEYPL
AF_KEY  LDA #0
        STA JOY1
        STA FIRE1
        LDA AIST
        BEQ AF_DONE     ; not going anywhere
        LDX #AI_P
        LDA CURCOL,X    ; stick towards the square
        CMP AI_C
        BEQ AF_V
        LDA #J_RIGHT
        BCC AF_H
        LDA #J_LEFT
AF_H    STA JOY1
AF_V    LDA CURROW,X
        CMP AI_R
        BEQ AF_AT
        LDA #J_DOWN
        BCC AF_VS
        LDA #J_UP
AF_VS   ORA JOY1
        STA JOY1
        RTS
AF_AT   LDA JOY1        ; there, and the cursor has settled on it?
        BNE AF_DONE
        LDA CURX,X
        ORA CURY,X
        AND #7
        BNE AF_DONE
        LDA #0          ; buy (refused if it can't pay or the square
        STA AIST        ; was taken meanwhile)
        LDA AI_IT
        JMP ECO_BUY
AF_DONE RTS

; ---------------------------------------------------------------------
;  AI_TIC -- each tic of a round: think every AI_RATE tics.
;  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
AI_TIC
        JSR AI_ON
        BEQ AT_DONE
        DEC AITMR
        BNE AT_DONE
        LDX SU_VAL+SU_FLVL
        LDA AI_RATE-1,X
        STA AITMR
        LDA AIST
        BNE AT_DONE     ; still on its way
        JSR AI_PICK     ; what
        BEQ AT_DONE
        STA AI_IT
        TAY             ; can it pay?  else save up
        LDA GOLD+2*AI_P+1
        BNE AT_PAY
        LDA GOLD+2*AI_P
        CMP PRICES,Y
        BCC AT_DONE
AT_PAY  LDA AI_IT
        CMP #I_REBL
        BCC AT_LAND
        LDX #AI_P       ; a boat or a rebel: no square needed
        JMP ECO_BUY
AT_LAND JSR AI_SPOT     ; where
        BCS AT_DONE     ; no free land
        LDA #1
        STA AIST
AT_DONE RTS

; Tics between decisions, levels 1-3
AI_RATE .BYTE 60,40,20

; ---------------------------------------------------------------------
;  AI_PICK -- the item to buy next (see above), or A = 0 (Z set) to
;  wait.  Trashes A, X, Y.
; ---------------------------------------------------------------------
AI_PICK
        LDA SU_VAL+SU_FLVL
        CMP #1
        BNE AK_PLAN
        LDA #AI_RNDL    ; level 1: sometimes anything (1-6)
        JSR RAND_N
        BNE AK_PLAN
        LDA #I_HOUS
        JSR RAND_N
        CLC
        ADC #1
        RTS
AK_PLAN LDA POP+2*AI_P  ; need = p100 / 6 + 1 (+ 1 at level 3)
        LDX POP+2*AI_P+1
        JSR NUM16
        LDA #100
        JSR DIVN
        LDA M_NUM
        LDX #0
AK_DIV6 CMP #6
        BCC AK_N
        SBC #6
        INX
        BNE AK_DIV6     ; always
AK_N    INX
        LDA SU_VAL+SU_FLVL
        CMP #3
        BNE AK_N2
        INX
AK_N2   STX AI_N
        LDY #0          ; the plan: first item short of its number
AK_ITEM LDX AIPLAN,Y
        BEQ AK_DONE     ; all there
        LDA COUNT+10*AI_P,X
        CPX #I_CROP
        BNE AK_HAVE
        CLC             ; food: crops + fishing boats
        ADC COUNT+10*AI_P+I_FSBT
AK_HAVE STA AI_V
        LDA AIPLAN+1,Y  ; how many: 0 means AI_N
        BNE AK_CMP
        LDA AI_N
AK_CMP  CMP AI_V
        BEQ AK_SKIP
        BCS AK_GOT      ; wanted > have
AK_SKIP INY
        INY
        BNE AK_ITEM     ; always
AK_GOT  TXA
        RTS
AK_DONE LDA SU_VAL+SU_FLVL      ; level 3: spare gold sends a rebel
        CMP #3
        BNE AK_NONE
        LDA GOLD+2*AI_P+1
        BNE AK_REB
        LDA GOLD+2*AI_P
        CMP #AI_REB
        BCC AK_NONE
AK_REB  LDA #I_REBL
        RTS
AK_NONE LDA #0
        RTS

; The plan: item, how many (0: AI_N, the crops or houses for full
; food or housing points; crops count fishing boats too)
AIPLAN  .BYTE I_CROP,0, I_FACT,1, I_HOUS,0
        .BYTE I_SCHL,1, I_FACT,3, I_HOSP,1, I_FORT,1, I_FSBT,1
        .BYTE I_FACT,5, I_FORT,2, I_SCHL,2, I_HOSP,2
        .BYTE I_FORT,3, I_FORT,4
        .BYTE 0

; ---------------------------------------------------------------------
;  AI_SPOT -- the square for land item AI_IT (see above): AI_C, AI_R.
;  Out: C set if there is no free land.  Trashes A, X, Y.
; ---------------------------------------------------------------------
AI_SPOT
        LDX #AI_P
        JSR RB_LAND     ; the island's land squares in RBCOL / RBROW
        LDA #0
        STA AI_BV       ; best value + 1 so far (0: none)
        LDY RB_N
AS_SQ   DEY
        BMI AS_END
        STY AI_I
        LDX RBCOL,Y
        LDA RBROW,Y
        TAY
        JSR MAP_GET
        CMP #0
        BNE AS_NEXT     ; taken
        LDA AI_IT
        CMP #I_FORT
        BNE AS_PROT
        JSR AI_NBR      ; a fort: its own buildings around it, x 2
        ASL A
        JMP AS_VAL
AS_PROT JSR FORT_NEAR   ; anything else: next to a fort counts 2
        LDA #0
        BCC AS_VAL
        LDA #2
AS_VAL  STA AI_V
        LDA #2          ; + 0 or 1 at random, for variety
        JSR RAND_N
        SEC             ; + 1, so any free square beats none
        ADC AI_V
        CMP AI_BV
        BCC AS_NEXT
        BEQ AS_NEXT
        STA AI_BV
        LDY AI_I
        LDA RBCOL,Y
        STA AI_C
        LDA RBROW,Y
        STA AI_R
AS_NEXT LDY AI_I
        JMP AS_SQ
AS_END  LDA AI_BV
        BEQ AS_NONE
        CLC
        RTS
AS_NONE SEC             ; no free land
        RTS

; ---------------------------------------------------------------------
;  AI_NBR -- how many of the 8 squares around X, Y hold a building
;  (not a rebel).  Out: A.  X, Y kept.
; ---------------------------------------------------------------------
AI_NBR
        STX AN_C
        STY AN_R
        LDA #0
        STA AN_N
        LDA #7
        STA AN_I
AN_LOOP LDX AN_I
        LDA AN_C
        CLC
        ADC NBR_DC,X
        CMP #MAPSQ      ; also catches -1
        BCS AN_NEXT
        STA AN_T
        LDA AN_R
        CLC
        ADC NBR_DR,X
        CMP #MAPROWS
        BCS AN_NEXT
        TAY
        LDX AN_T
        JSR MAP_GET
        CMP #0
        BEQ AN_NEXT
        CMP #I_REBL
        BEQ AN_NEXT
        INC AN_N
AN_NEXT DEC AN_I
        BPL AN_LOOP
        LDX AN_C
        LDY AN_R
        LDA AN_N
        RTS
