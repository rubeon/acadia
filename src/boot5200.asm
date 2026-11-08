; =====================================================================
;  BOOT5200.ASM -- the 5200's start-up without the BIOS screen (D77)
;
;  Part of the 5200's platform layer, in code block 2 (block 1 is
;  full).  The header's $BFFD = $FF tells the BIOS to skip its title
;  screen ("COPYRIGHT 19.." and the Atari logo).  It then jumps to
;  START at once, after only SEI, CLD and a fresh stack: no RAM or
;  chip clear, no vectors at $0200, no NMIs, no keypad scan.  So the
;  cartridge does that itself here (D62 had found the crash without
;  it).  The handlers are our own, not the BIOS's: their addresses in
;  its ROM differ between BIOS revisions.  The BIOS's NMI and IRQ
;  entries ($FFFA, $FFFE) still run first; they only dispatch:
;    NMI  BIT NMIST, STA NMIRES, then JMP (VDSLST) for a DLI or
;         JMP (VVBLKI) for the VBI, with no register saved
;    IRQ  JMP (VIMIRQ), with no register saved
; =====================================================================

; ---------------------------------------------------------------------
;  BT_INIT -- from START (I flag set, D clear, a fresh stack): all RAM
;  and the chips' registers cleared, the vectors, the keypad scan, as
;  the BIOS leaves them on its normal path, then MAIN_INIT.  NMIs and
;  IRQs stay off: PLAT_INIT turns the VBI on, and no IRQ is ever
;  enabled (POKMSK stays 0; the keypad and buttons are polled).
;  Entered by JMP; never returns.
; ---------------------------------------------------------------------
BT_INIT
        LDA #0
        STA ZPTR        ; ZPTR -> $3F00, the top page of RAM
        LDA #>BT_TOP
        STA ZPTR+1
        LDA #0
        TAY
BT_RAM  STA (ZPTR),Y    ; pages $3F down to $01 (the stack is empty)
        INY
        BNE BT_RAM
        DEC ZPTR+1
        LDX ZPTR+1
        BNE BT_RAM
BT_CHIP STA AUDF1,X     ; then POKEY's, GTIA's and ANTIC's registers
        STA HPOSP0,X    ; (and their mirrors), and the zero page last,
        STA DMACTL,X    ; as ZPTR is in it
        STA $00,X
        INX
        BNE BT_CHIP

        LDX #BT_VECN-1  ; our handlers in the vectors
BT_VEC  LDA BT_VECS,X
        STA VIMIRQ,X
        DEX
        BPL BT_VEC
        LDA #ROMFONT    ; the BIOS's font until a screen sets one
        STA CHBASE
        LDA #BT_SKEY    ; the keypad scan on (and the pots' fast scan
        STA SKCTL       ; off), as the BIOS sets it
        JMP MAIN_INIT

BT_TOP  =  RAMEND-$100   ; the top page of RAM
BT_SKEY =  $02          ; SKCTL: keyboard (keypad) scan on

; the vector table, from VIMIRQ ($0200) on
BT_VECS .WORD BT_IRQ    ; VIMIRQ: an IRQ (none is enabled)
        .WORD BT_VBI    ; VVBLKI: the immediate VBI
        .WORD BT_XIT    ; VVBLKD: the deferred VBI's end
        .WORD BT_RTI    ; VDSLST: no DLI until a screen sets one
        .WORD BT_RTI    ; VKYBDI, VKYBDF: only called from the BIOS's
        .WORD BT_RTI    ; IRQ handler, which VIMIRQ no longer is
BT_VECN =  12           ; bytes in BT_VECS

; ---------------------------------------------------------------------
;  BT_VBI -- the immediate VBI (VVBLKI), the BIOS's work: A, X, Y
;  saved; RTCLOK counted, ATRACT every 256 frames; unless CRITIC is
;  set, the display list and DMA shadows to ANTIC, the colour shadows
;  to GTIA (attract mode: shifted and dimmed once ATRACT reaches $80),
;  the pots read into PADDL0-7 and a new pot scan; then the deferred
;  VBI (VVBLKD), which ends at BT_XIT.
; ---------------------------------------------------------------------
BT_VBI  PHA
        TXA
        PHA
        TYA
        PHA
        INC RTCLOK+1    ; the low byte (the BIOS keeps it high first)
        BNE BV_CRIT
        INC ATRACT      ; every 256 frames
        INC RTCLOK
BV_CRIT LDA CRITIC      ; critical code: nothing more
        BNE BT_XIT
        LDA SDLSTL
        STA DLISTL
        LDA SDLSTH
        STA DLISTH
        LDA SDMCTL
        STA DMACTL
        LDA ATRACT      ; attract mode: hold ATRACT at $80
        BPL BV_COL0
        LDA #BV_ATR
        STA ATRACT
BV_COL0 LDX #COLOR4-PCOLR0
BV_COL  LDA PCOLR0,X    ; COLPM0-3, COLPF0-3, COLBK
        BIT ATRACT
        BPL BV_SET
        EOR RTCLOK      ; attract: colours change every 256 frames,
        AND #BV_DIM     ; never full brightness
BV_SET  STA COLPM0,X
        DEX
        BPL BV_COL
        LDX #7
BV_POT  LDA POT0,X      ; the controllers' pots
        STA PADDL0,X
        DEX
        BPL BV_POT
        STA POTGO       ; and the next scan
        JMP (VVBLKD)

BV_ATR  =  $80          ; ATRACT from here on: attract mode
BV_DIM  =  $F6          ; attract: luminance bits 0 and 3 off

; ---------------------------------------------------------------------
;  BT_XIT -- the end of the VBI (the default VVBLKD, and PLAT_VBI's
;  last jump through PV_OLD): A, X, Y back, RTI
; ---------------------------------------------------------------------
BT_XIT  PLA
        TAY
        PLA
        TAX
        PLA
BT_RTI  RTI

; ---------------------------------------------------------------------
;  BT_IRQ -- VIMIRQ: no IRQ is enabled, so any that comes is turned off
;  (IRQEN to 0, then POKMSK's) and ignored
; ---------------------------------------------------------------------
BT_IRQ  PHA
        LDA #0
        STA IRQEN
        LDA POKMSK
        STA IRQEN
        PLA
        RTI
