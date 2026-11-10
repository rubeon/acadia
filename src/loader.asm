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
;  where the title screen has it, on black, LOADING and under it a bar
;  that fills as the file loads.  The logo area is cleared first; the
;  join (TOOLS/XEXJOIN.PY) loads the title graphics (LOGO first) right
;  after this, so the logo fills in while it loads.  It also splits the
;  game into chunks of at most 1K with an INITAD to LD_STEP after each,
;  and loads LD_TAB, the bar's length after each chunk, first.  The
;  screen stays up until the game's own display list replaces it.
;
;  While SIO runs the OS sets CRITIC, and its VBI then copies no
;  shadow registers: so the colours and the display list are written
;  to the hardware as well, in vertical blank, and the one DLI handler
;  (LD_DLI) sets COLPF1 at the top (the logo's gold) and above the bar
;  (its purple) every frame.  It is short: SIO's IRQs can wait.
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
LDRB2   =  $9700        ; and after the island data (free, D81)
LD_LOGO =  $8000        ; LOGO (TITLEGFX, MEM_A800.ASM): 26 mode D
                        ; lines of 40 bytes, $8000-$840F
LD_BK   =  $00          ; background (COLBK): black
LD_GOLD =  $2C          ; the logo (COLPF1): the title's logo gold
LD_SHD  =  $00          ; its shadow (COLPF2), as C_TSHD
LD_TXTC =  $1E          ; LOADING (COLPF3)
LD_TRK  =  $60          ; the bar's track (COLPF0): dark violet
LD_FILL =  $54          ; the bar's fill (COLPF1 from LD_DLI): purple
LD_PF3  =  $C0          ; mode 6 character bits 6-7: COLPF3
LD_BTRK =  $55          ; a mode D byte of track (4 pixels of PF0)
LD_BON  =  $AA          ; and of fill (PF1)
LD_BX   =  4            ; the bar's first byte in its line
LD_BW   =  32           ; its bytes (128 pixels); LD_TAB entries 0-32
LD_NTAB =  48           ; LD_TAB's room: steps at most
LD_VMID =  48           ; VCOUNT between LD_DLI's two calls
LD_VBL  =  124          ; VCOUNT in vertical blank (NTSC and PAL)
NMI_ALL =  NMI_DLI+NMI_VBI

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
        STA LD_LOGO+$400,X  ; up to $84FF
        INX
        BNE LD_CLR
        STA LD_N        ; A = 0: no chunk loaded yet
        LDX #39         ; the bar's line: black, then the empty track
LD_BCL  LDA #0
        CPX #LD_BX
        BCC LD_BC1
        CPX #LD_BX+LD_BW
        BCS LD_BC1
        LDA #LD_BTRK
LD_BC1  STA LD_BAR,X
        DEX
        BPL LD_BCL

        LDA #LD_TRK     ; the shadows, for the VBIs outside SIO
        STA COLOR0
        LDA #LD_GOLD
        STA COLOR1
        LDA #LD_SHD
        STA COLOR2
        LDA #LD_TXTC
        STA COLOR3
        LDA #LD_BK
        STA COLOR4
        LDA #<LD_DL
        STA SDLSTL
        LDA #>LD_DL
        STA SDLSTL+1
        LDA #<LD_DLI
        STA VDSLST
        LDA #>LD_DLI
        STA VDSLST+1

LD_WVB  LDA VCOUNT      ; and the hardware, in vertical blank, for
        CMP #LD_VBL     ; the frames in SIO (CRITIC: no copy)
        BCC LD_WVB
        LDA #LD_TRK
        STA COLPF0
        LDA #LD_GOLD
        STA COLPF1
        LDA #LD_SHD
        STA COLPF2
        LDA #LD_TXTC
        STA COLPF3
        LDA #LD_BK
        STA COLBK
        LDA #<LD_DL
        STA DLISTL
        LDA #>LD_DL
        STA DLISTL+1

        LDA #NMI_ALL    ; VBI back on, and LD_DLI
        STA NMIEN
        RTS

; ---------------------------------------------------------------------
;  Second part, at $9700 (not loaded by the game, free at run time)
; ---------------------------------------------------------------------
        *= LDRB2

; "LOADING", ending where the bar ends (character 17), ROM font screen
; codes in COLPF3
LD_TXT  .BYTE 0,0,0,0,0,0,0,0,0,0,0
        .BYTE $2C+LD_PF3,$2F+LD_PF3,$21+LD_PF3,$24+LD_PF3
        .BYTE $29+LD_PF3,$2E+LD_PF3,$27+LD_PF3,0,0

; the loading screen (here, as the first part is full; one 1K block): the logo on the title's lines (TDLIST, 28 blank
; lines, LOGO_H mode D lines), LOADING on lines 180-187, the bar 192-197
LD_DL   .BYTE DL_DLI+DL_BLANK8          ; LD_DLI: the logo's gold
        .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK4
        .BYTE DL_LMS+DL_MODED
        .WORD LD_LOGO
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK8
        .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK8,DL_BLANK8
        .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK4
        .BYTE DL_LMS+DL_MODE6
        .WORD LD_TXT
        .BYTE DL_DLI+DL_BLANK4          ; LD_DLI: the bar's purple
        .BYTE DL_LMS+DL_MODED           ; the bar, 3 mode D lines of
        .WORD LD_BAR                    ; the same 40 bytes
        .BYTE DL_LMS+DL_MODED
        .WORD LD_BAR
        .BYTE DL_LMS+DL_MODED
        .WORD LD_BAR
        .BYTE DL_JVB
        .WORD LD_DL

; ---------------------------------------------------------------------
;  LD_DLI -- the loading screen's DLI: COLPF1 = the logo's gold at the
;  top of the screen, the bar's purple above the bar
;  In: nothing.  Out: nothing.  Keeps A, X, Y.
; ---------------------------------------------------------------------
LD_DLI  PHA
        LDA VCOUNT      ; which of the two
        CMP #LD_VMID
        LDA #LD_GOLD    ; (keeps the carry)
        BCC LD_DI1
        LDA #LD_FILL
LD_DI1  STA WSYNC
        STA COLPF1
        PLA
        RTI

; ---------------------------------------------------------------------
;  LD_STEP -- INITAD after each chunk of the game: the bar grows to
;  LD_TAB's next entry (bytes of fill, 0-LD_BW)
;  In: LD_N chunks loaded before this one.  Out: LD_N + 1.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
LD_STEP LDX LD_N
        LDY LD_TAB,X    ; the bar's length after this chunk
        INX
        STX LD_N
        TYA
        BEQ LD_SX
        LDA #LD_BON
LD_SL   STA LD_BAR+LD_BX-1,Y
        DEY
        BNE LD_SL
LD_SX   RTS

; RAM (not loaded): set up by LDR_INIT; LD_TAB loaded by the join
LD_N    *= *+1          ; chunks loaded
LD_BAR  *= *+40         ; the bar's mode D line
LD_TAB  *= *+LD_NTAB    ; the bar's length after each chunk
LD_END
