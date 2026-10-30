; =====================================================================
;  SCREENS.ASM -- the round loop, end-of-round summary, game over and
;  the info displays (T-SCR-2: R-SCR-6, R-MODE-4, R-CTL-4 / D18)
;
;  GSTATE steps through:
;    GS_PLAY   a round is running: TIME counts down each second
;    GS_SUM1   round over: each player's score for the round (3 s)
;    GS_SUM2   then each player's total score (3 s); then the next
;              round, or game over after the last one
;    GS_OVER   final scores and the winner; fire or any key goes back
;              to the setup screen (SETUP.ASM, GS_SETUP)
;  as the original does at $53EA-$549E ("SCORES", then "TOTALS", then
;  the next round or "FINAL SCORE").  The original holds each summary
;  in a busy loop of 12,500 RAND calls; 3 s here is an estimate of it.
;  Nothing moves and no keys act during a summary.
;
;  While a console key is held during a round, status line 1 shows
;  (D18): START both total scores, SELECT both populations, OPTION
;  both scores for the last round.
;
;  The setup screen (SETUP.ASM) sets NUMTRN and TRNLEN and calls
;  GAME_START; GAME_NEW starts a game with the defaults (tests).
; =====================================================================

GS_PLAY =  0
GS_SUM1 =  1
GS_SUM2 =  2
GS_OVER =  3

DEF_NUMTRN = 10         ; default rounds per game (setup screen)
DEF_TRNLEN = 30         ; default seconds per round (setup screen)
SUM_TICS =  60          ; each summary page: 60 tics = 3 s

; Status line 1 layout of the two-number pages (offsets)
SP_V0   =  3            ; player 1's number, 4 digits
SP_MID  =  9            ; 22-character title
SP_P2   =  33           ; "P2"
SP_V1   =  36           ; player 2's number, 4 digits

; ---------------------------------------------------------------------
;  GAME_NEW -- a new game with the default settings
;  GAME_START -- a new game with the current NUMTRN and TRNLEN
;  Clears the map and every player's buildings and scores, puts the
;  cursors back and starts round 1.  Trashes A, X, Y.
; ---------------------------------------------------------------------
GAME_NEW
        LDA #DEF_NUMTRN
        STA NUMTRN
        LDA #DEF_TRNLEN
        STA TRNLEN
GAME_START
        JSR MUS_STOP    ; the title tune ends
        JSR ST_COLS     ; the status bar's font and colours (D54)
        JSR KP_OFF      ; port 2: a stick, or the keypad in a 1-player
        LDA SU_VAL+SU_FPLY ; game with KEYPAD set (D49)
        CMP #1
        BNE GS_KP
        LDA SU_VAL+SU_FKP
        BEQ GS_KP
        JSR KP_ON
GS_KP
        LDA #0
        LDX #19
GN_CNT  STA COUNT,X
        DEX
        BPL GN_CNT
        LDX #3
GN_SC   STA SCORE,X
        STA RGOLD,X
        DEX
        BPL GN_SC
        STA RSCORE
        STA RSCORE+1
        STA PRSCORE
        STA PRSCORE+1
        STA CURTRN
        STA GSTATE
        STA INFOK
        LDA MAPNO       ; the chosen map's islands (D56)
        JSR MAP_LOAD
        JSR MAP_INIT    ; empty islands
        JSR MAP_DRAW
        JSR ECO_INIT    ; 1000 people, 100 gold each
        JSR CUR_INIT
        JSR FISH_INIT   ; no schools yet
        JSR WTH_INIT    ; no weather either
        JSR PIR_INIT    ; nor pirates
        JSR AI_INIT     ; the CPU starts afresh
        JSR TIC_INIT    ; the clock starts now, not when the last game ended
        LDA TRNLEN
        STA REMSEC
        LDX #39         ; status line 2 back to its template
GN_L2   LDA STATTPL+40,X
        STA STATUS2,X
        DEX
        BPL GN_L2
        JSR NEWS_OFF    ; no news yet
        ; fall through

; ---------------------------------------------------------------------
;  STAT_LINE -- status line 1 back to its template, then the numbers
; ---------------------------------------------------------------------
STAT_LINE
        LDA #C_SDKG     ; line 1's PF1: the gold bars' dark gold
        STA ST_L1
        LDX #39
SL_COPY LDA STATTPL,X
        STA STATUS1,X
        DEX
        BPL SL_COPY
        ; fall through

