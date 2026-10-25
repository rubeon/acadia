; =====================================================================
;  MAP.ASM -- the map grid: what stands on each square
;
;  A square is described by three things:
;    kind    ISLKIND (constant, generated): K_SEA, K_LAND, K_HARB,
;            K_ROCK, with K_P1 (bit 7) set on player 1's squares
;    terrain ISLTILE (constant, generated): the tile drawn when the
;            square is empty
;    item    MAPITEM (RAM): 0 = nothing, 1-9 = the item with that key
;            number (1 fort ... 9 fishing boat); a parked boat has
;            I_P1 (bit 7) set if it is player 2's, since boats can
;            park anywhere at sea (D32)
;  so removing an item just redraws the terrain.  All three are
;  20 x 11 grids, row-major, index = row x 20 + column (MAP_IDX).
;
;  Columns are 0-19 and rows 0-10.  Every routine treats a square off
;  the map as open sea with nothing on it.
; =====================================================================

I_FORT  =  1            ; item numbers = keypad keys (utopia-rules.md)
I_FACT  =  2
I_CROP  =  3
I_SCHL  =  4
I_HOSP  =  5
I_HOUS  =  6
I_REBL  =  7
I_PTBT  =  8
I_FSBT  =  9
I_ITEM  =  $7F          ; mask: item number
I_P1    =  $80          ; on a boat: it belongs to player 2 (D32)

MAPSIZE =  220          ; 20 x 11 squares

; ---------------------------------------------------------------------
;  MAP_INIT -- clear every square's item
;  Trashes A, X.
; ---------------------------------------------------------------------
MAP_INIT
        LDA #0
        LDX #MAPSIZE-1
MI_CLR  STA MAPITEM,X
        DEX
        CPX #$FF
        BNE MI_CLR
        RTS

; ---------------------------------------------------------------------
;  MAP_GET -- what is on a square
;  In: X = column, Y = row.
;  Out: A = item (0 = none), MKIND = kind (with owner bit), C clear;
;       off the map: A = 0, MKIND = K_SEA, C set.
;  X and Y kept.
; ---------------------------------------------------------------------
MAP_GET
        CPX #MAPSQ
        BCS MG_OFF
        CPY #MAPROWS
        BCS MG_OFF
        JSR MAP_IDX
        STX MG_X
        TAX
        LDA ISLKIND,X
        STA MKIND
        LDA MAPITEM,X
        LDX MG_X
        CLC
        RTS
MG_OFF  LDA #K_SEA
        STA MKIND
        LDA #0
        SEC
        RTS

; ---------------------------------------------------------------------
;  MAP_SET -- put an item on a square (0 removes it) and redraw it
;  In: A = item 0-9, X = column, Y = row.
;  Out: C set (and nothing done) if the square is off the map.
;  Does not check whether the item is allowed there (see T-ECO-1).
;  X kept; trashes A, Y, ZPTR.
; ---------------------------------------------------------------------
MAP_SET
        CPX #MAPSQ
        BCS MS_OFF
        CPY #MAPROWS
        BCS MS_OFF
        STA MS_ITEM
        JSR MAP_IDX
        STX MG_X
        TAX
        LDA MS_ITEM
        STA MAPITEM,X
        BEQ MS_TERR
        AND #I_ITEM
        CLC             ; item k is tile T_ITEM+k-1
        ADC #T_ITEM-1
        BNE MS_DRAW     ; always taken (T_ITEM > 0)
MS_TERR LDA ISLTILE,X   ; empty: the square's own terrain
MS_DRAW LDX MG_X
        JSR MAP_PUT     ; A = tile, X = column, Y = row
        LDA MS_ITEM     ; player 2's boat: inverse, light parts white
        BPL MS_DONE
        LDA (ZPTR),Y    ; MAP_PUT left ZPTR/Y on the right character
        ORA #$80
        STA (ZPTR),Y
        DEY
        LDA (ZPTR),Y
        ORA #$80
        STA (ZPTR),Y
MS_DONE CLC
        RTS
MS_OFF  SEC
        RTS

; ---------------------------------------------------------------------
;  MAP_HARB -- the square of player A's harbour (where boats launch)
;  In: A = player 0/1.  Out: X = column, Y = row.  Trashes A.
; ---------------------------------------------------------------------
MAP_HARB
        LSR A           ; player 1 -> K_P1 (bit 7)
        ROR A
        ORA #K_HARB
        LDX #MAPSIZE-1
MH_FIND CMP ISLKIND,X
        BEQ MH_ROW
        DEX
        BNE MH_FIND     ; (square 0 is open sea, never a harbour)
MH_ROW  TXA             ; index -> row, column
        LDY #0
MH_DIV  CMP #MAPSQ
        BCC MH_DONE
        SBC #MAPSQ      ; carry set
        INY
        BNE MH_DIV
MH_DONE TAX
        RTS

; ---------------------------------------------------------------------
;  FORT_NEAR -- is there a fort on one of the 8 squares around this one?
;  As the original (FORT_NEAR_MOB / NBR_TBL, $564A-$568C): the eight
;  neighbours E, SW, S, SE, W, NE, N, NW are checked in that order, the
;  square itself is not, and a fort of either player counts.  Unlike
;  the original, which steps through screen memory and so wraps from
;  one row's end to the next row's start, neighbours off the map edge
;  are simply skipped.
;  In: X = column, Y = row.
;  Out: C set if a fort was found, A = its owner (0 or 1); else C clear.
;  X and Y kept.
; ---------------------------------------------------------------------
FORT_NEAR
        STX FN_COL
        STY FN_ROW
        LDA #0
        STA FN_I
FN_LOOP LDX FN_I
        LDA FN_COL
        CLC
        ADC NBR_DC,X
        CMP #MAPSQ      ; also catches -1 ($FF)
        BCS FN_NEXT
        STA FN_C
        LDA FN_ROW
        CLC
        ADC NBR_DR,X
        CMP #MAPROWS
        BCS FN_NEXT
        TAY
        LDX FN_C
        JSR MAP_IDX
        TAX
        LDA MAPITEM,X
        CMP #I_FORT
        BNE FN_NEXT
        LDA ISLKIND,X   ; owner: bit 7 of the kind
        ASL A
        LDA #0
        ROL A           ; A = 0 or 1
        LDX FN_COL
        LDY FN_ROW
        SEC
        RTS
FN_NEXT INC FN_I
        LDA FN_I
        CMP #8
        BNE FN_LOOP
        LDX FN_COL
        LDY FN_ROW
        CLC
        RTS

; Neighbour offsets in the original's order: E, SW, S, SE, W, NE, N, NW
NBR_DC  .BYTE 1,$FF,0,1,$FF,1,0,$FF
NBR_DR  .BYTE 0,1,1,1,0,$FF,$FF,$FF
