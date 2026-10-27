; =====================================================================
;  NEWS.ASM -- status line 2 during play (T-SCR-4, D44)
;
;  Line 2 shows each player's population at their end, under their
;  gold (drawn by STAT_DRAW), and a 20-character news slot in the
;  middle.  Game code calls NEWS where something happens (a hurricane,
;  a boat sunk, storm damage, rebels, a refused key); the
;  message is centred in the slot, prefixed "P1 ", "P2 " or, for the
;  CPU in a 1-player game, "CPU ", and cleared NW_TICS tics later.
;
;  A message only replaces one still showing if its priority (NWPRI)
;  is no lower, so a refusal never hides a sunk boat.  Refusals go
;  through NEWS_REF, which says nothing for the CPU.
;
;  Pirates and tropical storms appearing are not news: they come every
;  few seconds and are plain to see, so the slot would hardly ever show
;  anything else.
;
;  The original has no such line; this is Acadia's own (D44).
; =====================================================================

NW_COL  =  50           ; status offset of the slot (line 2, column 10)
NW_LEN  =  20           ; slot width
NW_TICS =  60           ; a message shows 60 tics = 3 s

; message numbers (the refusals match ECO_BUY's R_ reasons)
NW_HURR =  0            ; a hurricane appears
NW_PSNK =  1            ; a hurricane sank a pirate
NW_LAND =  2            ; R_LAND: not the player's land
NW_TAKN =  3            ; R_TAKEN: something stands there
NW_GOLD =  4            ; R_GOLD: not enough gold
NW_SINK =  5            ; a player's boat sunk
NW_DMG  =  6            ; weather destroyed an item
NW_REBL =  7            ; rebels on a player's island
NW_NOBT =  8            ; key 0: no own boat under the cursor
NW_NOPK =  9            ; key 0: the boat can't park here

; ---------------------------------------------------------------------
;  NEWS -- show message A for player X (0, 1; $FF: no player).
;  Keeps A, X and Y.
; ---------------------------------------------------------------------
NEWS    STA NW_SA
        STX NW_P
        STY NW_SY
        TAY
        LDA NW_T        ; one still showing with a higher priority?
        BEQ NS_SHOW
        LDA NWPRI,Y
        CMP NW_PR
        BCC NS_DONE
NS_SHOW LDA NWPRI,Y
        STA NW_PR
        LDA #NW_TICS
        STA NW_T
        JSR NW_CLR
        LDA NWLO,Y      ; length: prefix + message
        LDX NWHI,Y
        JSR NW_SLEN
        STA NW_N
        LDX NW_P
        BMI NS_CTR      ; no player: no prefix
        JSR NW_PFX
        LDX NWHI,Y
        JSR NW_SLEN
        CLC
        ADC NW_N
        STA NW_N
NS_CTR  LDA #NW_LEN     ; centred: NW_COL + (NW_LEN - length) / 2
        SEC
        SBC NW_N
        LSR A
        CLC
        ADC #NW_COL
        TAX
        LDY NW_P
        BMI NS_MSG
        STX NW_N        ; the prefix first
        LDX NW_P
        JSR NW_PFX
        PHA
        LDA NWHI,Y
        TAY
        PLA
        LDX NW_N
        JSR TXT_STR
NS_MSG  LDY NW_SA
        LDA NWLO,Y
        PHA
        LDA NWHI,Y
        TAY
        PLA
        JSR TXT_STR
NS_DONE LDA NW_SA
        LDX NW_P
        LDY NW_SY
        RTS

; NW_PFX -- prefix for player X: A = low byte, Y = its index in NWLO /
; NWHI.  Trashes A, Y.
NW_PFX  LDY #NW_TP1
        CPX #0
        BEQ NP_DONE
        LDY #NW_TP2
        JSR AI_ON       ; player 2 is the CPU in a 1-player game
        BEQ NP_DONE
        LDY #NW_TCPU
NP_DONE LDA NWLO,Y
        RTS

; NW_SLEN -- A = length of the string at A (low) / X (high).
; Trashes X, TPTR; keeps Y.
NW_SLEN STA TPTR
        STX TPTR+1
        STY NW_SY2
        LDY #0
NL_LOOP LDA (TPTR),Y
        CMP #TX_END
        BEQ NL_DONE
        INY
        BNE NL_LOOP
NL_DONE TYA
        LDY NW_SY2
        RTS

; NW_CLR -- blank the news slot.  Trashes A, X.
NW_CLR  LDA #0
        LDX #NW_LEN-1
NC_LOOP STA STATUS1+NW_COL,X
        DEX
        BPL NC_LOOP
        RTS

; ---------------------------------------------------------------------
;  NEWS_REF -- NEWS for a refused key of player X, unless X is the CPU.
;  Keeps A, X and Y.
; ---------------------------------------------------------------------
NEWS_REF
        CPX #1
        BEQ NR_P2
        JMP NEWS
NR_P2   PHA
        JSR AI_ON
        BNE NR_CPU
        PLA
        JMP NEWS
NR_CPU  PLA
        RTS

; ---------------------------------------------------------------------
;  NEWSG -- NEWS for no player.  Keeps A, X and Y.
; ---------------------------------------------------------------------
NEWSG   STX NW_GX
        LDX #$FF
        JSR NEWS
        LDX NW_GX
        RTS

; ---------------------------------------------------------------------
;  NEWS_TIC -- each tic: clear the message when its time is up.
;  Trashes A, X.
; ---------------------------------------------------------------------
NEWS_TIC
        LDA NW_T
        BEQ NT_DONE
        DEC NW_T
        BNE NT_DONE
        JMP NW_CLR
NT_DONE RTS

; NEWS_OFF -- no message: slot blank, timer stopped.  Trashes A, X.
NEWS_OFF
        LDA #0
        STA NW_T
        JMP NW_CLR

; ---------------------------------------------------------------------
;  The messages: priority, then the strings (screen codes) by number,
;  then the prefixes.
; ---------------------------------------------------------------------
NWPRI   .BYTE 2,2,1,1,1,3,3,3,1,1

NW_TP1  =  10           ; prefix indices, after the messages
NW_TP2  =  11
NW_TCPU =  12

NWLO    .BYTE <NT_HURR,<NT_PSNK,<NT_LAND,<NT_TAKN,<NT_GOLD
        .BYTE <NT_SINK,<NT_DMG,<NT_REBL,<NT_NOBT,<NT_NOPK
        .BYTE <NT_P1,<NT_P2,<NT_CPU
NWHI    .BYTE >NT_HURR,>NT_PSNK,>NT_LAND,>NT_TAKN,>NT_GOLD
        .BYTE >NT_SINK,>NT_DMG,>NT_REBL,>NT_NOBT,>NT_NOPK
        .BYTE >NT_P1,>NT_P2,>NT_CPU

NT_LAND .SBYTE "NOT YOUR LAND"
        .BYTE TX_END
NT_TAKN .SBYTE "SQUARE TAKEN"
        .BYTE TX_END
NT_GOLD .SBYTE "NOT ENOUGH GOLD"
        .BYTE TX_END
NT_HURR .SBYTE "HURRICANE!"
        .BYTE TX_END
NT_SINK .SBYTE "BOAT SUNK"
        .BYTE TX_END
NT_PSNK .SBYTE "PIRATE SUNK"
        .BYTE TX_END
NT_DMG  .SBYTE "STORM DAMAGE"
        .BYTE TX_END
NT_REBL .SBYTE "REBELS!"
        .BYTE TX_END
NT_NOBT .SBYTE "NO BOAT HERE"
        .BYTE TX_END
NT_NOPK .SBYTE "NO PARKING HERE"
        .BYTE TX_END
NT_P1   .SBYTE "P1 "
        .BYTE TX_END
NT_P2   .SBYTE "P2 "
        .BYTE TX_END
NT_CPU  .SBYTE "CPU "
        .BYTE TX_END
