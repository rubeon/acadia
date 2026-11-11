; =====================================================================
;  SANDBOX2.ASM -- the SANDBOX map's island and setup lines (T-MODE-1,
;  D87): the part of it that SANDBOX.ASM has no room for, after the
;  stats summary page in the pause font's block on both machines.
;    SB_MAPG  MAP_LOAD's last step: RANDOM's islands (RM_GEN) or
;             SANDBOX's (SB_GEN)
;    SB_GEN   SANDBOX's island on RANDOM's open sea
;    SU_OK    can the setup screen's line X be chosen?
;    SB_SYP   the stats summary page's players: in SANDBOX player 1's
;             numbers only, and player 2's pawns blank
; =====================================================================

; ---------------------------------------------------------------------
;  SB_MAPG -- after MAP_LOAD has copied map MAPLD's block: RANDOM's new
;  pair or SANDBOX's island drawn on its sea.  Trashes A, X, Y, ZPTR.
; ---------------------------------------------------------------------
SB_MAPG LDA MAPLD
        CMP #MAP_RND
        BNE SQ_MSBX
        JMP RM_GEN
SQ_MSBX CMP #MAP_SBX
        BEQ SB_GEN
        RTS

; ---------------------------------------------------------------------
;  SB_GEN -- SANDBOX (D87): its island on the open sea of the live
;  tables (RANDOM's block): land where SBLAND has a bit, player 0's;
;  its harbour, then the land squares' tiles as RANDOM's.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
SB_GEN  LDY #0          ; square SB_SQ0 + Y
        LDX #0          ; SBLAND byte
SG_BYTE LDA SBLAND,X
        STA RM_K
        LDA #8
        STA RM_I        ; bits left in it
SG_BIT  ASL RM_K
        BCC SG_SEA
        LDA #K_LAND
        STA ISLKIND+SB_SQ0,Y
SG_SEA  INY
        CPY #SB_NSQ
        BEQ SG_HARB
        DEC RM_I
        BNE SG_BIT
        INX
        BNE SG_BYTE     ; always
SG_HARB LDA #K_HARB
        STA ISLKIND+SB_HSQ
        LDA #SB_HTL
        STA ISLTILE+SB_HSQ
        JMP RM_TILES


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
;  SB_SYP -- (SY_DRAW, its names drawn) X = the last player, as SB_LSTP;
;  in SANDBOX (X = 0) also player 2's pawns blank in the page's three
;  headings (BUILT, GOLD FROM, BOATS LOST: SYTXT).  Trashes A, Y.
; ---------------------------------------------------------------------
SB_SYP  JSR SB_LSTP
        TXA
        BNE SQ_YRTS     ; 2 players: X = 1
        LDY #SB_NPW-1   ; A = 0: blank
SQ_YPW  LDX SBPWO,Y
        STA SYSCR,X
        DEY
        BPL SQ_YPW
        TAX             ; X = 0 again
SQ_YRTS RTS

SBPWO   .BYTE 15,16,38,39   ; line 0: BUILT's, GOLD FROM's player 2 pawn
        .BYTE 238,239       ; line 5 (5 x 40 + 38): BOATS LOST's
SB_NPW  =  6
