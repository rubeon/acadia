; =====================================================================
;  INPUT.ASM -- controller and keyboard input layer (stub)
;
;  The rest of the game reads only the variables below, never the
;  hardware.  A 5200 build replaces this file (analog sticks, two fire
;  buttons, keypad) and keeps the same variable meanings.
;
;  In a 1-player game with KEYPAD set on the setup screen (D49), port 2
;  has an Atari keypad controller (CX21 Video Touch Pad or CX50
;  Keyboard Controller, 12 keys) instead of a stick: KP_ON makes its
;  stick lines outputs that select a row of keys, JOY1 and FIRE1 stay
;  0, and its keys come in as KEY (player 1), * as PAUSEK and # as
;  HELPK.
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
;  Call once per frame.  Trashes A, X, Y.
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
        LDA KPMODE      ; a keypad in port 2: no stick 2 (D49)
        BEQ IP_CON
        LDA #0
        STA JOY1
        STA FIRE1
IP_CON

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
IP_ATR  JSR IP_KBD      ; the keyboard
        LDA KPMODE      ; then the keypad, if there is one
        BEQ IP_RTS
        JMP KP_SCAN
IP_RTS  RTS

; IP_KBD -- KEY, KEYPL, PAUSEK, HELPK from the keyboard.  Trashes A, X.
IP_KBD  LDA #0
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

; ---------------------------------------------------------------------
;  KP_ON / KP_OFF -- keypad controller in port 2 on / off (D49).
;  KP_ON makes port 2's four stick lines outputs, one per row of keys;
;  KP_OFF makes them inputs again for a joystick.  Trashes A.
; ---------------------------------------------------------------------
KP_ON   LDA #$FF        ; no row selected yet
        STA PORTA
        LDA #KP_OUT
        JSR KP_DDR
        LDA #1
        STA KPMODE
        LDA #0
        STA KPROW
        STA KPDOWN
        LDA #KP_NONE
        STA KPHIT
        RTS
KP_OFF  LDA #0
        STA KPMODE
        ; A = 0: every line an input, falls through

; KP_DDR -- PORTA's data direction = A (1 = output).  Trashes A.
KP_DDR  PHA
        LDA PACTL
        AND #$FF-PA_DATA ; PORTA is the direction register
        STA PACTL
        PLA
        STA PORTA
        LDA PACTL
        ORA #PA_DATA    ; and the data register again
        STA PACTL
        RTS

; ---------------------------------------------------------------------
;  KP_SCAN -- read one row of the keypad each poll; after all four,
;  report a newly pressed key.  The row's line goes low; a key down in
;  it holds its column low, the others are pulled up.  Columns (D56,
;  as Atari's own CX21 reader): left on pot 3, middle on pot 2, read
;  after POTGO and KP_WAIT steps through ALLPOT (1 = still low); right
;  on the trigger (0 = low).  A row with more than one column down (or no
;  controller: the pots never charge) counts as no key.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
KP_SCAN LDX KPROW
        LDA KPROWS,X    ; this row's line low, the others high
        STA PORTA
        STA POTGO       ; the pot lines start charging from 0
        LDY #KP_WAIT
KS_W1   LDA VCOUNT      ; wait KP_WAIT steps of VCOUNT (2 lines each)
KS_W2   CMP VCOUNT
        BEQ KS_W2
        DEY
        BNE KS_W1
        LDA ALLPOT
        LSR A           ; pot 2 (middle) to bit 0, pot 3 (left) to 1
        LSR A
        AND #$03
        LDY TRIG1
        BNE KS_COL
        ORA #$04        ; right column
KS_COL  TAY
        LDA KPCOL,Y     ; column 0-2, KP_NONE for none or several
        BMI KS_NXT
        LDY KPHIT       ; the first key found counts
        BPL KS_NXT
        CLC
        ADC KPR3,X      ; + row x 3
        STA KPHIT
KS_NXT  INX
        STX KPROW
        CPX #4
        BCC KS_RTS
        LDX #0          ; a whole scan done
        STX KPROW
        LDY KPHIT
        LDA #KP_NONE
        STA KPHIT
        TYA
        BPL KS_KEY
        STX KPDOWN      ; no key down: rearm
KS_RTS  RTS
KS_KEY  STX ATRACT      ; a key held: no attract mode
        LDA KPDOWN
        BNE KS_RTS      ; still the same press
        INC KPDOWN
        LDA KPKEY,Y     ; digit, KP_STAR or KP_HASH
        BMI KS_SPEC
        LDX KEY         ; a keyboard key this poll wins
        BPL KS_RTS
        STA KEY
        LDA #0          ; the keypad is player 1's
        STA KEYPL
        RTS
KS_SPEC LDX #1
        CMP #KP_STAR
        BNE KS_HASH
        STX PAUSEK      ; *: pause (D19)
        RTS
KS_HASH STX HELPK       ; #: help (D34)
        RTS

PA_DATA =  $04          ; PACTL bit 2: 1 = PORTA data, 0 = direction
KP_OUT  =  $F0          ; port 2's lines out, port 1's in
KP_WAIT =  8            ; VCOUNT steps (~15 lines) before reading the
                        ; columns; a free line charges in under 10 (D56)
KP_NONE =  $FF
KP_STAR =  $80          ; KPKEY codes for * and #
KP_HASH =  $81

KPROWS  .BYTE $EF,$DF,$BF,$7F   ; row 1-2-3, 4-5-6, 7-8-9, *-0-#
KPR3    .BYTE 0,3,6,9
KPCOL   .BYTE KP_NONE,1,0,KP_NONE,2,KP_NONE,KP_NONE,KP_NONE ; b0 pot 2,
                        ; b1 pot 3, b2 trigger -> column 0-2 (D56)
KPKEY   .BYTE 1,2,3,4,5,6,7,8,9,KP_STAR,0,KP_HASH

; Input variables (JOY0/1, FIRE0/1, KEY, KEYPL, PAUSEK, HELPK, KEYDOWN,
; KPMODE, KPROW, KPHIT, KPDOWN) live in VARS.ASM.
