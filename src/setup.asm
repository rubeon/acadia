; =====================================================================
;  SETUP.ASM -- the game setup screen (T-SCR-1: R-MODE-3, R-MODE-4;
;  redrawn in T-SCR-6, D65)
;
;  Shown at start-up and after every game over.  Five lines:
;    ROUNDS              1-50
;    SECONDS PER ROUND   30-120, in steps of 5
;    PLAYERS             1-2
;    CPU LEVEL           EASY, MEDIUM, HARD (1 player only; skipped
;                        with 2)
;    MAP                 STANDARD, RANDOM, SANDBOX (N_MAPS names,
;                        MAPNAME); with SANDBOX (D87) ROUNDS, PLAYERS
;                        and CPU LEVEL show "-" and are skipped
;  Stick up/down or SELECT picks a line; stick left/right changes it
;  (held: repeats), going round from one end of its range to the other,
;  or digits type a number.  START or fire begins.  Typed numbers are
;  brought into range when the line is left or the game begins.  The
;  values stay as they were for the next game.
;
;  At the top left the title screen's "Acadia" logo (LOGO, mode D) on
;  its sunset sky, with the title's clouds drifting behind it (D71;
;  SU_CLDS, TT_CLD in TITLE.ASM).  SU_DLI, on the last blank line, sets
;  COLBK and the logo's COLPF1 every second scan line from the title's
;  colour tables (TTBK, TTP1) and moves the cloud players as TT_DLI
;  does, then black and the options' colours.  Under the logo the five lines in mode 5 in the help font HLPFONT, yellow text
;  and the current line in white (inverse characters), the chosen map's
;  minimap (MMAPL/MMAPH, generated), ANTIC mode A, green land on blue
;  sea, and a small prompt in mode 4.  Lines are built in STATUS1 with
;  the text routines (the status bar is not shown here), then copied in
;  the help font's codes.
;
;  It all lives in the map's screen memory, which GAME_START redraws,
;  display list included: SETUP_ENTER copies SUDLIST to SU_DL, past the
;  map's 928 bytes, so it can't cross a 1K boundary wherever the code
;  sits (and the display list page keeps its room).  Switching to it
;  and back stores both bytes of SDLSTL.
; =====================================================================

GS_SETUP = 4            ; GSTATE while the setup screen is up

SU_NF   =  5            ; number of lines (fields)
SU_FSEC =  1            ; SECONDS field
SU_FPLY =  2            ; PLAYERS field
SU_FLVL =  3            ; CPU LEVEL field: 1 player only
SU_FMAP =  4            ; MAP field: map 1 to N_MAPS
SU_MAPW =  8            ; characters in a map's name (MAPNAME)
SU_LVLW =  6            ; characters in a CPU level's name (SULVN)
SU_DEFP =  2            ; default: 2 players
SU_DEFL =  2            ; default CPU level: MEDIUM
SU_DELAY = 20           ; frames before a held left/right repeats
SU_RATE =  5            ; frames between repeats

SU_LW   =  40           ; bytes in a mode 5 line
SU_MW   =  20           ; bytes in a mode A line
SU_SCR  =  MAPSCR       ; cleared (was the title line)
SU_TXT  =  MAPSCR+40    ; the five value lines
SU_MINI =  MAPSCR+240   ; the minimap, MM_ROWS mode A lines
SU_PRM  =  MAPSCR+460   ; the prompt line, mode 4
SU_DL   =  MAPSCR+928   ; the display list, copied from SUDLIST: past
                        ; the map (SCR_END), inside MAPSCR's 1K
SU_SKY0 =  3            ; the logo's first row shown (1) in the title's
SU_SKY1 =  27           ; colour tables, and its last + 1 (24 rows)
SU_MCOL =  7            ; minimap: first byte in its mode A lines
SU_CGT  =  3            ; column of the ">" on the current line
SU_CLAB =  5            ; column of the labels
SU_COLV =  33           ; value column (3 digits; names end there too)
SC_GT   =  $1E          ; screen code of ">"
SC_DASH =  $0D          ; screen code of "-"
SU_WHITE = $80          ; help font: inverse = white (PF3)
C_TITLE =  $1C          ; text colour (COLPF2): yellow
C_SUBK  =  $00          ; background: black

