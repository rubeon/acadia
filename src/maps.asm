; =====================================================================
;  MAPS.ASM -- the choice of map (D56)
;
;  Each map is made by tools/mkfont.py: its own fonts, and a data
;  block (MAPS0, MAPS1, ...) laid out like the live tables TILECH ...
;  FONTPG in ISLANDS.ASM.  MAP_LOAD copies the chosen map's block over
;  the live tables at the start of a game, and works out the CPU's
;  steps by sea (AI_HD, AI_UP, AI_DN) for it, so the rest of the game
;  reads the same labels whatever the map.  RANDOM's block is the open
;  sea; RM_GEN draws a new pair of islands on it for every game.
; =====================================================================

ML_ROW  =  20           ; squares per row (MAPSQ)
ML_LAST =  200          ; first square of the last row
ML_UP   =  40           ; squares in rows 0-1 (AI_UP's goal)
ML_DN   =  180          ; first square of rows 9-10 (AI_DN's goal)
ML_NONE =  $FF          ; steps: land, or no way there
RM_N    =  32           ; RANDOM: land squares a side (mkfont.py RND_N)
RM_ROW0 =  2            ; RANDOM: land rows 2-8
RM_NROW =  7
RM_NCOL =  8            ; RANDOM: land columns 1-8 and 11-18
RM_FULL =  15           ; land on all four sides: a grass square

; ---------------------------------------------------------------------
;  MAP_LOAD -- make map A (0 to N_MAPS-1) the live one.  Nothing is
;  done if it already is (MAPLD; the program starts with map 0),
;  unless it is RANDOM, which is new every time.
;  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
MAP_LOAD
        CMP #MAP_RND
        BEQ ML_GO
        CMP MAPLD
        BEQ ML_RTS
ML_GO   STA MAPLD
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
ML_AI   LDA MAPLD
        CMP #MAP_RND
        BNE ML_AIT
        JSR RM_GEN      ; RANDOM: new islands on the sea
ML_AIT  LDX #2          ; AI_DN, AI_UP, AI_HD
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

; ---------------------------------------------------------------------
;  RM_GEN -- RANDOM: a new pair of islands on the open sea of the live
;  tables.  Each grows from a square in the middle of its side, one
;  random square next to it at a time, to RM_N squares in rows 2-8 and
;  columns 1-8 (player 0) or 11-18 (player 1), so the channel stays
;  open and each island is in one piece.  A pair that shuts in any sea
;  is thrown away and grown again.  Each harbour goes on the sea square
;  just outside the island's outer coast, in row 5 if it has land
;  there, else 4, 6, 3, 7.  Land squares get the coast piece for their
;  land neighbours (RNDTILE), or grass (GRSTL).
;  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
RM_GEN
        LDX #1
RG_SIDE STX RM_S        ; both sides back to sea, then an island each
        JSR RM_ISLE
        LDX RM_S
        DEX
        BPL RG_SIDE
        LDA #1          ; steps to the open sea at the top: any sea
        STA ML_T        ; square with none is shut in
        JSR ML_STEPS
        LDY #MAPSIZE-1
RG_HOLE LDA ISLKIND,Y
        BNE RG_HNXT     ; land
        LDA AI_UP,Y
        CMP #ML_NONE
        BEQ RM_GEN      ; shut-in sea: grow the pair again
RG_HNXT DEY
        CPY #$FF
        BNE RG_HOLE
        LDX #1          ; the harbours
RG_HARB LDY #0
RG_HROW STY RM_I
        LDA RMHROW,Y
        TAY
        LDA ROWIDX,Y    ; first square of the row: the outer edge
        CPX #0          ; inwards (player 1: from column 19)
        BEQ RG_HSCN
        CLC
        ADC #ML_ROW-1
RG_HSCN TAY
        LDA #ML_ROW
        STA RM_K
RG_HSQ  LDA ISLKIND,Y
        BNE RG_HFND
        INY             ; player 0: east
        CPX #0
        BEQ RG_HSTP
        DEY             ; player 1: west
        DEY
RG_HSTP DEC RM_K
        BNE RG_HSQ
        LDY RM_I        ; no land in this row: the next row
        INY
        BNE RG_HROW     ; (row 5 always has its start square)
RG_HFND LDA #T_PIER_E   ; the square before: player 0, land east
        DEY
        CPX #0
        BEQ RG_HSET
        INY             ; player 1, land west
        INY
        LDA #T_PIER_W
RG_HSET STA ISLTILE,Y
        LDA RMHKIND,X
        STA ISLKIND,Y
        DEX
        BPL RG_HARB
        LDY #MAPSIZE-ML_ROW-1 ; the land squares' tiles (none in
RG_TILE LDA ISLKIND,Y   ; the first or last row)
        AND #K_KIND
        CMP #K_LAND
        BNE RG_TNXT
        LDA #0          ; land neighbours: 1 N, 2 E, 4 S, 8 W
        STA RM_K
        LDX #3
RG_NB   TYA
        CLC
        ADC RMNBO,X     ; the neighbour (no wrap: land is never at
        STY RM_I        ; the map's edge)
        TAY
        LDA ISLKIND,Y
        AND #K_KIND
        CMP #K_LAND
        BNE RG_NBN
        LDA RM_K
        ORA RMNBB,X
        STA RM_K
RG_NBN  LDY RM_I
        DEX
        BPL RG_NB
        LDX RM_K
        CPX #RM_FULL
        BEQ RG_GRS
        LDA RNDTILE,X   ; a coast piece
        BNE RG_TSET
RG_GRS  JSR RM_RC       ; grass, by row and column AND 3
        LDA RM_R
        AND #3
        ASL A
        ASL A
        STA RM_K
        LDA RM_C
        AND #3
        ORA RM_K
        TAX
        LDA GRSTL,X
RG_TSET STA ISLTILE,Y
RG_TNXT DEY
        CPY #ML_ROW-1
        BNE RG_TILE
        RTS

; RM_ISLE -- side RM_S: its squares back to sea, then its island
RM_ISLE LDA #RM_ROW0    ; clear the side's rows 2-8, columns 1-8 or
        STA RM_R        ; 11-18
RI_ROW  LDY RM_R
        LDA ROWIDX,Y
        LDX RM_S
        CLC
        ADC RMLO,X
        TAY
        LDX #RM_NCOL
        LDA #K_SEA
RI_CLR  STA ISLKIND,Y
        INY
        DEX
        BNE RI_CLR
        INC RM_R
        LDA RM_R
        CMP #RM_ROW0+RM_NROW
        BNE RI_ROW
        LDX RM_S        ; the start square, row 5
        LDY RMST,X
        LDA RMOWN,X
        STA ISLKIND,Y
        LDA #RM_N-1
        STA RM_K        ; squares still to add
RI_TRY  LDA #RM_NROW    ; a random square of the side
        JSR RAND_N
        CLC
        ADC #RM_ROW0
        TAY
        LDA #RM_NCOL
        JSR RAND_N
        LDX RM_S
        CLC
        ADC RMLO,X
        ADC ROWIDX,Y    ; carry clear: < 220
        TAY
        LDA ISLKIND,Y
        BNE RI_TRY      ; land already
        LDA ISLKIND-1,Y ; land next to it?
        ORA ISLKIND+1,Y
        ORA ISLKIND-ML_ROW,Y
        ORA ISLKIND+ML_ROW,Y
        BEQ RI_TRY
        LDA RMOWN,X
        STA ISLKIND,Y
        DEC RM_K
        BNE RI_TRY
        RTS

; RM_RC -- RM_R, RM_C = row and column of square Y.  Keeps Y;
; trashes A, X.
RM_RC   TYA
        LDX #0
RC_ROW  CMP #ML_ROW
        BCC RC_DONE
        SBC #ML_ROW     ; carry set
        INX
        BNE RC_ROW
RC_DONE STA RM_C
        STX RM_R
        RTS

RMLO    .BYTE 1,11      ; first column of each side
RMST    .BYTE 104,115   ; start squares: row 5, columns 4 and 15
RMOWN   .BYTE K_LAND,K_LAND+K_P1
RMHKIND .BYTE K_HARB,K_HARB+K_P1
RMHROW  .BYTE 5,4,6,3,7 ; rows tried for a harbour
RMNBO   .BYTE 256-ML_ROW,1,ML_ROW,255 ; N, E, S, W
RMNBB   .BYTE 1,2,4,8
