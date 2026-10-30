; =====================================================================
;  HELP.ASM -- purchase help screen (T-SCR-3, D34)
;
;  H (or HELP on an XL/XE) during a round puts a price list over the
;  map: one line per item with its key, the tile it has on the map,
;  its name and its price.  H or HELP again goes back to the game.
;  While the list is up the game stands still as when paused (D19):
;  no cursors, buying, tics or round clock; TIC_SYNC drops the frames
;  that passed.  H does nothing while the game is paused or between
;  rounds.
;
;  The list uses its own display list, HDLIST: the status bar, then 11
;  mode 5 lines from HELPSCR in the help font HLPFONT (FONT_MAP.ASM,
;  generated): the fixed tiles at their map codes, plus 3 x 5 letters
;  and digits at screen code + HELP_OFS.  Text is yellow, or white
;  with the inverse bit (HL_WHITE).  The DLI sees HELPON and loads
;  the help font, with player 3 (fish) off screen.
; =====================================================================

HELPSCR =  $4400        ; 11 x 40 help screen, after P/M memory
HL_ROWS =  11           ; lines on the help screen
HL_YELL =  $00          ; text colour: yellow (PF2)
HL_WHITE = $80          ; text colour: white (PF3, inverse characters)
HL_CKEY =  2            ; column of the key digit
HL_CICN =  5            ; column of the tile (2 characters)
HL_CNAM =  9            ; column of the name
HL_CPRC =  27           ; column of the price (3 digits)

; ---------------------------------------------------------------------
;  HELP_KEY -- open or close the help screen if H / HELP was pressed
;  Call after INPUT_POLL.  Out: A = HELPON (0 = no help), Z set if the
;  help screen is not up.  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
HELP_KEY
        LDA HELPK
        BEQ HK_DONE
        LDA HELPON
        BNE HK_OFF
        LDA PAUSED      ; not while paused
        BNE HK_DONE
        LDA GSTATE      ; only while a round runs
        BNE HK_DONE
        JSR HELP_ON
        JMP HK_DONE
HK_OFF  JSR HELP_OFF
HK_DONE LDA HELPON
        RTS

; ---------------------------------------------------------------------
;  HELP_ON -- draw the price list and show it.
;  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
HELP_ON
        JSR HELP_DRAW
        LDA #0          ; cursors off screen (HPOS 0)
        STA SPRHP
        STA SPRHP+1
        LDA #1
        STA HELPON
        LDA #<HDLIST    ; same page as DLIST: one store switches
        STA SDLSTL
        RTS

; ---------------------------------------------------------------------
;  HELP_OFF -- back to the map; the frames spent in help are dropped.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
HELP_OFF
        LDA #<DLIST
        STA SDLSTL
        LDA #0
        STA HELPON
        JSR TIC_SYNC
        LDX #0          ; cursors back where they were
        JSR CU_SHOW
        LDX #1
        JMP CU_SHOW

; ---------------------------------------------------------------------
;  HELP_DRAW -- fill HELPSCR: title, one line per item 1-9, how to
;  leave.  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
HELP_DRAW
        LDA #0          ; clear (code 0: the blank sea tile)
        LDX #HL_ROWS*MAPCOLS/2-1
HD_CLR  STA HELPSCR,X
        STA HELPSCR+HL_ROWS*MAPCOLS/2,X
        DEX
        CPX #$FF
        BNE HD_CLR
        LDA #0          ; title line
        LDX #HL_CKEY
        JSR HL_AT
        LDA #<HLS_TTL
        LDY #>HLS_TTL
        LDX #HL_YELL
        JSR HL_STR
        LDA #0
        LDX #HL_CPRC-2
        JSR HL_AT
        LDA #<HLS_PRC
        LDY #>HLS_PRC
        LDX #HL_YELL
        JSR HL_STR
        LDA #HL_ROWS-1  ; last line: how to leave
        LDX #HL_CKEY
        JSR HL_AT
        LDA #<HLS_BACK
        LDY #>HLS_BACK
        LDX #HL_YELL
        JSR HL_STR

        LDA #1          ; items 1-9 on lines 1-9
        STA HL_K
