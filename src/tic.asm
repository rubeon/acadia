; =====================================================================
;  TIC.ASM -- the 20 Hz game tic and the seconds count (D20)
;
;  Game logic runs on 20 tics per second, like the original, on both
;  TV standards.  The VBI only counts frames (FRAME); the main loop
;  calls TIC_POLL, which turns the frames since its last call into
;  due tics using a per-standard pattern, so a slow main-loop pass
;  delays tics but never loses them:
;
;    NTSC  60 Hz  period 3  0,0,1        -> 1 tic per 3 frames
;    PAL   50 Hz  period 5  0,1,0,0,1    -> 2 tics per 5 frames
;
;  The standard comes from GTIA's PAL register at TIC_INIT.
;
;  Use:   JSR TIC_POLL
;  TI_LP  JSR TIC_NEXT      ; C clear: no tic due
;         BCC done
;         ...one tic of game logic...; Z set: a new second began
;         JMP TI_LP
; =====================================================================

; ---------------------------------------------------------------------
;  TIC_INIT -- detect NTSC/PAL and start counting from now
;  Trashes A.
; ---------------------------------------------------------------------
TIC_INIT
        LDA PAL
        AND #$0E        ; bits 1-3 clear on a PAL machine
        BEQ TI_PAL
        LDA #TP_NTSC-TICPAT
        STA TICOFS
        LDA #3
        BNE TI_STD
TI_PAL  LDA #TP_PAL-TICPAT
        STA TICOFS
        LDA #5
TI_STD  STA TICLEN
        LDA #0
        STA TICPH
        STA TICSEC
        ; fall through into TIC_SYNC

; ---------------------------------------------------------------------
;  TIC_SYNC -- forget frames passed so far (e.g. after a pause)
;  Trashes A.
; ---------------------------------------------------------------------
TIC_SYNC
        LDA FRAME
        STA LASTFR
        LDA #0
        STA TICDUE
        RTS

; ---------------------------------------------------------------------
;  TIC_POLL -- add the tics due for the frames since the last call
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
TIC_POLL
        LDA FRAME
        SEC
        SBC LASTFR      ; frames elapsed (wraps correctly at 256)
        BEQ TP_DONE
        TAX
        LDA FRAME
        STA LASTFR
TP_FRM  LDY TICPH       ; next phase of the pattern
        INY
        CPY TICLEN
        BCC TP_PH
        LDY #0
TP_PH   STY TICPH
        TYA
        CLC
        ADC TICOFS
        TAY
        LDA TICPAT,Y
        BEQ TP_NEXT
        INC TICDUE
TP_NEXT DEX
        BNE TP_FRM
TP_DONE RTS

; ---------------------------------------------------------------------
;  TIC_NEXT -- take one due tic
;  Out: C clear if none is due.  C set: one tic taken; A = TICSEC
;  (0-19, tic within the second) and Z set when a new second begins.
; ---------------------------------------------------------------------
TIC_NEXT
        LDA TICDUE
        BEQ TN_NONE
        DEC TICDUE
        LDA TICSEC
        CLC
        ADC #1
        CMP #20
        BCC TN_SEC
        LDA #0
TN_SEC  STA TICSEC
        LDA TICSEC      ; Z = new second
        SEC
        RTS
TN_NONE CLC
        RTS

; Frame patterns: 1 = a tic is due on this frame
TICPAT
TP_NTSC .BYTE 0,0,1
TP_PAL  .BYTE 0,1,0,0,1
