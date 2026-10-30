; =====================================================================
;  SETUP.ASM -- the game setup screen (T-SCR-1: R-MODE-3, R-MODE-4)
;
;  Shown at start-up and after every game over.  Five lines:
;    ROUNDS              1-50     ("term of office" in the original)
;    SECONDS PER ROUND   30-120   ("turn length")
;    PLAYERS             1-2
;    CPU LEVEL           1-3      (1 player only; skipped with 2)
;    KEYPAD IN PORT 2    NO/YES   (1 player only; skipped with 2; D49)
;  Stick up/down or SELECT picks a line; stick left/right changes it
;  (held: repeats), or digits type a number.  START or fire begins.
;  Typed numbers are brought into range when the line is left or the
;  game begins.  The values stay as they were for the next game.
;
;  The screen has its own display list (SUDLIST, next to DLIST in page
;  $38, so switching is one store to SDLSTL) and uses the map's screen
;  memory, which GAME_START redraws.  Lines are built in STATUS1 with
;  the text routines (the status bar is not shown here), then copied.
; =====================================================================

GS_SETUP = 4            ; GSTATE while the setup screen is up

SU_NF   =  5            ; number of lines (fields)
SU_FPLY =  2            ; PLAYERS field
SU_FLVL =  3            ; CPU LEVEL field; this and the next: 1 player
SU_FKP  =  4            ; KEYPAD field: 0 no, 1 yes
SU_DEFP =  2            ; default: 2 players
SU_DEFL =  2            ; default CPU level
SU_DELAY = 20           ; frames before a held left/right repeats
SU_RATE =  5            ; frames between repeats

SU_SCR  =  MAPSCR       ; mode 7 title line (20 bytes)
SU_TXT  =  MAPSCR+20    ; mode 2 lines, 40 bytes each
SU_LINES = 18           ; mode 2 lines in SUDLIST
SU_COLV =  32           ; value column (3 digits)
SC_GT   =  $1E          ; screen code of ">"
SC_DASH =  $0D          ; screen code of "-"
C_TITLE =  $1C          ; title colour (COLPF0): yellow, as C_LIGHT

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
        LDA #0          ; no keypad
        STA SU_VAL+SU_FKP
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
        LDA #GS_SETUP
        STA GSTATE
        LDA #0
        STA SU_ARM
        STA SU_FLD
        STA SU_TYPD
        JSR PM_HIDE     ; no cursors, fish, weather or pirates
        LDA #0
        TAX
SE_CLR  STA SU_SCR,X    ; clear title and text lines (740 bytes)
        STA SU_SCR+$100,X
        STA SU_SCR+$200,X
        INX
        BNE SE_CLR
        LDX #19
SE_TTL  LDA SUS_TTL,X
        STA SU_SCR,X
        DEX
        BPL SE_TTL
        LDX #SUS_N-1    ; the fixed lines
SE_STA  STX SU_I
        LDA SUS_ROW,X
        JSR SU_ROWADR
        LDX SU_I
        LDA SUS_LO,X
        STA TPTR
        LDA SUS_HI,X
        STA TPTR+1
        LDY #0
SE_CHR  LDA (TPTR),Y
        CMP #TX_END
        BEQ SE_NXT
        STA (ZPTR),Y
        INY
        BNE SE_CHR
SE_NXT  LDX SU_I
        DEX
        BPL SE_STA
        JSR SU_DRAW
        JSR TI_COLS     ; ROM font, text colours
        LDA #C_TITLE
        STA COLOR0
        LDA #<SUDLIST   ; same page as DLIST: one store switches
        STA SDLSTL
        RTS

; ---------------------------------------------------------------------
;  SETUP_FRAME -- each frame of the setup screen.  Trashes A, X, Y.
; ---------------------------------------------------------------------
SETUP_FRAME
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
        LDA #<DLIST     ; back to the map display list
        STA SDLSTL
        JMP GAME_START

; ---------------------------------------------------------------------
;  SU_NEXT / SU_PREV -- move to the next / previous line, bringing the
;  line left into range; CPU LEVEL and KEYPAD are skipped with 2
;  players.
;  Trashes A, X.
; ---------------------------------------------------------------------
SU_NEXT JSR SU_CLAMP
        LDX SU_FLD
        INX
        CPX #SU_NF
        BCC SN_LVL
        LDX #0
SN_LVL  CPX #SU_FLVL
        BCC SU_SETF
        LDA SU_VAL+SU_FPLY
        CMP #2
        BNE SU_SETF
        LDX #0          ; 2 players: no CPU level
SU_SETF STX SU_FLD
        LDA #0
        STA SU_TYPD
        RTS
SU_PREV JSR SU_CLAMP
        LDX SU_FLD
        DEX
        BPL SP_LVL
        LDX #SU_NF-1
SP_LVL  CPX #SU_FLVL
        BCC SU_SETF
        LDA SU_VAL+SU_FPLY
        CMP #2
        BNE SU_SETF
        LDX #SU_FPLY
        BNE SU_SETF

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
;  SU_INC / SU_DEC -- step the current line's value up / down, stopping
;  at the ends of its range.  Trashes A, X.
; ---------------------------------------------------------------------
SU_INC  LDX SU_FLD
        LDA SU_VAL,X
        CLC
        ADC SU_STP,X
        BCS SI_MAX
        CMP SU_MAX,X
        BCC SI_SET
SI_MAX  LDA SU_MAX,X
SI_SET  STA SU_VAL,X
        RTS
SU_DEC  LDX SU_FLD
        LDA SU_VAL,X
        SEC
        SBC SU_STP,X
        BCC SD_MIN
        CMP SU_MIN,X
        BCS SD_SET
