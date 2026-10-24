; =====================================================================
;  ACADIA -- a clone of Mattel's "Utopia" for the Atari 8-bit
;
;  Main file.  Assemble with ATasm:  atasm -Isrc -obuild/acadia.xex
;
;  Memory map
;    $00CB-$00CF  zero page work area (free with or without BASIC)
;    $2000-       code and variables
;    $3000-$33FF  map font (1K aligned)
;    $3400-$376F  map screen (22 x 40)
;    $3800-       display list
;    $3900-$3FFF  RAM variables (VARS.ASM)
; =====================================================================

        .INCLUDE "hw_a800.asm"

; ---------------------------------------------------------------------
;  Zero page
; ---------------------------------------------------------------------
ZPTR    =  $CB          ; 2-byte general pointer
OLDVBD  =  $CD          ; 2-byte saved deferred VBI vector

; ---------------------------------------------------------------------
;  Entry point
; ---------------------------------------------------------------------
        *= $2000
START
        CLD
        JSR VARS_INIT
        JSR DISP_INIT

MAIN    LDA FRAME       ; wait for the next frame
MN_WAIT CMP FRAME
        BEQ MN_WAIT
        JSR INPUT_POLL
        JSR SHOW_INPUT
        JMP MAIN

; ---------------------------------------------------------------------
;  SHOW_INPUT -- echo the input layer state on status line 2
; ---------------------------------------------------------------------
SHOW_INPUT
        LDX JOY0
        LDA HEXTAB,X
        STA STATUS2+ST_J0
        LDX FIRE0
        LDA HEXTAB,X
        STA STATUS2+ST_F0
        LDX JOY1
        LDA HEXTAB,X
        STA STATUS2+ST_J1
        LDX FIRE1
        LDA HEXTAB,X
        STA STATUS2+ST_F1

        LDX KEY         ; show only new presses; keep the last one
        BMI SI_FRM
        LDA HEXTAB,X
        STA STATUS2+ST_KEY

SI_FRM  LDA FRAME
        LSR A
        LSR A
        LSR A
        LSR A
        TAX
        LDA HEXTAB,X
        STA STATUS2+ST_FRM
        LDA FRAME
        AND #$0F
        TAX
        LDA HEXTAB,X
        STA STATUS2+ST_FRM+1
        RTS

HEXTAB  .SBYTE "0123456789ABCDEF"

; ---------------------------------------------------------------------
;  VARS_INIT -- clear the RAM variable block, then set the variables
;  that do not start at zero.  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
VARS_INIT
        LDA #<VARBASE
        STA ZPTR
        LDA #>VARBASE
        STA ZPTR+1
        LDX #VARPAGES
        LDA #0
        TAY
VI_CLR  STA (ZPTR),Y
        INY
        BNE VI_CLR
        INC ZPTR+1
        DEX
        BNE VI_CLR

        LDA #$FF        ; no key pressed yet
        STA KEY
        RTS

        .INCLUDE "input.asm"
        .INCLUDE "display.asm"
        .INCLUDE "vars.asm"

; ---------------------------------------------------------------------
;  Run address
; ---------------------------------------------------------------------
        *= RUNAD
        .WORD START
