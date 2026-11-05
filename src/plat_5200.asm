; =====================================================================
;  PLAT_5200.ASM -- the 5200 build's platform hooks (D62)
;
;  MAIN.ASM calls PLAT_INIT after VARS_INIT, and MAP_LOAD calls
;  PLAT_MAP after copying a map's block over the live tables.
;
;  The cartridge can't load RAM, so PLAT_INIT sets up what the 800's
;  XEX loads or its OS keeps: the shadow bytes the BIOS lacks (CHBAS,
;  GPRIOR, COLRSH, DRKMSK, HW_5200.ASM) and map 1 in the live tables.
;  The map fonts are ROM, but WAVE_ANI writes into them, so PLAT_MAP
;  copies the live map's fonts into RAM (RMFONT0-2) and points ROWFONT
;  and FONTPG there.  PLAT_VBI, chained after the deferred VBI, copies
;  CHBAS and GPRIOR to the hardware each frame, as the 800's OS does.
; =====================================================================

PV_OLD  =  PLATRAM+4    ; 2 bytes: the BIOS's deferred VBI vector
PM_ORG  =  PLATRAM+6    ; PLAT_MAP: FONTPG's ROM pages (N_FONTS bytes)
PM_I    =  PLATRAM+9    ; PLAT_MAP: font index
PM_N    =  PLATRAM+10   ; PLAT_MAP: pages left to copy

; ---------------------------------------------------------------------
;  PLAT_INIT -- the shadow bytes, PLAT_VBI after the deferred VBI, and
;  map 1 in the live tables (with its fonts in RAM).  Before DISP_INIT,
;  which saves VVBLKD (now PLAT_VBI) as VBI_D's next handler.
;  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
PLAT_INIT
        LDA #ROMFONT    ; the BIOS font until a screen sets one
        STA CHBAS
        LDA #0
        STA GPRIOR
        STA COLRSH      ; no attract mode colours yet (T-5200-3)
        LDA #$FF
        STA DRKMSK
        STA MAPLD       ; no map in the live tables: MAP_LOAD copies

        LDA #0
        STA NMIEN       ; no VBI while the vector is patched
        LDA VVBLKD      ; PLAT_VBI, then the BIOS's deferred VBI
        STA PV_OLD
        LDA VVBLKD+1
        STA PV_OLD+1
        LDA #<PLAT_VBI
        STA VVBLKD
        LDA #>PLAT_VBI
        STA VVBLKD+1
        LDA #NMI_VBI
        STA NMIEN
        JSR IN_INIT     ; the controllers (INPUT5200.ASM)

        LDA #0          ; map 1, as the 800's XEX loads it
        JMP MAP_LOAD

; ---------------------------------------------------------------------
;  PLAT_VBI -- end of the deferred VBI (VBI_D chains here through
;  OLDVBD): the font and priority shadows to the hardware, then the
;  BIOS's own deferred VBI
; ---------------------------------------------------------------------
PLAT_VBI
        LDA CHBAS
        STA CHBASE
        LDA GPRIOR
        STA PRIOR
        JMP (PV_OLD)

; ---------------------------------------------------------------------
;  PLAT_MAP -- the live map's fonts into RAM.  Each font page in FONTPG
;  is copied into RAM slot i (RANDOM lists one page N_FONTS times; it
;  is copied once), and FONTPG and the ROWFONT entries with that page
;  then point at the copy.  ROWFONT pages not in FONTPG (the corner
;  font of every map's corner rows, D65) stay on ROM: nothing writes
;  them.  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
PLAT_MAP
        LDX #0
PM_FONT LDA FONTPG,X    ; font i's ROM page
        STA PM_ORG,X
        STX PM_I
        LDY #0
PM_DUP  CPY PM_I        ; an earlier font on the same page?
        BEQ PM_COPY
        CMP PM_ORG,Y
        BEQ PM_SAME
        INY
        BNE PM_DUP
PM_SAME LDA FONTPG,Y    ; yes: its RAM copy
        STA FONTPG,X
        BNE PM_NEXT     ; (never page 0)
PM_COPY STA TPTR+1      ; no: copy the 1K into slot i
        LDA PMSLOT,X
        STA FONTPG,X
        STA ZPTR+1
        LDY #0
        STY TPTR
        STY ZPTR
        LDA #4
        STA PM_N
PM_PAGE LDA (TPTR),Y
        STA (ZPTR),Y
        INY
        BNE PM_PAGE
        INC TPTR+1
        INC ZPTR+1
        DEC PM_N
        BNE PM_PAGE
PM_NEXT LDX PM_I
        INX
        CPX #N_FONTS
        BNE PM_FONT

        LDY #MAPCROWS-1 ; each character row's font
PM_ROW  LDA ROWFONT,Y
        LDX #N_FONTS-1
PM_RF   CMP PM_ORG,X
        BEQ PM_RSET
        DEX
        BPL PM_RF
        BMI PM_RNXT     ; not one of FONTPG's: stays on ROM
PM_RSET LDA FONTPG,X
        STA ROWFONT,Y
PM_RNXT DEY
        BPL PM_ROW
        RTS

PMSLOT  .BYTE >RMFONT0,>RMFONT1,>RMFONT2
