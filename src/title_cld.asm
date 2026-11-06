; =====================================================================
;  TITLE_CLD.ASM -- the title screen's clouds (T-REL-4, D70), generated
;  by tools/mktitle.py; do not edit.  Constant tables, with TITLE.ASM.
; =====================================================================

TC_NUM  =  11           ; clouds
TC_PAIR =  6           ; the first pair of lines with a cloud
TC_NPR  =  57           ; pairs of lines in TCP0 / TCP1 / TCP2

; per cloud: the first and last+1 pair of lines whose TT_DLI entry is its
; position, lane (0: P0 + P1, 1: P2), start position, frames a clock - 1
TC_A
        .BYTE $04,$0F,$19,$25,$30,$3B,$09,$14,$1F,$2B,$36
TC_E
        .BYTE $09,$13,$1E,$29,$35,$3F,$0D,$18,$23,$2F,$3A
TC_L
        .BYTE $00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01
TC_X0
        .BYTE $96,$3C,$BE,$64,$1E,$AA,$5A,$DC,$8C,$0A,$78
TC_PER
        .BYTE $06,$08,$0A,$0E,$12,$18,$07,$09,$0C,$10,$14
; the players, quadruple width, from pair TC_PAIR (P/M line 16+TC_PAIR)
TCP0
        .BYTE $0F,$7F,$7F,$00,$00,$00,$00,$00,$00,$00,$00,$7F,$3F,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$1F,$FF,$7F,$00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$7F,$1F,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1F,$7F,$7F,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$FF,$3F
TCP1
        .BYTE $F8,$FE,$F0,$00,$00,$00,$00,$00,$00,$00,$00,$F8,$E0,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$FC,$FF,$FC,$00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$FC,$F8,$00,$00,$00,$00,$00,$00,$00,$00,$00,$F8,$FF,$F8,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$F0,$E0
TCP2
        .BYTE $00,$00,$00,$00,$00,$FE,$1E,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .BYTE $7F,$3E,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7E,$38,$00,$00,$00
        .BYTE $00,$00,$00,$00,$00,$00,$00,$FF,$3E,$00,$00,$00,$00,$00,$00,$00
        .BYTE $00,$00,$7F,$3C,$00,$00,$00,$00,$00
