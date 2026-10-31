; =====================================================================
;  LOADER.ASM -- runs while the XEX loads, before the rest of it (D57)
;
;  The program loads map fonts and blocks at $A000-$BBFF (D56).  An
;  XL/XE may start with BASIC switched in (OPTION not held, or a loader
;  such as the MiSTer core's that leaves it on): then $A000-$BFFF is
;  the BASIC ROM, and those segments would be lost.  This segment is
;  loaded first and run at once through INITAD: it switches BASIC out,
;  so $A000-$BFFF is RAM.  The screen the OS shows while loading
;  ($9C20-$9FFF with BASIC in at boot, $BC20-$BFFF with it out) is
;  never loaded over (D57).  On the 400/800 PORTB is not there and
;  BASIC is a cartridge the 48K needs out anyway.
;
;  Assembled on its own, and its INITAD word in LDRINIT.ASM, and put
;  in front of the game's XEX by the Makefile: ATasm writes a file's
;  segments in address order, so with the word in the same file it
;  would load, and be called, before this code at $8730.
; =====================================================================

        .INCLUDE "hw_a800.asm"

PB_BASOFF = $02         ; PORTB bit 1 set: BASIC ROM out (XL/XE)
GINTLK  =  $03FA        ; XL OS: TRIG3 at power-on (cartridge there)
BASICF  =  $03F8        ; XL OS: not 0 = BASIC out after RESET
LDRBASE =  $8730        ; free RAM after the logo, below the BASIC ROM

        *= LDRBASE
LDR_INIT
        LDA #0          ; no VBI between BASIC going and GINTLK
        STA NMIEN
        LDA PORTB       ; BASIC out
        ORA #PB_BASOFF
        STA PORTB
        LDA TRIG3       ; the XL OS's VBI hangs if TRIG3 (cartridge
        STA GINTLK      ; there) is not what it was at power-on
        LDA #1          ; and RESET keeps BASIC out
        STA BASICF
        LDA #NMI_VBI
        STA NMIEN
        RTS
