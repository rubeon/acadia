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
;    PAUSEK        1 on the poll the pause key (P) was pressed, else 0
;    HELPK         1 on the poll H or HELP (XL/XE) was pressed, else 0
;    KEYPL         player the key belongs to (D17): the one holding
;                  fire; neither holding fire -> 0; both -> the key is
;                  dropped (KEY and KEYPL = $FF).  $FF with no key.
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

        LDA CONSOL      ; console keys, 1 = held (D18)
        EOR #$FF
        AND #$07        ; b0 START, b1 SELECT, b2 OPTION
        STA CONKEY
        ORA JOY0        ; any input holds off attract mode (D48)
        ORA JOY1
        ORA FIRE0
        ORA FIRE1
        BEQ IP_ATR
        LDA #0
        STA ATRACT
IP_ATR
        LDA #0
        STA PAUSEK
        STA HELPK
        LDA #$FF
        STA KEY
        STA KEYPL
        LDA SKSTAT
        AND #$04        ; bit 2 clear = key held
        BEQ IP_HELD
        LDA #$00        ; no key: rearm
        STA KEYDOWN
        RTS
IP_HELD LDA #0          ; a key held: no attract mode either
        STA ATRACT
        LDA KEYDOWN
        BNE IP_DONE     ; still the same press
        INC KEYDOWN
        LDA KBCODE
        AND #$3F        ; ignore SHIFT / CONTROL
        CMP #KC_P
        BEQ IP_PAUS
        CMP #KC_H
        BEQ IP_HELP
        CMP #KC_HELP
        BEQ IP_HELP
        LDX #9
IP_FIND CMP KEYTAB,X
        BEQ IP_GOT
        DEX
        BPL IP_FIND
IP_DONE RTS
IP_PAUS INC PAUSEK      ; P: pause key (D19)
        RTS
IP_HELP INC HELPK       ; H or HELP: help screen (D34)
        RTS
IP_GOT  STX KEY
        LDA FIRE1       ; whose key is it? (D17)
        BEQ IP_P0       ; player 2 not on fire: player 1's
        LDA FIRE0
        BNE IP_BOTH
        LDA #1
        STA KEYPL
        RTS
IP_P0   LDA #0
        STA KEYPL
        RTS
IP_BOTH LDA #$FF        ; both on fire: ambiguous, drop the key
        STA KEY
        STA KEYPL
        RTS

KC_P    =  $0A          ; keyboard code of P
KC_H    =  $39          ; keyboard code of H
KC_HELP =  $11          ; keyboard code of the XL/XE HELP key

; Keyboard codes for the digit keys 0-9
KEYTAB  .BYTE $32,$1F,$1E,$1A,$18,$1D,$1B,$33,$35,$30

; Input variables (JOY0/1, FIRE0/1, KEY, KEYPL, PAUSEK, HELPK, KEYDOWN) live in
; VARS.ASM.
