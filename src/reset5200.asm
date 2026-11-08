; =====================================================================
;  RESET5200.ASM -- the 5200's RESET key (D76)
;
;  Part of the 5200's platform layer (PLAT_5200.ASM), on its own so it
;  can sit in code block 2: block 1 ($4000-$4FFF) is full.  Uses
;  PV_OLD from PLAT_5200.ASM and SK_KEY from INPUT5200.ASM.
; =====================================================================

; ---------------------------------------------------------------------
;  PLAT_RST -- the RESET key (INPUT5200.ASM): back to the title screen,
;  as at power-on (D76).  The 5200's RESET is only a keypad key: the
;  BIOS does nothing with it, and the machine and RAM stay as they
;  are.  So: sound off, a black screen (the DLIs and VBI that colour
;  it stop), the BIOS's deferred VBI back in VVBLKD (else
;  PLAT_INIT and DISP_INIT would chain our VBIs to themselves), wait
;  until RESET is let go and its contacts have settled (else the new
;  title would see it held as a new press), then RESTART (MAIN.ASM).
;  Entered by JMP from anywhere in the game; never returns.
; ---------------------------------------------------------------------
PLAT_RST
        JSR SND_INIT    ; no note left sounding
        LDA #0
        STA NMIEN       ; no VBI or DLI while the vector is patched
        STA DMACTL      ; and a black screen while RESET is held:
        STA SDMCTL      ; no playfield (DISP_INIT turns it on again),
        STA GRACTL      ; no players or missiles,
        STA COLBK       ; black border
        LDX #GRAFM-GRAFP0
RS_PM   STA GRAFP0,X    ; and nothing left in their latches
        DEX
        BPL RS_PM
        LDA PV_OLD
        STA VVBLKD
        LDA PV_OLD+1
        STA VVBLKD+1
RS_KEY  LDA SKSTAT      ; until no key is held on the keypad
        AND #SK_KEY
        BEQ RS_KEY
        LDX #RS_FRMS    ; then RS_FRMS frames of nothing (NMIs are
RS_TOP  LDA VCOUNT      ; off, so VCOUNT counts them): the top of a
        BNE RS_TOP      ; frame,
RS_LINE LDA VCOUNT      ; then past it
        BEQ RS_LINE
        DEX
        BNE RS_TOP
        JMP RESTART

RS_FRMS =  6            ; PLAT_RST: frames to let RESET's contacts settle
