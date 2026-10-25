; =====================================================================
;  RAND.ASM -- random numbers from POKEY's RANDOM register
;
;  RANDOM (an equate in the platform file) reads 8 bits of POKEY's
;  17-bit polynomial counter, which runs at the machine clock, so every
;  read gives a fresh value.  The 5200 has the same POKEY register at
;  its own address.
;
;  RAND_N gives an unbiased 0..N-1 by masking to the next power of two
;  and rejecting values >= N (on average under 2 reads).
;
;  The sound driver must leave AUDCTL bit 7 clear: setting it switches
;  POKEY to the 9-bit polynomial, and RANDOM would repeat every 511
;  clocks.
; =====================================================================

; ---------------------------------------------------------------------
;  RAND_N -- uniform random number 0..N-1
;  In: A = N (1-255; 0 means 256, i.e. any byte).
;  Out: A = random number, Z and N set from it.  Trashes RN_N, RN_M;
;  X and Y kept.
; ---------------------------------------------------------------------
RAND_N
        CMP #2
        BCC RN_SMALL
        STA RN_N
        SEC             ; mask = N-1 with every lower bit set
        SBC #1
        STA RN_M
        LSR A
        ORA RN_M
        STA RN_M
        LSR A
        LSR A
        ORA RN_M
        STA RN_M
        LSR A
        LSR A
        LSR A
        LSR A
        ORA RN_M
        STA RN_M
RN_TRY  LDA RANDOM
        AND RN_M
        CMP RN_N
        BCS RN_TRY      ; out of range: try again
        ORA #0          ; Z and N from A, not from the CMP
        RTS
RN_SMALL
        CMP #1          ; N = 1: always 0
        BEQ RN_ZERO
        LDA RANDOM      ; N = 0: any byte
        RTS
RN_ZERO LDA #0
        RTS
