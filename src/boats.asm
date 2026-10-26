; =====================================================================
;  BOATS.ASM -- picking up, steering and parking boats (T-EVT-1:
;  R-RULE-6, R-CTL-3; the original's $5774-$5875, $5320-$53CD)
;
;  Boats are bought into the harbour (ECONOMY.ASM) and stand there as
;  map items.  Key 0 (KEYPL's player, D17) toggles, as the original:
;    cursor mode: the player's own boat on the square under the
;      cursor is lifted off the map; the cursor sprite becomes that
;      boat and the stick now steers it.  No own boat there: refused.
;    boat mode:   the boat is parked on the square under its centre,
;      which must be sea (or harbour or rock) with nothing on it;
;      the sprite becomes the cursor again.  Else refused.
;  A steered boat moves BOAT_NUM/BOAT_DEN of the cursor's speed (the
;  original: 10 against 15), in 8 directions, and stops dead when the
;  stick is let go.  It stays on the map and never touches land: an
;  axis whose next step would put any part of the boat on a land
;  square does not move.  Parked boats don't block it.
;  The boat's position is the player's CURX / CURY.
; =====================================================================

BOAT_NUM = 2            ; boat moves on 2 frames out of 3
BOAT_DEN = 3

; ---------------------------------------------------------------------
;  BOAT_KEY -- key 0 for player X: pick up or park a boat
;  Out: C clear: done; C set: refused (refusal sound played).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
BOAT_KEY
        STX BK_P
        LDY CURROW,X
        LDA CURCOL,X
        TAX
        JSR MAP_GET     ; A = item under the cursor / boat centre
        STA BK_ITEM
        LDX BK_P
        LDA BOATK,X
        BNE BK_PARK
        LDA BK_ITEM     ; pick up: must be this player's boat
        BEQ BK_NO
        AND #I_ITEM
        CMP #I_PTBT
        BCC BK_NO       ; not a boat
        STA BOATK,X
        LDA BK_ITEM     ; owner: I_P1 -> 1
        ASL A
        LDA #0
        ROL A
        CMP BK_P
        BEQ BK_LIFT
        LDA #0          ; the other player's boat
        STA BOATK,X
        BEQ BK_NO
BK_LIFT LDY CURROW,X    ; off the map: terrain (sea or pier) again
        LDA CURCOL,X
        TAX
        LDA #0
        JSR MAP_SET
        LDX BK_P
        LDA BOATK,X     ; the sprite becomes the boat
        SEC
        SBC #I_PTBT-SH_PT
        JSR SPR_SHAPE
        CLC
        RTS
BK_PARK LDA BK_ITEM     ; park: nothing on the square
        BNE BK_NO
        LDA MKIND       ; and it must not be land
        AND #K_KIND
        CMP #K_LAND
        BEQ BK_NO
        LDA BOATK,X     ; boat item, with I_P1 for player 2
        CPX #0
        BEQ BK_PUT
        ORA #I_P1
BK_PUT  LDY CURROW,X
        PHA
        LDA CURCOL,X
        TAX
        PLA
        JSR MAP_SET
        LDX BK_P
        LDA #0          ; cursor mode again
        STA BOATK,X
        LDA #SH_CUR
        JSR SPR_SHAPE
        CLC
        RTS
BK_NO   JSR SND_REFUSE
        SEC
        RTS

; ---------------------------------------------------------------------
;  BOAT_MOVE -- steer player X's boat one frame by stick bits A
;  Ends in CU_SHOW (CURCOL / CURROW, sprite).  Trashes A, X, Y.
; ---------------------------------------------------------------------
BOAT_MOVE
        STA CUJOY
        STX BM_P
        INC BOATPH,X    ; move on BOAT_NUM frames of BOAT_DEN
        LDA BOATPH,X
        CMP #BOAT_DEN
        BCC BM_PH
        LDA #0
        STA BOATPH,X
BM_PH   CMP #BOAT_DEN-BOAT_NUM
        BCC BM_SHOW
        LDA CUJOY       ; horizontal
        AND #J_LEFT+J_RIGHT
        CMP #J_LEFT
        BEQ BM_LEFT
        CMP #J_RIGHT
        BNE BM_VERT
        LDA CURX,X
        CMP #CUR_MAXX
        BCS BM_VERT
        ADC #1          ; carry clear
        BNE BM_TRYX     ; always (CURX < 152)
BM_LEFT LDA CURX,X
        BEQ BM_VERT
        SEC
        SBC #1
BM_TRYX STA BM_X
        LDY CURY,X
        JSR BM_FREE
        LDX BM_P
        BCS BM_VERT     ; land in the way
        LDA BM_X
        STA CURX,X
BM_VERT LDA CUJOY       ; vertical
        AND #J_UP+J_DOWN
        CMP #J_UP
        BEQ BM_UP
        CMP #J_DOWN
        BNE BM_SHOW
        LDA CURY,X
        CMP #CUR_MAXY
        BCS BM_SHOW
        ADC #1          ; carry clear
        BNE BM_TRYY     ; always
BM_UP   LDA CURY,X
        BEQ BM_SHOW
        SEC
        SBC #1
BM_TRYY STA BM_Y
        TAY
        LDA CURX,X
        JSR BM_FREE
        LDX BM_P
        BCS BM_SHOW
        LDA BM_Y
        STA CURY,X
BM_SHOW LDX BM_P
        JMP CU_SHOW

; ---------------------------------------------------------------------
;  BM_FREE -- can a boat stand at map pixel A (column), Y (line)?
;  Checks the up to 4 squares its 8 x 8 box covers for land.
;  Out: C clear if free, C set if any is land.  Trashes A, X, Y.
; ---------------------------------------------------------------------
BM_FREE STY BM_T
        PHA
        LSR A           ; first and last column covered
        LSR A
        LSR A
        STA BM_C0
        PLA
        CLC
        ADC #7
        LSR A
        LSR A
        LSR A
        STA BM_C1
        TYA             ; first and last row covered
        LSR A
        LSR A
        LSR A
        STA BM_R0
        LDA BM_T
        CLC
        ADC #7
        LSR A
        LSR A
        LSR A
        STA BM_R1
        LDX BM_C0
        LDY BM_R0
        JSR BM_LAND
        BCS BF_DONE
        LDX BM_C1
        JSR BM_LAND
        BCS BF_DONE
        LDY BM_R1
        JSR BM_LAND
        BCS BF_DONE
        LDX BM_C0
        ; fall through

; BM_LAND -- C set if square X, Y is land.  X, Y kept; trashes A.
BM_LAND JSR MAP_GET
        LDA MKIND
        AND #K_KIND
        CMP #K_LAND
        BEQ BL_YES
        CLC
BF_DONE RTS
BL_YES  SEC
        RTS

; ---------------------------------------------------------------------
;  BOAT_LOSE -- player X's steered boat sinks (weather, pirates, a PT
;  boat): one fewer of its kind, the sprite is the cursor again, and
;  the sinking sound.  Trashes A, X, Y, WH_P, WH_K.
; ---------------------------------------------------------------------
BOAT_LOSE
        STX WH_P
        LDA BOATK,X
        STA WH_K
        JSR WS_COUNT    ; one fewer boat
        LDX WH_P
        LDA #0          ; back to the cursor
        STA BOATK,X
        LDA #SH_CUR
        JSR SPR_SHAPE
        JMP SND_SINK
