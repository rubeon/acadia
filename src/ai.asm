; =====================================================================
;  AI.ASM -- the CPU governor of 1-player games (T-AI-1, T-AI-2,
;  T-AI-3: R-AI-1 to -5; D39, D40)
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
;    - the plan (AIPLAN, AI_PICK): a fishing boat (food too), enough
;      crops for full food points, a factory, enough houses for full
;      housing points (crops and houses: p100 / 6 + 1 at its
;      population), a school, factories, hospital, fort, then more of
;      each.  The first item short of its number is the one; if it
;      can't pay for it, it saves up (it doesn't skip to something
;      cheaper).  The order was tuned in simulated games
;      (tests/test_ai.py);
;    - where (AI_SPOT): a fort on the free square with the most of its
;      buildings around it; anything else on a free square next to a
;      fort if there is one (rebels never land there), else any;
;    - fishing (levels 2-3): while it saves up and a school is out, it
;      walks to its parked fishing boat, lifts it and steers it after
;      the nearest school, away from pirates; it parks once it can
;      pay, the schools are gone or the boat is stuck: where it is,
;      or in the harbour while a pirate is out (AI_BOAT).
;  Levels: 1 thinks every 3 s, 1 time in 3 buys a random building
;  instead, and never fishes; 2 thinks every 2 s; 3 thinks every
;  second, keeps one crop and one house ahead, and with the plan done
;  and 150 gold or more sends a rebel to player 1's island.
; =====================================================================

AI_P    =  1            ; the CPU's player
AI_REB  =  150          ; level 3: gold that sends a rebel
AI_RNDL =  3            ; level 1: 1 in 3 decisions is random
AI_NEAR =  20           ; pirate this close (pixels, both axes): flee
AI_FLT  =  30           ; frames it keeps fleeing
AI_FAR  =  48           ; pirate this close: park in the harbour,
                        ; don't lift the boat
AI_HGAP =  12           ; hurricane this close to touching: flee
AI_STUCK = 3            ; decisions without moving: stop fishing
AS_BUY  =  1            ; AIST: walking to a square to buy on it
AS_GOB  =  2            ;   walking to its parked fishing boat
AS_FISH =  3            ;   steering the boat after a school
AS_PARK =  4            ;   steering the boat to a place to park

; ---------------------------------------------------------------------
;  AI_INIT -- start of a game: nothing under way.  Trashes A.
; ---------------------------------------------------------------------
AI_INIT
        LDA #0
        STA AIST
        STA AI_FL
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
;  game the keys go to player 1 and JOY1 is the CPU's stick.  Walking
;  (AS_BUY, AS_GOB) it heads for square AI_C, AI_R and, once there,
;  buys or lifts its boat; with the boat (AS_FISH, AS_PARK) it steers
;  after a school, away from pirates, or parks.  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
AI_FRAME
        JSR AI_ON
        BNE AF_KEYS
        RTS
AF_KEYS LDA KEY         ; a key is always player 1's
        BMI AF_KEY
        LDA #0
        STA KEYPL
AF_KEY  LDA #0
        STA JOY1
        STA FIRE1
        LDA AIST
        BEQ AF_DONE     ; nothing under way
        CMP #AS_FISH
        BCC AF_WALK
        JMP AI_BOAT     ; steering its fishing boat
AF_WALK LDX #AI_P
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
        LDA AIST
        CMP #AS_GOB
        BEQ AF_LIFT
        LDA #0          ; buy (refused if it can't pay or the square
        STA AIST        ; was taken meanwhile)
        LDA AI_IT
        JMP ECO_BUY
AF_LIFT LDA #AI_FAR     ; not with a pirate or a hurricane about
        JSR AI_PIR
        BCS AF_NOT
        JSR AI_HURR
        BCS AF_NOT
        LDX #AI_P
        JSR BOAT_KEY    ; key 0: its boat off the map
        LDA #AS_FISH
        LDX BOATK+AI_P
        BNE AF_FISH
