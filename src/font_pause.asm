; =====================================================================
;  FONT_PAUSE.ASM -- the pause band's font (D69)
;
;  PAUSED across the middle of the map, in two mode 4 character rows
;  (PB_ROW, PB_ROW+1): each letter is the help font's 3 x 5 glyph
;  (tools/mkfont.py GLYPHS) with every line doubled, as in mode 5, 10
;  lines in the band's 16, from line 3.  Code 0 is blank, letter n
;  (0-5 for P A U S E D) is code 1+2n for its top half (row PB_ROW)
;  and 2+2n for its bottom half (row PB_ROW+1).  Pixels are 01: PF0,
;  which the band's rows set to the text colour (VD_SHADE).
;  Only the first 13 characters are used; the rest of the 1K is free.
; =====================================================================

        *= PSFONTA        ; 1K aligned (MEM_A800.ASM / MEM_5200.ASM)
PSFONT
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00   ; 0: blank
        .BYTE $00,$00,$00,$50,$50,$44,$44,$50   ; 1: P top
        .BYTE $50,$40,$40,$40,$40,$00,$00,$00   ; 2: P bottom
        .BYTE $00,$00,$00,$10,$10,$44,$44,$54   ; 3: A top
        .BYTE $54,$44,$44,$44,$44,$00,$00,$00   ; 4: A bottom
        .BYTE $00,$00,$00,$44,$44,$44,$44,$44   ; 5: U top
        .BYTE $44,$44,$44,$54,$54,$00,$00,$00   ; 6: U bottom
        .BYTE $00,$00,$00,$14,$14,$40,$40,$10   ; 7: S top
        .BYTE $10,$04,$04,$50,$50,$00,$00,$00   ; 8: S bottom
        .BYTE $00,$00,$00,$54,$54,$40,$40,$50   ; 9: E top
        .BYTE $50,$40,$40,$54,$54,$00,$00,$00   ; 10: E bottom
        .BYTE $00,$00,$00,$50,$50,$44,$44,$44   ; 11: D top
        .BYTE $44,$44,$44,$50,$50,$00,$00,$00   ; 12: D bottom
