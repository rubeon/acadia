; =====================================================================
;  TRAIL.ASM -- boats leave a fading wake (D64; was dots, D63,
;  sparkles, D62, and waves, D59)
;
;  When a steered boat's centre moves on to a new square, the square
;  it left gets a thin dashed line if it is open sea with nothing on
;  it (plain sea, or one of the ambient waves or sparkles, which come
;  back after): along the boat's waterline if it moved across (its
;  column changed), down the middle if it moved up or down.  After
;  WK_RATE frames the dashes thin to dots, after as many more the
;  square is drawn as it should be again.  The lines are characters
;  (WK_H1 ... WK_V2B, TILES.ASM) written straight into screen memory:
;  across, the bottom two; up and down, the right two.  The corner
;  rows' halves (D55) take the ones on PF0 sea (TLBND).  A wake is
;  never drawn over an item, and only changed or taken off the map
;  while its square still shows it (a wreck or a boat drawn there
;  since stays).
; =====================================================================

; TL_N (wakes at once) is in VARS.ASM, which reserves the slots
WK_RATE =  16           ; frames per fade step (a boat crosses a
                        ; square in 12 or more)

; ---------------------------------------------------------------------
;  TRAIL_INIT -- no wakes, no boat out.  Call after MAP_DRAW.
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
;  TRAIL_TIC -- once a frame during play: every wake fades, and a new
;  one goes on each square a steered boat has just left.
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
TT_MOVE LDY #0          ; across (the column changed) or up / down
        LDA TLLC,X
        CMP CURCOL,X
        BNE TT_DIR
        INY
TT_DIR  STY TL_D
        STA TL_C        ; the square it left
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
;  TL_AGE -- every wake's time runs down; at 0 it fades a step.
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
;  TL_WAKE -- a wake (direction TL_D: 0 across, 1 up / down) on square
;  TL_C, TL_R if it is open sea with nothing on it.
;  Trashes A, X, Y, ZPTR, MTILE.
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
TW_OK   LDX #TL_N-1     ; already a wake there (the boat came back):
TW_DUP  LDA TLSTEP,X    ; it ends, this one replaces it
        BEQ TW_DUPN
        LDA TLCOL,X
        CMP TL_C
        BNE TW_DUPN
        LDA TLROW,X
        CMP TL_R
        BNE TW_DUPN
        JSR TL_END
TW_DUPN DEX
        BPL TW_DUP
        LDX TLNEXT      ; the next slot; if in use, its wake ends now
        LDA TLSTEP,X
        BEQ TW_FREE
        JSR TL_END
TW_FREE LDA TL_C
        STA TLCOL,X
        LDA TL_R
        STA TLROW,X
        LDA TL_D
        STA TLDIR,X
        LDA #WK_STEPS   ; dashes first
        STA TLSTEP,X
        LDA #WK_RATE
        STA TLTIME,X
        TXA             ; the next slot after this one
        CLC
        ADC #1
        AND #TL_N-1
        STA TLNEXT
        JMP TL_PUT

; ---------------------------------------------------------------------
;  TL_FADE -- slot X's wake a step fainter, or gone (its square drawn
;  as it should be: item or terrain); only if the square still shows
;  it, else the slot is just freed.
;  TL_END  -- slot X's wake gone now, the same way.
;  X kept; trashes A, Y, ZPTR, MTILE.
; ---------------------------------------------------------------------
TL_END  STX TL_S
        JSR TL_SHOWN
        BCC TF_FREE
        BCS TF_END

TL_FADE STX TL_S
        JSR TL_SHOWN
        BCC TF_FREE     ; something else drawn over it
        DEC TLSTEP,X
        BEQ TF_END
        LDA #WK_RATE
        STA TLTIME,X
        JMP TL_PUT      ; the fainter line
TF_END  LDY TLROW,X
        LDA TLCOL,X
        TAX
        JSR MAP_GET     ; A = item (0: terrain)
        JSR MAP_SET     ; drawn as it should be
TF_FREE LDX TL_S
        LDA #0
        STA TLSTEP,X
        RTS

; ---------------------------------------------------------------------
;  TL_PUT -- draw slot X's line at its step.  TL_SHOWN -- C set if its
;  square still shows it (its first character).  Both keep X; trash
;  A, Y, ZPTR.
; ---------------------------------------------------------------------
TL_PUT  JSR TL_FIRST    ; TL_K1, ZPTR, Y: the first character
        STA (ZPTR),Y
        LDA TLDIR,X
        BNE TP_V
        INY             ; across: the bottom right one too
        LDA TL_K1
        STA (ZPTR),Y
        RTS
TP_V    LDA #2          ; up / down: the bottom right one, its own sea
        JSR TL_CODE
        PHA
        LDA TL_Y        ; (TL_CODE trashed Y)
        CLC
        ADC #MAPCOLS
        TAY
        PLA
        STA (ZPTR),Y
        RTS

TL_SHOWN
        JSR TL_FIRST
        CMP (ZPTR),Y
        BNE TS_NO
        SEC
        RTS
TS_NO   CLC
        RTS

; TL_FIRST -- slot X's first character: A = TL_K1 = its code, ZPTR + Y
; (also TL_Y) = where it goes (across: bottom left; up / down: top
; right).  Keeps X.
TL_FIRST
        LDA #2          ; across: the bottom half's sea
        LDY TLDIR,X
        BEQ TF_1
        LDA #1          ; up / down: the top half's sea
TF_1    JSR TL_CODE
        STA TL_K1
        LDY TLROW,X     ; the square's screen address
        LDA ROWLO,Y
        STA ZPTR
        LDA ROWHI,Y
        STA ZPTR+1
        LDA TLCOL,X
        ASL A           ; two characters per square
        LDY TLDIR,X
        BNE TF_V
        ADC #MAPCOLS    ; across: bottom left (carry clear)
        BCC TF_Y        ; always
TF_V    ADC #1          ; up / down: top right (carry clear)
TF_Y    STA TL_Y
        TAY
        LDA TL_K1
        RTS

; TL_CODE -- A = slot X's character for a half (A = 1 top, 2 bottom):
; WKCODE by direction, the half's sea (TLBND) and step.  Keeps X.
TL_CODE STA TL_T
        LDY TLROW,X
        LDA TLBND,Y     ; corner rows' sea in this half?
        AND TL_T
        BEQ TK_SEA
        LDA #2
TK_SEA  CLC
        ADC TLSTEP,X    ; + step 1-2
        STA TL_T
        LDA TLDIR,X
        ASL A
        ASL A           ; + 4 x direction
        CLC
        ADC TL_T
        TAY
        LDA WKCODE-1,Y
        RTS

; Per square row 0-10: the open sea a wake may be drawn on, and which
; halves are on the corner rows' PF0 sea (1 top, 2 bottom, D55)
TLSEA   .BYTE T_SEAB,T_SEAB1,T_SEA,T_SEA,T_SEA,T_SEA,T_SEA,T_SEA,T_SEA,T_SEAB9,T_SEAB
TLBND   .BYTE 3,1,0,0,0,0,0,0,0,2,3
; The wake characters: across, then up / down; each on COLBK sea
; (steps 1, 2), then on PF0 sea
WKCODE  .BYTE WK_H1,WK_H2,WK_H1B,WK_H2B,WK_V1,WK_V2,WK_V1B,WK_V2B