; ---------------------------------------------------------------------
;  SETUP_INIT -- default values, once at start-up.  Trashes A.
; ---------------------------------------------------------------------
SETUP_INIT
        LDA #DEF_NUMTRN
        STA SU_VAL
        LDA #DEF_TRNLEN
        STA SU_VAL+1
        LDA #SU_DEFP
        STA SU_VAL+SU_FPLY
        LDA #SU_DEFL
        STA SU_VAL+SU_FLVL
        LDA #1          ; map 1
        STA SU_VAL+SU_FMAP
        RTS

; ---------------------------------------------------------------------
;  SETUP_ENTER -- show the setup screen.  Nothing acts until the stick,
;  fire, console keys and keyboard have all been let go.
;  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
SETUP_ENTER
        LDA MZ_ON       ; the title tune while the setup is up, unless
        AND MZ_LOOP     ; it is still playing from the title screen
        BNE SE_MUS
        JSR MUS_TITLE
SE_MUS
        JSR KP_OFF      ; port 2 is a stick port again
        LDA #0
        STA SU_ARM
        STA SU_FLD
        STA SU_TYPD
        TAX             ; SANDBOX: SECONDS first, not ROUNDS (D87)
        JSR SU_OK
        BCS SE_FLD
        INC SU_FLD
SE_FLD
        JSR SU_CLDS     ; the clouds; no cursors, fish, weather or
                        ; pirates (TITLE.ASM)
        LDA #0
        TAX
SE_CLR  STA SU_SCR,X    ; clear the screen (500 bytes used)
        STA SU_SCR+$100,X
        INX
        BNE SE_CLR
        LDX #SU_DLN-1   ; the display list into RAM
SE_DL   LDA SUDLIST,X
        STA SU_DL,X
        DEX
        BPL SE_DL
        LDA #<SUS_PRM   ; the prompt, yellow
        LDY #>SUS_PRM
        LDX #0
        JSR SU_FIX
        LDA #<SU_PRM
        LDY #>SU_PRM
        JSR SU_PUT
        JSR SU_DRAW
        LDA #>HLPFONT   ; the help font, the minimap's green (PF0),
        STA CHBAS       ; the logo's colours and the sky above it;
        LDA #C_GRASS    ; SU_DLI sets the rest's
        STA COLOR0
        LDA TTP1+SU_SKY0
        STA COLOR1
        LDA #C_TSHD
        STA COLOR2
        LDA #C_WHITE
        STA COLOR3
        LDA TTBK
        STA COLOR4
        LDA #<SU_DL
        STA SDLSTL
        LDA #>SU_DL
        STA SDLSTH
        LDA #GS_SETUP   ; last: from now on ST_VBI points the DLIs at
        STA GSTATE      ; SU_DLI, which must not run on another
        RTS             ; screen's display list

; ---------------------------------------------------------------------
;  SU_DLI -- the DLI on the setup display list's last blank line (D71):
;  the clouds' shade, then for each logo row COLBK and COLPF1 (the
;  logo's gold) from the title's tables and the clouds' positions as
;  TT_DLI sets them (lane 1 on one row, lane 0 on the next); then
;  black, the minimap's sea (PF1) and the text's yellow (PF2; black in
;  the logo, its shadow).  Keeps all registers.
; ---------------------------------------------------------------------
SU_DLI  PHA
        TXA
        PHA
        TYA
        PHA
        LDA TTP0+SU_SKY0 ; the clouds' shade (the sky's PF0 there)
        STA COLPM0
        STA COLPM1
        STA COLPM2
        LDX #SU_SKY0
SL_ROW  LDA TTBK,X      ; a logo row: 2 scan lines
        LDY TTP1,X
        STA WSYNC
        STA COLBK
        STY COLPF1
        LDA TT_HB,X     ; lane 1
        STA WSYNC
        STA HPOSP2
        INX
        LDA TTBK,X      ; the next row
        LDY TTP1,X
        STA WSYNC
        STA COLBK
        STY COLPF1
        LDA TT_HA,X     ; lane 0: P0, and P1 just right of it
        STA WSYNC
        STA HPOSP0
        CLC
        ADC #32
        STA HPOSP1
        INX
        CPX #SU_SKY1    ; SU_SKY1 - SU_SKY0 must be even
        BNE SL_ROW
        LDA #C_SUBK     ; under the logo
        LDX #C_SEA
        LDY #C_TITLE
        STA WSYNC
        STA COLBK
        STX COLPF1
        STY COLPF2
        PLA
        TAY
        PLA
        TAX
        PLA
        RTI

