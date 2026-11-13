; =====================================================================
;  AI2.ASM -- part of AI.ASM (D90): AI_AVOID's AV_BOX and helpers.
;  It sits in the free end of RANDOM's map font (MFNT10E: codes
;  105-127 are never drawn), as code block 2 is full on the 800;
;  184 bytes at most
; =====================================================================

; AV_BOX -- the boat a step from pirate X's box (it is never inside:
; AI_FLEE runs first): AN_C, AN_R = dx, dy, AN_N, AN_T = |dx|, |dy|;
; one of them is AI_NEAR.  X kept; trashes A, Y.
AV_BOX  LDA #0
        STA AI_I        ; the move dropped (0: none)
        LDA AN_T        ; up or down less than AI_NEAR: no move across
        CMP #AI_NEAR    ; towards it
        BCS AV_V
        LDA AN_C
        LDY #0
        JSR AV_DROP
AV_V    LDA AN_C        ; still moving across towards it (at the
        LDY #0          ; corner)?  then no up or down towards it
        JSR AV_TWD
        AND JOY1
        BNE AV_VD
        LDA AN_N        ; nor with it less than AI_NEAR across
        CMP #AI_NEAR
        BCS AV_SIDE
AV_VD   LDA AN_R
        LDY #2
        JSR AV_DROP
AV_SIDE LDA AI_I        ; a move dropped and none on the other axis:
        BEQ AV_DONE     ; step aside, away from the pirate
        LDA AI_TX       ; but not if the target is in the box: wait
        SEC
        SBC FXH,X
        CLC
        ADC #8+AI_NEAR-1
        CMP #2*AI_NEAR-1
        BCS AV_OUT
        LDA AI_TY
        SEC
        SBC FYH,X
        CLC
        ADC #8+AI_NEAR-1
        CMP #2*AI_NEAR-1
        BCC AV_DONE
AV_OUT  LDA AI_I
        AND #J_LEFT+J_RIGHT
        BEQ AV_SV
        LDA JOY1        ; across dropped: up or down, if it has none
        AND #J_UP+J_DOWN
        BNE AV_DONE
        LDY #J_UP       ; pirate below (or level): up
        LDA AN_R
        BPL AV_SET
        LDY #J_DOWN
        BNE AV_SET      ; always
AV_SV   LDA JOY1        ; up or down dropped: across, if it has none
        AND #J_LEFT+J_RIGHT
        BNE AV_DONE
        LDY #J_LEFT     ; pirate to the right (or level): left
        LDA AN_C
        BPL AV_SET
        LDY #J_RIGHT
AV_SET  TYA
        ORA JOY1
        STA JOY1
AV_DONE RTS

; AV_DROP -- drop JOY1's move towards the pirate on one axis (A, Y as
; for AV_TWD), noting it in AI_I.  Trashes A, Y.
AV_DROP JSR AV_TWD
        AND JOY1
        BEQ AV_DRZ
        STA AI_I
        EOR JOY1
        STA JOY1
AV_DRZ  RTS

; AV_ABS -- A = |A| (signed).  Trashes nothing else.
AV_ABS  BPL AV_POS
        EOR #$FF
        CLC
        ADC #1
AV_POS  RTS

; AV_TWD -- A = the stick bit towards the pirate on one axis: A = its
; signed distance, Y = 0 across, 2 up or down; 0 if the distance is
; 0.  Trashes Y.
AV_TWD  CMP #0
        BEQ AV_TZ
        BPL AV_TP
        INY
AV_TP   LDA AV_TW,Y
AV_TZ   RTS

AV_TW   .BYTE J_RIGHT,J_LEFT,J_DOWN,J_UP
