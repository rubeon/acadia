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
INSVOL  .BYTE 8,7
INSSUS  .BYTE 4,3

; AUDF of notes 1-36, C3-B5, at the 64 kHz clock (pure tone; within
; 1.3 % of equal temperament)
NOTEF   .BYTE 243,230,217,204,193,182,172,162,153,144,136,128
        .BYTE 121,114,108,102,96,91,85,81,76,72,68,64
        .BYTE 60,57,53,50,47,45,42,40,37,35,33,31

; per tune: loops?, each voice's start in MUSDAT
MUSLP   .BYTE 1,0
MUSV0   .BYTE MT_MEL-MUSDAT,MF_MEL-MUSDAT
MUSV1   .BYTE MT_BAS-MUSDAT,MF_BAS-MUSDAT

; lengths (frames): a 4/4 bar of the title is MW; the title moves in
; halves and quarters only (D45)
MQ      =  30           ; quarter
MH      =  60           ; half
MDH     =  90           ; dotted half
MW      =  120          ; whole

MUSDAT
; title, melody: 9 bars of slow 4/4 in D minor, few and long notes
; (Dm Bb F C Dm Gm A Dm, then a bar's rest before it comes round)
MT_MEL  .BYTE N_A4,MW
        .BYTE N_G4,MH, N_F4,MH
        .BYTE N_A4,MDH, N_C5,MQ
        .BYTE N_G4,MW
        .BYTE N_F4,MH, N_A4,MH
        .BYTE N_D5,MDH, N_C5,MQ
        .BYTE N_E4,MH, N_CS4,MH
        .BYTE N_D4,MW
        .BYTE 0,MW
        .BYTE $FF
; title, bass: one root a bar
MT_BAS  .BYTE N_D3,MW, N_AS3,MW, N_F3,MW, N_C3,MW
        .BYTE N_D3,MW, N_G3,MW, N_A3,MW, N_D3,MW
        .BYTE 0,MW
        .BYTE $FF
; fanfare, melody: up the D minor chord, a step down to D
MF_MEL  .BYTE N_A4,8, N_D5,8, N_F5,8, N_E5,12, N_D5,36
        .BYTE $FF
; fanfare, bass: D, A, D
MF_BAS  .BYTE N_D3,24, N_A3,12, N_D3,36
        .BYTE $FF
MUSEND