; ---------------------------------------------------------------------
;  SETUP_FRAME -- each frame of the setup screen.  Trashes A, X, Y.
; ---------------------------------------------------------------------
SETUP_FRAME             ; (the clouds drift in the VBI: TT_CLD, D82)
        LDA JOY0        ; either stick, either fire button
        ORA JOY1
        STA SU_J
        LDA FIRE0
        ORA FIRE1
        STA SU_F
        LDA SU_ARM
        BNE SF_ON
        LDA SU_J        ; wait until everything is let go
        ORA SU_F
        ORA CONKEY
        ORA KEYDOWN
        BNE SF_RTS
        INC SU_ARM
        LDA #0
        STA SU_OLDJ
        STA SU_OLDF
        STA SU_OLDC
SF_RTS  RTS

SF_ON   LDA SU_F        ; fire pressed: begin
        BEQ SF_STRT
        LDA SU_OLDF
        BNE SF_STRT
        JMP SU_GO
SF_STRT LDA CONKEY      ; START pressed: begin
        AND #1
        BEQ SF_SEL
        LDA SU_OLDC
        AND #1
        BNE SF_SEL
        JMP SU_GO
SF_SEL  LDA CONKEY      ; SELECT pressed: next line
        AND #2
        BEQ SF_UD
        LDA SU_OLDC
        AND #2
        BNE SF_UD
        JSR SU_NEXT
SF_UD   LDA SU_OLDJ     ; directions pressed this frame
        EOR #$0F
        AND SU_J
        STA SU_NEW
        AND #1          ; up
        BEQ SF_DN
        JSR SU_PREV
SF_DN   LDA SU_NEW
        AND #2          ; down
        BEQ SF_LR
        JSR SU_NEXT
SF_LR   LDA SU_J
        AND #$0C        ; left or right held?
        BEQ SF_KEY
        LDA SU_NEW
        AND #$0C
        BEQ SF_HELD
        LDA #SU_DELAY   ; just pressed: step now, repeat later
        STA SU_RPT
        BNE SF_STEP
SF_HELD DEC SU_RPT
        BNE SF_KEY
        LDA #SU_RATE
        STA SU_RPT
SF_STEP JSR SU_CLAMP
        LDA #0
        STA SU_TYPD
        LDA SU_J
        AND #8          ; right wins if both
        BEQ SF_LEFT
        JSR SU_INC
        JMP SF_KEY
SF_LEFT JSR SU_DEC
SF_KEY  LDA KEY         ; a digit typed
        BMI SF_DONE
        JSR SU_DIGIT
SF_DONE LDA SU_J
        STA SU_OLDJ
        LDA SU_F
        STA SU_OLDF
        LDA CONKEY
        STA SU_OLDC
        JMP SU_DRAW

; ---------------------------------------------------------------------
;  SU_GO -- leave setup: every value into range, then a new game
; ---------------------------------------------------------------------
SU_GO   LDX #SU_NF-1
SG_CLMP JSR SU_CLX
        DEX
        BPL SG_CLMP
        LDA SU_VAL
        STA NUMTRN
        LDA SU_VAL+1
        STA TRNLEN
        LDX SU_VAL+SU_FMAP ; map 1 to N_MAPS: map number 0 up
        DEX
        STX MAPNO
        LDA #GS_PLAY    ; first: SU_DLI never runs on DLIST
        STA GSTATE
        LDA #<DLIST     ; back to the map display list
        STA SDLSTL
        LDA #>DLIST
        STA SDLSTH
        JSR PM_INIT     ; no clouds: P/M memory, sizes, priority as the
        JMP GAME_START  ; game has them

; ---------------------------------------------------------------------
;  SU_NEXT / SU_PREV -- move to the next / previous line that can be
;  chosen (SU_OK), bringing the line left into range.
;  Trashes A, X.
; ---------------------------------------------------------------------
SU_NEXT JSR SU_CLAMP
SN_STEP INX
        CPX #SU_NF
        BCC SN_OK
        LDX #0