AF_NOT  LDA #0          ; refused (the boat was gone), or not now
AF_FISH STA AIST
        LDA #0
        STA AI_STK
        STA AI_FL
AF_DONE RTS

; ---------------------------------------------------------------------
;  AI_BOAT -- one frame of the CPU's steered fishing boat.
;  AS_FISH: towards the nearest school, away from a pirate within
;  AI_NEAR pixels; no school: park.  AS_PARK: away from a close
;  pirate; with a pirate within AI_FAR, home to the harbour first (a
;  parked boat in open sea is attacked); then park on the square under it if
;  that is free sea, else head for the harbour, or off it if the
;  harbour itself is taken.  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
AI_BOAT
        LDA BOATK+AI_P
        BNE AB_ON
        STA AIST        ; sunk: nothing under way (A = 0)
        RTS
AB_ON   LDA AI_FL       ; still fleeing: the same way
        BEQ AB_FLEE
        DEC AI_FL
        LDA AI_FJ
        STA JOY1
        RTS
AB_FLEE JSR AI_FLEE     ; a pirate close: away from it
        BCS AB_DONE
        LDA AIST
        CMP #AS_PARK
        BEQ AB_PARK
        JSR AI_SCHOOL   ; the nearest school
        BCS AB_TOPK
        JMP AB_FISH
AB_TOPK LDA #AS_PARK
        STA AIST
AB_PARK LDA #AI_FAR      ; a pirate about: home first
        JSR AI_PIR
        PHP
        LDA #0          ; AI_TX, AI_TY: next square towards home
        JSR AI_WAY
        PLP
        BCC AB_HERE
        LDA AI_BV       ; not there yet: on
        BNE AB_GO
        JSR AI_STEER    ; the harbour square itself
        LDA JOY1
        BNE AB_DONE
AB_HERE LDX #AI_P       ; free sea under it?  park there
        LDY CURROW,X
        LDA CURCOL,X
        TAX
        JSR MAP_GET
        CMP #0
        BNE AB_HOME
        LDA MKIND
        AND #K_KIND
        CMP #K_LAND
        BEQ AB_HOME
        LDX #AI_P
        JSR BOAT_KEY
        LDA BOATK+AI_P
        BNE AB_DONE
        STA AIST        ; parked: back to the cursor (A = 0)
AB_DONE RTS
AB_HOME JSR AI_STEER    ; else towards the harbour
        LDA JOY1
        ORA AI_BV
        BNE AB_DONE
        LDA FRAME       ; at the harbour and it is taken: wander
        LSR A           ; off it, a new way every 16 frames
        LSR A
        LSR A
        LSR A
        AND #3
        TAX
        LDA AB_WAY,X
        STA JOY1
        RTS
AB_GO   JMP AI_STEER
AB_FISH LDY #1          ; the school's side: 1 above (rows 0-4),
        LDA AI_TY       ; 2 below
        CMP #5*8
        BCC AB_SIDE
        INY
AB_SIDE LDA CURROW+AI_P ; the boat out in the open sea on that
        CPY #1          ; side: straight at it
        BNE AB_DNS
        CMP #2
        BCC AB_GO
        BCS AB_NEAR     ; always
AB_DNS  CMP #MAPROWS-2
        BCS AB_GO
AB_NEAR LDA AI_TX       ; within a square of it both ways: straight
        SEC             ; at it
        SBC CURX+AI_P
        CLC
        ADC #15
        CMP #31
        BCS AB_ROUND
        LDA AI_TY
        SEC
        SBC CURY+AI_P
        CLC
        ADC #15
        CMP #31
        BCC AB_GO
AB_ROUND TYA            ; else round the islands to that side first
        JSR AI_WAY
        JMP AI_STEER

AB_WAY  .BYTE J_UP,J_LEFT,J_DOWN,J_RIGHT

