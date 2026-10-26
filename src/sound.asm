; =====================================================================
;  SOUND.ASM -- POKEY sound driver and effects (T-SND-1, T-SND-2:
;  R-SND-1, -3, -4; D41)
;
;  Game code calls a hook (SND_BUY, SND_FISH, ...) where something
;  happens; each hook keeps A, X and Y and only starts an effect.  The
;  sound itself runs in the deferred VBI (SND_VBI), so it never holds
;  up the game.
;
;  An effect is a list of steps in SNDDAT, 4 bytes each:
;    frames (0 ends the effect), AUDF, AUDC, slide
;  The step's AUDF and AUDC are written at its first frame; on each
;  further frame AUDF moves by the slide (signed: + lower, - higher).
;
;  Four channels, one per POKEY voice.  A new effect takes a free
;  channel, else the one playing the lowest priority if that is no
;  higher than its own, else it is dropped.  SFXPRI gives each
;  effect's priority.
;
;  While PAUSED is set the driver stands still; PAUSE_ON silences
;  POKEY and each channel rewrites its voice every frame, so play
;  picks up where it was.  AUDCTL stays 0: 64 kHz clock, and bit 7
;  clear so RANDOM keeps its 17-bit polynomial (RAND.ASM).
;
;  All effects are composed for Acadia; none is taken from the
;  original (R-SND-4).  Durations are in frames, so they run 6/5 as
;  long on PAL.
; =====================================================================

SN_CH   =  4            ; channels (POKEY voices)

; effect numbers (offsets into SFXPOS / SFXPRI)
SF_BUY  =  0
SF_REF  =  1
SF_FISH =  2
SF_RAIN =  3
SF_SMIT =  4
SF_SINK =  5
SF_ROUN =  6
SF_REBL =  7
SF_STRM =  8

; AUDC distortions (high nibble; low nibble is the volume)
SD_PURE =  $A0          ; pure tone
SD_NOIS =  $80          ; white noise (17-bit polynomial)
SD_BUZZ =  $C0          ; buzz (4-bit polynomial)

; ---------------------------------------------------------------------
;  SND_INIT -- start-up: POKEY quiet, no effect playing.  Trashes A, X.
; ---------------------------------------------------------------------
SND_INIT
        LDA #0
        STA AUDCTL
        LDX #SN_CH-1
SI_CH   STA SN_ON,X
        DEX
        BPL SI_CH
        ; fall through

; SND_OFF -- silence all four voices.  Trashes A.
SND_OFF LDA #0
        STA AUDC1
        STA AUDC2
        STA AUDC3
        STA AUDC4
        RTS

; ---------------------------------------------------------------------
;  The hooks: each starts its effect and keeps A, X and Y.
; ---------------------------------------------------------------------
; SND_BUY -- an item was bought
SND_BUY PHA
        LDA #SF_BUY
        JMP SND_GO

; SND_REFUSE -- a purchase or a key was refused
SND_REFUSE
        PHA
        LDA #SF_REF
        JMP SND_GO

; SND_FISH -- a fishing boat caught 1 gold
SND_FISH
        PHA
        LDA #SF_FISH
        JMP SND_GO

; SND_RAIN -- rain over crops earned 1 gold
SND_RAIN
        PHA
        LDA #SF_RAIN
        JMP SND_GO

; SND_SMITE -- weather or a rebel destroyed an item
SND_SMITE
        PHA
        LDA #SF_SMIT
        JMP SND_GO

; SND_SINK -- a boat sank
SND_SINK
        PHA
        LDA #SF_SINK
        JMP SND_GO

; SND_ROUND -- end of a round
SND_ROUND
        PHA
        LDA #SF_ROUN
        JMP SND_GO

; SND_REBEL -- a rebel appeared
SND_REBEL
        PHA
        LDA #SF_REBL
        JMP SND_GO

; SND_STORM -- a tropical storm or a hurricane appeared
SND_STORM
        PHA
        LDA #SF_STRM
        ; fall through

; SND_GO -- the hooks' tail: start effect A, then restore X, Y and the
; A each hook pushed.
SND_GO  STX SN_SX
        STY SN_SY
        JSR SND_PLAY
        LDX SN_SX
        LDY SN_SY
        PLA
        RTS

; ---------------------------------------------------------------------
;  SND_PLAY -- start effect A on a channel (see above).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
SND_PLAY
        TAY
        LDX #SN_CH-1    ; a free channel?
SP_FREE LDA SN_ON,X
        BEQ SP_GOT
        DEX
        BPL SP_FREE
        LDX #SN_CH-1    ; else the lowest priority playing
        STX SN_T
SP_LOW  LDA SN_PRI,X
        STX SN_I
        LDX SN_T
        CMP SN_PRI,X
        LDX SN_I
        BCS SP_NEXT
        STX SN_T        ; lower than the best so far
SP_NEXT DEX
        BPL SP_LOW
        LDX SN_T
        LDA SFXPRI,Y    ; only if that is no higher than ours
        CMP SN_PRI,X
        BCS SP_GOT
        RTS             ; dropped
