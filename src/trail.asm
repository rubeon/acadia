; =====================================================================
;  TRAIL.ASM -- boats leave a fading trail of sparkles (D62, was
;  waves, D59)
;
;  When a steered boat's centre moves on to a new square, the square
;  it left gets a sparkle if it is open sea with nothing on it (plain
;  sea, or one of the ambient waves or sparkles, which come back after).
;  The sparkle fades in SPK_STEPS steps of SPK_RATE frames: a
;  twinkling star (T_SPKx3), two dots, one dot, then the square is
;  drawn as it should be again.  Each kind of row has its own 3 tiles
;  (TLBASE): rows 2-8 (A), row 1 (B), row 9 (C), rows 0 and 10 (D),
;  for the corner rows' PF0 sea (D55).  A sparkle is never drawn over
;  an item, and is only changed or taken off the map while its square
;  still shows it (a wreck or a boat drawn there since stays).
; =====================================================================

; TL_N (sparkles at once) is in VARS.ASM, which reserves the slots
SPK_RATE =  12          ; frames per fade step (a boat crosses a
                        ; square in 12 or more)

; ---------------------------------------------------------------------
;  TRAIL_INIT -- no sparkles, no boat out.  Call after MAP_DRAW.
;  Trashes A, X.
; ---------------------------------------------------------------------
TRAIL_INIT
        LDA #0
        STA TLNEXT
        LDX #TL_N-1
TI_CLR  STA TLSTEP,X    ; 0: the slot is free
        DEX
        BPL TI_CLR
        LDA #$FF        ; no boat on a square yet
        STA TLLC
        STA TLLC+1
        RTS

; ---------------------------------------------------------------------
;  TRAIL_TIC -- once a frame during play: every sparkle fades, and a
;  new one goes on each square a steered boat has just left.
;  Trashes A, X, Y, ZPTR, MTILE.
; ---------------------------------------------------------------------
TRAIL_TIC
        JSR TL_AGE      ; first, so a new one shows its full time
        LDX #1
TT_PL   STX TL_P
        LDA BOATK,X
        BEQ TT_NONE     ; a cursor, not a boat
        LDA CURCOL,X
        CMP TLLC,X
        BNE TT_MOVE
        LDA CURROW,X
        CMP TLLR,X
        BEQ TT_NEXT     ; still on the same square
TT_MOVE LDA TLLC,X      ; the square it left
        STA TL_C
        LDA TLLR,X
        STA TL_R
        LDA CURCOL,X    ; the one it is on now
        STA TLLC,X
        LDA CURROW,X
        STA TLLR,X
        LDA TL_C
        CMP #$FF
        BEQ TT_NEXT     ; just lifted off the map: nothing left yet
        JSR TL_WAKE
        JMP TT_NEXT
TT_NONE LDA #$FF        ; no boat out
        STA TLLC,X
TT_NEXT LDX TL_P
        DEX
        BPL TT_PL
        RTS

; ---------------------------------------------------------------------
;  TL_AGE -- every sparkle's time runs down; at 0 it fades a step.
;  Trashes A, X, Y, ZPTR, MTILE.
; ---------------------------------------------------------------------
TL_AGE  LDX #TL_N-1
TA_SLOT LDA TLSTEP,X
        BEQ TA_NEXT     ; free
        DEC TLTIME,X
        BNE TA_NEXT
        JSR TL_FADE
TA_NEXT DEX
        BPL TA_SLOT
TW_NO   RTS             ; (also TL_WAKE's early way out)

; ---------------------------------------------------------------------
;  TL_WAKE -- a sparkle on square TL_C, TL_R if it is open sea with
;  nothing on it.  Trashes A, X, Y, ZPTR, MTILE.
; ---------------------------------------------------------------------
TL_WAKE LDX TL_C
        LDY TL_R
        JSR MAP_GET     ; A = item there
        BCS TW_NO       ; off the map
        CMP #0
        BNE TW_NO       ; something on it
        JSR MAP_IDX
        TAX
        LDA ISLTILE,X   ; terrain: the row's open sea
        CMP TLSEA,Y
        BEQ TW_OK
        LDX TLSEA,Y     ; or in rows 2-8 (T_SEA = 0) an ambient wave
        BNE TW_NO       ; or sparkle
        CMP #T_WAVE1
        BEQ TW_OK
        CMP #T_WAVE2
        BEQ TW_OK
        CMP #T_SPARK
        BNE TW_NO
TW_OK   LDX #TL_N-1     ; already a sparkle there (the boat came
TW_DUP  LDA TLSTEP,X    ; back): this one replaces it
        BEQ TW_DUPN
        LDA TLCOL,X
        CMP TL_C
        BNE TW_DUPN
        LDA TLROW,X
        CMP TL_R
        BNE TW_DUPN
        LDA #0
        STA TLSTEP,X
