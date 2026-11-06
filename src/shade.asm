; =====================================================================
;  SHADE.ASM -- per-row sea and grass shading, moving waves (D51)
; =====================================================================

; ---------------------------------------------------------------------
;  VD_SHADE -- ROWBK / ROWPF0: the sea and grass colours of each
;  character row (D51): MAPPAL's, luminance + SEADEL / GRNDEL (kept
;  0-14), attract mode applied.  In the corner rows (GRNDEL = GR_SEA,
;  D55) PF0 is the dark corner sea instead of grass (D67).  Notes what
;  it was built from in AP_SH, AP_MSK, AP_BK, AP_GR.  Trashes A, X, Y.
; ---------------------------------------------------------------------
VD_SHADE
        LDA COLRSH
        STA AP_SH
        LDA DRKMSK
        STA AP_MSK
        LDA MAPPAL
        STA AP_BK
        LDA MAPPAL+1
        STA AP_GR
        LDX #MAPCROWS-1
VS_ROW  LDA MAPPAL      ; sea
        LDY SEADEL,X
        JSR VS_LUM
        STA ROWBK,X
        LDA MAPPAL+1    ; grass
        LDY GRNDEL,X
        CPY #GR_SEA
        BNE VS_GR
        LDA MAPPAL      ; a corner row: PF0 is the dark corners'
        LDY #0          ; sea, MAPPAL's (D55, D67)
VS_GR   JSR VS_LUM
        STA ROWPF0,X
        DEX
        BPL VS_ROW
        LDA PB_ON       ; the pause band's rows (PAUSE.ASM, D69): black,
        BEQ VS_RTS      ; PF0 the text's white
        LDA #C_PBK
        EOR COLRSH
        AND DRKMSK
        STA ROWBK+PB_ROW
        STA ROWBK+PB_ROW+1
        STA ROWBK+PB_ROW+2
        LDA #C_PTX
        EOR COLRSH
        AND DRKMSK
        STA ROWPF0+PB_ROW
        STA ROWPF0+PB_ROW+1
        STA ROWPF0+PB_ROW+2
VS_RTS  RTS

; VS_LUM -- colour A with luminance + Y (signed), kept 0-14, attract
; mode applied.  Keeps X.
VS_LUM  STA VS_C
        STY VS_D
        AND #$0F
        CLC
        ADC VS_D
        BPL VL_POS
        LDA #0          ; below black: black
VL_POS  CMP #$0F
        BCC VL_OK
        LDA #$0E        ; above white: white
VL_OK   AND #$0E
        STA VS_D
        LDA VS_C
        AND #$F0        ; hue
        ORA VS_D
        EOR COLRSH
        AND DRKMSK
        RTS

; Luminance change per character row.  The sea, COLBK, is the light
; blue (MAPPAL + SEA_LT) everywhere.  The top and bottom 3 rows (D55)
; hold no land, so their PF0 (GRNDEL = GR_SEA) is MAPPAL's darker blue
; for the rounded corners; the corners were COLBK and the sea PF0
; until D67, which hid the pirates (the fifth player, under PF0) there.
; The grass is lit from the north.  Every band starts on an odd
; (mid-square) row, where DLI_ROW sets the shades first (D52)
SEA_LT  =  2            ; the light sea: MAPPAL's sea, 2 lighter
GR_SEA  =  $80          ; GRNDEL: PF0 is the dark corner sea
SEADEL  .BYTE 2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
GRNDEL  .BYTE GR_SEA,GR_SEA,GR_SEA,2,2,2,2,0,0,0,0,0,0,0,0,$FE,$FE,$FE,$FE
        .BYTE GR_SEA,GR_SEA,GR_SEA

