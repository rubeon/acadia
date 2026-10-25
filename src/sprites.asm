; =====================================================================
;  SPRITES.ASM -- player/missile graphics (D13, D15)
;
;  Double-line resolution: one P/M byte covers 2 scan lines, like a
;  mode 5 pixel, so a player 8 bytes tall is one map square (16 scan
;  lines) and a normal-width player (8 colour clocks) is one square
;  wide.  P/M memory is 1K at PMAREA:
;
;    PMAREA+$180  missiles     PMAREA+$200  player 0
;    PMAREA+$280  player 1     PMAREA+$300  player 2   +$380  player 3
;
;  Positions are kept in map pixels (column 0-159, line 0-87, the map's
;  top-left at 0,0).  SPR_PUT redraws a player's shape in P/M memory;
;  the horizontal positions go to the hardware in SPR_VBI, called from
;  the deferred VBI, so they never change mid-frame.
;
;  Only players 0 and 1 (the cursors) are used so far; pirates, fish
;  and weather (P2, P3, fifth player) come with M4.
; =====================================================================

PMAREA  =  $4000        ; 1K aligned (double-line)
PM_P0   =  PMAREA+$200
PM_LEN  =  $80          ; bytes per player
SPR_H   =  8            ; shape height in P/M lines

; Cursor colours (COLPM0, COLPM1)
C_CUR0  =  $46          ; player 1: red
C_CUR1  =  $AC          ; player 2: light turquoise

; ---------------------------------------------------------------------
;  PM_INIT -- clear P/M memory and switch players on
;  Call before DISP_INIT sets SDMCTL (DISP_INIT includes DMA_PM).
;  Trashes A, X.
; ---------------------------------------------------------------------
PM_INIT
        LDA #>PMAREA
        STA PMBASE
        LDA #0
        TAX
PI_CLR  STA PMAREA+$100,X       ; $4100-$43FF: missiles and players
        STA PMAREA+$200,X
        STA PMAREA+$300,X
        INX
        BNE PI_CLR
        STA SIZEP0      ; normal width: one square
        STA SIZEP1
        LDA #$FF        ; nothing drawn yet
        STA SPRY
        STA SPRY+1
        LDA #0          ; off screen until positioned
        STA SPRHP
        STA SPRHP+1
        LDA #C_CUR0
        STA PCOLR0
        LDA #C_CUR1
        STA PCOLR1
        LDA #PRI_MAP
        STA GPRIOR
        LDA #GR_PM
        STA GRACTL
        RTS

; ---------------------------------------------------------------------
;  SPR_PUT -- place player X (0 or 1) at map pixel A (column), Y (line)
;  Redraws the shape if the line changed.  Trashes A, Y, SPTR.
; ---------------------------------------------------------------------
SPR_PUT
        CLC
        ADC #HP_MAP
        STA SPRHP,X     ; horizontal: SPR_VBI writes it
        TYA
        CMP SPRY,X
        BEQ SP_DONE     ; same line: nothing to redraw
        PHA
        LDA SPRY,X      ; erase at the old line
        CMP #$FF
        BEQ SP_NEW
        JSR SP_ADDR
        LDY #SPR_H-1
        LDA #0
SP_CLR  STA (SPTR),Y
        DEY
        BPL SP_CLR
SP_NEW  PLA             ; draw at the new line
        STA SPRY,X
        JSR SP_ADDR
        LDY #SPR_H-1
SP_DRAW LDA CURSHP,Y
        STA (SPTR),Y
        DEY
        BPL SP_DRAW
SP_DONE RTS

; SP_ADDR -- SPTR = P/M address of map line A for player X (0 or 1)
; Players 0 and 1 share one page; map line + PM_MAP is below $80.
SP_ADDR CLC
        ADC #PM_MAP
        CPX #0
        BEQ SA_P0
        ORA #PM_LEN     ; player 1 is $80 further on
SA_P0   STA SPTR
        LDA #>PM_P0
        STA SPTR+1
        RTS

; ---------------------------------------------------------------------
;  SPR_VBI -- copy the players' horizontal positions to GTIA
;  Called from the deferred VBI.  Trashes A.
; ---------------------------------------------------------------------
SPR_VBI
        LDA SPRHP
        STA HPOSP0
        LDA SPRHP+1
        STA HPOSP1
        RTS

; Cursor: a hollow square frame, one square
CURSHP  .BYTE $FF,$81,$81,$81,$81,$81,$81,$FF
