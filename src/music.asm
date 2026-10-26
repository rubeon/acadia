; =====================================================================
;  MUSIC.ASM -- music: a title tune and an end-of-round fanfare
;  (T-SND-3: R-SND-2, -4; D42)
;
;  Two voices, POKEY 1 (melody) and 2 (bass), driven from SND_VBI.
;  While music plays the sound effects use only voices 3 and 4
;  (SN_LO = 2); a tune that starts takes voices 1 and 2 from any effect
;  playing there.  The title tune loops on the setup screen until a
;  game starts; the fanfare plays once at the end of each round.
;
;  Each voice is a list of (note, frames) pairs in MUSDAT: note 1-36 is
;  C3-B5 (NOTEF), 0 a rest, $FF the end (back to the start if the tune
;  loops).  A note starts at its voice's volume (INSVOL) and falls by 1
;  every INSRATE frames to INSSUS; its last frame is silent, so repeated
;  notes are heard apart.  Both tunes are composed for Acadia
;  (R-SND-4).  Lengths are in frames: 6/5 slower on PAL.
; =====================================================================

TU_TITL =  0            ; tunes
TU_FANF =  1
INSRATE =  3            ; frames per volume step down

N_C3  =  1
N_CS3 =  2
N_D3  =  3
N_DS3 =  4
N_E3  =  5
N_F3  =  6
N_FS3 =  7
N_G3  =  8
N_GS3 =  9
N_A3  =  10
N_AS3 =  11
N_B3  =  12
N_C4  =  13
N_CS4 =  14
N_D4  =  15
N_DS4 =  16
N_E4  =  17
N_F4  =  18
N_FS4 =  19
N_G4  =  20
N_GS4 =  21
N_A4  =  22
N_AS4 =  23
N_B4  =  24
N_C5  =  25
N_CS5 =  26
N_D5  =  27
N_DS5 =  28
N_E5  =  29
N_F5  =  30
N_FS5 =  31
N_G5  =  32
N_GS5 =  33
N_A5  =  34
N_AS5 =  35
N_B5  =  36

; ---------------------------------------------------------------------
;  MUS_TITLE -- start the title tune (loops).  MUS_FANF -- start the
;  end-of-round fanfare.  Both keep A, X and Y.
; ---------------------------------------------------------------------
MUS_TITLE
        PHA
        LDA #TU_TITL
        JMP MZ_GO
MUS_FANF
        PHA
        LDA #TU_FANF
MZ_GO   STX SN_SX
        STY SN_SY
        JSR MUS_PLAY
        LDX SN_SX
        LDY SN_SY
        PLA
        RTS

; ---------------------------------------------------------------------
;  MUS_PLAY -- start tune A on voices 1 and 2.  Trashes A, X, Y.
; ---------------------------------------------------------------------
MUS_PLAY
        TAY
        LDA #0          ; the VBI leaves the music alone meanwhile
        STA MZ_ON
        STA SN_ON       ; and no effect on voices 1 and 2
        STA SN_ON+1
        LDA #2
        STA SN_LO
        LDA MUSLP,Y
        STA MZ_LOOP
        LDA MUSV0,Y
        STA MZ_ST
        STA MZ_POS
        LDA MUSV1,Y
        STA MZ_ST+1
        STA MZ_POS+1
        LDA #1
        LDX #1
MP_V    STA MZ_CNT,X    ; first note at the next VBI
        STA MZ_ACT,X
        DEX
        BPL MP_V
        STA MZ_ON
        RTS

; ---------------------------------------------------------------------
;  MUS_STOP -- stop the music; effects get all four voices again.
;  Trashes A.
; ---------------------------------------------------------------------
MUS_STOP
        LDA #0
        STA MZ_ON
        STA SN_LO
        STA AUDC1
        STA AUDC2
        RTS

; ---------------------------------------------------------------------
;  MUS_VBI -- one frame of the music.  From SND_VBI (not while paused).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
MUS_VBI
        LDA MZ_ON
        BNE MV_GO
        RTS
MV_GO   LDX #1
MV_V    LDA MZ_ACT,X
        BEQ MV_NEXT
        JSR MV_ONE
MV_NEXT DEX
        BPL MV_V
        LDA MZ_ACT      ; both voices done: the tune is over
        ORA MZ_ACT+1
        BNE MV_DONE
        STA MZ_ON
        STA SN_LO
MV_DONE RTS

; MV_ONE -- one frame of voice X.  X kept; trashes A, Y.
MV_ONE  DEC MZ_CNT,X
        BNE MV_DEC
        LDY MZ_POS,X    ; the next note
        LDA MUSDAT,Y
        CMP #$FF
        BNE MV_NOTE
        LDA MZ_LOOP     ; the end: again, or this voice is done
        BEQ MV_END
        LDY MZ_ST,X
        LDA MUSDAT,Y
