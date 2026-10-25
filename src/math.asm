; =====================================================================
;  MATH.ASM -- unsigned multiply and divide for the scoring formulas
;
;  All routines work on the 24-bit number M_NUM (zero page, low byte
;  first).  For 8- or 16-bit values clear the upper byte(s) first, or
;  use MUL8 / NUM16.  Ranges needed by utopia-rules.md:
;    pop/10 x fertility   <= 999 x 64    = 63936   (16 bits)
;    houses x 500         <= 36 x 500    = 18000
;    gold earned x 100    may pass 65535 once D11 widens it (24 bits)
;
;  ROM-safe: no self-modifying code; work bytes are in zero page.
; =====================================================================

; ---------------------------------------------------------------------
;  NUM16 -- set M_NUM from a 16-bit value
;  In: A = low byte, X = high byte.  Out: M_NUM = X:A, M_NUM+2 = 0.
; ---------------------------------------------------------------------
NUM16
        STA M_NUM
        STX M_NUM+1
        LDA #0
        STA M_NUM+2
        RTS

; ---------------------------------------------------------------------
;  MUL8 -- 8 x 8 multiply
;  In: A, X = factors.  Out: M_NUM = A x X (16 bits, M_NUM+2 = 0).
;  Trashes A, X.
; ---------------------------------------------------------------------
MUL8
        STA M_NUM
        LDA #0
        STA M_NUM+1
        STA M_NUM+2
        TXA
        ; fall through into MULN

; ---------------------------------------------------------------------
;  MULN -- 24 x 8 multiply
;  In: M_NUM = multiplicand, A = multiplier.
;  Out: M_NUM = product (low 24 bits); C set if it overflowed 24 bits.
;  Trashes A, X.
; ---------------------------------------------------------------------
MULN
        STA M_OP
        LDA M_NUM       ; copy the multiplicand to M_TMP
        STA M_TMP
        LDA M_NUM+1
        STA M_TMP+1
        LDA M_NUM+2
        STA M_TMP+2
        LDA #0          ; product = 0
        STA M_NUM
        STA M_NUM+1
        STA M_NUM+2
        STA M_OVF
        LDX #8
MU_LOOP ASL M_NUM       ; product = product x 2
        ROL M_NUM+1
        ROL M_NUM+2
        BCC MU_BIT
        INC M_OVF
MU_BIT  ASL M_OP        ; next multiplier bit, high bit first
        BCC MU_NEXT
        CLC             ; product += multiplicand
        LDA M_NUM
        ADC M_TMP
        STA M_NUM
        LDA M_NUM+1
        ADC M_TMP+1
        STA M_NUM+1
        LDA M_NUM+2
        ADC M_TMP+2
        STA M_NUM+2
        BCC MU_NEXT
        INC M_OVF
MU_NEXT DEX
        BNE MU_LOOP
        LDA M_OVF
        CMP #1          ; C set if any carry left the 24 bits
        RTS

; ---------------------------------------------------------------------
;  DIVN -- 24 / 8 divide, truncating
;  In: M_NUM = dividend, A = divisor.
;  Out: M_NUM = quotient, A = remainder, C clear.
;       Divisor 0: M_NUM = $FFFFFF, A = 0, C set.
;  Trashes X.
; ---------------------------------------------------------------------
DIVN
        STA M_OP
        CMP #0
        BEQ DV_ZERO
        LDA #0          ; remainder
        LDX #24
DV_LOOP ASL M_NUM       ; shift the next dividend bit into the remainder
        ROL M_NUM+1
        ROL M_NUM+2
        ROL A
        BCS DV_SUB      ; remainder passed 255: certainly >= divisor
        CMP M_OP
        BCC DV_NEXT
DV_SUB  SBC M_OP        ; C is set on both paths
        INC M_NUM       ; quotient bit = 1
DV_NEXT DEX
        BNE DV_LOOP
        CLC
        RTS
DV_ZERO LDA #$FF
        STA M_NUM
        STA M_NUM+1
        STA M_NUM+2
        LDA #0
        SEC
        RTS

; ---------------------------------------------------------------------
;  DIVNR -- 24 / 8 divide, rounding half up (as the original's
;  divide-with-rounding: 1043 / 10 = 104, 1045 / 10 = 105)
;  In: M_NUM = dividend, A = divisor.
;  Out: M_NUM = rounded quotient, C clear; divisor 0 as DIVN (C set).
;  Trashes A, X.
; ---------------------------------------------------------------------
DIVNR
        JSR DIVN
        BCS DR_DONE
        ASL A           ; 2 x remainder >= divisor ?
        BCS DR_UP       ; 2 x remainder > 255
        CMP M_OP
        BCC DR_OK
DR_UP   INC M_NUM
        BNE DR_OK
        INC M_NUM+1
        BNE DR_OK
        INC M_NUM+2
DR_OK   CLC
DR_DONE RTS