TW_DUPN DEX
        BPL TW_DUP
        LDX TLNEXT      ; the next slot; if in use, its sparkle ends now
        LDA TLSTEP,X
        BEQ TW_FREE
        LDA #1
        STA TLSTEP,X
        JSR TL_FADE
TW_FREE LDA TL_C
        STA TLCOL,X
        LDA TL_R
        STA TLROW,X
        LDA #SPK_STEPS  ; the brightest step
        STA TLSTEP,X
        LDA #SPK_RATE
        STA TLTIME,X
        TXA             ; the next slot after this one
        CLC
        ADC #1
        AND #TL_N-1
        STA TLNEXT
        JSR TL_TILE
        LDX TL_C
        LDY TL_R
        JMP MAP_PUT

; ---------------------------------------------------------------------
;  TL_FADE -- slot X's sparkle a step fainter, or gone (its square
;  drawn as it should be: item or terrain); only if the square still
;  shows it, else the slot is just freed.  X kept; trashes A, Y,
;  ZPTR, MTILE.
; ---------------------------------------------------------------------
TL_FADE STX TL_S
        JSR TL_SHOWN
        BCC TF_FREE     ; something else drawn over it
        DEC TLSTEP,X
        BEQ TF_END
        LDA #SPK_RATE
        STA TLTIME,X
        JSR TL_TILE     ; the fainter tile
        LDY TLROW,X
        PHA
        LDA TLCOL,X
        TAX
        PLA
        JSR MAP_PUT
        LDX TL_S
        RTS
TF_END  LDY TLROW,X
        LDA TLCOL,X
        TAX
        JSR MAP_GET     ; A = item (0: terrain)
        JSR MAP_SET     ; drawn as it should be
TF_FREE LDX TL_S
        LDA #0
        STA TLSTEP,X
        RTS

; TL_TILE -- A = the tile slot X shows (TLBASE + step - 1).  Keeps X.
TL_TILE LDY TLROW,X
        LDA TLBASE,Y
        CLC
        ADC TLSTEP,X
        SEC
        SBC #1
        RTS

; TL_SHOWN -- C set if slot X's square still shows its sparkle (its
; top left and bottom right characters).  In: X = TL_S = slot.
; Keeps X; trashes A, Y, ZPTR.
TL_SHOWN
        JSR TL_TILE
        STA TL_T
        LDY TLROW,X     ; the square's screen address
        LDA ROWLO,Y
        STA ZPTR
        LDA ROWHI,Y
        STA ZPTR+1
        LDA TLCOL,X
        ASL A           ; two characters per square
        TAY
        LDX TL_T
        LDA (ZPTR),Y    ; top left
        CMP TILECH,X
        BNE TS_NO
        TYA
        CLC
        ADC #MAPCOLS+1  ; bottom right
        TAY
        LDA (ZPTR),Y
        CMP TILECBR,X
        BNE TS_NO
        LDX TL_S
        SEC
        RTS
TS_NO   LDX TL_S
        CLC
        RTS

; Per square row 0-10: the open sea a sparkle may be drawn on, and its
; sparkle tiles' first (faintest) step
TLSEA   .BYTE T_SEAB,T_SEAB1,T_SEA,T_SEA,T_SEA,T_SEA,T_SEA,T_SEA,T_SEA,T_SEAB9,T_SEAB
TLBASE  .BYTE T_SPKD1,T_SPKB1,T_SPKA1,T_SPKA1,T_SPKA1,T_SPKA1,T_SPKA1,T_SPKA1
        .BYTE T_SPKA1,T_SPKC1,T_SPKD1