SD_MIN  LDA SU_MIN,X
SD_SET  STA SU_VAL,X
        RTS

; ---------------------------------------------------------------------
;  SU_DIGIT -- digit A typed on the current line.  Rounds and seconds
;  build a number (a new one after moving, or when it would pass 249);
;  players and CPU level take the digit if it is in range.
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
;  SU_DRAW -- redraw the five value lines: a ">" and an inverse value
;  on the current one, "-" for CPU LEVEL and KEYPAD with 2 players,
;  NO / YES for KEYPAD.
;  Trashes A, X, Y, ZPTR, TPTR, M_NUM.
; ---------------------------------------------------------------------
SU_DRAW LDX #SU_NF-1
SW_LINE STX SU_I
        LDA #0
        LDY #39
SW_CLR  STA STATUS1,Y
        DEY
        BPL SW_CLR
        CPX SU_FLD
        BNE SW_LAB
        LDA #SC_GT
        STA STATUS1+2
SW_LAB  LDA SULAB_L,X
        LDY SULAB_H,X
        LDX #4
        JSR TXT_STR
        LDX SU_I
        CPX #SU_FLVL
        BCC SW_NUM
        LDA SU_VAL+SU_FPLY
        CMP #2
        BNE SW_ONE
        LDA #SC_DASH    ; no CPU or keypad in a 2-player game
        STA STATUS1+SU_COLV+2
        BNE SW_INV
SW_ONE  CPX #SU_FKP
        BNE SW_NUM
        LDY SU_VAL+SU_FKP
        LDA SUKP_L,Y    ; NO / YES
        PHA
        LDA SUKP_H,Y
        TAY
        PLA
        LDX #SU_COLV
        JSR TXT_STR
        JMP SW_INV
SW_NUM  LDA SU_VAL,X
        LDX #0
        JSR NUM16
        LDA #3
        LDX #SU_COLV
        JSR TXT_DEC
SW_INV  LDX SU_I
        CPX SU_FLD
        BNE SW_COPY
        LDX #4          ; inverse box, one space either side
SW_INVL LDA STATUS1+SU_COLV-1,X
        ORA #$80
        STA STATUS1+SU_COLV-1,X
        DEX
        BPL SW_INVL
SW_COPY LDX SU_I
        LDA SUF_ROW,X
        JSR SU_ROWADR
        LDY #39
SW_CPY  LDA STATUS1,Y
        STA (ZPTR),Y
        DEY
        BPL SW_CPY
        LDX SU_I
        DEX
        BMI SW_RTS
        JMP SW_LINE
SW_RTS  RTS

; ---------------------------------------------------------------------
;  SU_ROWADR -- ZPTR = address of mode 2 line A (0-17).  Trashes A, Y.
; ---------------------------------------------------------------------
SU_ROWADR
        STA SU_T
        ASL A
        ASL A
        ADC SU_T        ; x 5 (carry clear: A <= 17)
        LDY #0
        STY ZPTR+1
        ASL A           ; x 40
        ROL ZPTR+1
        ASL A
        ROL ZPTR+1
        ASL A
        ROL ZPTR+1
        CLC
        ADC #<SU_TXT
        STA ZPTR
        LDA ZPTR+1
        ADC #>SU_TXT
        STA ZPTR+1
        RTS

; Field ranges (original: $504C, $50F3) and stick steps
SU_MIN  .BYTE 1,30,1,1,0
SU_MAX  .BYTE 50,120,2,3,1
SU_STP  .BYTE 1,5,1,1,1
SUF_ROW .BYTE 3,5,7,9,11        ; mode 2 line of each field

SULAB_L .BYTE <SUL_RND,<SUL_SEC,<SUL_PLY,<SUL_LVL,<SUL_KP
SULAB_H .BYTE >SUL_RND,>SUL_SEC,>SUL_PLY,>SUL_LVL,>SUL_KP
SUL_RND .SBYTE "ROUNDS (1-50)"
        .BYTE TX_END
SUL_SEC .SBYTE "SECONDS PER ROUND (30-120)"
        .BYTE TX_END
SUL_PLY .SBYTE "PLAYERS (1-2)"
        .BYTE TX_END
SUL_LVL .SBYTE "CPU LEVEL (1-3)"
        .BYTE TX_END
SUL_KP  .SBYTE "KEYPAD IN PORT 2 (0-1)"
        .BYTE TX_END
SUKP_L  .BYTE <SUK_NO,<SUK_YES
SUKP_H  .BYTE >SUK_NO,>SUK_YES
SUK_NO  .SBYTE " NO"
        .BYTE TX_END
SUK_YES .SBYTE "YES"
        .BYTE TX_END

; Fixed text: title (mode 7, 20 characters) and mode 2 lines
SUS_TTL .SBYTE "       ACADIA       "
SUS_N   =  4
SUS_ROW .BYTE 1,13,14,16
SUS_LO  .BYTE <SUS_1,<SUS_12,<SUS_13,<SUS_15
SUS_HI  .BYTE >SUS_1,>SUS_12,>SUS_13,>SUS_15
SUS_1   .SBYTE "      BUILD, FEED AND KEEP THE PEACE"
        .BYTE TX_END
SUS_12  .SBYTE " STICK UP/DOWN OR SELECT: CHOOSE A LINE"
        .BYTE TX_END
SUS_13  .SBYTE " STICK LEFT/RIGHT OR 0-9: CHANGE IT"
        .BYTE TX_END
SUS_15  .SBYTE "     PRESS START OR FIRE TO BEGIN"
        .BYTE TX_END
