; =====================================================================
;  WEATHER.ASM -- rain, tropical storms and hurricanes (T-EVT-4:
;  R-RULE-4, -5; the original's $51AA-$5235, $5555-$5759; D35)
;
;  Up to two weather objects, both shown by player 2 (D35).  Each tic
;  of a round:
;    - 1 in 100: a new one in a free slot (the second only once the
;      first is a row clear of the top, D14): a hurricane 1 time in
;      12, a tropical storm 3 in 12, rain 8 in 12.  It starts near the
;      top left, above the map, drifting down and right;
;    - each gets, 1 in 10, a kick of 1 to its speed: east, west, north
;      or south; nothing blocks it, and it is gone once off the map;
;    - the square under its centre, if an item or a parked boat is on
;      it, is hit:
;        damage: storm 1, hurricane 5 (rain 0) goes to the square's
;          owner; at 125 the item is destroyed (any item; a parked boat
;          sinks and leaves a wreck for a few seconds; anything else
;          also kills 0-100 people) and the owner's damage starts
;          again from 0;
;        rain: any weather over a crop counts one for the crop's
;          owner; every 12 earn 1 gold (GOLD and RGOLD);
;    - a hurricane sinks a steered boat it touches.
;  Forts give no protection from weather (the original's WTHR_V_LAND
;  never asks).
;
;  Positions as FISH.ASM: 8.8 fixed point, WXH = map column + 8
;  (0-168), WYH = map line + 8 (0-96), speeds in 38/256 pixel per tic
;  each, 3/4 of the original's 51/256 (D43).  Rain and storms are 16 x 8 pixels
;  (2 squares by 1), hurricanes 16 x 32.
;
;  Player 2 is double width (16 pixels), over the playfield, light
;  grey for rain, dark grey for a storm, white for a hurricane (the
;  original: rain grey, storm black).  WTH_SHOW (every frame) draws
;  both objects in player 2 memory and fills HP2ROW and WCROW, the
;  position and colour for each map row, which the DLIs load.
;  Two objects sharing a map row take turns, one per frame (D14).
; =====================================================================

W_SPAWN =  100          ; 1 in 100 tics: new weather
W_TYPES =  12           ; type roll: 0 hurricane, 1-3 storm, 4-11 rain
W_KICK  =  10           ; 1 in 10 tics: a speed kick
W_X0    =  27           ; start: WXH (map column 19), WYH (above the map)
W_Y0    =  0
W_VX0   =  4            ; start speed: down and to the right
W_VY0   =  5
W_VMAX  =  15           ; speed limit either way (table size)
W_XMAX  =  168          ; WXH range 0-168
W_YMAX  =  96           ; WYH range 0-96
W_CROP  =  12           ; rain over crops: tics for 1 gold
W_DMG   =  125          ; damage that destroys an item
W_WRECK =  60           ; tics a wreck stays (3 s)
W_ANIM  =  4            ; tics per animation frame
WT_RAIN =  1            ; WACT values
WT_STRM =  2
WT_HURR =  3
PM_P2   =  PMAREA+$300  ; player 2 memory
PM_TOP  =  PM_MAP-8     ; first P/M line WTH_SHOW uses (WYH = 0)
C_RAIN  =  $0C          ; light grey
C_STRM  =  $04          ; dark grey
C_HURR  =  $0E          ; white
C_FLASH =  $0E          ; a storm lit by its lightning: white
W_BOLT  =  7            ; WANIM of a storm's lightning (frame 4)

; ---------------------------------------------------------------------
;  WTH_INIT -- no weather, no damage, no rain counts (start of a game).
;  Trashes A, X.
; ---------------------------------------------------------------------
WTH_INIT
        LDA #0
        LDX #1
WI_SLOT STA WACT,X
        STA WRCNT,X
        STA WDMG,X
        DEX
        BPL WI_SLOT
        STA WANIM
        STA WATIC
        STA SNKT
        LDX #MAPROWS-1
WI_HM   STA HP2ROW,X
        DEX
        BPL WI_HM
        LDX #PM_LEN-1
WI_PM   STA PM_P2,X
        DEX
        BPL WI_PM
        LDA #$FF        ; nothing drawn
        STA WDRAWN
        STA WDRAWN+1
        RTS

; ---------------------------------------------------------------------
;  WTH_TIC -- one tic of the weather (during a round).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
WTH_TIC
        INC WATIC       ; animation: WANIM 0-7
        LDA WATIC
        CMP #W_ANIM
        BCC WT_WRK
        LDA #0
        STA WATIC
        LDA WANIM
        CLC
        ADC #1
        AND #7
        STA WANIM
WT_WRK  LDA SNKT        ; a wreck showing: clear it when its time is up
        BEQ WT_SPWN
        DEC SNKT
        BNE WT_SPWN
        LDX SNKC
        LDY SNKR
        JSR MAP_GET
        CMP #0
        BNE WT_SPWN     ; something was put there since: leave it
        LDX SNKC
        LDY SNKR
        JSR MAP_SET     ; A = 0: the square's terrain again
WT_SPWN LDA #W_SPAWN
        JSR RAND_N
        BNE WT_RUN
        LDX #0          ; a free slot
        LDA WACT
        BEQ WT_NEW
        INX
        LDA WACT+1
        BNE WT_RUN      ; both out already
WT_NEW  JSR WTH_NEW
WT_RUN  LDX #1
WT_ONE  STX WT_I
        LDA WACT,X
        BEQ WT_NEXT
        JSR WTH_KICK
        LDX WT_I
        JSR WTH_MOVE
        LDX WT_I
        LDA WACT,X
        BEQ WT_NEXT     ; it left the map
        JSR WTH_HIT
        LDX WT_I
        LDA WACT,X
        CMP #WT_HURR
        BNE WT_NEXT
        JSR WTH_BOAT
WT_NEXT LDX WT_I
        DEX
        BPL WT_ONE
        RTS

; ---------------------------------------------------------------------
;  WTH_NEW -- start weather in slot X, unless the other slot's object
;  is still within a row of the top (D14).  Trashes A, Y; X kept.
; ---------------------------------------------------------------------
WTH_NEW
        STX WN_S
        TXA             ; the other slot
        EOR #1
        TAY
        LDA WACT,Y
        BEQ WN_GO
        TAX             ; its top line (WYH - 8) must be at least its
        LDA WHGT,X      ; height + 8 down: WYH >= height + 16
        CLC
        ADC #16
        STA WN_T
        LDX WN_S
        LDA WYH,Y
        CMP WN_T
        BCC WN_DONE     ; still near the top
WN_GO   LDA #W_TYPES
        JSR RAND_N
        BEQ WN_HURR
        CMP #4
        LDA #WT_STRM
        BCC WN_TYPE
        LDA #WT_RAIN
        BNE WN_TYPE
WN_HURR LDA #WT_HURR
WN_TYPE STA WACT,X
        LDA #W_X0
        STA WXH,X
        LDA #W_Y0
        STA WYH,X
        LDA #0
        STA WXL,X
        STA WYL,X
        LDA #W_VX0
        STA WVX,X
        LDA #W_VY0
        STA WVY,X
        LDA #$FF        ; must be drawn afresh
        STA WDRAWN,X
        LDA WACT,X      ; a storm or a hurricane: its rumble
        CMP #WT_STRM
        BCC WN_DONE
        CMP #WT_HURR    ; a hurricane is news too
        BCC WN_SND
        LDA #NW_HURR
        JSR NEWSG
WN_SND  JMP SND_STORM
WN_DONE RTS

; ---------------------------------------------------------------------
;  WTH_KICK -- 1 in W_KICK: change slot X's speed by 1 east, west,
;  north or south (within +-W_VMAX).  Trashes A, Y; X kept.
; ---------------------------------------------------------------------
WTH_KICK
        LDA #W_KICK
        JSR RAND_N
        BNE WK_DONE
        LDA #4
        JSR RAND_N
        LSR A           ; C: minus, A: 0 = east-west, 1 = north-south
        TAY
        BEQ WK_X
        LDA WVY,X
        JSR FK_STEP     ; (FISH.ASM; W_VMAX = F_VMAX)
        STA WVY,X
WK_DONE RTS
WK_X    LDA WVX,X
        JSR FK_STEP
        STA WVX,X
        RTS

; ---------------------------------------------------------------------
;  WTH_MOVE -- move slot X one tic; gone once off the map.
;  Trashes A, Y; X kept.
; ---------------------------------------------------------------------
WTH_MOVE
        LDA WVX,X       ; horizontal
        CLC
        ADC #W_VMAX
        TAY
        LDA WXL,X
        CLC
        ADC WV_LO,Y
        STA WXL,X
        LDA WXH,X
        ADC WV_HI,Y
        CMP #W_XMAX+1
        BCS WM_GONE     ; off the map (or below 0)
        STA WXH,X
        LDA WVY,X       ; vertical
        CLC
        ADC #W_VMAX
        TAY
        LDA WYL,X
        CLC
        ADC WV_LO,Y
        STA WYL,X
        LDA WYH,X
        ADC WV_HI,Y
        CMP #W_YMAX+1
        BCS WM_GONE
        STA WYH,X
        RTS
WM_GONE LDA #0
        STA WACT,X
        RTS

; ---------------------------------------------------------------------
;  WTH_HIT -- slot X over the square under its centre: damage and
;  rain on crops (the original's WTHR_V_LAND, $5691-$5759).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
WH_OUT  RTS
WTH_HIT
        STX WH_I
        LDA WXH,X       ; centre column: WXH - 8 + 8
        CMP #MAPSQ*8
        BCS WH_OUT
        LSR A
        LSR A
        LSR A
        STA WH_C
        LDY WACT,X      ; centre line: WYH - 8 + height / 2
        LDA WYH,X
        CLC
        ADC WHALF,Y
        SEC
        SBC #8
        BCC WH_OUT     ; above the map
        CMP #MAPROWS*8
        BCS WH_OUT
        LSR A
        LSR A
        LSR A
        STA WH_R
        TAY
        LDX WH_C
        JSR MAP_GET
        CMP #0
        BEQ WH_OUT     ; open sea or bare land: nothing happens
        STA WH_IT
        AND #I_ITEM
        STA WH_K
        CMP #I_PTBT
        BCC WH_LAND
        LDA WH_IT       ; a parked boat: its owner bit
        JMP WH_OWN
WH_LAND LDA MKIND       ; an item on land: the island's owner
WH_OWN  ASL A           ; bit 7 -> player 0/1
        LDA #0
        ROL A
        STA WH_P
        LDX WH_I        ; damage to the owner
        LDY WACT,X
        LDA WRATE,Y
        BEQ WH_RAIN     ; rain does no damage
        LDX WH_P
        CLC
        ADC WDMG,X
        STA WDMG,X
        CMP #W_DMG
        BCC WH_RAIN
        JMP WTH_SMITE   ; destroyed: no crop left to rain on
WH_RAIN LDA WH_K        ; over a crop: rain count for its owner
        CMP #I_CROP
        BNE WH_DONE
        LDX WH_P
        INC WRCNT,X
        LDA WRCNT,X
        CMP #W_CROP
        BCC WH_DONE
        LDA #0
        STA WRCNT,X
        LDA #1
        STA EG_AMT
        LDA #0
        STA EG_AMT+1
        JSR ECO_EARN
        JSR STAT_SHOW
        JMP SND_RAIN
WH_DONE RTS

; ---------------------------------------------------------------------
;  WTH_SMITE -- destroy item WH_K of player WH_P on square WH_C, WH_R:
;  one fewer owned, damage back to 0; a parked boat sinks (wreck),
;  anything else also kills 0-100 people.  Trashes A, X, Y.
;  WS_GONE -- the same without touching the damage: pirates (and PT
;  boats) sinking a parked fishing boat (PIRATES.ASM).
; ---------------------------------------------------------------------
WTH_SMITE
        LDX WH_P
        LDA #0
        STA WDMG,X
WS_GONE JSR WS_COUNT    ; one fewer of the item
        LDX WH_C        ; the square's terrain again
        LDY WH_R
        LDA #0
        JSR MAP_SET
        LDA WH_K
        CMP #I_PTBT
        BCC WS_PEOP
        LDA SNKT        ; a boat: show the wreck (one at a time)
        BNE WS_SNK
        LDA #W_WRECK
        STA SNKT
        LDX WH_C
        STX SNKC
        LDY WH_R
        STY SNKR
        LDA #T_WRECK
        JSR MAP_PUT
WS_SNK  LDA #NW_SINK     ; news: the owner's boat sunk
        LDX WH_P
        JSR NEWS
        JMP SND_SINK
WS_PEOP LDA #101        ; 0-100 people die
        JSR RAND_N
        STA WS_N
        LDA WH_P
        ASL A
        TAX
        LDA POP,X
        SEC
        SBC WS_N
        STA POP,X
        LDA POP+1,X
        SBC #0
        STA POP+1,X
        BCS WS_SND
        LDA #0          ; not below 0 (D35)
        STA POP,X
        STA POP+1,X
WS_SND  LDA #NW_DMG      ; news: storm damage to the owner
        LDX WH_P
        JSR NEWS
        JMP SND_SMITE

; WS_COUNT -- one fewer item WH_K for player WH_P (not below 0).
; Trashes A, X.
WS_COUNT
        LDA WH_P        ; COUNT + 10 x player + item
        ASL A
        STA WS_N
        ASL A
        ASL A
        CLC
        ADC WS_N
        ADC WH_K
        TAX
        LDA COUNT,X
        BEQ WC_DONE
        DEC COUNT,X
WC_DONE RTS

; ---------------------------------------------------------------------
;  WTH_BOAT -- hurricane in slot X sinks any steered boat or pirate it
;  touches: the 16 x 32 hurricane and the 8 x 8 box overlap.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
WTH_BOAT
        STX WH_I
        LDX #1
WB_PL   STX WH_P
        LDA BOATK,X
        BEQ WB_NEXT
        STA WH_K
        LDY WH_I
        LDA CURX,X      ; overlap if 0 < CURX + 16 - WXH < 24
        CLC
        ADC #16-1
        SEC
        SBC WXH,Y
        CMP #23
        BCS WB_NEXT
        LDA CURY,X      ; and 0 < CURY + 16 - WYH < 40
        CLC
        ADC #16-1
        SEC
        SBC WYH,Y
        CMP #39
        BCS WB_NEXT
        JSR BOAT_LOSE   ; sunk
WB_NEXT LDX WH_P
        DEX
        BPL WB_PL
        LDX #3          ; pirates (slots 2, 3)
WB_PIR  STX WH_P
        LDA FACT,X
        BEQ WB_PNXT
        LDY WH_I
        LDA FXH,X       ; as above, with FXH - 8 for CURX
        CLC
        ADC #16-8-1
        SEC
        SBC WXH,Y
        CMP #23
        BCS WB_PNXT
        LDA FYH,X
        CLC
        ADC #16-8-1
        SEC
        SBC WYH,Y
        CMP #39
        BCS WB_PNXT
        LDA #0          ; sunk: gone
        STA FACT,X
        LDA #NW_PSNK
        JSR NEWSG
        JSR SND_SINK
WB_PNXT LDX WH_P
        DEX
        CPX #2
        BCS WB_PIR
        RTS

; ---------------------------------------------------------------------
;  WTH_SHOW -- draw the weather in player 2 memory, fill HP2ROW, WCROW
;  (every frame).  Objects sharing a map row take turns (D14).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
WTH_SHOW
        LDA WACT        ; which to show: both, unless they share a row
        STA WS_V
        LDA WACT+1
        STA WS_V+1
        BEQ WW_ERA
        LDA WACT
        BEQ WW_ERA
        LDX #0
        JSR WW_ROWS
        STA WS_A1       ; slot 0: rows WW_R0..A
        LDA WW_R0
        STA WS_A0
        LDX #1
        JSR WW_ROWS     ; slot 1: WW_R0..A
        CMP WS_A0
        BCC WW_ERA      ; 1 ends above 0
        LDA WS_A1
        CMP WW_R0
        BCC WW_ERA      ; 0 ends above 1
        LDA FRAME       ; shared rows: take turns
        AND #1
        TAX
        LDA #0
        STA WS_V,X
WW_ERA  LDX #1          ; erase both where they were
WW_E1   LDA WDRAWN,X
        CMP #$FF
        BEQ WW_E3
        TAY
        LDA WDH,X
        STA WS_N
        LDA #0
WW_E2   STA PM_P2,Y
        INY
        BMI WW_E2D      ; past player 2's memory
        DEC WS_N
        BNE WW_E2
WW_E2D  LDA #$FF
        STA WDRAWN,X
WW_E3   DEX
        BPL WW_E1
        LDA #0          ; no positions until set below; WCROW keeps its
        LDX #MAPROWS-1  ; colours, so the row above an object still has
WW_HP   STA HP2ROW,X  ; its colour when the DLI is late to set it
        DEX
        BPL WW_HP
        LDX #1
WW_ONE  STX WS_I
        LDA WS_V,X
        BNE WW_SHOW
        JMP WW_NEXT
WW_SHOW TAY             ; shape: WSHAPE[type] + frame x height
        LDA WDRH,Y
        STA WDH,X
        STA WS_N
        LDA WSH_LO,Y
        STA SPTR
        LDA WSH_HI,Y
        STA SPTR+1
        LDA WANIM       ; frame: WANIM 0-3, 4-7 again, except a
        CMP #W_BOLT     ; storm's lightning (frame 4) at W_BOLT
        BNE WW_F03
        CPY #WT_STRM
        BNE WW_F03
        LDA #4
        BNE WW_F4
WW_F03  AND #3
WW_F4   LDY WDH,X
        CMP #0
WW_FRM  BEQ WW_LINE     ; + frame x height
        PHA
        TYA
        CLC
        ADC SPTR
        STA SPTR
        BCC WW_FR1
        INC SPTR+1
WW_FR1  PLA
        SEC
        SBC #1
        JMP WW_FRM
WW_LINE LDY WACT,X      ; P/M line: WYH - 8 + PM_MAP - WTOP
        LDA WYH,X
        CLC
        ADC #PM_TOP
        SEC
        SBC WTOP,Y
        STA WDRAWN,X
        TAX
        LDY #0
WW_PUT  LDA (SPTR),Y
        STA PM_P2,X
        INX
        BMI WW_PUTD     ; past player 2's memory
        INY
        DEC WS_N
        BNE WW_PUT
WW_PUTD LDX WS_I        ; its rows get its horizontal position
        JSR WW_ROWS
        STA WS_A1
        LDY WACT,X      ; its colour; a storm lights up with its
        LDA WCOL,Y      ; lightning
        CPY #WT_STRM
        BNE WW_COL
        LDY WANIM
        CPY #W_BOLT
        BNE WW_COL
        LDA #C_FLASH
WW_COL  STA WS_N
        LDA WXH,X       ; WXH - 8 + HP_MAP
        CLC
        ADC #HP_MAP-8
        LDY WW_R0
WW_ROW  STA HP2ROW,Y
        PHA
        LDA WS_N
        STA WCROW,Y
        PLA
        CPY WS_A1
        BCS WW_NEXT
        INY
        BNE WW_ROW
WW_NEXT LDX WS_I
        DEX
        BMI WW_DONE
        JMP WW_ONE
WW_DONE RTS

; WW_ROWS -- map rows slot X's shape covers: WW_R0..A, held to
; 0..10.  X kept; trashes A, Y.
WW_ROWS LDY WACT,X      ; first: ((WYH - WTOP) >> 3) - 1, at least 0
        LDA WYH,X
        SEC
        SBC WTOP,Y
        BCS WR_POS
        LDA #0          ; above the top of P/M line 0's row
WR_POS  LSR A
        LSR A
        LSR A
        BEQ WR_TOP
        SEC
        SBC #1
        CMP #MAPROWS
        BCC WR_TOP
        LDA #MAPROWS-1  ; below the map: row 10 (nothing shows there)
WR_TOP  STA WW_R0
        LDY WACT,X      ; last: ((WYH - WTOP + height - 1) >> 3) - 1,
        LDA WYH,X       ; at most 10
        CLC
        ADC WDRH,Y
        SEC
        SBC WTOP,Y
        SEC
        SBC #1
        LSR A
        LSR A
        LSR A
        SEC
        SBC #1
        BCS WR_LO
        LDA #0
WR_LO   CMP #MAPROWS
        BCC WR_DONE
        LDA #MAPROWS-1
WR_DONE RTS

; Per type (none, rain, storm, hurricane)
WHGT    .BYTE 0,8,8,32          ; height in lines (the original's)
WDRH    .BYTE 0,16,16,32        ; height drawn: clouds tower above it
WTOP    .BYTE 0,8,8,0           ; lines drawn above WYH - 8
WHALF   .BYTE 0,4,4,16          ; half the height: the centre
WRATE   .BYTE 0,0,1,5           ; damage per tic (the original's DMG_RT)
WCOL    .BYTE 0,C_RAIN,C_STRM,C_HURR ; colour (COLPM2)
WSH_LO  .BYTE 0,<WSH_RAIN,<WSH_STRM,<WSH_HURR
WSH_HI  .BYTE 0,>WSH_RAIN,>WSH_STRM,>WSH_HURR

; Speed steps, speeds -15..+15: 38/256 pixel per tic for each unit,
; 3/4 of the original's 51/256 (D43), as 8.8 fixed point
WV_LO   .BYTE $C6,$EC,$12,$38,$5E,$84,$AA,$D0,$F6,$1C,$42,$68,$8E,$B4,$DA,$00
        .BYTE $26,$4C,$72,$98,$BE,$E4,$0A,$30,$56,$7C,$A2,$C8,$EE,$14,$3A
WV_HI   .BYTE $FD,$FD,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FF,$FF,$FF,$FF,$FF,$FF,$00
        .BYTE $00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$02,$02

; Shapes, a byte per line, 8 pixels of 2 colour clocks (D52).  Rain
; and storms are drawn 16 lines tall, WTOP above their 8-line box (the
; cloud), so the rain falls on the square they damage; storms have a
; fifth frame, their lightning.

WSH_RAIN
; rain, frame 0: the drops fall 2 lines a frame
        .BYTE $18   ;    XX
        .BYTE $3C   ;   XXXX
        .BYTE $7E   ;  XXXXXX
        .BYTE $DE   ; XX XXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $7E   ;  XXXXXX
        .BYTE $40   ;  X
        .BYTE $40   ;  X
        .BYTE $04   ;      X
        .BYTE $24   ;   X  X
        .BYTE $20   ;   X
        .BYTE $10   ;    X
        .BYTE $10   ;    X
        .BYTE $02   ;       X
        .BYTE $02   ;       X
; frame 1
        .BYTE $18   ;    XX
        .BYTE $3C   ;   XXXX
        .BYTE $7E   ;  XXXXXX
        .BYTE $DE   ; XX XXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $7E   ;  XXXXXX
        .BYTE $02   ;       X
        .BYTE $02   ;       X
        .BYTE $40   ;  X
        .BYTE $40   ;  X
        .BYTE $04   ;      X
        .BYTE $24   ;   X  X
        .BYTE $20   ;   X
        .BYTE $10   ;    X
        .BYTE $10   ;    X
; frame 2
        .BYTE $18   ;    XX
        .BYTE $3C   ;   XXXX
        .BYTE $7E   ;  XXXXXX
        .BYTE $DE   ; XX XXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $7E   ;  XXXXXX
        .BYTE $10   ;    X
        .BYTE $10   ;    X
        .BYTE $02   ;       X
        .BYTE $02   ;       X
        .BYTE $40   ;  X
        .BYTE $40   ;  X
        .BYTE $04   ;      X
        .BYTE $24   ;   X  X
        .BYTE $20   ;   X
; frame 3
        .BYTE $18   ;    XX
        .BYTE $3C   ;   XXXX
        .BYTE $7E   ;  XXXXXX
        .BYTE $DE   ; XX XXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $7E   ;  XXXXXX
        .BYTE $20   ;   X
        .BYTE $20   ;   X
        .BYTE $10   ;    X
        .BYTE $10   ;    X
        .BYTE $02   ;       X
        .BYTE $02   ;       X
        .BYTE $40   ;  X
        .BYTE $40   ;  X
        .BYTE $04   ;      X

WSH_STRM
; storm, frame 0: rain driven by the wind
        .BYTE $36   ;   XX XX
        .BYTE $7F   ;  XXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $DB   ; XX XX XX
        .BYTE $49   ;  X  X  X
        .BYTE $80   ; X
        .BYTE $10   ;    X
        .BYTE $22   ;   X   X
        .BYTE $44   ;  X   X
        .BYTE $88   ; X   X
        .BYTE $11   ;    X   X
        .BYTE $02   ;       X
        .BYTE $40   ;  X
        .BYTE $80   ; X
; frame 1
        .BYTE $36   ;   XX XX
        .BYTE $7F   ;  XXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $DB   ; XX XX XX
        .BYTE $49   ;  X  X  X
        .BYTE $22   ;   X   X
        .BYTE $44   ;  X   X
        .BYTE $08   ;     X
        .BYTE $01   ;        X
        .BYTE $20   ;   X
        .BYTE $44   ;  X   X
        .BYTE $88   ; X   X
        .BYTE $11   ;    X   X
        .BYTE $22   ;   X   X
; frame 2
        .BYTE $36   ;   XX XX
        .BYTE $7F   ;  XXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $DB   ; XX XX XX
        .BYTE $49   ;  X  X  X
        .BYTE $80   ; X
        .BYTE $10   ;    X
        .BYTE $22   ;   X   X
        .BYTE $44   ;  X   X
        .BYTE $88   ; X   X
        .BYTE $11   ;    X   X
        .BYTE $02   ;       X
        .BYTE $40   ;  X
        .BYTE $80   ; X
; frame 3
        .BYTE $36   ;   XX XX
        .BYTE $7F   ;  XXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $DB   ; XX XX XX
        .BYTE $49   ;  X  X  X
        .BYTE $22   ;   X   X
        .BYTE $44   ;  X   X
        .BYTE $08   ;     X
        .BYTE $01   ;        X
        .BYTE $20   ;   X
        .BYTE $44   ;  X   X
        .BYTE $88   ; X   X
        .BYTE $11   ;    X   X
        .BYTE $22   ;   X   X
; frame 4: lightning (WANIM = W_BOLT)
        .BYTE $36   ;   XX XX
        .BYTE $7F   ;  XXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $FF   ; XXXXXXXX
        .BYTE $DB   ; XX XX XX
        .BYTE $49   ;  X  X  X
        .BYTE $10   ;    X
        .BYTE $30   ;   XX
        .BYTE $20   ;   X
        .BYTE $30   ;   XX
        .BYTE $10   ;    X
        .BYTE $08   ;     X
        .BYTE $10   ;    X
        .BYTE $00   ; 
        .BYTE $00   ; 

WSH_HURR
; hurricane, frame 0: two arms round the eye, turning
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $20   ;   X
        .BYTE $70   ;  XXX
        .BYTE $78   ;  XXXX
        .BYTE $C8   ; XX  X
        .BYTE $CC   ; XX  XX
        .BYTE $8C   ; X   XX
        .BYTE $9C   ; X  XXX
        .BYTE $BC   ; X XXXX
        .BYTE $A4   ; X X  X
        .BYTE $A4   ; X X  X
        .BYTE $25   ;   X  X X
        .BYTE $25   ;   X  X X
        .BYTE $3D   ;   XXXX X
        .BYTE $3D   ;   XXXX X
        .BYTE $31   ;   XX   X
        .BYTE $33   ;   XX  XX
        .BYTE $13   ;    X  XX
        .BYTE $1E   ;    XXXX
        .BYTE $0E   ;     XXX
        .BYTE $04   ;      X
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
; frame 1: an eighth of a turn on
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $70   ;  XXX
        .BYTE $78   ;  XXXX
        .BYTE $08   ;     X
        .BYTE $0C   ;     XX
        .BYTE $04   ;      X
        .BYTE $04   ;      X
        .BYTE $06   ;      XX
        .BYTE $06   ;      XX
        .BYTE $1E   ;    XXXX
        .BYTE $3E   ;   XXXXX
        .BYTE $66   ;  XX  XX
        .BYTE $66   ;  XX  XX
        .BYTE $66   ;  XX  XX
        .BYTE $66   ;  XX  XX
        .BYTE $7C   ;  XXXXX
        .BYTE $7C   ;  XXXXX
        .BYTE $60   ;  XX
        .BYTE $60   ;  XX
        .BYTE $20   ;   X
        .BYTE $20   ;   X
        .BYTE $30   ;   XX
        .BYTE $30   ;   XX
        .BYTE $1E   ;    XXXX
        .BYTE $0E   ;     XXX
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
; frame 2: an eighth of a turn on
        .BYTE $00   ; 
        .BYTE $08   ;     X
        .BYTE $08   ;     X
        .BYTE $0C   ;     XX
        .BYTE $04   ;      X
        .BYTE $04   ;      X
        .BYTE $06   ;      XX
        .BYTE $02   ;       X
        .BYTE $02   ;       X
        .BYTE $02   ;       X
        .BYTE $02   ;       X
        .BYTE $32   ;   XX  X
        .BYTE $7A   ;  XXXX X
        .BYTE $7E   ;  XXXXXX
        .BYTE $66   ;  XX  XX
        .BYTE $66   ;  XX  XX
        .BYTE $66   ;  XX  XX
        .BYTE $66   ;  XX  XX
        .BYTE $7E   ;  XXXXXX
        .BYTE $7E   ;  XXXXXX
        .BYTE $4C   ;  X  XX
        .BYTE $40   ;  X
        .BYTE $40   ;  X
        .BYTE $40   ;  X
        .BYTE $40   ;  X
        .BYTE $60   ;  XX
        .BYTE $20   ;   X
        .BYTE $20   ;   X
        .BYTE $30   ;   XX
        .BYTE $10   ;    X
        .BYTE $10   ;    X
        .BYTE $00   ; 
; frame 3: an eighth of a turn on
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $02   ;       X
        .BYTE $03   ;       XX
        .BYTE $03   ;       XX
        .BYTE $31   ;   XX   X
        .BYTE $79   ;  XXXX  X
        .BYTE $59   ;  X XX  X
        .BYTE $5D   ;  X XXX X
        .BYTE $FD   ; XXXXXX X
        .BYTE $E5   ; XXX  X X
        .BYTE $E7   ; XXX  XXX
        .BYTE $A7   ; X X  XXX
        .BYTE $A7   ; X X  XXX
        .BYTE $BF   ; X XXXXXX
        .BYTE $BE   ; X XXXXX
        .BYTE $9A   ; X  XX X
        .BYTE $9E   ; X  XXXX
        .BYTE $8C   ; X   XX
        .BYTE $C0   ; XX
        .BYTE $C0   ; XX
        .BYTE $40   ;  X
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
        .BYTE $00   ; 
