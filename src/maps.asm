; =====================================================================
;  MAPS.ASM -- the choice of map (D56)
;
;  Each map is an island pair made by tools/mkfont.py: its own fonts,
;  and a data block (MAPS0, MAPS1, ...) laid out like the live tables
;  TILECH ... FONTPG in ISLANDS.ASM.  MAP_LOAD copies the chosen map's
;  block over the live tables at the start of a game, and works out
;  the CPU's steps by sea (AI_HD, AI_UP, AI_DN) for it, so the rest of
;  the game reads the same labels whatever the map.
; =====================================================================

ML_ROW  =  20           ; squares per row (MAPSQ)
ML_LAST =  200          ; first square of the last row
ML_UP   =  40           ; squares in rows 0-1 (AI_UP's goal)
ML_DN   =  180          ; first square of rows 9-10 (AI_DN's goal)
ML_NONE =  $FF          ; steps: land, or no way there

; ---------------------------------------------------------------------
;  MAP_LOAD -- make map A (0 to N_MAPS-1) the live one.  Nothing is
;  done if it already is (MAPLD; the program starts with map 0).
;  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
MAP_LOAD
        CMP MAPLD
        BEQ ML_RTS
        STA MAPLD
        TAX
        LDA MAPSL,X     ; from the map's block
        STA TPTR
        LDA MAPSH,X
        STA TPTR+1
        LDA #<TILECH    ; to the live tables
        STA ZPTR
        LDA #>TILECH
        STA ZPTR+1
        LDY #0
        LDX #>MAPBLK    ; whole pages first
        BEQ ML_PART
ML_PAGE LDA (TPTR),Y
        STA (ZPTR),Y
        INY
        BNE ML_PAGE
        INC TPTR+1
        INC ZPTR+1
        DEX
        BNE ML_PAGE
ML_PART CPY #<MAPBLK    ; then the rest (Y = 0 here)
        BEQ ML_AI
        LDA (TPTR),Y
        STA (ZPTR),Y
        INY
        BNE ML_PART
ML_AI   LDX #2          ; AI_DN, AI_UP, AI_HD
ML_TBL  STX ML_T
        JSR ML_STEPS
        LDX ML_T
        DEX
        BPL ML_TBL
ML_RTS  RTS

; ---------------------------------------------------------------------
;  ML_STEPS -- steps by sea from each square to the nearest goal
;  square, 4 ways, never over land, as tools/mkfont.py's sea_steps:
;  the goal squares get 0, then each pass gives every free sea square
;  next to a square of D steps D + 1, until a pass changes nothing.
;  In: ML_T = 0: AI_HD (goal: player 2's harbour), 1: AI_UP (rows
;  0-1), 2: AI_DN (rows 9-10).  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
ML_STEPS
        LDX ML_T
        LDA MLTL,X
        STA ZPTR
        LDA MLTH,X
        STA ZPTR+1
        LDY #0          ; first every square: goal 0, else none
MS_INIT LDA ISLKIND,Y
        AND #K_KIND
        CMP #K_LAND
        BEQ MS_NONE     ; land is never a goal
        LDA ML_T
        BNE MS_UPDN
        LDA ISLKIND,Y
        CMP #K_HARB+K_P1
        BEQ MS_GOAL
        BNE MS_NONE
MS_UPDN CMP #1
        BNE MS_DN
        CPY #ML_UP
        BCC MS_GOAL
        BCS MS_NONE
MS_DN   CPY #ML_DN
        BCS MS_GOAL
MS_NONE LDA #ML_NONE
        BNE MS_SET
MS_GOAL LDA #0
MS_SET  STA (ZPTR),Y
        INY
        CPY #MAPSIZE
        BNE MS_INIT
        LDA #0
        STA ML_D
MS_PASS LDA #0
        STA ML_CH
        STA ML_C
        TAY
MS_SQ   LDA (ZPTR),Y
        CMP ML_D
        BNE MS_NEXT
        STY ML_I        ; a square of D steps: its neighbours
        LDA ML_C
        BEQ MS_E
        DEY             ; west
        JSR ML_NB
MS_E    LDA ML_C
        CMP #ML_ROW-1
        BEQ MS_N
        INY             ; east
        JSR ML_NB
MS_N    CPY #ML_ROW
        BCC MS_S
        TYA             ; north
        SBC #ML_ROW     ; carry set
        TAY
        JSR ML_NB
MS_S    CPY #ML_LAST
        BCS MS_NEXT
        TYA             ; south
        ADC #ML_ROW     ; carry clear
        TAY
        JSR ML_NB
MS_NEXT INC ML_C        ; next square
        LDA ML_C
        CMP #ML_ROW
        BNE MS_COL
        LDA #0
        STA ML_C
MS_COL  INY
        CPY #MAPSIZE
        BNE MS_SQ
        INC ML_D
        LDA ML_CH
        BNE MS_PASS     ; something changed: another pass
        RTS

; ML_NB -- square Y, next to square ML_I of ML_D steps: ML_D + 1 if it
; is sea with no steps yet (ML_CH set).  Out: Y = ML_I.  Trashes A.
ML_NB   LDA (ZPTR),Y
        CMP #ML_NONE
        BNE MN_RTS
        LDA ISLKIND,Y
        AND #K_KIND
        CMP #K_LAND
        BEQ MN_RTS
        LDA ML_D
        CLC
        ADC #1
        STA (ZPTR),Y
        STA ML_CH       ; not 0
MN_RTS  LDY ML_I
        RTS

MLTL    .BYTE <AI_HD,<AI_UP,<AI_DN
MLTH    .BYTE >AI_HD,>AI_UP,>AI_DN