SN_OK   JSR SU_OK
        BCC SN_STEP
SU_SETF STX SU_FLD
        LDA #0
        STA SU_TYPD
        RTS
SU_PREV JSR SU_CLAMP
SP_STEP DEX
        BPL SP_OK
        LDX #SU_NF-1
SP_OK   JSR SU_OK
        BCC SP_STEP
        BCS SU_SETF

; ---------------------------------------------------------------------
;  SU_OK -- C set if line X can be chosen, clear if it shows "-": CPU
;  LEVEL with 2 players; with the SANDBOX map (D87) all but SECONDS
;  and MAP.  Keeps X.  Trashes A.
; ---------------------------------------------------------------------
SU_OK   CPX #SU_FMAP
        BEQ SO_YES
        LDA SU_VAL+SU_FMAP
        CMP #MAP_SBX+1
        BNE SO_STD
        CPX #SU_FSEC    ; SANDBOX: SECONDS and MAP only
        BEQ SO_YES
SO_NO   CLC
        RTS
SO_STD  CPX #SU_FLVL    ; CPU LEVEL: 1 player only
        BNE SO_YES
        LDA SU_VAL+SU_FPLY
        CMP #2
        BEQ SO_NO
SO_YES  SEC
        RTS

; ---------------------------------------------------------------------
;  SU_CLAMP -- bring the current line's value into range
;  SU_CLX   -- the same for line X (X kept).  Trashes A.
; ---------------------------------------------------------------------
SU_CLAMP
        LDX SU_FLD
SU_CLX  LDA SU_VAL,X
        CMP SU_MIN,X
        BCS SC_HI
        LDA SU_MIN,X
SC_HI   CMP SU_MAX,X
        BCC SC_SET
        LDA SU_MAX,X
SC_SET  STA SU_VAL,X
        RTS

; ---------------------------------------------------------------------
;  SU_INC / SU_DEC -- step the current line's value up / down; past an
;  end of its range it goes round to the other end (D65).
;  Trashes A, X.
; ---------------------------------------------------------------------
SU_INC  LDX SU_FLD
        LDA SU_VAL,X
        CLC
        ADC SU_STP,X
        BCS SI_MIN
        CMP SU_MAX,X
        BEQ SI_SET
        BCC SI_SET
SI_MIN  LDA SU_MIN,X    ; past the top: the bottom
SI_SET  STA SU_VAL,X
        RTS
SU_DEC  LDX SU_FLD
        LDA SU_VAL,X
        SEC
        SBC SU_STP,X
        BCC SD_MAX
        CMP SU_MIN,X
        BCS SD_SET
SD_MAX  LDA SU_MAX,X    ; past the bottom: the top
SD_SET  STA SU_VAL,X
        RTS

; ---------------------------------------------------------------------
;  SU_DIGIT -- digit A typed on the current line.  Rounds and seconds
;  build a number (a new one after moving, or when it would pass 249);
;  the other lines take the digit if it is in range.
;  Trashes A, X.
; ---------------------------------------------------------------------
SU_DIGIT
        STA SU_D
        LDX SU_FLD
        CPX #SU_FPLY
        BCS SD_ONE
        LDA SU_TYPD
        BEQ SD_NEW
        LDA SU_VAL,X
        CMP #25
        BCS SD_NEW      ; a third digit would not fit: start again
        ASL A           ; value x 10 + digit
        STA SU_T
        ASL A
        ASL A
        ADC SU_T        ; carry clear: value < 25
        ADC SU_D
        STA SU_VAL,X
        RTS
SD_NEW  LDA SU_D
        STA SU_VAL,X
        LDA #1
        STA SU_TYPD
        RTS
SD_ONE  LDA SU_D
        CMP SU_MIN,X
        BCC SD_RTS
        CMP SU_MAX,X
        BEQ SD_OK
        BCS SD_RTS
SD_OK   STA SU_VAL,X
SD_RTS  RTS

