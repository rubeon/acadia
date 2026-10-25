; =====================================================================
;  FISH.ASM -- schools of fish and fishing (T-EVT-2: R-RULE-4, -6;
;  the original's $520D-$52B3, $549F-$54D2; D33)
;
;  Up to two schools, both shown by player 3 (D13).  Each tic:
;    - 1 in 20: a school appears in a free slot, at the left edge
;      heading right or the right edge heading left, in the top band
;      (map row 1) or the bottom band (row 10); if the other school is
;      out, the new one takes the other band (D14);
;    - each school gets, 1 in 10, a kick of 1 to its speed: east,
;      west, north or south;
;    - it moves; an axis that would take its centre onto land or a
;      parked PT boat stops (speed 0 on that axis); a school that
;      leaves the map is gone;
;    - a fishing boat over a school counts a touch for its owner:
;      a steered one whose 8 x 8 box overlaps the school's, or a
;      parked one on the square under the school's centre.  Every
;      50 touches earn 1 gold (GOLD and RGOLD), with the "pling".
;  Fishing never uses a school up.
;
;  Positions are 8.8 fixed point, offset by 8 so a school can sit
;  just off the map: FXH = map pixel column + 8 (0-168), FYH = map
;  line + 8 (0-96).  Speeds are signed, in steps of 1/5 pixel per tic
;  (the original's units: boat 10, cursor 15, fish 3).
;
;  Player 3 shows both schools: FISH_SHOW (every frame) draws them in
;  P3 memory and fills HP3ROW, the horizontal position for each map
;  row, which the DLIs load (DISPLAY.ASM).  When both schools share a
;  map row, they take turns, one per frame (D14).
; =====================================================================

F_SPAWN =  20           ; 1 in 20 tics: a new school
F_KICK  =  10           ; 1 in 10 tics: a speed kick
F_V0    =  3            ; starting speed
F_VMAX  =  15           ; speed limit either way (table size)
F_XMAX  =  168          ; FXH range 0-168: map column -8..160
F_YMAX  =  96           ; FYH range 0-96: map line -8..88
F_TOP   =  12           ; FYH of the top band: lines 4-11 (centre row 1)
F_BOT   =  84           ; FYH of the bottom band: lines 76-83 (row 10)
F_CATCH =  50           ; touches for 1 gold
F_ANIM  =  4            ; tics per animation frame
C_FISH  =  $C6          ; school colour (PCOLR3): green
PM_P3   =  PMAREA+$380

; ---------------------------------------------------------------------
;  FISH_INIT -- no schools, no touches (start of a game).
;  Trashes A, X.
; ---------------------------------------------------------------------
FISH_INIT
        LDA #0
        STA FACT
        STA FACT+1
        STA FCNT
        STA FCNT+1
        STA FANIM
        STA FATIC
        LDX #MAPROWS-1
FI_HP   STA HP3ROW,X
        DEX
        BPL FI_HP
        LDX #PM_LEN-1
FI_PM   STA PM_P3,X
        DEX
        BPL FI_PM
        LDA #$FF        ; nothing drawn
        STA FDRAWN
        STA FDRAWN+1
        RTS

; ---------------------------------------------------------------------
;  FISH_TIC -- one tic of the schools (during a round).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
FISH_TIC
        INC FATIC       ; animation
        LDA FATIC
        CMP #F_ANIM
        BCC FT_SPWN
        LDA #0
        STA FATIC
        LDA FANIM
        CLC
        ADC #1
        AND #3
        STA FANIM
FT_SPWN LDA #F_SPAWN
        JSR RAND_N
        BNE FT_RUN
        LDX #0
        LDA FACT
        BEQ FT_NEW
        INX
        LDA FACT+1
        BNE FT_RUN      ; both out already
FT_NEW  JSR FISH_NEW
FT_RUN  LDX #1
FT_ONE  STX FT_I
        LDA FACT,X
        BEQ FT_NEXT
        JSR FISH_KICK
        LDX FT_I
        JSR FISH_MOVE
        LDX FT_I
        LDA FACT,X
        BEQ FT_NEXT     ; it left the map
        JSR FISH_CATCH
FT_NEXT LDX FT_I
        DEX
        BPL FT_ONE
        RTS

; ---------------------------------------------------------------------
;  FISH_NEW -- start school X.  Trashes A, Y; X kept.
; ---------------------------------------------------------------------
FISH_NEW
        TXA             ; band: the other school's opposite, if it is out
        EOR #1
        TAY
        LDA FACT,Y
        BEQ FN_RND
        LDA FYH,Y
        CMP #(F_TOP+F_BOT)/2
        LDA #0
        ROL A           ; 1 if the other is low: then go high
        EOR #1
        JMP FN_BAND
FN_RND  LDA #2
        JSR RAND_N      ; 0 top, 1 bottom
FN_BAND STA FN_T
        LDA #8
        JSR RAND_N
        CLC
        ADC #F_TOP
        LDY FN_T
        BEQ FN_Y
        ADC #F_BOT-F_TOP
FN_Y    STA FYH,X
        LDA #0
        STA FXL,X
        STA FYL,X
        STA FVY,X
        LDA #2
        JSR RAND_N      ; 0: from the left, 1: from the right
        BNE FN_RIGHT
        STA FXH,X       ; A = 0
        LDA #F_V0
        BNE FN_GO
FN_RIGHT
        LDA #F_XMAX
        STA FXH,X
        LDA #256-F_V0
FN_GO   STA FVX,X
        LDA #$FF        ; must be drawn afresh
        STA FDRAWN,X
        LDA #1
        STA FACT,X
        RTS

; ---------------------------------------------------------------------
;  FISH_KICK -- 1 in F_KICK: change school X's speed by 1 east, west,
;  north or south (within +-F_VMAX).  Trashes A, Y; X kept.
; ---------------------------------------------------------------------
FISH_KICK
        LDA #F_KICK
        JSR RAND_N
        BNE FK_DONE
        LDA #4
        JSR RAND_N
        LSR A           ; C: minus, A: 0 = east-west, 1 = north-south
        TAY
        BEQ FK_X
        LDA FVY,X
        JSR FK_STEP
        STA FVY,X
FK_DONE RTS
FK_X    LDA FVX,X
        JSR FK_STEP
        STA FVX,X
        RTS
; FK_STEP -- A +1 (C clear) or -1 (C set), held within +-F_VMAX
FK_STEP BCS FS_DEC
        CMP #F_VMAX
        BEQ FS_DONE
        CLC
        ADC #1
        RTS
FS_DEC  CMP #256-F_VMAX
        BEQ FS_DONE
        SEC
        SBC #1
FS_DONE RTS

; ---------------------------------------------------------------------
;  FISH_MOVE -- move school X one tic, axis by axis.  Trashes A, Y.
; ---------------------------------------------------------------------
FISH_MOVE
        LDA FVX,X       ; horizontal
        CLC
        ADC #F_VMAX
        TAY
        LDA FXL,X
        CLC
        ADC FV_LO,Y
        STA FM_L
        LDA FXH,X
        ADC FV_HI,Y
        CMP #F_XMAX+1
        BCS FM_GONE     ; off the map (or below 0)
        STA FM_H
        LDY FYH,X
        JSR FISH_BLK
        BCC FM_XOK
        LDA #0          ; stopped on this axis
        STA FVX,X
        BEQ FM_VERT
FM_XOK  LDA FM_L
        STA FXL,X
        LDA FM_H
        STA FXH,X
FM_VERT LDA FVY,X       ; vertical
        CLC
        ADC #F_VMAX
        TAY
        LDA FYL,X
        CLC
        ADC FV_LO,Y
        STA FM_L
        LDA FYH,X
        ADC FV_HI,Y
        CMP #F_YMAX+1
        BCS FM_GONE
        STA FM_H
        TAY
        LDA FXH,X
        JSR FISH_BLK2
        BCC FM_YOK
        LDA #0
        STA FVY,X
        RTS
FM_YOK  LDA FM_L
        STA FYL,X
        LDA FM_H
        STA FYH,X
        RTS
FM_GONE LDA #0
        STA FACT,X
        RTS

; ---------------------------------------------------------------------
;  FISH_BLK  -- would a school at FXH = FM_H, FYH = Y be stopped?
;  FISH_BLK2 -- the same for FXH = A, FYH = Y.
;  Looks at the square under the school's centre: land or a parked PT
;  boat stops it; off the map is open sea.
;  Out: C set if stopped.  X kept; trashes A, Y.
; ---------------------------------------------------------------------
FISH_BLK
        LDA FM_H
FISH_BLK2
        STX FB_X
        SEC
        SBC #4          ; centre column: FXH - 8 + 4
        BCC FB_FREE
        CMP #MAPSQ*8
        BCS FB_FREE
        LSR A
        LSR A
        LSR A
        STA FB_C
        TYA
        SEC
        SBC #4          ; centre line: FYH - 8 + 4
        BCC FB_FREE
        CMP #MAPROWS*8
        BCS FB_FREE
        LSR A
        LSR A
        LSR A
        TAY
        LDX FB_C
        JSR MAP_GET
        AND #I_ITEM
        CMP #I_PTBT
        BEQ FB_STOP
        LDA MKIND
        AND #K_KIND
        CMP #K_LAND
        BEQ FB_STOP
FB_FREE LDX FB_X
        CLC
        RTS
FB_STOP LDX FB_X
        SEC
        RTS

; ---------------------------------------------------------------------
;  FISH_CATCH -- touches between school X and the fishing boats.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
FISH_CATCH
        STX FC_I
        LDA FXH,X       ; parked: a fishing boat under the centre
        LDY FYH,X
        JSR FC_SQ
        BCS FC_STEER
        JSR MAP_GET
        STA FC_T
        AND #I_ITEM
        CMP #I_FSBT
        BNE FC_STEER
        LDA FC_T        ; owner: I_P1 -> 1
        ASL A
        LDA #0
        ROL A
        TAX
        JSR FISH_TOUCH
FC_STEER
        LDX #1          ; steered fishing boats over the school
FC_PL   STX FC_P
        LDA BOATK,X
        CMP #I_FSBT
        BNE FC_NEXT
        LDY FC_I
        LDA CURX,X      ; boat x + 8 - school FXH, overlapping if -7..7
        CLC
        ADC #8
        SEC
        SBC FXH,Y
        CLC
        ADC #7
        CMP #15
        BCS FC_NEXT
        LDA CURY,X
        CLC
        ADC #8
        SEC
        SBC FYH,Y
        CLC
        ADC #7
        CMP #15
        BCS FC_NEXT
        JSR FISH_TOUCH
FC_NEXT LDX FC_P
        DEX
        BPL FC_PL
        RTS

; FC_SQ -- square under the centre of a school at FXH = A, FYH = Y:
; X = column, Y = row, C clear; C set if off the map.  Trashes A.
FC_SQ   SEC
        SBC #4
        BCC FQ_OFF
        CMP #MAPSQ*8
        BCS FQ_OFF
        LSR A
        LSR A
        LSR A
        TAX
        TYA
        SEC
        SBC #4
        BCC FQ_OFF
        CMP #MAPROWS*8
        BCS FQ_OFF
        LSR A
        LSR A
        LSR A
        TAY
        CLC
        RTS
FQ_OFF  SEC
        RTS

; FISH_TOUCH -- one touch for player X; 1 gold every F_CATCH.
; Trashes A, Y; X kept.
FISH_TOUCH
        INC FCNT,X
        LDA FCNT,X
        CMP #F_CATCH
        BCC FH_DONE
        LDA #0
        STA FCNT,X
        STA EG_AMT+1
        LDA #1
        STA EG_AMT
        JSR ECO_EARN
        STX FC_T
        JSR STAT_SHOW
        JSR SND_FISH
        LDX FC_T
FH_DONE RTS

; ---------------------------------------------------------------------
;  FISH_SHOW -- draw the schools in player 3 and set HP3ROW.
;  Every frame.  Trashes A, X, Y.
; ---------------------------------------------------------------------
FISH_SHOW
        LDA FACT        ; which to show: both, unless they share a row
        STA FS_V
        LDA FACT+1
        STA FS_V+1
        AND FACT
        BEQ FW_CLR
        LDX #0
        JSR FW_ROWS
        STA FS_A1       ; school 0: rows FW_R0..A
        LDA FW_R0
        STA FS_A0
        LDX #1
        JSR FW_ROWS     ; school 1: FW_R0..A
        CMP FS_A0
        BCC FW_CLR      ; 1 ends above 0
        LDA FS_A1
        CMP FW_R0
        BCC FW_CLR      ; 0 ends above 1
        LDA FRAME       ; shared rows: take turns
        AND #1
        TAX
        LDA #0
        STA FS_V,X
FW_CLR  LDA #0          ; no positions until set below
        LDX #MAPROWS-1
FW_HP   STA HP3ROW,X
        DEX
        BPL FW_HP
        LDX #1
FW_ONE  STX FS_I
        LDA FDRAWN,X    ; erase where it was
        CMP #$FF
        BEQ FW_DRAW
        TAY
        LDA #0
        LDX #SPR_H-1
FW_ERA  STA PM_P3,Y
        INY
        DEX
        BPL FW_ERA
        LDX FS_I
        LDA #$FF
        STA FDRAWN,X
FW_DRAW LDA FS_V,X
        BEQ FW_NEXT
        LDA FYH,X       ; P/M line: map line + PM_MAP = FYH - 8 + PM_MAP
        CLC
        ADC #PM_MAP-8
        STA FDRAWN,X
        TAY
        LDA FANIM       ; shape: frame x 8
        ASL A
        ASL A
        ASL A
        TAX
        LDA #SPR_H
        STA FS_N
FW_PUT  LDA FISHSHP,X
        STA PM_P3,Y
        INX
        INY
        DEC FS_N
        BNE FW_PUT
        LDX FS_I        ; its rows get its horizontal position
        JSR FW_ROWS
        STA FS_A1
        LDA FXH,X       ; FXH - 8 + HP_MAP
        CLC
        ADC #HP_MAP-8
        LDY FW_R0
FW_ROW  STA HP3ROW,Y
        CPY FS_A1
        BCS FW_NEXT
        INY
        BNE FW_ROW
FW_NEXT LDX FS_I
        DEX
        BPL FW_ONE
        RTS

; FW_ROWS -- map rows school X covers: FW_R0..A, held to 0..10.
; X kept; trashes A.
FW_ROWS LDA FYH,X       ; first: (FYH >> 3) - 1, at least 0
        LSR A
        LSR A
        LSR A
        BEQ FR_TOP
        SEC
        SBC #1
        CMP #MAPROWS
        BCC FR_TOP
        LDA #MAPROWS-1  ; below the map: row 10 (nothing shows there)
FR_TOP  STA FW_R0
        LDA FYH,X       ; last: ((FYH + 7) >> 3) - 1, at most 10
        CLC
        ADC #7
        LSR A
        LSR A
        LSR A
        SEC
        SBC #1
        BCS FR_LO
        LDA #0
FR_LO   CMP #MAPROWS
        BCC FR_DONE
        LDA #MAPROWS-1
FR_DONE RTS

; Speed steps: 51/256 pixel per tic for each unit, speeds -15..+15
FV_LO   .BYTE $03,$36,$69,$9C,$CF,$02,$35,$68,$9B,$CE,$01,$34,$67,$9A,$CD,$00
        .BYTE $33,$66,$99,$CC,$FF,$32,$65,$98,$CB,$FE,$31,$64,$97,$CA,$FD
FV_HI   .BYTE $FD,$FD,$FD,$FD,$FD,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$00
        .BYTE $00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02

; School shapes: 4 frames of a shimmering scatter of small fish
FISHSHP .BYTE $22,$08,$41,$14,$22,$88,$14,$41
        .BYTE $11,$44,$20,$0A,$11,$44,$0A,$20
        .BYTE $88,$22,$04,$50,$88,$22,$50,$04
        .BYTE $44,$11,$82,$28,$44,$11,$28,$82