; DLI_END -- the map's last line ends: below it the background is the
; dark corner sea (row 0's PF0), as the corners run into it (D55);
; COLBK in the map is the light sea since D67
; Row 21 is wide, so WSYNC first (D67): with work before it, the DLI
; missed the line's end and left one light line below the corners.
; Nothing is drawn below the map, so the width can come after COLBK.
DLI_END STA WSYNC
        PHA
        LDA ROWPF0
        STA COLBK
        LDA #DMA_N      ; and the normal width again (D67)
        STA DMACTL
        LDA #<DLI_ST    ; the next frame's first DLI, in case the
        STA VDSLST      ; deferred VBI is late or skipped (D69)
        LDA #>DLI_ST
        STA VDSLST+1
        PLA
        RTI

; ---------------------------------------------------------------------
;  WAVE_ANI -- every WV_RATE frames, the next phase of the wave glints:
;  WV_N characters copied from WVDATA into every map font (D51).
;  Call from the main loop during play.  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
WAVE_ANI
        LDA FRAME
        AND #WV_RATE-1
        BNE WA_RTS
        LDA FRAME
        LSR A           ; / WV_RATE (16)
        LSR A
        LSR A
        LSR A
        AND #WV_PH-1
        TAX
        LDA WVSRCL,X    ; this phase's characters
        STA TPTR
        LDA WVSRCH,X
        STA TPTR+1
        LDX #N_FONTS-1
WA_FONT STX WA_F
        LDX #0
WA_CHR  LDA WVDL,X      ; ZPTR + 8 x X = the character in this font
        STA ZPTR
        LDY WA_F
        LDA FONTPG,Y
        CLC
        ADC WVDH,X
        STA ZPTR+1
        TXA
        ASL A
        ASL A
        ASL A
        TAY             ; 8 x X: the same offset in both
WA_CPY  LDA (TPTR),Y
        STA (ZPTR),Y
        INY
        TYA
        AND #7
        BNE WA_CPY
        INX
        CPX #WV_N
        BNE WA_CHR
        LDX WA_F
        DEX
        BPL WA_FONT
WA_RTS  RTS

WV_RATE =  16           ; frames per wave phase (power of 2)

; ---------------------------------------------------------------------
;  BND_TILE -- MAP_PUT: a PT boat, fishing boat or wreck in a corner
;  row (D55) is drawn as that row's variant (BNDVAR), whose sea is in
;  PF0 like the rest of the row.  In: MTILE, Y = row.  Out: MTILE.
;  Keeps X, Y; trashes A.
; ---------------------------------------------------------------------
BND_TILE
        LDA BNDVAR,Y
        BEQ BT_DONE     ; not a corner row
        LDA MTILE
        SEC
        SBC #T_PTBOAT   ; T_PTBOAT, T_FISHBOAT, T_WRECK in a row
        CMP #3
        BCS BT_DONE
        ADC BNDVAR,Y    ; carry clear
        STA MTILE
BT_DONE RTS

; ---------------------------------------------------------------------
;  DLI_R3, DLI_R19 -- DISPLAY.ASM's DLI code for the rows where the width
;  changes (D67); here in code block 2 for room on the 5200
; ---------------------------------------------------------------------
; DLI_R3 -- DLI_ROW for character row 3, the first normal-width row
; after the wide ones (D67).  Its DLI runs in a wide line, where ANTIC
; leaves the CPU so few cycles that DLI_ROW's work before WSYNC could
; miss the line's end (row 3 then fetched wide: the map below it shifted,
; now and then).  So WSYNC first, then the width at once.
DLI_R3  STA WSYNC
        PHA
        LDA #DMA_N
        STA DMACTL      ; row 3: normal width, before its DMA starts
        TXA
        PHA
        LDX DL_NFN      ; then its font and shades, as DLI_ROW
        STX CHBASE
        LDA DL_NBK
        STA COLBK
        LDA DL_NPF
        STA COLPF0
        TYA
        PHA
        JMP DR_LOOK

; DLI_R19 -- start character row 19, the first bottom wide row (D67).
; Row 19 changes width, font (the corners) and PF0 at once, and all
; three must be stored before its first line's DMA starts.  A DLI at
; the end of row 18 sometimes reached its WSYNC too late (row 19 then
; came out at normal width with row 18's font and green: the bottom
; corners flickered).  So row 18 has no DLI: DLI_SQ, which starts row
; 18 with time to spare, comes here with A and X saved, waits for
; row 18's last 2 lines on VCOUNT, loads all three, and stores them
; straight after the WSYNC at the end of row 18, as DLI_MAP does for
; row 0.  Then DR_LOOK does what row 18's DLI_ROW did.  This costs
; about 5 lines of CPU time a frame.
MAPLN0  =  48           ; first scan line of map row 0 (8 + DLIST's
                        ; 22 blank lines, 2 x 8 status, 2 blank)
