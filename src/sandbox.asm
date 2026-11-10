; =====================================================================
;  SANDBOX.ASM -- the SANDBOX map (T-MODE-1, D87)
;
;  SANDBOX is the third choice on the setup screen's MAP line.  One
;  player builds alone on one big island (SB_GEN in MAPS.ASM draws it,
;  SBLAND in ISLANDS.ASM, generated): no CPU and no second island, and
;  rounds go on with no limit.  Weather, pirates and rebels from an
;  unhappy people all come as in a normal game; key 7 (a rebel for the
;  other island) is refused, as there is none.  The setup screen shows
;  "-" for ROUNDS, PLAYERS and CPU LEVEL and skips them.
;
;  These routines stand in for the calls they end in, so the rest of
;  the game only changes where it calls them:
;    SB_ON    Z set in a SANDBOX game (AI_ON, IN_SEL, GAME_START use it)
;    SB_TRN   status line 1: rounds left, or in SANDBOX the round
;    SB_HIDE  status lines: player 2's gold and people blank, ROUND
;    SB_RND   counts a round, never past 255
;    SB_PKEY  PAUSE_KEY, and in SANDBOX while paused START ends the
;             game (the game-over and stats screens follow as usual);
;             the news slot says so while paused
;    SB_CUR   CUR_MOVE, then player 2's cursor hidden in SANDBOX
;    SB_REB   key 7: refused in SANDBOX, else EB_PAY
;    SB_REBR  REB_ROUND, player 1 only in SANDBOX
;    SB_WIN   GAME_OVER's line 2: no winner in SANDBOX
;    SB_LINE, SB_MM, SB_NPL, SB_LSTP  the stats screen: player 1 only
;    SB_AI    AI_TIC's test: no CPU in SANDBOX
;  It sits in the free end of STANDARD's map font 2 (MFNT02E: codes
;  past its last character are never drawn) on both machines, as the
;  code blocks are full; SANDBOX2.ASM has the island and setup parts.
; =====================================================================

SB_TCOL =  11           ; status column of TURNS, ROUND in SANDBOX
SB_P2C  =  33           ; first column of player 2's gold bar
SB_P2L  =  73           ; first offset of player 2's pawn (line 2)
SB_HCOL =  NW_COL+1     ; the hint while paused (news slot, line 2)

; ---------------------------------------------------------------------
;  SB_ON -- Z set (A = 0) in a SANDBOX game.  Trashes A.
; ---------------------------------------------------------------------
SB_ON   LDA MAPNO
        EOR #MAP_SBX
        RTS

; ---------------------------------------------------------------------
;  SB_AI -- Z clear (A = 1) if player 2 is the CPU: a 1-player game,
;  not SANDBOX (AI_TIC).  Trashes A.
; ---------------------------------------------------------------------
SB_AI   JSR SB_ON
        BEQ SQ_ARTS     ; SANDBOX: A = 0
        JMP AI_ON
SQ_ARTS RTS

; ---------------------------------------------------------------------
;  SB_TRN -- status line 1's round field (STAT_DRAW): rounds left, 2
;  digits; in SANDBOX this round's number, 3 digits (ROUND before it,
;  SB_HIDE).  Trashes A, X, Y, M_NUM.
; ---------------------------------------------------------------------
SB_TRN  JSR SB_ON
        BEQ SQ_TSBX
        LDA NUMTRN      ; rounds left
        SEC
        SBC CURTRN
        LDX #0
        JSR NUM16
        LDA #2
        LDX #ST_TRN
        JMP TXT_DEC
SQ_TSBX  LDA CURTRN      ; SANDBOX: rounds played + 1
        LDX #0
        CLC
        ADC #1
        BCC SQ_TNUM
        INX             ; 256
SQ_TNUM  JSR NUM16
        LDA #3
        LDX #ST_TRN-1
        JMP TXT_DEC

