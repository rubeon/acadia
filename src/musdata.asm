; =====================================================================
;  MUSDATA.ASM -- the music's tables and tunes (MUSIC.ASM, D42, D45,
;  D85).  Constants only.  On the 800 after the summary page (code
;  block 2 is full); on the 5200 after MUSIC.ASM.  MUSDAT is indexed
;  by a byte: it must stay under 256 bytes.
; =====================================================================

; per voice (melody, bass): distortion, starting volume, sustain volume
INSDIST .BYTE SD_PURE,SD_PURE
INSVOL  .BYTE 8,7
INSSUS  .BYTE 4,5

; AUDF of notes 1-36, C3-B5, at the 64 kHz clock (pure tone; within
; 1.3 % of equal temperament)
NOTEF   .BYTE 243,230,217,204,193,182,172,162,153,144,136,128
        .BYTE 121,114,108,102,96,91,85,81,76,72,68,64
        .BYTE 60,57,53,50,47,45,42,40,37,35,33,31

; AUDF2:AUDF1 of the bass notes (B_ equates: A1 D2), voices
; 1+2 joined at 1.79 MHz: f = 1789773 / (2 x (AUDF + 7)) Hz, within
; 0.01 % of equal temperament
BASFL   .BYTE 136,150
BASFH   .BYTE 63,47

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
; title, bass (D85): a drone on low D, a note every 2 bars, under the
; first 6 bars; A for the A bar, D for the last; the rest bar kept
MT_BAS  .BYTE B_D2,MW*2, B_D2,MW*2, B_D2,MW*2
        .BYTE B_A1,MW, B_D2,MW
        .BYTE 0,MW
        .BYTE $FF
; fanfare, melody: up the D minor chord, a step down to D
MF_MEL  .BYTE N_A4,8, N_D5,8, N_F5,8, N_E5,12, N_D5,36
        .BYTE $FF
; fanfare, bass: D, A, D
MF_BAS  .BYTE B_D2,24, B_A1,12, B_D2,36
        .BYTE $FF
MUSEND