; ---------------------------------------------------------------------
;  STAT_DRAW -- status line 1: both players' gold, rounds left and the
;  seconds left in the round (R-SCR-1); line 2: both populations (D44)
; ---------------------------------------------------------------------
STAT_DRAW
        LDA GOLD
        LDX GOLD+1
        JSR NUM16
        LDA #4          ; the numbers are white (D54)
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
        JSR TXT_DEC
        LDA POP         ; line 2: populations (D44)
        LDX POP+1
        JSR NUM16
        LDA #5
        LDX #ST_P0
        JSR TXT_DEC
        LDA POP+2
        LDX POP+3
        JSR NUM16
        LDA #5
        LDX #ST_P1
        JMP TXT_DEC

; ---------------------------------------------------------------------
;  GAME_SEC -- a new second: during a round, count TIME down and end
;  the round at 0.  Trashes A, X, Y.
; ---------------------------------------------------------------------
GAME_SEC
        LDA GSTATE
        BNE GS_DONE
        DEC REMSEC
        BEQ ROUND_END
        JMP STAT_SHOW
GS_DONE RTS

; ROUND_END -- tone, income/population/score, then the summary
ROUND_END
        JSR SND_ROUND
        JSR ECO_ROUND
        JSR REB_ROUND   ; then a rebel more or less for each player
        INC CURTRN
        LDA #0
        STA INFOK
        LDA #GS_SUM1
        STA GSTATE
        LDA #SUM_TICS
        STA GTIMER
        LDA RSCORE      ; this round's scores
        STA SV0
        LDA RSCORE+1
        STA SV1
        LDA #0
        STA SV0+1
        STA SV1+1
        LDA #<TX_RND
        LDY #>TX_RND
        JMP SHOW_PAIR

; ---------------------------------------------------------------------
;  GAME_TIC -- every tic: time the news and the summary pages.  Trashes A, X, Y.
; ---------------------------------------------------------------------
GAME_TIC
        JSR NEWS_TIC    ; the news slot clears after 3 s
        LDA GSTATE
        BEQ GT_DONE     ; in a round
        CMP #GS_OVER
        BEQ GT_DONE
        DEC GTIMER
        BNE GT_DONE
        LDA GSTATE
        CMP #GS_SUM1
        BNE GT_NEXT
        LDA #GS_SUM2    ; round scores done: totals
        STA GSTATE
        LDA #SUM_TICS
        STA GTIMER
        LDX #3
GT_TOT  LDA SCORE,X
        STA SV0,X       ; SV0, SV1 follow each other, like SCORE
        DEX
        BPL GT_TOT
        LDA #<TX_TOT
        LDY #>TX_TOT
        JMP SHOW_PAIR
GT_NEXT LDA CURTRN      ; totals done: next round or game over
        CMP NUMTRN
        BCC GT_RND
        JMP GAME_OVER
GT_RND  LDA TRNLEN
        STA REMSEC
        LDA #GS_PLAY
        STA GSTATE
        JMP STAT_LINE
GT_DONE RTS

; ---------------------------------------------------------------------
;  GAME_OVER -- final scores on line 1, the winner on line 2
; ---------------------------------------------------------------------
GAME_OVER
        LDA #GS_OVER
        STA GSTATE
        LDA #0
        STA GO_ARM
        STA NW_T        ; line 2 blank for the winner
        LDX #39
GO_CL2  STA STATUS2,X
        DEX
        BPL GO_CL2
        LDX #3
GO_TOT  LDA SCORE,X
        STA SV0,X
        DEX
        BPL GO_TOT
        LDA #<TX_FIN
        LDY #>TX_FIN
        JSR SHOW_PAIR
        LDA SCORE+1     ; compare the totals
        CMP SCORE+3
        BNE GO_CMP
        LDA SCORE
        CMP SCORE+2
        BEQ GO_DRAW
GO_CMP  BCC GO_P2       ; player 1's total is lower
        LDA #<TX_W1
        LDY #>TX_W1
        BNE GO_LINE
GO_P2   LDA #<TX_W2
        LDY #>TX_W2
        BNE GO_LINE
GO_DRAW LDA #<TX_TIE
        LDY #>TX_TIE
GO_LINE LDX #40         ; status line 2
        JMP TXT_STR

; ---------------------------------------------------------------------
;  OVER_FRAME -- each frame of the game-over screen: once everything is
;  let go, fire or any key goes back to the setup screen.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
OVER_FRAME
        LDA FIRE0
        ORA FIRE1
        ORA KEYDOWN
        LDX GO_ARM
        BNE OF_ARMED
        CMP #0
        BNE OF_DONE     ; still held from the last round
        INC GO_ARM
