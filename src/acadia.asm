; =====================================================================
;  ACADIA -- a clone of Mattel's "Utopia" for the Atari 8-bit
;
;  Main file.  Assemble with ATasm:  atasm -Isrc -obuild/acadia.xex
;
;  Memory map
;    $0080-$0087  zero page: math work area (MATH.ASM)
;    $00CB-$00CE  zero page: ZPTR, OLDVBD
;    $2000-       code and constant tables
;    $3000-$33FF  map font 0 (1K aligned)
;    $3400-$35B7  map screen (11 x 40, mode 5)
;    $3800-       display list
;    $3900-$3FFF  RAM variables (VARS.ASM)
;    $4800-$4BFF  map font 1
; =====================================================================

        .INCLUDE "hw_a800.asm"
        .INCLUDE "tiles.asm"

; ---------------------------------------------------------------------
;  Zero page
; ---------------------------------------------------------------------
M_NUM   =  $80          ; 3-byte math operand / result (MATH.ASM)
M_TMP   =  $83          ; 3-byte math work copy
M_OP    =  $86          ; math multiplier / divisor
M_OVF   =  $87          ; math overflow count
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
        JSR TIC_INIT

MAIN    LDA FRAME       ; wait for the next frame
MN_WAIT CMP FRAME
        BEQ MN_WAIT
        JSR INPUT_POLL
        JSR TIC_POLL
MN_TIC  JSR TIC_NEXT    ; run every due tic
        BCC MN_SHOW
        BNE MN_TIC      ; not a new second
        INC DEMOSEC
        JMP MN_TIC
MN_SHOW JSR SHOW_INPUT
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

        LDA DEMOSEC     ; seconds since start
        LSR A
        LSR A
        LSR A
        LSR A
        TAX
        LDA HEXTAB,X
        STA STATUS2+ST_SEC
        LDA DEMOSEC
        AND #$0F
        TAX
        LDA HEXTAB,X
        STA STATUS2+ST_SEC+1
        LDA #$2E        ; screen code "N"
        LDX TICLEN
        CPX #5
        BNE SI_STD
        LDA #$30        ; screen code "P"
SI_STD  STA STATUS2+ST_STD
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
        .INCLUDE "math.asm"
        .INCLUDE "rand.asm"
        .INCLUDE "tic.asm"
        .INCLUDE "display.asm"
        .INCLUDE "vars.asm"

; ---------------------------------------------------------------------
;  Run address
; ---------------------------------------------------------------------
        *= RUNAD
        .WORD START