HD_ITEM LDA HL_K
        LDX #0
        JSR HL_AT       ; ZPTR = start of line k
        LDA HL_K        ; key digit
        CLC
        ADC #SC_0+HELP_OFS
        ORA #HL_WHITE
        LDY #HL_CKEY
        STA (ZPTR),Y
        LDA HL_K        ; the item's tile, 2 help font characters
        CLC
        ADC #T_ITEM-1
        TAX
        LDA HLPCH,X
        LDY #HL_CICN
        STA (ZPTR),Y
        LDA HLPCHR,X    ; right half
        INY
        STA (ZPTR),Y
        LDX HL_K        ; price
        LDA PRICES,X
        LDY #HL_CPRC
        JSR HL_NUM
        LDA HL_K        ; name
        LDX #HL_CNAM
        JSR HL_AT
        LDX HL_K
        LDA HLN_LO-1,X
        LDY HLN_HI-1,X
        LDX #HL_WHITE
        JSR HL_STR
        INC HL_K
        LDA HL_K
        CMP #10
        BNE HD_ITEM
        RTS

; ---------------------------------------------------------------------
;  HL_AT -- ZPTR = HELPSCR + line A * 40 + column X.  Trashes A, X.
; ---------------------------------------------------------------------
HL_AT   STX HL_T
        TAX
        LDA #<HELPSCR
        CLC
        ADC HL_T
        STA ZPTR
        LDA #>HELPSCR
        ADC #0
        STA ZPTR+1
HA_ROW  DEX
        BMI HA_DONE
        LDA ZPTR
        CLC
        ADC #MAPCOLS
        STA ZPTR
        BCC HA_ROW
        INC ZPTR+1
        BCS HA_ROW      ; always
HA_DONE RTS

; ---------------------------------------------------------------------
;  HL_STR -- write screen codes at A/Y (low/high, ending in TX_END) to
;  ZPTR in the help font, colour X (HL_YELL / HL_WHITE).  Spaces stay
;  code 0.  Trashes A, Y, TPTR.
; ---------------------------------------------------------------------
HL_STR  STA TPTR
        STY TPTR+1
        STX HL_C
        LDY #0
HS_CHR  LDA (TPTR),Y
        CMP #TX_END
        BEQ HS_DONE
        CMP #0
        BEQ HS_PUT      ; space: blank
        CLC
        ADC #HELP_OFS
        ORA HL_C
HS_PUT  STA (ZPTR),Y
        INY
        BNE HS_CHR
HS_DONE RTS

; ---------------------------------------------------------------------
;  HL_NUM -- write A (0-255) as 3 white digits at (ZPTR),Y, leading
;  zeros blank.  Trashes A, X, Y.
; ---------------------------------------------------------------------
HL_NUM  LDX #0          ; hundreds
HN_100  CMP #100
        BCC HN_H
        SBC #100        ; carry set
        INX
        BNE HN_100      ; always
HN_H    STX HL_H
        LDX #0          ; tens
HN_10   CMP #10
        BCC HN_T
        SBC #10
        INX
        BNE HN_10       ; always
HN_T    STA HL_D        ; ones
        LDA HL_H        ; hundreds: blank if 0
        BEQ HN_H0
        JSR HN_DIG
HN_H0   INY
        TXA             ; tens: blank if 0 and no hundreds
        ORA HL_H
        BEQ HN_T0
        TXA
        JSR HN_DIG
HN_T0   INY
        LDA HL_D
HN_DIG  CLC             ; digit A at (ZPTR),Y, white
        ADC #SC_0+HELP_OFS
        ORA #HL_WHITE
        STA (ZPTR),Y
        RTS

; Help screen text (screen codes)
HLS_TTL  .SBYTE "ITEMS FOR SALE"
         .BYTE TX_END
HLS_PRC  .SBYTE "PRICE"
         .BYTE TX_END
HLS_BACK .SBYTE "H: BACK TO THE GAME"
         .BYTE TX_END
HLN_1   .SBYTE "FORT"
        .BYTE TX_END
HLN_2   .SBYTE "FACTORY"
        .BYTE TX_END
HLN_3   .SBYTE "CROPS"
        .BYTE TX_END
HLN_4   .SBYTE "SCHOOL"
        .BYTE TX_END
HLN_5   .SBYTE "HOSPITAL"
        .BYTE TX_END
HLN_6   .SBYTE "HOUSING"
        .BYTE TX_END
HLN_7   .SBYTE "REBELS"
        .BYTE TX_END
HLN_8   .SBYTE "PT BOAT"
        .BYTE TX_END
HLN_9   .SBYTE "FISHING BOAT"
        .BYTE TX_END
HLN_LO  .BYTE <HLN_1,<HLN_2,<HLN_3,<HLN_4,<HLN_5,<HLN_6,<HLN_7,<HLN_8,<HLN_9
HLN_HI  .BYTE >HLN_1,>HLN_2,>HLN_3,>HLN_4,>HLN_5,>HLN_6,>HLN_7,>HLN_8,>HLN_9