; ---------------------------------------------------------------------
;  SU_DRAW -- redraw the five value lines and the minimap: the current
;  line white with a ">", the others yellow; "-" for a line that can't
;  be chosen (SU_OK), a level's name (SULVN) for CPU LEVEL, a map's name
;  (MAPNAME) for MAP.
;  Trashes A, X, Y, ZPTR, TPTR, M_NUM.
; ---------------------------------------------------------------------
SU_DRAW LDA #0          ; plain digits from TXT_DEC
        STA TXCOL
        LDX #SU_NF-1
SW_LINE STX SU_I
        LDA #0
        LDY #SU_LW-1
SW_CLR  STA STATUS1,Y
        DEY
        BPL SW_CLR
        CPX SU_FLD
        BNE SW_LAB
        LDA #SC_GT
        STA STATUS1+SU_CGT
SW_LAB  LDA SULAB_L,X
        LDY SULAB_H,X
        LDX #SU_CLAB
        JSR TXT_STR
        LDX SU_I
        CPX #SU_FMAP
        BEQ SW_MAP
        JSR SU_OK
        BCS SW_VAL
        LDA #SC_DASH    ; no CPU in a 2-player game; SANDBOX (D87)
        STA STATUS1+SU_COLV+2
        BNE SW_COPY
SW_VAL  CPX #SU_FLVL
        BNE SW_NUM
SW_LVL  LDA SU_VAL+SU_FLVL ; level 1 up: x 6 = SU_LVLW
        SEC
        SBC #1
        STA SU_T
        ASL A
        ADC SU_T        ; x 3 (carry clear: A < 3)
        ASL A
        TAX
        LDY #0
SW_LCH  LDA SULVN,X
        STA STATUS1+SU_COLV+3-SU_LVLW,Y
        INX
        INY
        CPY #SU_LVLW
        BNE SW_LCH
        BEQ SW_COPY
SW_MAP  LDA SU_VAL+SU_FMAP ; name number 1 up, ending where numbers do
        SEC
        SBC #1
        ASL A
        ASL A
        ASL A           ; x 8 = SU_MAPW
        TAX
        LDY #0
SW_MCH  LDA MAPNAME,X
        STA STATUS1+SU_COLV+3-SU_MAPW,Y
        INX
        INY
        CPY #SU_MAPW
        BNE SW_MCH
        BEQ SW_COPY
SW_NUM  LDA SU_VAL,X
        LDX #0
        JSR NUM16
        LDA #3
        LDX #SU_COLV
        JSR TXT_DEC
SW_COPY LDX SU_I        ; white on the current line
        LDA #0
        CPX SU_FLD
        BNE SW_COL
        LDA #SU_WHITE
SW_COL  STA SU_C
        LDA SUF_LO,X
        LDY SUF_HI,X
        JSR SU_PUT
        LDX SU_I
        DEX
        BMI SU_MMAP
        JMP SW_LINE

; ---------------------------------------------------------------------
;  SU_MMAP -- the chosen map's minimap (MM_ROWS rows of MM_W bytes)
;  into its mode A lines.  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
SU_MMAP LDX SU_VAL+SU_FMAP ; map 1 up
        LDA MMAPL-1,X
        STA TPTR
        LDA MMAPH-1,X
        STA TPTR+1
        LDA #<[SU_MINI+SU_MCOL]
        STA ZPTR
        LDA #>[SU_MINI+SU_MCOL]
        STA ZPTR+1
        LDX #MM_ROWS
SM_ROW  LDY #MM_W-1
SM_BYTE LDA (TPTR),Y
        STA (ZPTR),Y
        DEY
        BPL SM_BYTE
        LDA TPTR        ; next row of the map
        CLC
        ADC #MM_W
        STA TPTR
        BCC SM_SCR
        INC TPTR+1
SM_SCR  LDA ZPTR        ; next mode A line
        CLC
        ADC #SU_MW
        STA ZPTR
        BCC SM_NXT
        INC ZPTR+1
SM_NXT  DEX
        BNE SM_ROW
        RTS

; ---------------------------------------------------------------------
;  SU_FIX -- STATUS1 = the fixed line at A/Y (low/high: a column, then
;  screen codes ending in TX_END), colour X for SU_PUT.
;  Trashes A, X, Y, TPTR.
; ---------------------------------------------------------------------
SU_FIX  STA TPTR
        STY TPTR+1
        STX SU_C
        LDA #0
        LDY #SU_LW-1
