; =====================================================================
;  ACADIA -- a clone of Mattel's "Utopia" for the Atari 8-bit
;
;  Main file.  Assemble with ATasm:  atasm -Isrc -obuild/acadia.xex
;
;  Memory map
;    $00CB-$00CF  zero page work area (free with or without BASIC)
;    $2000-       code and variables
;    $3000-$33FF  map font (1K aligned)
;    $3400-$35B7  map screen (11 x 40, mode 5)
;    $3800-       display list
;    $4000-$43FF  P/M graphics (double-line)
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
        JSR DISP_INIT

MAIN    LDA FRAME       ; wait for the next frame
MN_WAIT CMP FRAME
        BEQ MN_WAIT
        JSR INPUT_POLL
        JMP MAIN

        .INCLUDE "input.asm"
        .INCLUDE "display.asm"

; ---------------------------------------------------------------------
;  Run address
; ---------------------------------------------------------------------
        *= RUNAD
        .WORD START
