; =====================================================================
;  PIRATES.ASM -- pirate ships and what boats do to each other (T-EVT-3:
;  R-RULE-4, -6; the original's $520D-$52B3, $54F8-$5600; D36)
;
;  Up to two pirates, slots 2 and 3 of the fish arrays (FISH.ASM), so
;  they appear, drift and are blocked as schools do, at the original's
;  speed.  Each tic of a round:
;    - 1 in 100: a pirate appears in a free slot (FISH_NEW: the left or
;      right edge, the top or bottom band, the other band if the other
;      pirate is out);
;    - each gets, 1 in 10, a kick of 1 to its speed; land and parked
;      PT boats stop it on that axis; it is gone once off the map;
;    - a parked fishing boat on the square under its centre is
;      attacked (PIR_ATK);
;    - a steered fishing boat touching it sinks, unless there is a
;      fort (either player's) next to the boat;
;    - a steered PT boat touching it stops it dead (speed 0).  PT
;      boats don't sink pirates; only a hurricane does (WEATHER.ASM).
;  And between the players' boats (PT_TIC):
;    - a steered PT boat over the other player's parked fishing boat
;      attacks it, as a pirate does;
;    - a steered fishing boat touching the other player's steered PT
;      boat sinks, unless a fort of its own player is next to it.
;
;  PIR_ATK: nothing while a wreck is showing; nothing if the first
;  fort found next to the boat (FORT_NEAR) is its owner's; otherwise
;  the owner's attack count goes up, and at 20 the boat sinks (wreck,
;  one fewer fishing boat) and the count starts again.
;
;  The missiles show both pirates as a fifth player in COLPF3 (white),
;  M3 to M0 side by side, 8 pixels wide.  PIR_SHOW (every frame)
;  draws them in missile memory and fills HMROW, the position for
;  each map row, which the DLIs load (DISPLAY.ASM).  Two pirates in
;  one map row take turns, one per frame (D14).
; =====================================================================

P_SPAWN =  100          ; 1 in 100 tics: a new pirate
P_SINK  =  20           ; attacks that sink a parked fishing boat
P_SLOT  =  2            ; first pirate slot in the fish arrays
PM_MSL  =  PMAREA+$180  ; missile memory

; ---------------------------------------------------------------------
;  PIR_INIT -- no pirates, no attack counts (start of a game).
;  Trashes A, X.
; ---------------------------------------------------------------------
PIR_INIT
        LDA #0
        STA FACT+P_SLOT
        STA FACT+P_SLOT+1
        STA PTCH
        STA PTCH+1
        LDX #MAPROWS-1
PI_HM   STA HMROW,X
        DEX
        BPL PI_HM
        LDX #PM_LEN-1
PI_PM   STA PM_MSL,X
        DEX
        BPL PI_PM
        LDA #$FF        ; nothing drawn
        STA FDRAWN+P_SLOT
        STA FDRAWN+P_SLOT+1
        RTS

; ---------------------------------------------------------------------
;  PIR_TIC -- one tic of the pirates and the boats (during a round).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
PIR_TIC
        LDA #P_SPAWN
        JSR RAND_N
        BNE PT_RUN
        LDX #P_SLOT     ; a free slot
        LDA FACT,X
        BEQ PT_NEW
        INX
        LDA FACT,X
        BNE PT_RUN      ; both out already
PT_NEW  JSR FISH_NEW
PT_RUN  LDX #P_SLOT+1
PT_ONE  STX PT_I
        LDA FACT,X
        BEQ PT_NEXT
        JSR FISH_KICK
        LDX PT_I
        JSR FISH_MOVE
        LDX PT_I
        LDA FACT,X
        BEQ PT_NEXT     ; it left the map
        JSR PIR_HIT
PT_NEXT LDX PT_I
        DEX
        CPX #P_SLOT
        BCS PT_ONE
        JMP PT_TIC

; ---------------------------------------------------------------------
;  PIR_HIT -- pirate X against the boats.  Trashes A, X, Y.
; ---------------------------------------------------------------------
PIR_HIT
        STX PH_I
        LDA FXH,X       ; parked: a fishing boat under the centre
        LDY FYH,X
        JSR FC_SQ
        BCS PH_STR
        STX PA_C
        STY PA_R
        JSR MAP_GET
        STA PA_O
        AND #I_ITEM
        CMP #I_FSBT
        BNE PH_STR
        LDA PA_O        ; owner: I_P1 -> 1
        ASL A
        LDA #0
        ROL A
        STA PA_O
        JSR PIR_ATK
PH_STR  LDX #1          ; steered boats touching it
PH_PL   STX PH_P
        LDA BOATK,X
        BEQ PH_NEXT
        LDY PH_I
        LDA CURX,X      ; boat x + 8 - pirate FXH, touching if -7..7
        CLC
        ADC #8+7
        SEC
        SBC FXH,Y
        CMP #15
        BCS PH_NEXT
        LDA CURY,X
        CLC
        ADC #8+7
        SEC
        SBC FYH,Y
        CMP #15
        BCS PH_NEXT
        LDA BOATK,X
        CMP #I_PTBT
        BNE PH_FISH
        LDA #0          ; a PT boat: the pirate stops dead
        STA FVX,Y
        STA FVY,Y
        BEQ PH_NEXT     ; always
PH_FISH LDY CURROW,X    ; a fishing boat: sunk unless a fort is near
        LDA CURCOL,X
        TAX
        JSR FORT_NEAR
        BCS PH_NEXT     ; any fort protects it
        LDX PH_P
        JSR BOAT_LOSE
PH_NEXT LDX PH_P
        DEX
        BPL PH_PL
        RTS

; ---------------------------------------------------------------------
;  PIR_ATK -- attack on the parked fishing boat of player PA_O on
;  square PA_C, PA_R (a pirate, or the other player's PT boat).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
PIR_ATK
        LDA SNKT        ; one sinking at a time
        BNE PA_DONE
        LDX PA_C
        LDY PA_R
        JSR FORT_NEAR
        BCC PA_HIT
        CMP PA_O        ; its owner's fort protects it
        BEQ PA_DONE
PA_HIT  LDX PA_O
        INC PTCH,X
        LDA PTCH,X
        CMP #P_SINK
        BCC PA_DONE
        LDA #0          ; sunk: the count starts again
        STA PTCH,X
        STX WH_P        ; WTH_SMITE's boat path: count, square, wreck
        LDA #I_FSBT
        STA WH_K
        LDA PA_C
        STA WH_C
        LDA PA_R
        STA WH_R
        JMP WS_GONE
PA_DONE RTS

; ---------------------------------------------------------------------
;  PT_TIC -- the players' steered PT boats against the other player's
;  fishing boats.  Trashes A, X, Y.
; ---------------------------------------------------------------------
PT_TIC
        LDX #1
PB_PL   STX PH_P
        LDA BOATK,X
        CMP #I_PTBT
        BNE PB_NEXT
        LDY CURROW,X    ; a parked fishing boat under its centre
        LDA CURCOL,X
        STA PA_C
        STY PA_R
        TAX
        JSR MAP_GET
        STA PA_O
        AND #I_ITEM
        CMP #I_FSBT
        BNE PB_STR
        LDA PA_O        ; owner: I_P1 -> 1
        ASL A
        LDA #0
        ROL A
        STA PA_O
        CMP PH_P
        BEQ PB_STR      ; its own: left alone
        JSR PIR_ATK
PB_STR  LDA PH_P        ; the other player's steered fishing boat
        EOR #1
        TAX
        LDA BOATK,X
        CMP #I_FSBT
        BNE PB_NEXT
        LDY PH_P
        LDA CURX,X      ; touching: both boxes within 7 pixels
        CLC
        ADC #7
        SEC
        SBC CURX,Y
        CMP #15
        BCS PB_NEXT
        LDA CURY,X
        CLC
        ADC #7
        SEC
        SBC CURY,Y
        CMP #15
        BCS PB_NEXT
        LDY CURROW,X    ; sunk, unless a fort of its own is near
        LDA CURCOL,X
        TAX
        JSR FORT_NEAR
        BCC PB_SINK
        LDX PH_P        ; its owner is the other player: != PH_P
        STA PA_O
        CPX PA_O
        BNE PB_NEXT
PB_SINK LDA PH_P
        EOR #1
        TAX
        JSR BOAT_LOSE
PB_NEXT LDX PH_P
        DEX
        BMI PB_DONE
        JMP PB_PL
PB_DONE RTS

; ---------------------------------------------------------------------
;  PIR_SHOW -- draw the pirates in missile memory and set HMROW.
;  Every frame.  Trashes A, X, Y.
; ---------------------------------------------------------------------
PIR_SHOW
        LDA FACT+P_SLOT ; which to show: both, unless they share a row
        STA PS_V
        LDA FACT+P_SLOT+1
        STA PS_V+1
        AND FACT+P_SLOT
        BEQ PW_CLR
        LDX #P_SLOT
        JSR FW_ROWS
        STA PS_A1       ; pirate 2: rows FW_R0..A
        LDA FW_R0
        STA PS_A0
        LDX #P_SLOT+1
        JSR FW_ROWS     ; pirate 3: FW_R0..A
        CMP PS_A0
        BCC PW_CLR      ; 3 ends above 2
        LDA PS_A1
        CMP FW_R0
        BCC PW_CLR      ; 2 ends above 3
        LDA FRAME       ; shared rows: take turns
        AND #1
        TAX
        LDA #0
        STA PS_V,X
PW_CLR  LDA #0          ; no positions until set below
        LDX #MAPROWS-1
PW_HP   STA HMROW,X
        DEX
        BPL PW_HP
        LDX #P_SLOT+1
PW_ONE  STX PS_I
        LDA FDRAWN,X    ; erase where it was
        CMP #$FF
        BEQ PW_DRAW
        TAY
        LDA #0
        LDX #SPR_H-1
PW_ERA  STA PM_MSL,Y
        INY
        DEX
        BPL PW_ERA
        LDX PS_I
        LDA #$FF
        STA FDRAWN,X
PW_DRAW LDA PS_V-P_SLOT,X
        BEQ PW_NEXT
        LDA FYH,X       ; P/M line: FYH - 8 + PM_MAP
        CLC
        ADC #PM_MAP-8
        STA FDRAWN,X
        TAY
        LDX #0
PW_PUT  LDA PIRSHP,X
        STA PM_MSL,Y
        INY
        INX
        CPX #SPR_H
        BNE PW_PUT
        LDX PS_I        ; its rows get its horizontal position
        JSR FW_ROWS
        STA PS_A1
        LDA FXH,X       ; FXH - 8 + HP_MAP: M3, the left edge
        CLC
        ADC #HP_MAP-8
        LDY FW_R0
PW_ROW  STA HMROW,Y
        CPY PS_A1
        BCS PW_NEXT
        INY
        BNE PW_ROW
PW_NEXT LDX PS_I
        DEX
        CPX #P_SLOT
        BCS PW_ONE
        RTS

; Pirate ship, 8 x 8: a flag on the mast, a sail, a hull with ports
; (missile bits: M3 is the left 2 pixels, M0 the right 2)
PIRSHP  .BYTE $18,$10,$1C,$1E,$1F,$10,$FF,$5A
