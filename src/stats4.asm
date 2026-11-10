; =====================================================================
;  STATS4.ASM -- the stats screen's summary page (T-SCR-11, D84)
;
;  The first page of the stats screen: for each player, how many of
;  each item they bought (rebels too), the gold they earned from
;  fishing, crops and factories, and the boats they lost to weather,
;  pirates and PT boats.  Two columns of 10 text lines in the status
;  font, at SYSCR (the chart's memory, free on this page), shown by
;  SYDLIST (DISPLAY.ASM) with the legend's colours: names yellow,
;  player 1's numbers red, player 2's turquoise, under each player's
;  pawn.
;
;  The counts are kept during play, by the routines below, which the
;  game calls in place of the one they end in:
;    SYBLT   ECO_BUY (ECONOMY.ASM), next to COUNT
;    SYGOLD  SY_FISH (FISH_TOUCH), SY_CROP (rain on crops, WEATHER.ASM),
;            SY_INC (the round's income, ECO_INCOME: 1 a fishing boat is
;            fishing, the rest factories); all go on to ECO_EARN, so
;            the three add up to the INCOME page's total
;    SYLOST  SY_LOSS (BOAT_LOSE, WS_GONE: every boat lost), by SY_WHY:
;            SY_PIR (the main loop's PIR_TIC) sets pirates, SY_PT (its
;            PT_TIC) PT boats; anything else (WTH_TIC) is weather
;  GAME_START clears them with COUNT (SY_NCLR bytes).
;
;  It sits after the pause band's font (FONT_PAUSE.ASM, 152 of its 1K),
;  on the 800 and the 5200: every code block is full.  SYEND must stay
;  below the title font (TTFONTA) at the next 1K.
; =====================================================================

SY_LC1  =  12           ; items: player 1's numbers end at this column
SY_LC2  =  16           ;   player 2's
SY_RC1  =  33           ; gold, boats lost: player 1's
SY_RC2  =  39           ;   player 2's
SY_ROWS =  10           ; text lines
SY_LR0  =  6            ; the first line of boats lost (weather)

; ---------------------------------------------------------------------
;  SY_DRAW -- (CT_DRAW, its page names drawn) the summary page: the
;  text cleared, its display list, the names, the numbers.
;  Trashes A, X, Y, ZPTR, M_NUM.
; ---------------------------------------------------------------------
SY_DRAW
        JSR CT_CLR      ; no chart left in SYSCR (its memory)
        LDA #<SYDLIST
        LDX #>SYDLIST
        JSR SY_DL
        LDX #0
SY_REC  LDA SYTXT,X     ; a record: line, column, characters, $FF
        BMI SY_NUMS     ; line $FF: the end
        STX SY_I
        PHA
        LDA SYTXT+1,X
        TAX
        PLA
        JSR SY_AT
        LDX SY_I
        INX
        INX
        LDY #0
SY_CH   LDA SYTXT,X
        INX
        CMP #$FF
        BEQ SY_REC      ; X: the next record
        STA (ZPTR),Y
        INY
        BNE SY_CH       ; (always)

SY_NUMS JSR SB_LSTP     ; the numbers, player 2 first (X = 1; in
                        ; SANDBOX player 1 only, X = 0, D87)
SY_PL   STX CT_P
        LDA CTPCOL,X    ; in the player's colour
        STA CT_TC
        LDA SYLCOL,X    ; items: lines 9 ... 1 are items 9 ... 1
        STA SY_C
        LDA #I_FSBT
        STA SY_R
SY_BLT  LDX CT_P
        LDA SY_R
        CLC
        ADC SYBOF,X     ; SYBLT + player x 10 + item
        TAX
        LDA SYBLT,X
        LDX #0
        JSR SY_NUM
        DEC SY_R
        BNE SY_BLT
        LDX CT_P
        LDA SYRCOL,X    ; gold: lines 3 ... 1 (factories ... fishing)
        STA SY_C
        LDA #3
        STA SY_R
SY_GLD  LDX CT_P
        LDA SY_R
        ASL A
        CLC
        ADC SYGOF,X     ; SYGOLD + player x 6 + (line - 1) x 2
        TAX
        LDA SYGOLD,X
        PHA
        LDA SYGOLD+1,X
        TAX
        PLA
        JSR SY_NUM
        DEC SY_R
        BNE SY_GLD
        LDA #SY_LR0+2   ; boats lost: lines 8 ... 6 (PT boats ... weather)
        STA SY_R
SY_LST  LDX CT_P
        LDA SY_R
        CLC
        ADC SYLOF,X     ; SYLOST + player x 3 + line - SY_LR0
        TAX
        LDA SYLOST,X
        LDX #0
        JSR SY_NUM
        DEC SY_R
        LDA SY_R
        CMP #SY_LR0
        BCS SY_LST
        LDX CT_P
        DEX
        BPL SY_PL
        RTS

; ---------------------------------------------------------------------
;  SY_NUM -- print A (low) / X (high) on line SY_R, ending at column
;  SY_C, the digits ORed with CT_TC.  Trashes A, X, Y, ZPTR, M_NUM.
; ---------------------------------------------------------------------
SY_NUM
        JSR NUM16
        JSR CT_DIGS     ; CTDB, CT_K digits
        LDA SY_C
        SEC
        SBC CT_K
        TAX
        INX             ; the first digit's column
        LDA SY_R
        JSR SY_AT
        LDY #0
SY_DIG  LDA CTDB,Y
        ORA #SC_0
        ORA CT_TC
        STA (ZPTR),Y
        INY
        CPY CT_K
        BCC SY_DIG
        RTS

; ---------------------------------------------------------------------
;  SY_AT -- ZPTR = SYSCR + A x 40 + X (A = line 0-9, X = column).
;  Trashes A, X.
; ---------------------------------------------------------------------
SY_AT
        STX SY_T
        STA ZPTR
        ASL A
        ASL A
        ADC ZPTR        ; line x 5 (C clear: line x 4 < 128)
        LDX #0
        STX ZPTR+1
        ASL A           ; x 40: only the last shift carries (45 x 8)
        ASL A
        ASL A
        ROL ZPTR+1      ; (C clear after it)
        ADC SY_T        ; + column
        STA ZPTR
        LDA ZPTR+1
        ADC #>SYSCR     ; (SYSCR is page aligned)
        STA ZPTR+1
        RTS

; ---------------------------------------------------------------------
;  SY_DL -- show display list A (low) / X (high).  The VBI copies
;  SDLSTL/H at VCOUNT 124, so both bytes are stored while VCOUNT is
;  under SY_VMAX: never half a change.  Trashes Y.
; ---------------------------------------------------------------------
SY_VMAX =  100
SY_DL
        LDY VCOUNT
        CPY #SY_VMAX
        BCS SY_DL       ; too near the VBI: wait
        STA SDLSTL
        STX SDLSTH
        RTS

; ---------------------------------------------------------------------
;  SY_FISH, SY_CROP -- ECO_EARN for player X's EG_AMT gold from fishing
;  (FISH_TOUCH) or rain on crops (WEATHER.ASM), also counted as such.
;  SY_INC -- the same for the round's income (ECO_INCOME, EC_CI =
;  player x 10): 1 gold for each fishing boat is fishing, the rest
;  (4 a factory and the bonus) factories.  As ECO_EARN: X kept,
;  A and Y trashed.
; ---------------------------------------------------------------------
SY_FISH LDY #0
        BEQ SY_EARN     ; (always)