MV_NOTE STA MZ_N
        LDA MUSDAT+1,Y
        STA MZ_CNT,X
        INY
        INY
        TYA
        STA MZ_POS,X
        LDA #0
        STA MZ_DT,X
        LDY MZ_N
        BEQ MV_REST
        LDA NOTEF-1,Y
        STA MZ_F,X
        LDA INSVOL,X
        STA MZ_VOL,X
        JMP MV_OUT
MV_REST STA MZ_VOL,X    ; (A = 0)
        JMP MV_OUT
MV_DEC  INC MZ_DT,X     ; the note dies away to its sustain
        LDA MZ_DT,X
        CMP #INSRATE
        BCC MV_OUT
        LDA #0
        STA MZ_DT,X
        LDA MZ_VOL,X
        CMP INSSUS,X
        BEQ MV_OUT
        BCC MV_OUT
        DEC MZ_VOL,X
MV_OUT  TXA             ; write the voice: AUDF1 + 2 x voice
        ASL A
        TAY
        LDA MZ_F,X
        STA AUDF1,Y
        LDA MZ_VOL,X
        BEQ MV_C
        LDA MZ_CNT,X    ; last frame of the note: silent
        CMP #2
        LDA #0
        BCC MV_C
        LDA MZ_VOL,X
        ORA INSDIST,X
MV_C    STA AUDC1,Y
        RTS
MV_END  LDA #0          ; this voice is done: quiet
        STA MZ_ACT,X
        TXA
        ASL A
        TAY
        LDA #0
        STA AUDC1,Y
        RTS

; per voice: distortion, starting volume, sustain volume
INSDIST .BYTE SD_PURE,SD_PURE
INSVOL  .BYTE 10,9
INSSUS  .BYTE 5,4

; AUDF of notes 1-36, C3-B5, at the 64 kHz clock (pure tone; within
; 1.3 % of equal temperament)
NOTEF   .BYTE 243,230,217,204,193,182,172,162,153,144,136,128
        .BYTE 121,114,108,102,96,91,85,81,76,72,68,64
        .BYTE 60,57,53,50,47,45,42,40,37,35,33,31

; per tune: loops?, each voice's start in MUSDAT
MUSLP   .BYTE 1,0
MUSV0   .BYTE MT_MEL-MUSDAT,MF_MEL-MUSDAT
MUSV1   .BYTE MT_BAS-MUSDAT,MF_BAS-MUSDAT

; lengths (frames): eighth 10, quarter 20, dotted quarter 30, half 40,
; dotted half 60
ME      =  10
MQ      =  20
MDQ     =  30
MH      =  40
MDH     =  60

MUSDAT
; title, melody: 8 bars of 4/4 in C, pentatonic
MT_MEL  .BYTE N_E4,MQ, N_G4,ME, N_A4,ME, N_C5,MQ, N_A4,MQ
        .BYTE N_G4,MDQ, N_E4,ME, N_D4,MH
        .BYTE N_E4,MQ, N_G4,ME, N_A4,ME, N_C5,MQ, N_D5,MQ
        .BYTE N_E5,MDH, 0,MQ
        .BYTE N_D5,MQ, N_C5,ME, N_A4,ME, N_G4,MQ, N_A4,MQ
        .BYTE N_C5,MDQ, N_A4,ME, N_G4,MH
        .BYTE N_E4,MQ, N_D4,ME, N_E4,ME, N_G4,MQ, N_A4,MQ
        .BYTE N_C5,MDH, 0,MQ
        .BYTE $FF
; title, bass: root and fifth in quarters; C G C Am F C G C
MT_BAS  .BYTE N_C3,MQ, N_G3,MQ, N_C3,MQ, N_G3,MQ
        .BYTE N_G3,MQ, N_D3,MQ, N_G3,MQ, N_D3,MQ
        .BYTE N_C3,MQ, N_G3,MQ, N_C3,MQ, N_G3,MQ
        .BYTE N_A3,MQ, N_E3,MQ, N_A3,MQ, N_E3,MQ
        .BYTE N_F3,MQ, N_C4,MQ, N_F3,MQ, N_C4,MQ
        .BYTE N_C3,MQ, N_G3,MQ, N_C3,MQ, N_G3,MQ
        .BYTE N_G3,MQ, N_D3,MQ, N_G3,MQ, N_D3,MQ
        .BYTE N_C3,MQ, N_G3,MQ, N_C3,MH
        .BYTE $FF
; fanfare, melody: up the C chord to a held G
MF_MEL  .BYTE N_G4,6, N_C5,6, N_E5,6, N_G5,12, N_E5,6, N_G5,36
        .BYTE $FF
; fanfare, bass
MF_BAS  .BYTE N_C3,18, N_G3,12, N_C3,42
        .BYTE $FF
MUSEND