SX_CLR  STA STATUS1,Y
        DEY
        BPL SX_CLR
        LDY #0          ; its column
        LDA (TPTR),Y
        TAX
SX_CHR  INY
        LDA (TPTR),Y
        CMP #TX_END
        BEQ SX_RTS
        STA STATUS1,X
        INX
        BNE SX_CHR
SX_RTS  RTS

; ---------------------------------------------------------------------
;  SU_PUT -- copy STATUS1 (screen codes) to the mode 5 line at A/Y
;  (low/high) in help font codes, colour SU_C (0 yellow, SU_WHITE);
;  spaces stay code 0, the blank tile.  Trashes A, Y, ZPTR.
; ---------------------------------------------------------------------
SU_PUT  STA ZPTR
        STY ZPTR+1
        LDY #SU_LW-1
SU_PCH  LDA STATUS1,Y
        BEQ SU_PST
        CLC
        ADC #HELP_OFS
        ORA SU_C
SU_PST  STA (ZPTR),Y
        DEY
        BPL SU_PCH
        RTS

; Field ranges (original: $504C, $50F3) and stick steps
SU_MIN  .BYTE 1,30,1,1,1
SU_MAX  .BYTE 50,120,2,3,N_MAPS
SU_STP  .BYTE 1,5,1,1,1
SUF_LO  .BYTE <[SU_TXT],<[SU_TXT+40],<[SU_TXT+80],<[SU_TXT+120],<[SU_TXT+160]
SUF_HI  .BYTE >[SU_TXT],>[SU_TXT+40],>[SU_TXT+80],>[SU_TXT+120],>[SU_TXT+160]

SULAB_L .BYTE <SUL_RND,<SUL_SEC,<SUL_PLY,<SUL_LVL,<SUL_MAP
SULAB_H .BYTE >SUL_RND,>SUL_SEC,>SUL_PLY,>SUL_LVL,>SUL_MAP
SUL_RND .SBYTE "ROUNDS"
        .BYTE TX_END
SUL_SEC .SBYTE "SECONDS PER ROUND"
        .BYTE TX_END
SUL_PLY .SBYTE "PLAYERS"
        .BYTE TX_END
SUL_LVL .SBYTE "CPU LEVEL"
        .BYTE TX_END
SUL_MAP .SBYTE "MAP"
        .BYTE TX_END
SULVN   .SBYTE "  EASY"         ; CPU levels 1-3, SU_LVLW each
        .SBYTE "MEDIUM"
        .SBYTE "  HARD"

; Fixed lines: column, then the text
SUS_PRM .BYTE 6
        .SBYTE "PRESS START OR FIRE TO BEGIN"
        .BYTE TX_END

; The display list, copied to SU_DL (RAM) by SETUP_ENTER: the logo's
; rows 1-24 (rows 0 and 25 are empty), then the screen in MAPSCR.  The
; 6 blank lines stand for the title's 4 sky lines and logo row 0, so
; row 1 sits on the same scan line as on the title (D75)
SUDLIST
        .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK8
        .BYTE DL_DLI+DL_BLANK6          ; SU_DLI: the sky, the logo
        .BYTE DL_LMS+DL_MODED           ; the logo, 24 mode D lines
        .WORD LOGO+40
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_MODED,DL_MODED,DL_MODED,DL_MODED,DL_MODED
        .BYTE DL_BLANK4
        .BYTE DL_LMS+DL_MODE5           ; the five value lines (SU_TXT)
        .WORD SU_TXT
        .BYTE DL_MODE5,DL_MODE5,DL_MODE5,DL_MODE5
        .BYTE DL_BLANK2
        .BYTE DL_MODEA,DL_MODEA,DL_MODEA,DL_MODEA ; the minimap (SU_MINI),
        .BYTE DL_MODEA,DL_MODEA,DL_MODEA,DL_MODEA ; MM_ROWS lines
        .BYTE DL_MODEA,DL_MODEA,DL_MODEA
        .BYTE DL_BLANK4
        .BYTE DL_MODE4                  ; the prompt (SU_PRM), small
        .BYTE DL_JVB
        .WORD SU_DL
SU_DLE                          ; its end
SU_DLN  =  SU_DLE-SUDLIST       ; its length (55 bytes)
