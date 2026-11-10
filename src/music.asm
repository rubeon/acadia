; =====================================================================
;  MUSIC.ASM -- music: a title tune and an end-of-round fanfare
;  (T-SND-3: R-SND-2, -4; D42)
;
;  Two voices, driven from SND_VBI: the melody on POKEY voice 3, and
;  the bass on voices 1 and 2 joined into one 16-bit voice clocked at
;  1.79 MHz (AUDCTL = MZ_CTL; D85), so it reaches down to A1 in tune.
;  Voice 1 is the low byte and stays silent; voice 2 sounds.  While
;  music plays the sound effects use only voice 4 (SN_LO = 3); a tune
;  that starts takes voices 1-3 from any effect playing there.  The
;  title tune loops on the title and setup screens until a game starts;
;  the fanfare plays once at the end of each round.
;
;  Each voice is a list of (note, frames) pairs in MUSDAT: a melody
;  note is 1-36, C3-B5 (NOTEF), a bass note an index into BASFL/BASFH
;  (B_ equates); 0 is a rest, $FF the end (back to the start if the
;  tune loops).  A note starts at its voice's volume (INSVOL) and falls
;  by 1 every INSRATE frames to INSSUS; its last frame is silent, so
;  repeated notes are heard apart.  Both tunes are composed for Acadia
;  (R-SND-4).  Lengths are in frames: 6/5 slower on PAL.  The tables
;  and tunes are in MUSDATA.ASM (on the 800 after the summary page, as
;  code block 2 is full).
; =====================================================================

TU_TITL =  0            ; tunes
TU_FANF =  1
INSRATE =  3            ; frames per volume step down
MZ_CTL  =  $50          ; AUDCTL while music plays: voices 1+2 joined
                        ; (bit 4), voice 1 at 1.79 MHz (bit 6); bit 7
                        ; stays clear (RAND.ASM)

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

; bass notes: indices into BASFL / BASFH (only the notes the tunes use)
B_A1  =  1
B_AS1 =  2
B_C2  =  3
B_CS2 =  4
B_D2  =  5
B_E2  =  6
B_F2  =  7
B_G2  =  8
B_A2  =  9
B_AS2 =  10
B_C3  =  11
B_D3  =  12

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
;  MUS_PLAY -- start tune A on voices 1-3.  Trashes A, X, Y.
; ---------------------------------------------------------------------
MUS_PLAY
        TAY
        LDA #0          ; the VBI leaves the music alone meanwhile
        STA MZ_ON
        STA SN_ON       ; and no effect on voices 1-3
        STA SN_ON+1
        STA SN_ON+2
        STA AUDC1       ; the bass's low byte: never heard
        LDA #3
        STA SN_LO
        LDA #MZ_CTL     ; join voices 1 and 2
        STA AUDCTL
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
        STA AUDC3
MU_OFF  STA SN_LO       ; (A = 0; MUS_VBI joins here at a tune's end)
        STA AUDCTL      ; voices 1 and 2 apart again, 64 kHz
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
        JMP MU_OFF
MV_DONE RTS

; MV_ONE -- one frame of voice X.  X kept; trashes A, Y.
MV_ONE  DEC MZ_CNT,X
        BNE MV_DEC
        LDY MZ_POS,X    ; the next note
        LDA MUSDAT,Y
        CMP #$FF
        BNE MV_NOTE
        LDA MZ_LOOP     ; the end: again, or this voice is done
        BNE MV_AGN
        JMP MV_END      ; (out of a branch's reach)
MV_AGN  LDY MZ_ST,X
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
        LDA MZ_N        ; MZ_F keeps the note; MV_OUT looks it up
        STA MZ_F,X
        BEQ MV_REST
        LDA INSVOL,X
MV_REST STA MZ_VOL,X    ; (a rest: A = 0)
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
MV_OUT  LDY MZ_F,X      ; write the voice (a rest's note 0 reads the
        TXA             ; byte before the table: its volume is 0)
        BNE MV_BAS
        LDA NOTEF-1,Y   ; the melody: voice 3
        STA AUDF3
        JSR MV_VOL
        STA AUDC3
        RTS
MV_BAS  LDA BASFL-1,Y   ; the bass: voices 1+2, 16 bits
        STA AUDF1
        LDA BASFH-1,Y
        STA AUDF2
        JSR MV_VOL
        STA AUDC2
        RTS
; MV_VOL -- A = voice X's AUDC this frame.  Keeps X, Y.
MV_VOL  LDA MZ_VOL,X
        BEQ MV_C
        LDA MZ_CNT,X    ; last frame of the note: silent
        CMP #2
        LDA #0
        BCC MV_C
        LDA MZ_VOL,X
        ORA INSDIST,X
MV_C    RTS
MV_END  LDA #0          ; this voice is done: quiet
        STA MZ_ACT,X
        LDY MZAUDC,X
        STA AUDC1,Y
        RTS

; per voice: its AUDC's offset from AUDC1 (melody voice 3, bass 2)
MZAUDC  .BYTE 4,2

