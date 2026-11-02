; =====================================================================
;  TRAIL.ASM -- boats leave a trail of waves (D59)
;
;  When a steered boat's centre moves on to a new square, the square
;  it left gets a wave, if it is plain open sea with nothing on it:
;  the wave tile that is showing its crest now (T_WAVE1 or T_WAVE2,
;  which WAVE_ANI animates 2 phases apart), so every wake starts with
;  a crest that rolls on and breaks.  When that tile reaches its calm
;  phase, which looks the same as plain sea, the square is drawn as
;  its terrain again, so the wake ends without a jump.
;  Rows 1 and 9 (half corner rows, D55) have one wave tile each,
;  T_WAVE2B and T_WAVE1C; a wake there that starts while its tile is
;  calm waits up to WV_RATE frames for the crest.  Rows 0 and 10 get
;  no wake (no font room for a crest on PF0, see mkfont.py).
;  A wake is never drawn over an item, and one is only taken off the
;  map if its square still shows it (a wreck or a boat drawn there
;  since stays).  The ambient waves and sparkles are not touched.
; =====================================================================

; TL_N (wakes at once) is in VARS.ASM, which reserves the slots

; ---------------------------------------------------------------------
;  TRAIL_INIT -- no wakes, no boat out.  Call after MAP_DRAW.
;  Trashes A, X.
; ---------------------------------------------------------------------
TRAIL_INIT
        LDA #0
        STA TLNEXT
        LDX #TL_N-1
TI_CLR  STA TLTILE,X    ; 0: the slot is free
        DEX
        BPL TI_CLR
        LDA #$FF        ; no boat on a square yet
        STA TLLC
        STA TLLC+1
        RTS

; ---------------------------------------------------------------------
;  TRAIL_TIC -- once a frame during play, after WAVE_ANI: a wake on
;  each square a steered boat has just left; wakes whose wave has
;  gone calm are cleared.  Trashes A, X, Y, ZPTR, MTILE.
; ---------------------------------------------------------------------
TRAIL_TIC
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
        ; fall through: age the wakes

; ---------------------------------------------------------------------
;  TL_AGE -- clear each wake whose wave has gone calm after showing.
;  Trashes A, X, Y, ZPTR, MTILE.
; ---------------------------------------------------------------------
TL_AGE  JSR TL_PHASE
        STA TL_PH
        LDX #TL_N-1
TA_SLOT LDA TLTILE,X
        BEQ TA_NEXT     ; free
        LDA TL_PH       ; the phase its tile shows
        EOR TLLAG,X
        CMP #WV_PH-1
        BEQ TA_CALM
        LDA #1          ; it has shown a wave
        STA TLARM,X
        BNE TA_NEXT
TA_CALM LDA TLARM,X
        BEQ TA_NEXT     ; calm since it was drawn: the crest is to come
        JSR TL_END
TA_NEXT DEX
        BPL TA_SLOT
        RTS

; TL_PHASE -- A = the phase WAVE_ANI shows now (0 to WV_PH-1)
TL_PHASE
        LDA FRAME
        LSR A           ; / WV_RATE (16)
        LSR A
        LSR A
        LSR A
        AND #WV_PH-1
TW_NO   RTS             ; (also TL_WAKE's early way out)

; ---------------------------------------------------------------------
;  TL_WAKE -- a wake on square TL_C, TL_R if it is plain open sea with
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
        LDA ISLTILE,X   ; its terrain must be the row's plain sea
        CMP TLSEA,Y
        BNE TW_NO
        LDX #TL_N-1     ; already a wake there (the boat came back):
TW_DUP  LDA TLTILE,X    ; drop it, this one replaces it
        BEQ TW_DUPN
        LDA TLCOL,X
        CMP TL_C
        BNE TW_DUPN
        LDA TLROW,X
        CMP TL_R
        BNE TW_DUPN
        LDA #0
        STA TLTILE,X
TW_DUPN DEX
        BPL TW_DUP
        LDX TLNEXT      ; the next slot; if in use, its wake ends now
        LDA TLTILE,X
        BEQ TW_FREE
        JSR TL_END
TW_FREE JSR TL_PHASE    ; which wave shows a crest now: phases 0-1
        LDY TL_R        ; of T_WAVE1, or 2-3 (its 0-1) of T_WAVE2
        CMP #2
        BCS TW_PRF2
        LDA TLW1,Y      ; T_WAVE1's kind, if the row has one
        BNE TW_L0
        BEQ TW_L2       ; (row 1: only T_WAVE2's)
TW_PRF2 LDA TLW2,Y      ; T_WAVE2's kind, if the row has one
        BNE TW_L2B
        LDA TLW1,Y      ; (row 9: only T_WAVE1's)
TW_L0   STA TLTILE,X
        LDA #0          ; in step with WAVE_ANI's phase
        BEQ TW_SET
TW_L2   LDA TLW2,Y
TW_L2B  STA TLTILE,X
        LDA #WV_PH/2    ; T_WAVE2's kind runs 2 phases behind
TW_SET  STA TLLAG,X
        LDA TL_C
        STA TLCOL,X
        LDA TL_R
        STA TLROW,X
        JSR TL_PHASE    ; armed if its wave shows now, else not yet
        EOR TLLAG,X
        CMP #WV_PH-1
        LDA #0
        BCS TW_ARM      ; calm (phase 3): wait for the crest
        LDA #1
TW_ARM  STA TLARM,X
        TXA             ; the next slot after this one
        CLC
        ADC #1
        AND #TL_N-1
        STA TLNEXT
        LDA TLTILE,X
        LDX TL_C
        LDY TL_R
        JMP MAP_PUT

; ---------------------------------------------------------------------
;  TL_END -- slot X's wake ends: its square is drawn as it should be
;  (item or terrain), unless something else has been drawn over the
;  wake since.  X kept; trashes A, Y, ZPTR, MTILE.
; ---------------------------------------------------------------------
TL_END  STX TL_S
        LDY TLROW,X
        LDA ROWLO,Y     ; the square's screen address
        STA ZPTR
        LDA ROWHI,Y
        STA ZPTR+1
        LDA TLCOL,X
        ASL A           ; two characters per square
        TAY
        LDA TLTILE,X
        TAX
        LDA (ZPTR),Y    ; top left still the wake's?
        CMP TILECH,X
        BNE TE_FREE
        TYA
        CLC
        ADC #MAPCOLS    ; bottom left
        TAY
        LDA (ZPTR),Y
        CMP TILECBL,X
        BNE TE_FREE
        LDX TL_S
        LDY TLROW,X
        LDA TLCOL,X
        TAX
        JSR MAP_GET     ; A = item (0: terrain)
        JSR MAP_SET     ; drawn as it should be
TE_FREE LDX TL_S
        LDA #0
        STA TLTILE,X
        RTS

; Per square row 0-10: the plain open sea a wake may be drawn on ($FF:
; none in this row), the wave tile with a crest when the wave phase is
; 0-1 (TLW1) and when it is 2-3 (TLW2); 0 if the row has none
TLSEA   .BYTE $FF,T_SEAB1,T_SEA,T_SEA,T_SEA,T_SEA,T_SEA,T_SEA,T_SEA,T_SEAB9,$FF
TLW1    .BYTE 0,0,T_WAVE1,T_WAVE1,T_WAVE1,T_WAVE1,T_WAVE1,T_WAVE1,T_WAVE1,T_WAVE1C,0
TLW2    .BYTE 0,T_WAVE2B,T_WAVE2,T_WAVE2,T_WAVE2,T_WAVE2,T_WAVE2,T_WAVE2,T_WAVE2,0,0