; ---------------------------------------------------------------------
;  AI_WAY -- AI_TX, AI_TY: the top left of the square next to the one
;  under the CPU's boat that is fewest steps by sea from its goal, or
;  of this one if none is fewer; AI_BV = that square's steps (0: at
;  the goal).  A = 0: the goal is its harbour (AI_HD); 1: the open
;  sea above the islands (AI_UP); 2: below them (AI_DN).  The tables
;  are made by tools/mkfont.py (ISLANDS.ASM).
;  Trashes A, X.
; ---------------------------------------------------------------------
AI_WAY
        STA AI_TB
        LDA CURCOL+AI_P ; here first
        STA AN_C
        STA AI_C
        LDA CURROW+AI_P
        STA AN_R
        STA AI_R
        JSR AW_GET
        STA AI_BV
        LDA AN_C        ; west
        BEQ AW_E
        DEC AN_C
        JSR AW_TRY
        INC AN_C
AW_E    LDA AN_C        ; east
        CMP #MAPSQ-1
        BCS AW_N
        INC AN_C
        JSR AW_TRY
        DEC AN_C
AW_N    LDA AN_R        ; north
        BEQ AW_S
        DEC AN_R
        JSR AW_TRY
        INC AN_R
AW_S    LDA AN_R        ; south
        CMP #MAPROWS-1
        BCS AW_GO
        INC AN_R
        JSR AW_TRY
AW_GO   LDA AI_C        ; the best square's top left
        ASL A
        ASL A
        ASL A
        STA AI_TX
        LDA AI_R
        ASL A
        ASL A
        ASL A
        STA AI_TY
        RTS
AW_TRY  JSR AW_GET      ; fewer steps from AN_C, AN_R: the best
        CMP AI_BV
        BCS AW_NO
        STA AI_BV
        LDA AN_C
        STA AI_C
        LDA AN_R
        STA AI_R
AW_NO   RTS
AW_GET  LDA AN_R        ; A = steps at AN_C, AN_R; X = its index
        ASL A
        ASL A
        STA AN_T        ; row x 4
        ASL A
        ASL A
        CLC
        ADC AN_T        ; row x 20
        ADC AN_C
        TAX
        LDA AI_TB
        BNE AW_UD
        LDA AI_HD,X
        RTS
AW_UD   CMP #1
        BNE AW_DN
        LDA AI_UP,X
        RTS
AW_DN   LDA AI_DN,X
        RTS

; AI_STEER -- JOY1 towards map pixel AI_TX, AI_TY for the CPU's
; cursor or boat (its top left corner).  Trashes A.
AI_STEER
        LDA CURX+AI_P
        CMP AI_TX
        BEQ AE_V
        LDA #J_RIGHT
        BCC AE_H
        LDA #J_LEFT
AE_H    STA JOY1
AE_V    LDA CURY+AI_P
        CMP AI_TY
        BEQ AE_DONE
        LDA #J_DOWN
        BCC AE_VS
        LDA #J_UP
AE_VS   ORA JOY1
        STA JOY1
AE_DONE RTS

; ---------------------------------------------------------------------
;  AI_SCHOOL -- the school nearest the CPU's boat: its top left corner
;  (held to the map) in AI_TX, AI_TY.  C set if no school is out.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
AI_SCHOOL
        LDA #$FF
        STA AI_BV       ; best distance so far
        SEC
        STA AI_V        ; $FF: none found
        LDX #1
AH_ONE  LDA FACT,X
        BEQ AH_NEXT
        JSR AI_DIST     ; |dx| + |dy| to slot X, at most 255
        CMP AI_BV
        BCS AH_NEXT
        STA AI_BV
        STX AI_V
AH_NEXT DEX
        BPL AH_ONE
        LDX AI_V
        BMI AH_NONE
        LDA FXH,X       ; top left: FXH - 8, FYH - 8, within the map
        SEC
        SBC #8
        BCS AH_X0
        LDA #0
AH_X0   CMP #CUR_MAXX+1
        BCC AH_X1
        LDA #CUR_MAXX
