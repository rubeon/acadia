; =====================================================================
;  LOADER.ASM -- runs while the XEX loads, before the rest of it (D57,
;  D81)
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
;  It also puts up the loading screen (D81): the title's logo, drawn
;  where the title screen has it, on flat colours, and LOADING at the
;  bottom right.  The logo area is cleared first; the Makefile loads
;  the title graphics (LOGO first) right after this segment, so the
;  logo fills in while it loads and stays up until the game's own
;  display list replaces this one.  No DLI: SIO is busy meanwhile.
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
LD_LOGO =  $8000        ; LOGO (TITLEGFX, MEM_A800.ASM): 26 mode D
                        ; lines of 40 bytes, $8000-$840F
LD_NPG  =  5            ; pages cleared there ($8000-$84FF)
LD_BK   =  $60          ; sky (COLBK): the title's upper sky
LD_GOLD =  $2C          ; the logo (COLPF1): the title's logo gold
LD_SHD  =  $00          ; its shadow (COLPF2), as C_TSHD
LD_TXTC =  $1E          ; LOADING (COLPF3)
LD_PF3  =  $C0          ; mode 6 character bits 6-7: COLPF3

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

        LDA #0          ; clear the logo area, which still holds
        TAX             ; whatever RAM held at power-on
LD_CLR  STA LD_LOGO,X
        STA LD_LOGO+$100,X
        STA LD_LOGO+$200,X
        STA LD_LOGO+$300,X
        STA LD_LOGO+$400,X  ; LD_NPG pages
        INX
        BNE LD_CLR
        STA COLOR0      ; A = 0: PF0 unused in the logo
        LDA #LD_GOLD    ; colours (the OS VBI copies the shadows)
        STA COLOR1
        LDA #LD_SHD
        STA COLOR2
        LDA #LD_TXTC
        STA COLOR3
        LDA #LD_BK
        STA COLOR4
        LDA #<LD_DL     ; the loading screen's display list; the VBI
        STA SDLSTL      ; is off, so both bytes go in together
        LDA #>LD_DL
        STA SDLSTL+1

        LDA #NMI_VBI
        STA NMIEN
        RTS

; the loading screen: the logo on the title's lines (TDLIST, 28 blank
; lines, LOGO_H mode D lines), LOADING on the REBUILD line's first 8
LD_DL   .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK4
        .BYTE DL_LMS+DL_MODED
        .WORD LD_LOGO
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK8
        .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK8
        .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK8
        .BYTE DL_LMS+DL_MODE6
        .WORD LD_TXT
        .BYTE DL_JVB
        .WORD LD_DL

; "LOADING" at the right, ROM font screen codes in COLPF3
LD_TXT  .BYTE 0,0,0,0,0,0,0,0,0,0,0,0
        .BYTE $2C+LD_PF3,$2F+LD_PF3,$21+LD_PF3,$24+LD_PF3
        .BYTE $29+LD_PF3,$2E+LD_PF3,$27+LD_PF3,0
LD_END
