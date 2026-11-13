; =====================================================================
;  AI3.ASM -- part of AI.ASM: AI_NBR (D39), moved (D90) to the free
;  end of STANDARD's map font 1 (MFNT01E: codes 113-127 are never
;  drawn), as code block 2 is full on the 800; 120 bytes at most
; =====================================================================

; ---------------------------------------------------------------------
;  AI_NBR -- how many of the 8 squares around X, Y hold a building
;  (not a rebel).  Out: A.  X, Y kept.
; ---------------------------------------------------------------------
AI_NBR
        STX AN_C
        STY AN_R
        LDA #0
        STA AN_N
        LDA #7
        STA AN_I
AN_LOOP LDX AN_I
        LDA AN_C
        CLC
        ADC NBR_DC,X
        CMP #MAPSQ      ; also catches -1
        BCS AN_NEXT
        STA AN_T
        LDA AN_R
        CLC
        ADC NBR_DR,X
        CMP #MAPROWS
        BCS AN_NEXT
        TAY
        LDX AN_T
        JSR MAP_GET
        CMP #0
        BEQ AN_NEXT
        CMP #I_REBL
        BEQ AN_NEXT
        INC AN_N
AN_NEXT DEC AN_I
        BPL AN_LOOP
        LDX AN_C
        LDY AN_R
        LDA AN_N
        RTS