VC_R18  =  [MAPLN0+[19*8]-2]/2 ; VCOUNT on row 18's last 2 lines
R19SQ   =  9            ; DLI_SQ's square row for character row 18
DLI_R19 TYA             ; Y too, for DL_RDONE
        PHA
DT_WAIT LDA VCOUNT      ; to row 18's 7th line (or the end of its 6th)
        CMP #VC_R18
        BCC DT_WAIT
        LDX #3          ; ~16 cycles: surely inside the 7th line
DT_DLY  DEX
        BNE DT_DLY
        STA WSYNC       ; end of the 7th line
        LDA DL_NDM      ; the wide width
        LDX DL_NFN      ; the corner font
        LDY DL_NPF      ; the dark corner blue
        STA WSYNC       ; end of row 18
        STA DMACTL
        STX CHBASE
        STY COLPF0
        LDA DL_NBK
        STA COLBK
        JMP DR_LOOK

; ---------------------------------------------------------------------
;  Map screen memory (D67; DISPLAY.ASM draws it; here in code block 2
;  for room).  The corner rows (character rows 0-2 and
;  19-21) are wide playfield lines of WROW bytes: CH_PF0 in the 4
;  characters each side (the border, dark corner sea), the map's 40 in
;  between.  The others are normal lines of MAPCOLS.  So:
;    SCR_WT  rows 0-2 (3 x 48), SCR_N rows 3-18 (16 x 40), SCR_WB rows 19-21.
;  ROWLO/ROWHI: the address of map column 0 in each square row's top
;  character row, ROWBLO/ROWBHI in its bottom one (square rows 1 and
;  9 have one wide and one normal row).
; ---------------------------------------------------------------------
WROW    =  48           ; bytes per wide line
WBRD    =  4            ; border characters each side
DMA_N   =  DMA_NORM+DMA_PM ; DMACTL: normal width (as SDMCTL in play)
DMA_W   =  DMA_N+1      ; wide (playfield width bits 11)
SCR_WT   =  MAPSCR
SCR_N    =  MAPSCR+[3*WROW]
SCR_WB   =  SCR_N+[16*MAPCOLS]
SCR_END  =  SCR_WB+[3*WROW] ; MAPSCR+928
ROWLO   .BYTE <[SCR_WT+WBRD],<[SCR_WT+WROW+WROW+WBRD],<[SCR_N+40],<[SCR_N+120]
        .BYTE <[SCR_N+200],<[SCR_N+280],<[SCR_N+360],<[SCR_N+440],<[SCR_N+520]
        .BYTE <[SCR_N+600],<[SCR_WB+WROW+WBRD]
ROWHI   .BYTE >[SCR_WT+WBRD],>[SCR_WT+WROW+WROW+WBRD],>[SCR_N+40],>[SCR_N+120]
        .BYTE >[SCR_N+200],>[SCR_N+280],>[SCR_N+360],>[SCR_N+440],>[SCR_N+520]
        .BYTE >[SCR_N+600],>[SCR_WB+WROW+WBRD]
ROWBLO  .BYTE <[SCR_WT+WROW+WBRD],<SCR_N,<[SCR_N+80],<[SCR_N+160]
        .BYTE <[SCR_N+240],<[SCR_N+320],<[SCR_N+400],<[SCR_N+480],<[SCR_N+560]
        .BYTE <[SCR_WB+WBRD],<[SCR_WB+WROW+WROW+WBRD]
ROWBHI  .BYTE >[SCR_WT+WROW+WBRD],>SCR_N,>[SCR_N+80],>[SCR_N+160]
        .BYTE >[SCR_N+240],>[SCR_N+320],>[SCR_N+400],>[SCR_N+480],>[SCR_N+560]
        .BYTE >[SCR_WB+WBRD],>[SCR_WB+WROW+WROW+WBRD]
; ROWDMA: DMACTL per character row, set by DLI_MAP / DLI_ROW from DL_NDM
ROWDMA  .BYTE DMA_W,DMA_W,DMA_W,DMA_N,DMA_N,DMA_N,DMA_N,DMA_N,DMA_N,DMA_N,DMA_N
        .BYTE DMA_N,DMA_N,DMA_N,DMA_N,DMA_N,DMA_N,DMA_N,DMA_N,DMA_W,DMA_W,DMA_W