; ---------------------------------------------------------------------
;  SB_HIDE -- in SANDBOX: ROUND for TURNS, and player 2's gold bar,
;  gold, pawn and people blank (STAT_DRAW, after player 1's numbers,
;  so player 2's are never drawn there).  Trashes A, X.
; ---------------------------------------------------------------------
SB_HIDE JSR SB_ON
        BNE SQ_HRTS
        LDX #4
SQ_HLAB  LDA TX_SBRN,X
        STA STATUS1+SB_TCOL,X
        DEX
        BPL SQ_HLAB
        LDA #0
        LDX #39-SB_P2C
SQ_HGLD  STA STATUS1+SB_P2C,X
        DEX
        BPL SQ_HGLD
        LDX #79-SB_P2L
SQ_HPOP  STA STATUS1+SB_P2L,X
        DEX
        BPL SQ_HPOP
SQ_HRTS  RTS

; ---------------------------------------------------------------------
;  SB_RND -- a round more (ROUND_END), never past 255.  Trashes A.
; ---------------------------------------------------------------------
SB_RND  INC CURTRN
        BNE SQ_RRTS
        DEC CURTRN
SQ_RRTS  RTS

; ---------------------------------------------------------------------
;  SB_PKEY -- PAUSE_KEY; in SANDBOX, while paused, the hint in the news
;  slot and START (pressed now) ends the game; on resume the slot is
;  cleared.  Out: as PAUSE_KEY (A = 0 and Z set: the game runs).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
SB_PKEY LDA CONKEY      ; START pressed this frame: SB_NEWC
        AND #1
        TAX
        LDA SB_OLDC
        EOR #1
        STX SB_OLDC
        AND SB_OLDC
        STA SB_NEWC
        JSR PAUSE_KEY
        PHP
        JSR SB_ON
        BNE SQ_KRTS      ; not SANDBOX: as PAUSE_KEY said
        LDA PAUSED
        BNE SQ_KPSD
        LDA SB_HNT      ; running: the hint goes
        BEQ SQ_KRTS
        LDA #0
        STA SB_HNT
        JSR NW_CLR
        JMP SQ_KRTS
SQ_KPSD  STA SB_HNT      ; paused: the hint (A = 1)
        LDA #<TX_SBEND
        LDY #>TX_SBEND
        LDX #SB_HCOL
        JSR TXT_STR
        LDA SB_NEWC
        BEQ SQ_KRTS
        PLP             ; START: the end of the game
        LDA #0
        STA SB_HNT
        JSR PAUSE_OFF
        JSR NW_CLR
        JSR GAME_OVER
        LDA #1          ; nothing else moves this frame
        RTS
SQ_KRTS  PLP
        RTS

; ---------------------------------------------------------------------
;  SB_REBR -- REB_ROUND: a rebel more or less for each player; in
;  SANDBOX player 1 only (player 2 has no land to put one on).
;  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
SB_REBR LDX #0
        JSR REB_TURN
        JSR SB_ON
        BEQ SQ_BRTS
        LDX #1
        JMP REB_TURN
SQ_BRTS RTS

; ---------------------------------------------------------------------
;  SB_CUR -- CUR_MOVE; in SANDBOX player 2's cursor stays hidden.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
SB_CUR  JSR CUR_MOVE
        JSR SB_ON
        BNE SQ_CRTS
        STA SPRHP+1     ; A = 0: off screen (SPR_VBI)
SQ_CRTS  RTS

; ---------------------------------------------------------------------
;  SB_REB -- key 7 (ECO_BUY): a rebel for the other island, which
;  SANDBOX hasn't: refused as not the player's land.
; ---------------------------------------------------------------------
SB_REB  JSR SB_ON
        BEQ SQ_NREB
        JMP EB_PAY
SQ_NREB JMP EB_LAND

; ---------------------------------------------------------------------
;  SB_WIN -- GAME_OVER's line 2: A/Y = the winner's text, or SANDBOX's.
;  Trashes Y.
; ---------------------------------------------------------------------
SB_WIN  PHA
        JSR SB_ON
        BEQ SQ_WSBX
        PLA
        RTS
SQ_WSBX  PLA
        LDA #<TX_SBW
        LDY #>TX_SBW
        RTS

; ---------------------------------------------------------------------
;  The stats screen in SANDBOX: player 1 only.
;  SB_LINE -- CT_LINE of player 2's series CT_S in its colour
;  SB_MM   -- CT_MM of player 2's series (CT_S + 1)
;  SB_NPL  -- CPX #2: the legend's players (SANDBOX: CPX #1)
;  SB_LSTP -- X = the last player, 1 (SANDBOX: 0)
;  Each trashes what the routine it stands for does, and A.
; ---------------------------------------------------------------------
SB_LINE JSR SB_ON
        BEQ SQ_LRTS
        LDA #CT_COL2
        STA CT_C
        JMP CT_LINE
SB_MM   JSR SB_ON
        BEQ SQ_LRTS
        INC CT_S
        JMP CT_MM
SB_NPL  JSR SB_ON
        BEQ SQ_NP1
        CPX #2
        RTS
SQ_NP1  CPX #1
SQ_LRTS RTS
SB_LSTP LDX #1
        JSR SB_ON
        BNE SQ_LRTS
        DEX
        RTS

TX_SBRN .SBYTE "ROUND"
TX_SBEND .SBYTE "START: END GAME"
        .BYTE TX_END
TX_SBW  .SBYTE " SANDBOX FINISHED"  ; CT_WLEN characters, as TX_W1
        .BYTE TX_END
