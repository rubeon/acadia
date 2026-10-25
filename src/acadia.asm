; =====================================================================
;  ACADIA -- a clone of Mattel's "Utopia" for the Atari 8-bit
;
;  Main file.  Assemble with ATasm:  atasm -Isrc -obuild/acadia.xex
;
;  Memory map
;    $0080-$0087  zero page: math work area (MATH.ASM)
;    $0088-$0089  zero page: TPTR (TEXT.ASM)
;    $008A-$008B  zero page: SPTR (SPRITES.ASM)
;    $00CB-$00CE  zero page: ZPTR, OLDVBD
;    $2000-       code and constant tables
;    $3000-$33FF  map font 0 (1K aligned)
;    $3400-$35B7  map screen (11 x 40, mode 5)
;    $3800-       display list
;    $3900-$3FFF  RAM variables (VARS.ASM)
;    $4000-$43FF  P/M graphics, double-line (SPRITES.ASM)
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
TPTR    =  $88          ; 2-byte string pointer (TEXT.ASM)
SPTR    =  $8A          ; 2-byte P/M pointer (SPRITES.ASM)
ZPTR    =  $CB          ; 2-byte general pointer
OLDVBD  =  $CD          ; 2-byte saved deferred VBI vector

; ---------------------------------------------------------------------
;  Entry point
; ---------------------------------------------------------------------
        *= $2000
START
        CLD
        JSR VARS_INIT
        JSR MAP_INIT
        JSR DISP_INIT
        JSR CUR_INIT
        JSR TIC_INIT
        JSR DEMO_INIT

MAIN    LDA FRAME       ; wait for the next frame
MN_WAIT CMP FRAME
        BEQ MN_WAIT
        JSR INPUT_POLL
        JSR CUR_MOVE
        JSR TIC_POLL
MN_TIC  JSR TIC_NEXT    ; run every due tic
        BCC MN_SHOW
        BNE MN_TIC      ; not a new second
        JSR DEMO_SEC
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

        LDA #$2E        ; screen code "N"
        LDX TICLEN
        CPX #5
        BNE SI_STD
        LDA #$30        ; screen code "P"
SI_STD  STA STATUS2+ST_STD
        RTS

HEXTAB  .SBYTE "0123456789ABCDEF"

; ---------------------------------------------------------------------
;  Test-build demo clock: placeholder game state counted down by the
;  tic so the status bar (R-SCR-1) shows live values.  Replaced by the
;  real round logic in M3.  10 rounds of 30 s, 100 gold each, +10 gold
;  at the end of every round.
; ---------------------------------------------------------------------
DEMO_INIT
        LDA #10
        STA NUMTRN
        LDA #30
        STA TRNLEN
        STA REMSEC
        LDA #0
        STA CURTRN
        STA GOLD+1
        STA GOLD+3
        LDA #100
        STA GOLD
        STA GOLD+2
        JMP STAT_DRAW

DEMO_SEC
        DEC REMSEC
        BNE STAT_DRAW
        INC CURTRN      ; end of round
        LDA CURTRN
        CMP NUMTRN
        BCC DS_RND
        LDA #0          ; demo: start over after the last round
        STA CURTRN
DS_RND  LDA TRNLEN
        STA REMSEC
        LDX #0          ; +10 gold for each player
DS_GOLD CLC
        LDA GOLD,X
        ADC #10
        STA GOLD,X
        LDA GOLD+1,X
        ADC #0
        STA GOLD+1,X
        INX
        INX
        CPX #4
        BNE DS_GOLD
        ; fall through

; ---------------------------------------------------------------------
;  STAT_DRAW -- status line 1: both players' gold, rounds left and the
;  seconds left in the round (R-SCR-1)
; ---------------------------------------------------------------------
STAT_DRAW
        LDA GOLD
        LDX GOLD+1
        JSR NUM16
        LDA #4
        LDX #ST_G0
        JSR TXT_DEC
        LDA NUMTRN      ; rounds left
        SEC
        SBC CURTRN
        LDX #0
        JSR NUM16
        LDA #2
        LDX #ST_TRN
        JSR TXT_DEC
        LDA REMSEC
        LDX #0
        JSR NUM16
        LDA #3
        LDX #ST_TIME
        JSR TXT_DEC
        LDA GOLD+2
        LDX GOLD+3
        JSR NUM16
        LDA #4
        LDX #ST_G1
        JMP TXT_DEC

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
        .INCLUDE "text.asm"
        .INCLUDE "sprites.asm"
        .INCLUDE "cursor.asm"
        .INCLUDE "map.asm"
        .INCLUDE "display.asm"
        .INCLUDE "vars.asm"

; ---------------------------------------------------------------------
;  Run address
; ---------------------------------------------------------------------
        *= RUNAD
        .WORD START
