; =====================================================================
;  INPUT.ASM -- controller and keyboard input layer (stub)
;
;  The rest of the game reads only the variables below, never the
;  hardware.  A 5200 build replaces this file (analog sticks, two fire
;  buttons, keypad) and keeps the same variable meanings.
;
;    JOY0, JOY1    direction bits, 1 = pressed:
;                  bit 0 up, bit 1 down, bit 2 left, bit 3 right
;    FIRE0, FIRE1  1 = trigger held
;    KEY           item key 0-9 pressed this poll, or $FF for none
;                  (edge triggered: reported once per key press)
; =====================================================================

; ---------------------------------------------------------------------
;  INPUT_POLL -- sample sticks, triggers and keyboard
;  Call once per frame.  Trashes A, X.
; ---------------------------------------------------------------------
INPUT_POLL
        LDA PORTA
        EOR #$FF        ; make directions active high
        PHA
        AND #$0F
        STA JOY0
        PLA
        LSR A
        LSR A
        LSR A
        LSR A
        STA JOY1

        LDA TRIG0
        EOR #$01
        STA FIRE0
        LDA TRIG1
        EOR #$01
        STA FIRE1

        LDA #$FF
        STA KEY
        LDA SKSTAT
        AND #$04        ; bit 2 clear = key held
        BEQ IP_HELD
        LDA #$00        ; no key: rearm
        STA KEYDOWN
        RTS
IP_HELD LDA KEYDOWN
        BNE IP_DONE     ; still the same press
        INC KEYDOWN
        LDA KBCODE
        AND #$3F        ; ignore SHIFT / CONTROL
        LDX #9
IP_FIND CMP KEYTAB,X
        BEQ IP_GOT
        DEX
        BPL IP_FIND
IP_DONE RTS
IP_GOT  STX KEY
        RTS

; Keyboard codes for the digit keys 0-9
KEYTAB  .BYTE $32,$1F,$1E,$1A,$18,$1D,$1B,$33,$35,$30

; Input variables (JOY0/1, FIRE0/1, KEY, KEYDOWN) live in VARS.ASM.