SY_CROP LDY #2
SY_EARN JSR SY_GOLD
        JMP ECO_EARN

SY_INC
        LDA EG_AMT      ; the whole amount, for ECO_EARN
        PHA
        LDA EG_AMT+1
        PHA
        LDY EC_CI       ; factories: all but 1 a fishing boat
        LDA EG_AMT
        SEC
        SBC COUNT+I_FSBT,Y
        STA EG_AMT
        BCS SY_INB
        DEC EG_AMT+1
SY_INB  LDY #4
        JSR SY_GOLD
        LDY EC_CI       ; fishing: 1 a fishing boat
        LDA COUNT+I_FSBT,Y
        STA EG_AMT
        LDA #0
        STA EG_AMT+1
        TAY
        JSR SY_GOLD
        PLA
        STA EG_AMT+1
        PLA
        STA EG_AMT
        JMP ECO_EARN

; SY_GOLD -- add EG_AMT to player X's gold from source Y (0 fishing,
; 2 crops, 4 factories); it stops at 65535.  Keeps X.  Trashes A, Y.
SY_GOLD
        TYA
        CPX #1
        BCC SY_GP1
        ADC #5          ; player 2: + 6 (C is set)
SY_GP1  TAY
        CLC
        LDA SYGOLD,Y
        ADC EG_AMT
        STA SYGOLD,Y
        LDA SYGOLD+1,Y
        ADC EG_AMT+1
        STA SYGOLD+1,Y
        BCC SY_GOK
        LDA #$FF
        STA SYGOLD,Y
        STA SYGOLD+1,Y
SY_GOK  RTS

; ---------------------------------------------------------------------
;  SY_LOSS -- WS_COUNT (one fewer item WH_K for player WH_P); a boat
;  also counts as lost to SY_WHY.  As WS_COUNT: trashes A, X; keeps Y.
; ---------------------------------------------------------------------
SY_LOSS
        LDA WH_K
        CMP #I_PTBT
        BCC SY_LDN      ; not a boat
        LDA SY_WHY
        LDX WH_P
        BEQ SY_LP1
        ADC #2          ; player 2: + 3 (C is set)
SY_LP1  TAX
        INC SYLOST,X
SY_LDN  JMP WS_COUNT