AH_X1   STA AI_TX
        LDA FYH,X
        SEC
        SBC #8
        BCS AH_Y0
        LDA #0
AH_Y0   CMP #CUR_MAXY+1
        BCC AH_Y1
        LDA #CUR_MAXY
AH_Y1   STA AI_TY
        CLC
        RTS
AH_NONE SEC
        RTS

; AI_DIST -- |FXH - 8 - CURX| + |FYH - 8 - CURY| for slot X and the
; CPU's boat, at most 255.  X kept; trashes A, Y.
AI_DIST LDA FXH,X
        SEC
        SBC #8
        SEC
        SBC CURX+AI_P
        BCS AD_X
        EOR #$FF
        ADC #1
AD_X    TAY
        LDA FYH,X
        SEC
        SBC #8
        SEC
        SBC CURY+AI_P
        BCS AD_Y
        EOR #$FF
        ADC #1
AD_Y    STY AI_I
        CLC
        ADC AI_I
        BCC AD_DONE
        LDA #$FF
AD_DONE RTS

; ---------------------------------------------------------------------
;  AI_FLEE -- a pirate within AI_NEAR of the CPU's boat on both axes,
;  or a hurricane about to touch it: JOY1 away from it, kept for
;  AI_FLT frames (AI_FJ, AI_FL), C set.
;  Else C clear.  Trashes A, X, Y.
; ---------------------------------------------------------------------
AI_FLEE
        LDA #AI_NEAR
        JSR AI_PIR
        BCS AL_AWAY
        JSR AI_HURR
        BCC AL_DONE
AL_AWAY LDA #J_LEFT     ; away: pirate to the right (dx >= 0) -> left
        LDY AN_C
        BPL AL_H
        LDA #J_RIGHT
AL_H    STA JOY1
        LDA #J_UP
        LDY AN_R
        BPL AL_V
        LDA #J_DOWN
AL_V    ORA JOY1
        STA JOY1
        STA AI_FJ       ; and keep on that way for a while
        LDA #AI_FLT
        STA AI_FL
        SEC
AL_DONE RTS

; AI_PIR -- C set if a pirate is within A pixels of the CPU's boat on
; both axes (A at most 64), with AN_C, AN_R = its dx, dy (signed).
; Trashes A, X, Y.
AI_PIR  STA AN_N        ; distance
        ASL A
        SEC
        SBC #1
        STA AN_T        ; 2 x distance - 1
        LDX #P_SLOT+1
AP_ONE  LDA FACT,X
        BEQ AP_NEXT
        LDA FXH,X       ; dx = pirate - boat
        SEC
        SBC #8
        SEC
        SBC CURX+AI_P
        STA AN_C
        CLC
        ADC AN_N
        SEC
        SBC #1
        CMP AN_T
        BCS AP_NEXT
        LDA FYH,X       ; dy
        SEC
        SBC #8
        SEC
        SBC CURY+AI_P
        STA AN_R
        CLC
        ADC AN_N
        SEC
        SBC #1
        CMP AN_T
        BCC AP_YES
AP_NEXT DEX
        CPX #P_SLOT
        BCS AP_ONE
        CLC
        RTS
AP_YES  SEC
        RTS

; AI_HURR -- C set if a hurricane (16 x 32) is within AI_HGAP pixels of
; touching the CPU's boat, with AN_C, AN_R = centre to centre dx, dy
; (signed).  Trashes A, X.
AI_HURR LDX #1
AZ_ONE  LDA WACT,X
        CMP #WT_HURR
        BNE AZ_NEXT
        LDA WXH,X       ; dx: WXH - 8 + 8 - (CURX + 4)
        SEC
        SBC #4
        SEC
        SBC CURX+AI_P
        STA AN_C
        CLC
        ADC #8+4+AI_HGAP-1
        CMP #2*(8+4+AI_HGAP)-1
        BCS AZ_NEXT
        LDA WYH,X       ; dy: WYH - 8 + 16 - (CURY + 4)
        CLC
        ADC #4
        SEC
        SBC CURY+AI_P
        STA AN_R
        CLC
        ADC #16+4+AI_HGAP-1
        CMP #2*(16+4+AI_HGAP)-1
        BCC AZ_YES