OF_DONE RTS
OF_ARMED
        CMP #0
        BEQ OF_DONE
        JMP SETUP_ENTER ; back to the setup screen (R-MODE-4)

; ---------------------------------------------------------------------
;  INFO_KEYS -- during a round: show the info page for a held console
;  key, or the normal status line when it is let go (D18)
; ---------------------------------------------------------------------
INFO_KEYS
        LDA CONKEY
        LDX #0
        LSR A           ; START
        BCS IK_1
        LSR A           ; SELECT
        BCS IK_2
        LSR A           ; OPTION
        BCS IK_3
        BCC IK_SET
IK_3    INX
IK_2    INX
IK_1    INX
IK_SET  CPX INFOK
        BEQ IK_DONE     ; no change
        STX INFOK
        TXA
        BNE INFO_DRAW
        JMP STAT_LINE   ; key let go: normal status line
IK_DONE RTS

; STAT_SHOW -- redraw line 1 each second: the info page if one is up
STAT_SHOW
        LDA INFOK
        BNE INFO_DRAW
        JMP STAT_DRAW

; INFO_DRAW -- the info page INFOK: 1 total, 2 population, 3 last round
INFO_DRAW
        LDA INFOK
        CMP #2
        BEQ ID_POP
        BCS ID_LAST
        LDX #3          ; START: total scores
ID_TOT  LDA SCORE,X
        STA SV0,X
        DEX
        BPL ID_TOT
        LDA #<TX_ITOT
        LDY #>TX_ITOT
        JMP SHOW_PAIR
ID_POP  LDX #3          ; SELECT: populations
ID_PP   LDA POP,X
        STA SV0,X
        DEX
        BPL ID_PP
        LDA #<TX_IPOP
        LDY #>TX_IPOP
        JMP SHOW_PAIR
ID_LAST LDA RSCORE      ; OPTION: last round's scores
        STA SV0
        LDA RSCORE+1
        STA SV1
        LDA #0
        STA SV0+1
        STA SV1+1
        LDA #<TX_ILST
        LDY #>TX_ILST
        ; fall through

; ---------------------------------------------------------------------
;  SHOW_PAIR -- status line 1 as "P1 nnnn  <title>  P2 nnnn"
;  In: A/Y = the 22-character title (screen codes ending in TX_END),
;      SV0 / SV1 = the two numbers (16 bits).  Trashes A, X, Y.
; ---------------------------------------------------------------------
SHOW_PAIR
        PHA
        LDA #C_SRED     ; line 1's PF1: player 1's red again
        STA ST_L1
        LDA #0
        LDX #39
SH_CLR  STA STATUS1,X
        DEX
        BPL SH_CLR
        PLA
        LDX #SP_MID
        JSR TXT_STR
        LDA #<TX_P1
        LDY #>TX_P1
        LDX #0
        JSR TXT_STR
        LDA #<TX_P2
        LDY #>TX_P2
        LDX #SP_P2
        JSR TXT_STR
        LDA SV0
        LDX SV0+1
        JSR NUM16
        LDA #4
        LDX #SP_V0
        LDY #TX_RED
        JSR ST_DEC
        LDA SV1
        LDX SV1+1
        JSR NUM16
        LDA #4
        LDX #SP_V1
        LDY #TX_TURQ
        JMP ST_DEC

; Texts (screen codes); titles are 22 characters, centred
TX_P1   .BYTE $30+TX_RED,$11+TX_RED,TX_END     ; "P1" in red (STFONT)
TX_P2   .BYTE $30+TX_TURQ,$12+TX_TURQ,TX_END   ; "P2" in turquoise
TX_RND  .SBYTE "     ROUND SCORES     "
        .BYTE TX_END
TX_TOT  .SBYTE "     TOTAL SCORES     "
        .BYTE TX_END
TX_FIN  .SBYTE "     FINAL SCORES     "
        .BYTE TX_END
TX_ITOT .SBYTE "     TOTAL SCORE      "
        .BYTE TX_END
TX_IPOP .SBYTE "      POPULATION      "
        .BYTE TX_END
TX_ILST .SBYTE "      LAST ROUND      "
        .BYTE TX_END
TX_W1   .SBYTE " PLAYER 1 WINS!  FIRE OR KEY: NEW GAME  "
        .BYTE TX_END
TX_W2   .SBYTE " PLAYER 2 WINS!  FIRE OR KEY: NEW GAME  "
        .BYTE TX_END
TX_TIE  .SBYTE "     A DRAW!  FIRE OR KEY: NEW GAME     "
        .BYTE TX_END