; ---------------------------------------------------------------------
;  SY_PIR -- PIR_TIC (main loop), with what it sinks counted as lost to
;  pirates; SY_PT, at its end, PT_TIC: lost to PT boats.  Then weather
;  again.  Trash A, X, Y.
; ---------------------------------------------------------------------
SY_PIR
        LDA #1          ; pirates
        STA SY_WHY
        JSR PIR_TIC
        LDA #0          ; anything else: weather
        STA SY_WHY
        RTS
SY_PT   LDA #2          ; PT boats
        STA SY_WHY
        JMP PT_TIC

; ---------------------------------------------------------------------
;  Tables
; ---------------------------------------------------------------------
SYLCOL  .BYTE SY_LC1,SY_LC2     ; per player: the items' last column
SYRCOL  .BYTE SY_RC1,SY_RC2     ;   gold's and boats lost's
SYBOF   .BYTE 0,10              ;   SYBLT offset (+ line)
SYGOF   .BYTE $FE,4             ;   SYGOLD offset (+ line x 2)
SYLOF   .BYTE $FA,$FD           ;   SYLOST offset (+ line)

; the names: line, column, screen codes (pawns: STFONT icons, as
; CTPWN), $FF; a line of $FF ends them.  Under 256 bytes.
SYTXT   .BYTE 0,0
        .SBYTE "BUILT"
        .BYTE $FF,0,SY_LC1-1,$62,$63,0,0,$E4,$E5,$FF
        .BYTE 0,19
        .SBYTE "GOLD FROM    "
        .BYTE $62,$63,0,0,0,0,$E4,$E5,$FF
        .BYTE 1,0
        .SBYTE "FORTS"
        .BYTE $FF,2,0
        .SBYTE "FACTORIES"
        .BYTE $FF,3,0
        .SBYTE "CROPS"
        .BYTE $FF,4,0
        .SBYTE "SCHOOLS"
        .BYTE $FF,5,0
        .SBYTE "HOSPITALS"
        .BYTE $FF,6,0
        .SBYTE "HOUSES"
        .BYTE $FF,7,0
        .SBYTE "REBELS"
        .BYTE $FF,8,0
        .SBYTE "PT BOATS"
        .BYTE $FF,9,0
        .SBYTE "FISH BOATS"
        .BYTE $FF,1,19
        .SBYTE "FISHING"
        .BYTE $FF,2,19
        .SBYTE "CROPS"
        .BYTE $FF,3,19
        .SBYTE "FACTORIES"
        .BYTE $FF,5,19
        .SBYTE "BOATS LOST   "
        .BYTE $62,$63,0,0,0,0,$E4,$E5,$FF
        .BYTE SY_LR0,19
        .SBYTE "WEATHER"
        .BYTE $FF,SY_LR0+1,19
        .SBYTE "PIRATES"
        .BYTE $FF,SY_LR0+2,19
        .SBYTE "PT BOATS"
        .BYTE $FF,$FF

; SYDLIST -- the summary page's display list: the status bar and the
; page names as in CTDLIST, then 10 text lines from SYSCR (the chart's
; memory), the hint where CTDLIST has it.  The same 6 DLIs: two in
; blank lines after the page names, so the text gets the legend's
; colours (zone 5: yellow, red, turquoise).  Not in DLIST's page (it is
; full): SY_DL switches both bytes; it must not cross a 1K boundary
; (this file sits inside the pause font's 1K)
SYDLIST
        .BYTE DL_BLANK6,DL_BLANK8       ; 22 lines as in DLIST (D75)
        .BYTE DL_DLI+DL_BLANK8          ; DLI 0: status line 1's colours
        .BYTE DL_DLI+DL_LMS+DL_MODE4    ; status line 1; DLI 1: line 2's
        .WORD STATUS1
        .BYTE DL_DLI+DL_MODE4           ; line 2; DLI 2: the page names'
        .BYTE DL_BLANK4
        .BYTE DL_DLI+DL_LMS+DL_MODE4    ; page names; DLI 3
        .WORD CT_TAB
        .BYTE DL_DLI+DL_BLANK2          ; DLI 4
        .BYTE DL_DLI+DL_BLANK2          ; DLI 5: the text's colours
        .BYTE DL_BLANK8
        .BYTE DL_LMS+DL_MODE4           ; text line 0
        .WORD SYSCR
        .BYTE DL_BLANK6,DL_MODE4,DL_BLANK6,DL_MODE4,DL_BLANK6,DL_MODE4
        .BYTE DL_BLANK6,DL_MODE4,DL_BLANK6,DL_MODE4,DL_BLANK6,DL_MODE4
        .BYTE DL_BLANK6,DL_MODE4,DL_BLANK6,DL_MODE4,DL_BLANK6,DL_MODE4
        .BYTE DL_BLANK8,DL_BLANK2       ; (line 206, as in CTDLIST)
        .BYTE DL_LMS+DL_MODE4           ; the hint (CT_HINT)
        .WORD CT_HINT
        .BYTE DL_JVB
        .WORD SYDLIST
