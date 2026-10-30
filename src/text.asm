; =====================================================================
;  TEXT.ASM -- print into the status bar (two mode 2 lines)
;
;  Positions are offsets into the status lines: 0-39 is line 1
;  (STATUS1), 40-79 is line 2 (STATUS2, which follows it in RAM).
;  Text is in screen codes (MAC/65 .SBYTE): "0" = $10, space = 0.
;  The status font (STFONT, D54) shows them white; TXCOL picks the
;  digits' colour.
; =====================================================================

TX_END  =  $FF          ; string terminator
SC_0    =  $10          ; screen code of "0"
SC_STAR =  $0A          ; screen code of "*" (number too wide)

; ---------------------------------------------------------------------
;  TXT_STR -- print a string
;  In: A/Y = address (low/high) of screen codes ending in TX_END,
;      X = status offset.  Out: X = offset after the string.
;  Trashes A, Y, TPTR.
; ---------------------------------------------------------------------
TXT_STR
        STA TPTR
        STY TPTR+1
        LDY #0
TS_LOOP LDA (TPTR),Y
        CMP #TX_END
        BEQ TS_DONE
        STA STATUS1,X
        INX
        INY
        BNE TS_LOOP
TS_DONE RTS

; ---------------------------------------------------------------------
;  TXT_DEC -- print a number in decimal, right-aligned in a field
;  In: M_NUM = value (24 bits; see NUM16), A = field width (1-5),
;      X = status offset of the field's first character, TXCOL = ORed
;      into each digit and "*" (0 white, TX_RED, TX_TURQ; ST_DEC).
;  Leading zeros become spaces (a zero value prints "0").  A value too
;  wide for the field prints as all "*".  The digits are worked out in
;  TBUF first, so each screen byte is written once, with its final
;  value: a leading zero never shows, even for a moment.
;  Trashes A, X, Y, M_NUM, TCNT, TOFS, TPOS.
; ---------------------------------------------------------------------
TXT_DEC
        STA TCNT
        STX TOFS
        STA TPOS        ; digits from the right, into TBUF
TD_DIG  DEC TPOS
        LDA #10
        JSR DIVN        ; A = next digit (DIVN trashes X)
        LDX TPOS
        STA TBUF,X
        TXA
        BNE TD_DIG
        LDA M_NUM       ; anything left over: too wide
        ORA M_NUM+1
        ORA M_NUM+2
        BNE TD_OVF
        LDX TOFS        ; the field: leading zeros as spaces, then the
        LDY #0          ; digits (the last one always)
TD_LZ   INY
        CPY TCNT
        BEQ TD_REST     ; the last digit
        LDA TBUF-1,Y
        BNE TD_REST     ; the first non-zero digit
        STA STATUS1,X   ; (A = 0: a space)
        INX
        BNE TD_LZ
TD_REST LDA TBUF-1,Y
        CLC
        ADC #SC_0
        ORA TXCOL       ; its colour
        STA STATUS1,X
        INX
        INY
        CPY TCNT
        BCC TD_REST
        BEQ TD_REST
        RTS
TD_OVF  LDX TOFS
        LDY TCNT
        LDA #SC_STAR
        ORA TXCOL
TD_STAR STA STATUS1,X
        INX
        DEY
        BNE TD_STAR
        RTS
