; =====================================================================
;  LOADER.ASM -- runs while the XEX loads, before the rest of it (D57)
;
;  The program loads data up to $BFFF (map fonts and blocks, D56).  An
;  XL/XE may start with BASIC switched in (OPTION not held, or a loader
;  such as the MiSTer core's that leaves it on): then $A000-$BFFF is
;  the BASIC ROM, so those segments would be lost, and the OS screen
;  and display list sit at $9C20-$9FFF, under the data loaded there.
;  This segment is loaded first and run at once through INITAD: it
;  switches BASIC out, so $A000-$BFFF is RAM, and turns the screen off
;  so the display list being loaded over shows nothing.  The game sets
;  its own display list and DMA at START.  On the 400/800 PORTB is not
;  there and BASIC is a cartridge the 48K needs out anyway.
;
;  Assembled on its own, and its INITAD word in LDRINIT.ASM, and put
;  in front of the game's XEX by the Makefile: ATasm writes a file's
;  segments in address order, so with the word in the same file it
;  would load, and be called, before this code at $8730.
; =====================================================================

        .INCLUDE "hw_a800.asm"

PB_BASOFF = $02         ; PORTB bit 1 set: BASIC ROM out (XL/XE)
LDRBASE =  $8730        ; free RAM after the logo, below the BASIC ROM

        *= LDRBASE
LDR_INIT
        LDA #0          ; no screen DMA: the OS screen may be loaded over
        STA SDMCTL
        STA DMACTL
        LDA PORTB       ; BASIC out
        ORA #PB_BASOFF
        STA PORTB
        RTS
