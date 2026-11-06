; =====================================================================
;  FONT_PAUSE.ASM -- the pause band's font (D69)
;
;  PAUSED across the bottom of the map, in its last three mode 4
;  character rows (PB_ROW to PB_ROW+2, the wide corner rows): each
;  letter is the help font's 3 x 5 glyph (tools/mkfont.py GLYPHS) with
;  every line doubled, as in mode 5, 10 lines in the band's 24, from
;  line 7.  Code 0 is blank; letter n (0-5 for P A U S E D) is code
;  1+3n in row PB_ROW, 2+3n in PB_ROW+1 and 3+3n in PB_ROW+2.  Pixels
;  are 01: PF0, which the band's rows set to the text colour
;  (VD_SHADE).  Only the first 19 characters are used; the rest of the
;  1K is free.
; =====================================================================

        *= PSFONTA        ; 1K aligned (MEM_A800.ASM / MEM_5200.ASM)
PSFONT
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00   ; 0: blank
        .BYTE $00,$00,$00,$00,$00,$00,$00,$50   ; 1: P top
        .BYTE $50,$44,$44,$50,$50,$40,$40,$40   ; 2: P middle
        .BYTE $40,$00,$00,$00,$00,$00,$00,$00   ; 3: P bottom
        .BYTE $00,$00,$00,$00,$00,$00,$00,$10   ; 4: A top
        .BYTE $10,$44,$44,$54,$54,$44,$44,$44   ; 5: A middle
        .BYTE $44,$00,$00,$00,$00,$00,$00,$00   ; 6: A bottom
        .BYTE $00,$00,$00,$00,$00,$00,$00,$44   ; 7: U top
        .BYTE $44,$44,$44,$44,$44,$44,$44,$54   ; 8: U middle
        .BYTE $54,$00,$00,$00,$00,$00,$00,$00   ; 9: U bottom
        .BYTE $00,$00,$00,$00,$00,$00,$00,$14   ; 10: S top
        .BYTE $14,$40,$40,$10,$10,$04,$04,$50   ; 11: S middle
        .BYTE $50,$00,$00,$00,$00,$00,$00,$00   ; 12: S bottom
        .BYTE $00,$00,$00,$00,$00,$00,$00,$54   ; 13: E top
        .BYTE $54,$40,$40,$50,$50,$40,$40,$54   ; 14: E middle
        .BYTE $54,$00,$00,$00,$00,$00,$00,$00   ; 15: E bottom
        .BYTE $00,$00,$00,$00,$00,$00,$00,$50   ; 16: D top
        .BYTE $50,$44,$44,$44,$44,$44,$44,$50   ; 17: D middle
        .BYTE $50,$00,$00,$00,$00,$00,$00,$00   ; 18: D bottom
