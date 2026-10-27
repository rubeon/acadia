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
        JSR SND_INIT    ; POKEY quiet
        JSR DISP_INIT
        JSR TIC_INIT
        JSR SETUP_INIT  ; default rounds and round length
        JSR TITLE_ENTER ; the title screen first (T-REL-1)

MAIN    LDA FRAME       ; wait for the next frame
MN_WAIT CMP FRAME
        BEQ MN_WAIT
        JSR GAME_FRAME
        JMP MAIN

; ---------------------------------------------------------------------
;  GAME_FRAME -- one frame of the game, called by the main loop
; ---------------------------------------------------------------------
GAME_FRAME
        JSR INPUT_POLL
        LDA GSTATE
        CMP #GS_SETUP
        BEQ GF_SETUP
        CMP #GS_TITLE
        BNE GF_OVER
        JMP TITLE_FRAME ; title screen (T-REL-1)
GF_SETUP JMP SETUP_FRAME ; setup screen
GF_OVER CMP #GS_OVER
        BNE GF_RUN
        JMP OVER_FRAME  ; game over: wait for fire or a key
GF_RUN  JSR HELP_KEY    ; H / HELP: price list (D34)
        BNE GF_SHOW     ; help is up: nothing moves
        JSR PAUSE_KEY   ; P: pause / resume (D19)
        BNE GF_SHOW     ; paused: nothing moves
        LDA GSTATE
        BNE GF_TICS     ; round summary: nothing moves either
        JSR AI_FRAME    ; 1 player: the CPU's stick (D39)
        JSR CUR_MOVE
        JSR ECO_KEY     ; buy with digit keys (D17)
        JSR INFO_KEYS   ; console keys: info pages (D18)
GF_TICS JSR TIC_POLL
GF_TIC  JSR TIC_NEXT    ; run every due tic
        BCC GF_SHOW
        BNE GF_T1       ; not a new second
        JSR GAME_SEC
GF_T1   JSR GAME_TIC
        LDA GSTATE
        BNE GF_TIC      ; fish only during a round
        JSR FISH_TIC
        JSR WTH_TIC
        JSR PIR_TIC
        JSR AI_TIC      ; the CPU thinks (1 player)
        JMP GF_TIC
GF_SHOW JSR FISH_SHOW
        JSR WTH_SHOW
        JMP PIR_SHOW

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

; ---------------------------------------------------------------------
;  Game logic: second code block above the fonts ($2000-$2FFF is full)
; ---------------------------------------------------------------------
CODE2   =  $5000
        *= CODE2
        .INCLUDE "economy.asm"
        .INCLUDE "boats.asm"
        .INCLUDE "fish.asm"
        .INCLUDE "weather.asm"
        .INCLUDE "pirates.asm"
        .INCLUDE "rebels.asm"
        .INCLUDE "ai.asm"
        .INCLUDE "sound.asm"
        .INCLUDE "music.asm"
        .INCLUDE "pause.asm"
        .INCLUDE "help.asm"
        .INCLUDE "screens.asm"
        .INCLUDE "title.asm"
        .INCLUDE "news.asm"
        .INCLUDE "setup.asm"
        .INCLUDE "vars.asm"

; ---------------------------------------------------------------------
;  Run address
; ---------------------------------------------------------------------
        *= RUNAD
        .WORD START
