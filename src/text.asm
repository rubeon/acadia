; =====================================================================
;  TEXT.ASM -- print into the status bar (two mode 2 lines)
;
;  Positions are offsets into the status lines: 0-39 is line 1
;  (STATUS1), 40-79 is line 2 (STATUS2, which follows it in RAM).
;  Text is in screen codes (MAC/65 .SBYTE): "0" = $10, space = 0.
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
;      X = status offset of the field's first character.
;  Leading zeros become spaces (a zero value prints "0").  A value too
;  wide for the field prints as all "*".
;  Trashes A, X, Y, M_NUM, TCNT, TOFS, TPOS, TLAST.
; ---------------------------------------------------------------------
TXT_DEC
        STA TCNT
        STX TOFS
        TXA
        CLC
        ADC TCNT
        STA TPOS        ; one past the field
        SEC
        SBC #1
        STA TLAST       ; last character of the field
TD_DIG  DEC TPOS        ; digits from the right
        LDA #10
        JSR DIVN        ; A = next digit (DIVN trashes X)
        CLC
        ADC #SC_0
        LDX TPOS
        STA STATUS1,X
        CPX TOFS
        BNE TD_DIG
        LDA M_NUM       ; anything left over: too wide
        ORA M_NUM+1
        ORA M_NUM+2
        BNE TD_OVF
        LDX TOFS        ; blank leading zeros, keep the last digit
TD_LZ   CPX TLAST
        BEQ TD_DONE
        LDA STATUS1,X
        CMP #SC_0
        BNE TD_DONE
        LDA #0
        STA STATUS1,X
        INX
        BNE TD_LZ
TD_DONE RTS
TD_OVF  LDX TOFS
        LDY TCNT
        LDA #SC_STAR
TD_STAR STA STATUS1,X
        INX
        DEY
        BNE TD_STAR
        RTS