AZ_NEXT DEX
        BPL AZ_ONE
        CLC
        RTS
AZ_YES  SEC
        RTS

; ---------------------------------------------------------------------
;  AI_TIC -- each tic of a round: think every AI_RATE tics.
;  Nothing under way: buy the plan's next item if it can pay; if it
;  is saving up (or the plan is done), levels 2-3 take the fishing
;  boat out when a school is about.  Fishing: back to park once it
;  can pay, or when the boat has been stuck for AI_STUCK decisions.
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
        CMP #AS_FISH
        BEQ AT_FISH
        CMP #0
        BNE AT_DONE     ; on its way somewhere
        JSR AI_PICK     ; what
        BEQ AT_GOFS     ; nothing to buy: fish
        STA AI_IT
        JSR AI_PAY
        BCC AT_GOFS     ; saving up: fish meanwhile
        LDA AI_IT
        CMP #I_REBL
        BCC AT_LAND
        LDX #AI_P       ; a boat or a rebel: no square needed
        JMP ECO_BUY
AT_LAND JSR AI_SPOT     ; where
        BCS AT_DONE     ; no free land
        LDA #AS_BUY
        STA AIST
AT_DONE RTS
AT_GOFS LDA SU_VAL+SU_FLVL      ; levels 2-3 only
        CMP #2
        BCC AT_DONE
        LDA FACT        ; a school about?
        ORA FACT+1
        BEQ AT_DONE
        JSR AI_FINDB    ; its parked fishing boat
        BCS AT_DONE
        LDA #AS_GOB
        STA AIST
        RTS
AT_FISH LDA CURX+AI_P   ; stuck?
        CMP AI_LX
        BNE AT_MOVD
        LDA CURY+AI_P
        CMP AI_LY
        BNE AT_MOVD
        INC AI_STK
        LDA AI_STK
        CMP #AI_STUCK
        BCS AT_PARK
        BCC AT_PAY      ; always
AT_MOVD LDA #0
        STA AI_STK
        LDA CURX+AI_P
        STA AI_LX
        LDA CURY+AI_P
        STA AI_LY
AT_PAY  JSR AI_PICK     ; enough gold for the next item now?
        BEQ AT_DONE
        STA AI_IT
        JSR AI_PAY
        BCC AT_DONE
AT_PARK LDA #AS_PARK
        STA AIST
        RTS

; AI_PAY -- C set if the CPU can pay for item AI_IT.  Trashes A, Y.
AI_PAY  LDY AI_IT
        LDA GOLD+2*AI_P+1
        BNE AY_YES
        LDA GOLD+2*AI_P
        CMP PRICES,Y    ; C set if gold >= price
        RTS
AY_YES  SEC
        RTS

; ---------------------------------------------------------------------
;  AI_FINDB -- the square of the CPU's parked fishing boat: AI_C,
;  AI_R, C clear; C set if it has none parked.  Trashes A, X, Y.
; ---------------------------------------------------------------------
AI_FINDB
        LDY #MAPROWS-1
AQ_ROW  LDX #MAPSQ-1
AQ_COL  JSR MAP_GET
        CMP #I_FSBT+I_P1
        BEQ AQ_GOT
        DEX
        BPL AQ_COL
        DEY
        BPL AQ_ROW
        SEC
        RTS
AQ_GOT  STX AI_C
        STY AI_R
        CLC
        RTS

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
AIPLAN  .BYTE I_FSBT,1, I_CROP,0, I_FACT,1, I_HOUS,0
        .BYTE I_SCHL,1, I_FACT,3, I_HOSP,1, I_FORT,1
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
