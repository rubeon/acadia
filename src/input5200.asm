; =====================================================================
;  INPUT5200.ASM -- the 5200 build's input layer (D63)
;
;  The same variables as INPUT.ASM (ARCHITECTURE.md section 4), from
;  the 5200's controllers: an analog stick, two side buttons and a
;  12-key keypad with START, PAUSE and RESET.  One side button is wired
;  to GTIA's TRIG (the bottom one, by A.N.A.L.O.G. #15 and the connector
;  pinouts), the other to the keypad's shift line (SKSTAT bit 3, read
;  like the keypad); D63.
;
;    stick         PADDL0-3 (the BIOS's pot shadows: controller 1 x, y,
;                  controller 2 x, y; low = left / up) past a dead
;                  zone around the centre -> JOY0, JOY1
;    fire          TRIG0, TRIG1 -> FIRE0, FIRE1
;    keypad 1-9    KEY 1-9, KEYPL = the controller it came from
;    0, the other  KEY 0 for that controller (lift / park a boat)
;    side button
;    *             HELPK (help screen, D34)
;    #             info pages (D18) while held, during a round: totals,
;                  then each press within IN_PGTM frames of the last
;                  one the next page (populations, last round, totals)
;    START         CONKEY's START bit while held (totals; begins a game
;                  on the setup and title screens, as on the 800)
;    PAUSE         PAUSEK (D19)
;    RESET         nothing (the BIOS's keypad IRQ ignores it too)
;
;  POKEY scans one controller's keypad and 2nd button at a time,
;  the one CONSOL bits 0-1 select.  INPUT_POLL reads the controller
;  selected the frame before and selects the next one: controller 1
;  every frame, except during the rounds of a 2-player game, when the
;  two take turns.  A digit, 0 or the 2nd button counts when it is
;  pressed on its controller; *, #, START and PAUSE are shared, like
;  the 800's console keys, and count when pressed on one controller
;  while the other is not holding the same key.  (atari800 presses a
;  key on every controller at once, so that keeps each a single press
;  there too.)  Keys are polled; the BIOS's keypad IRQ stays as it is.
; =====================================================================

FX_UP   =  0            ; FTAP: fire let go (as INPUT.ASM)
FX_TAP  =  1            ;       pressed, a tap so far
FX_USED =  2            ;       held, but not a tap

; Input state: PLATRAM bytes (MEM_5200.ASM), cleared by IN_INIT
IN_CTL  =  PLATRAM+11   ; controller selected for the next read (0/1)
IN_HELD =  PLATRAM+12   ; 2 bytes: per controller, keypad code held at
                        ; its last read (1-15, 0 = none)
IN_BOT  =  PLATRAM+14   ; 2 bytes: per controller, 2nd button held
                        ; at its last read (SK_BOT, 0 = not)
IN_PG   =  PLATRAM+16   ; info page # shows: 1-3 (D18)
IN_PGT  =  PLATRAM+17   ; frames left to step the page with #
IN_J    =  PLATRAM+18   ; IN_STK: direction bits so far
IN_N    =  8            ; bytes IN_INIT clears (IN_CTL ... IN_J)

IN_LO   =  74           ; pot < IN_LO: up / left (centre ~114)
IN_HI   =  155          ; pot >= IN_HI: down / right
IN_NONE =  228          ; both pots of a controller at 228 (never
                        ; charged): no controller plugged in
IN_PGTM =  90           ; frames after # is let go in which a new
                        ; press steps the page (1.5 s), else totals

SK_KEY  =  $04          ; SKSTAT bit 2: 0 = a key held
SK_BOT  =  $08          ; SKSTAT bit 3: 0 = the 2nd side button held
CN_POT  =  $04          ; CONSOL bit 2: pots on (bits 0-1: controller)
IQ_BOT  =  $80          ; IRQEN bit 7: the 2nd button's BREAK IRQ

; Keypad codes, (KBCODE / 2) AND 15
KC_HASH =  $01
KC_ZERO =  $02
KC_STAR =  $03
KC_RST  =  $04
KC_PAUS =  $08
KC_STRT =  $0C

; ---------------------------------------------------------------------
;  IN_INIT -- clear the input state, controller 1 selected, pots on,
;  and no IRQ for the 2nd button (polled; the BIOS's VTRIGR vector
;  at $020C may not be set).  Called by PLAT_INIT.  Keeps the I flag
;  as it is.  Trashes A, X.
; ---------------------------------------------------------------------
IN_INIT LDA #0
        LDX #IN_N-1
II_CLR  STA IN_CTL,X
        DEX
        BPL II_CLR
        LDA #CN_POT     ; controller 1, pots on
        STA CONSOL
        PHP
        SEI             ; the BIOS's IRQ handler writes IRQEN too
        LDA POKMSK
        AND #$FF-IQ_BOT
        STA POKMSK
        STA IRQEN
        PLP
        RTS

; ---------------------------------------------------------------------
;  INPUT_POLL -- sticks, buttons and the keypad.  Call once per frame.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
INPUT_POLL
        LDX #0          ; controller 1's pots
        JSR IN_STK
        STA JOY0
        LDX #2          ; controller 2's
        JSR IN_STK
        STA JOY1
        LDA TRIG0       ; fire buttons, 0 = pressed
        EOR #$01
        STA FIRE0
        LDA TRIG1
        EOR #$01
        STA FIRE1

        LDA #0
        STA PAUSEK
        STA HELPK
        LDA #$FF
        STA KEY
        STA KEYPL
        LDX IN_CTL      ; the controller POKEY scanned this frame
        JSR IN_PAD
        JSR IN_SEL      ; and the one it scans next

        LDA IN_HELD     ; KEYDOWN: anything held on a keypad
        ORA IN_HELD+1
        ORA IN_BOT
        ORA IN_BOT+1
        BEQ IP_KD
        LDA #1
IP_KD   STA KEYDOWN

        LDX #KC_HASH    ; # held: keep the page's time full,
        JSR IN_ANY      ; else count it down
        BNE IP_PGT
        LDA #IN_PGTM
        STA IN_PGT
        BNE IP_CON
IP_PGT  LDA IN_PGT
        BEQ IP_CON
        DEC IN_PGT
IP_CON

        LDA #0          ; CONKEY: START held, the # page (D18)
        STA CONKEY
        LDX #KC_STRT
        JSR IN_ANY
        BNE IP_HASH
        LDA #1
        STA CONKEY
IP_HASH LDX #KC_HASH
        JSR IN_ANY
        BNE IP_ATR
        LDA GSTATE      ; info pages only during a round, so # does
        BNE IP_ATR      ; not begin a game on the setup screen
        LDX IN_PG
        LDA IN_PGB,X
        ORA CONKEY
        STA CONKEY

IP_ATR  LDA JOY0        ; any input holds off attract mode (D48)
        ORA JOY1
        ORA FIRE0
        ORA FIRE1
        ORA CONKEY
        ORA KEYDOWN
        BEQ IP_RTS
        LDA #0
        STA ATRACT
IP_RTS  RTS

IN_PGB  .BYTE 0,1,2,4   ; IN_PG -> CONKEY bit: START, SELECT, OPTION

; ---------------------------------------------------------------------
;  IN_STK -- one controller's stick as JOY bits.  In: X = its first pot
;  (0 or 2).  Out: A.  Trashes Y.
; ---------------------------------------------------------------------
IN_STK  LDA PADDL0,X
        CMP #IN_NONE
        BCC IS_ON
        LDA PADDL0+1,X
        CMP #IN_NONE
        BCC IS_ON
        LDA #0          ; no controller
        RTS
IS_ON   LDY #0
        LDA PADDL0+1,X  ; y: up is low
        CMP #IN_LO
        BCS IS_DN
        LDY #J_UP
        BNE IS_X
IS_DN   CMP #IN_HI
        BCC IS_X
        LDY #J_DOWN
IS_X    STY IN_J
        LDA PADDL0,X    ; x: left is low
        CMP #IN_LO
        BCS IS_RT
        LDA #J_LEFT
        BNE IS_OR
IS_RT   CMP #IN_HI
        BCC IS_NOX
        LDA #J_RIGHT
IS_OR   ORA IN_J
        RTS
IS_NOX  LDA IN_J
        RTS

; ---------------------------------------------------------------------
;  IN_PAD -- read the keypad and 2nd button of controller X, which
;  POKEY has scanned this frame; KEY, KEYPL, PAUSEK, HELPK and the #
;  page on a new press.  Trashes A, Y.
; ---------------------------------------------------------------------
IN_PAD  LDY #0          ; Y = the code held, 0 = none
        LDA SKSTAT
        AND #SK_KEY
        BNE IA_CODE
        LDA KBCODE      ; bits 1-4: the key (bits 0, 5: no lines)
        LSR A
        AND #$0F
        TAY
IA_CODE TYA
        CMP IN_HELD,X
        BEQ IA_BOT      ; the same as last time: no new press
        STA IN_HELD,X
        TAY
        BEQ IA_BOT      ; let go
        LDA IN_KEYS,Y   ; a digit 0-9, or a shared key
        BMI IA_SHR
        STA KEY
        STX KEYPL       ; the controller's player
        JMP IA_BOT

IA_SHR  TXA             ; a shared key: not if the other controller
        EOR #1          ; is holding it already
        TAY
        LDA IN_HELD,X
        CMP IN_HELD,Y
        BEQ IA_BOT
        CMP #KC_STAR
        BNE IA_PAUS
        LDA #1          ; *: help screen (D34)
        STA HELPK
        BNE IA_BOT
IA_PAUS CMP #KC_PAUS
        BNE IA_HASH
        LDA #1          ; PAUSE (D19)
        STA PAUSEK
        BNE IA_BOT
IA_HASH CMP #KC_HASH
        BNE IA_BOT      ; START (held only), RESET: nothing here
        LDA IN_PGT      ; #: soon after the last one, the next page;
        BEQ IA_PG1      ; else totals
        LDY IN_PG
        CPY #3
        BCC IA_PGN
IA_PG1  LDY #0
IA_PGN  INY
        STY IN_PG

IA_BOT  LDA SKSTAT      ; the 2nd button: key 0 when pressed
        AND #SK_BOT
        EOR #SK_BOT     ; SK_BOT = held
        CMP IN_BOT,X
        BEQ IA_RTS
        STA IN_BOT,X
        TAY
        BEQ IA_RTS      ; let go
        LDA KEY
        BPL IA_RTS      ; a key on the keypad this read wins
        LDA #0
        STA KEY
        STX KEYPL
IA_RTS  RTS

IK_SHR  =  $80          ; IN_KEYS: a shared key, not a digit
; keypad code (KBCODE / 2 AND 15) -> digit, or IK_SHR
IN_KEYS .BYTE IK_SHR,IK_SHR,0,IK_SHR,IK_SHR,9,8,7
        .BYTE IK_SHR,6,5,4,IK_SHR,3,2,1

; ---------------------------------------------------------------------
;  IN_ANY -- Z set if either controller held keypad code X at its last
;  read.  Trashes A.
; ---------------------------------------------------------------------
IN_ANY  TXA
        CMP IN_HELD
        BEQ IY_RTS
        CMP IN_HELD+1
IY_RTS  RTS

; ---------------------------------------------------------------------
;  IN_SEL -- select the controller POKEY scans until the next poll:
;  the other one during the rounds of a 2-player game (not the demo),
;  else controller 1, with controller 2's state forgotten.  Trashes A.
; ---------------------------------------------------------------------
IN_SEL  LDA DEMO
        BNE IL_ONE
        LDA GSTATE      ; play or a round summary
        CMP #GS_OVER
        BCS IL_ONE
        LDA SU_VAL+SU_FPLY
        CMP #2
        BNE IL_ONE
        LDA IN_CTL      ; 2 players: take turns
        EOR #1
        BPL IL_SET
IL_ONE  LDA #0
        STA IN_HELD+1
        STA IN_BOT+1
IL_SET  STA IN_CTL
        ORA #CN_POT
        STA CONSOL
        RTS

; FIRE_TAP (D60), KP_ON / KP_OFF / KP_AUTO (the 800's keypad in port
; 2, D49): nothing to do on the 5200, which has key 0 and keypads of
; its own (D63)
FIRE_TAP
KP_ON
KP_OFF
KP_AUTO
        RTS
