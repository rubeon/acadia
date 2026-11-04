; =====================================================================
;  INPUT5200.ASM -- the 5200 build's input layer (stub, T-5200-1)
;
;  Defines every symbol of INPUT.ASM that the rest of the game uses,
;  with nothing pressed, so the cartridge runs the title screen and
;  the demo.  The controllers (analog sticks, two fire buttons,
;  keypads) come with T-5200-2; the meanings of JOY0 ... HELPK are
;  INPUT.ASM's (ARCHITECTURE.md section 4).
; =====================================================================

FX_UP   =  0            ; FTAP: fire let go (as INPUT.ASM)
FX_TAP  =  1            ;       pressed, a tap so far
FX_USED =  2            ;       held, but not a tap

; ---------------------------------------------------------------------
;  INPUT_POLL -- nothing held, no key.  Call once per frame.  Trashes A.
; ---------------------------------------------------------------------
INPUT_POLL
        LDA #0
        STA JOY0
        STA JOY1
        STA FIRE0
        STA FIRE1
        STA CONKEY
        STA PAUSEK
        STA HELPK
        STA KEYDOWN
        LDA #$FF        ; no key, so no player either
        STA KEY
        STA KEYPL
        RTS

; FIRE_TAP (D60), KP_ON / KP_OFF / KP_AUTO (the 800's keypad in port
; 2, D49): nothing to do yet
FIRE_TAP
KP_ON
KP_OFF
KP_AUTO
        RTS
