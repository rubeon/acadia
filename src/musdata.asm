; =====================================================================
;  MUSDATA.ASM -- the music's tables and tunes (MUSIC.ASM, D42, D45,
;  D85).  Constants only.  On the 800 after the summary page (code
;  block 2 is full); on the 5200 after MUSIC.ASM.  MUSDAT is indexed
;  by a byte: it must stay under 256 bytes.
; =====================================================================

; per voice (melody, bass): distortion, starting volume, sustain volume
INSDIST .BYTE SD_PURE,SD_PURE
INSVOL  .BYTE 8,8
INSSUS  .BYTE 4,4

; AUDF of notes 1-36, C3-B5, at the 64 kHz clock (pure tone; within
; 1.3 % of equal temperament)
NOTEF   .BYTE 243,230,217,204,193,182,172,162,153,144,136,128
        .BYTE 121,114,108,102,96,91,85,81,76,72,68,64
        .BYTE 60,57,53,50,47,45,42,40,37,35,33,31

; AUDF2:AUDF1 of the bass notes (B_ equates: A1 A#1 C2 C#2 D2 E2 F2 G2 A2 A#2 C3 D3), voices
; 1+2 joined at 1.79 MHz: f = 1789773 / (2 x (AUDF + 7)) Hz, within
; 0.01 % of equal temperament
BASFL   .BYTE 136,246,107,107,150,100,3,165,192,248,178,200
BASFH   .BYTE 63,59,53,50,47,42,40,35,31,29,26,23

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
; title, bass (D85): each bar the root for a half, then a quarter each
; of the fifth and the octave (or third), down in the second octave;
; the A bar walks down to C# into the last D, which is held
MT_BAS  .BYTE B_D2,MH, B_A2,MQ, B_D3,MQ
        .BYTE B_AS1,MH, B_F2,MQ, B_AS2,MQ
        .BYTE B_F2,MH, B_C3,MQ, B_A2,MQ
        .BYTE B_C2,MH, B_G2,MQ, B_C3,MQ
        .BYTE B_D2,MH, B_A2,MQ, B_F2,MQ
        .BYTE B_G2,MH, B_D3,MQ, B_AS2,MQ
        .BYTE B_A1,MH, B_E2,MQ, B_CS2,MQ
        .BYTE B_D2,MW
        .BYTE 0,MW
        .BYTE $FF
; fanfare, melody: up the D minor chord, a step down to D
MF_MEL  .BYTE N_A4,8, N_D5,8, N_F5,8, N_E5,12, N_D5,36
        .BYTE $FF
; fanfare, bass: D, A, D
MF_BAS  .BYTE B_D2,24, B_A1,12, B_D2,36
        .BYTE $FF
MUSEND
