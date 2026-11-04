; =====================================================================
;  MAIN.ASM -- start-up and frame loop shared by every build (D62)
;
;  Each build's top-level file (ACADIA.ASM: 800 XEX, ACADIA5200.ASM:
;  5200 cartridge) has its own START, which does that machine's set-up
;  and then jumps to MAIN_INIT here.  Two hooks, defined by each build's
;  PLAT_ file (PLAT_A800.ASM, PLAT_5200.ASM):
;    PLAT_INIT  called right after VARS_INIT
;    PLAT_MAP   called by MAP_LOAD right after it copies a map's block
;               over the live tables, before RM_GEN
;
;  Include in code space before any other module: the zero page
;  equates below must be known before the modules that use them.
; =====================================================================

; ---------------------------------------------------------------------
;  Zero page
; ---------------------------------------------------------------------
M_NUM   =  $80          ; 3-byte math operand / result (MATH.ASM)
M_TMP   =  $83          ; 3-byte math work copy
M_OP    =  $86          ; math multiplier / divisor
M_OVF   =  $87          ; math overflow count
TPTR    =  $88          ; 2-byte string pointer (TEXT.ASM)
SPTR    =  $8A          ; 2-byte P/M pointer (SPRITES.ASM)
DL_NP2  =  $8C          ; DLI_ROW -> DLI_SQ: next square row's weather
DL_NP3  =  $8D          ; and fish positions (DISPLAY.ASM, D52)
DL_NBK  =  $8E          ; DLI_MAP / DLI_SQ -> DLI_ROW: the next row's
DL_NPF  =  $8F          ; sea (COLBK), PF0 and font, ready before its
DL_NFN  =  $90          ; first line (D55)
ZPTR    =  $CB          ; 2-byte general pointer
OLDVBD  =  $CD          ; 2-byte saved deferred VBI vector

; ---------------------------------------------------------------------
;  MAIN_INIT -- common start-up, entered by JMP from START (CLD done).
;  Never returns: it runs the main loop.
; ---------------------------------------------------------------------
MAIN_INIT
        JSR VARS_INIT
        JSR PLAT_INIT   ; the machine's own set-up (D62)
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
        LDA DEMO
        BEQ GF_ST
        JSR DEMO_FRAME  ; the demo: scripted player 1, or back to title
        BCC GF_ST
        RTS
GF_ST   LDA GSTATE
        CMP #GS_TITLE
        BNE GF_SU
        JMP TITLE_FRAME ; title screen
GF_SU   CMP #GS_SETUP
        BNE GF_OVER
        JMP SETUP_FRAME ; setup screen
GF_OVER CMP #GS_OVER
        BNE GF_RUN
        JMP OVER_FRAME  ; game over: wait for fire or a key
GF_RUN  JSR FIRE_TAP    ; a tap of fire is key 0 (D60)
        JSR HELP_KEY    ; H / HELP: price list (D34)
        BNE GF_SHOW     ; help is up: nothing moves
        JSR PAUSE_KEY   ; P: pause / resume (D19)
        BNE GF_SHOW     ; paused: nothing moves
        LDA GSTATE
        BNE GF_TICS     ; round summary: nothing moves either
        JSR AI_FRAME    ; 1 player: the CPU's stick (D39)
        JSR CUR_MOVE
        JSR ECO_KEY     ; buy with digit keys (D17)
        JSR INFO_KEYS   ; console keys: info pages (D18)
        JSR WAVE_ANI    ; the waves move (D51)
        JSR TRAIL_TIC   ; and boats leave wakes (D59)
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