SP_GOT  LDA #0          ; the VBI leaves the channel alone while it is
        STA SN_ON,X     ; set up
        LDA SFXPRI,Y
        STA SN_PRI,X
        LDA SFXPOS,Y
        STA SN_POS,X
        LDA #1          ; first step at the next VBI
        STA SN_CNT,X
        STA SN_ON,X
        RTS

; ---------------------------------------------------------------------
;  SND_VBI -- one frame of every channel.  From the deferred VBI.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
SND_VBI
        LDA PAUSED
        BNE SV_DONE
        LDX #SN_CH-1
SV_CH   LDA SN_ON,X
        BEQ SV_NEXT
        DEC SN_CNT,X
        BNE SV_SLID
        LDY SN_POS,X    ; the next step
        LDA SNDDAT,Y
        BEQ SV_END
        STA SN_CNT,X
        LDA SNDDAT+1,Y
        STA SN_F,X
        LDA SNDDAT+2,Y
        STA SN_C,X
        LDA SNDDAT+3,Y
        STA SN_D,X
        TYA
        CLC
        ADC #4
        STA SN_POS,X
        JMP SV_OUT
SV_SLID LDA SN_F,X      ; same step: slide
        CLC
        ADC SN_D,X
        STA SN_F,X
SV_OUT  TXA             ; write the voice: AUDF1 + 2 x channel
        ASL A
        TAY
        LDA SN_F,X
        STA AUDF1,Y
        LDA SN_C,X
        STA AUDC1,Y
SV_NEXT DEX
        BPL SV_CH
SV_DONE RTS
SV_END  LDA #0          ; done: free and quiet
        STA SN_ON,X
        TXA
        ASL A
        TAY
        LDA #0
        STA AUDC1,Y
        JMP SV_NEXT

; ---------------------------------------------------------------------
;  The effects.  SFXPOS: each one's first step in SNDDAT; SFXPRI: its
;  priority (higher wins a channel).
; ---------------------------------------------------------------------
SFXPOS  .BYTE SX_BUY-SNDDAT,SX_REF-SNDDAT,SX_FISH-SNDDAT,SX_RAIN-SNDDAT
        .BYTE SX_SMIT-SNDDAT,SX_SINK-SNDDAT,SX_ROUN-SNDDAT,SX_REBL-SNDDAT
        .BYTE SX_STRM-SNDDAT
SFXPRI  .BYTE 2,2,1,1,4,4,5,3,3

; AUDF at the 64 kHz clock: f = 63921 / (2 x (AUDF + 1)) Hz;
; 121 is about C4, 60 C5, 47 E5, 40 G5, 29 C6.
SNDDAT
; buy: a quick rising pair
SX_BUY  .BYTE 4,60,SD_PURE+8,0, 3,40,SD_PURE+10,0, 5,40,SD_PURE+5,0
        .BYTE 0
; refuse: a short falling buzz
SX_REF  .BYTE 14,140,SD_BUZZ+8,2, 4,170,SD_BUZZ+4,0
        .BYTE 0
; fish: a high ping that dies away
SX_FISH .BYTE 2,26,SD_PURE+12,0, 3,26,SD_PURE+8,0, 4,26,SD_PURE+5,0
        .BYTE 5,26,SD_PURE+2,0
        .BYTE 0
; rain: two soft drops
SX_RAIN .BYTE 3,47,SD_PURE+6,0, 3,47,SD_PURE+2,0, 3,35,SD_PURE+6,0
        .BYTE 4,35,SD_PURE+2,0
        .BYTE 0
; item destroyed: a crash of noise falling away
SX_SMIT .BYTE 4,8,SD_NOIS+14,1, 8,20,SD_NOIS+10,3, 12,60,SD_NOIS+6,5
        .BYTE 10,120,SD_NOIS+3,6
        .BYTE 0
; boat sunk: a falling glide, then a low gurgle
SX_SINK .BYTE 32,30,SD_PURE+10,3, 6,140,SD_BUZZ+6,0, 6,160,SD_BUZZ+4,0
        .BYTE 8,180,SD_BUZZ+2,0
        .BYTE 0
; end of round: three notes up and a held fourth
SX_ROUN .BYTE 7,60,SD_PURE+10,0, 7,47,SD_PURE+10,0, 7,40,SD_PURE+10,0
        .BYTE 20,29,SD_PURE+10,0, 10,29,SD_PURE+5,0, 10,29,SD_PURE+2,0
        .BYTE 0
; rebel: two low growls
SX_REBL .BYTE 9,200,SD_BUZZ+10,0, 3,0,0,0, 14,240,SD_BUZZ+10,0
        .BYTE 0
; storm: a far rumble swelling and fading
SX_STRM .BYTE 10,230,SD_NOIS+3,0, 14,230,SD_NOIS+6,0, 16,240,SD_NOIS+4,0
        .BYTE 16,250,SD_NOIS+2,0
        .BYTE 0
SNDEND
