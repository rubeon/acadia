; =====================================================================
;  DISPLAY.ASM -- display list, DLI, VBI and test screen
;
;  Screen layout (192 scan lines):
;    24 blank lines
;     2 x ANTIC mode 2  status bar  (ROM font, OS shadow colours)
;    22 x ANTIC mode 4  map         (custom font, colours set by DLI)
;
;  The DLI on the last status line switches CHBASE and the colour
;  registers for the map zone.  The OS VBI restores the status-bar
;  values from the shadow registers at the top of every frame.
; =====================================================================

MAPROWS =  22           ; mode 4 lines in the map zone
MAPCOLS =  40           ; bytes per line, normal playfield width

; Status bar colours (OS shadows)
C_SBAR  =  $82          ; status bar background (COLPF2)
C_STXT  =  $0E          ; status bar text luminance (COLPF1)
C_SBRD  =  $00          ; status bar border (COLBK)

; Map zone colours (DLI)
C_WATER =  $96          ; COLBK  -- sea
C_LAND  =  $C8          ; COLPF0 -- grass
C_SAND  =  $EC          ; COLPF1 -- beach
C_HILL  =  $F4          ; COLPF2 -- hills / forest
C_MARK  =  $0E          ; COLPF3 -- inverse chars

; Map tile numbers (mode 4 character codes)
T_WATER =  0
T_LAND  =  1
T_SAND  =  2
T_HILL  =  3

; ---------------------------------------------------------------------
;  DISP_INIT -- install display list, DLI and VBI.
;  Writes only RAM vectors and shadows; calls no OS routines.
; ---------------------------------------------------------------------
DISP_INIT
        LDA #0
        STA NMIEN       ; no VBI/DLI while vectors are patched
        STA SDMCTL
        STA DMACTL

        JSR MAP_BUILD

        LDA #<DLI_MAP
        STA VDSLST
        LDA #>DLI_MAP
        STA VDSLST+1

        LDA VVBLKD      ; chain to whatever deferred VBI was there
        STA OLDVBD
        LDA VVBLKD+1
        STA OLDVBD+1
        LDA #<VBI_D
        STA VVBLKD
        LDA #>VBI_D
        STA VVBLKD+1

        LDA #<DLIST
        STA SDLSTL
        LDA #>DLIST
        STA SDLSTH

        LDA #C_SBAR
        STA COLOR2
        LDA #C_STXT
        STA COLOR1
        LDA #C_SBRD
        STA COLOR4
        LDA #ROMFONT
        STA CHBAS

        LDA #DMA_NORM
        STA SDMCTL
        LDA #NMI_VBI+NMI_DLI
        STA NMIEN
        RTS

; ---------------------------------------------------------------------
;  DLI_MAP -- switch font and colours for the map zone
; ---------------------------------------------------------------------
DLI_MAP
        PHA
        TXA
        PHA
        TYA
        PHA
        LDA #C_WATER
        LDX #C_LAND
        LDY #C_SAND
        STA WSYNC
        STA COLBK
        STX COLPF0
        STY COLPF1
        LDA #C_HILL
        STA COLPF2
        LDA #C_MARK
        STA COLPF3
        LDA #>MAPFONT
        STA CHBASE
        PLA
        TAY
        PLA
        TAX
        PLA
        RTI

; ---------------------------------------------------------------------
;  VBI_D -- deferred VBI: frame counter, keep attract mode off
; ---------------------------------------------------------------------
VBI_D
        INC FRAME
        LDA #0
        STA ATRACT
        JMP (OLDVBD)

; ---------------------------------------------------------------------
;  MAP_BUILD -- clear the map and draw two test islands
; ---------------------------------------------------------------------
MAP_BUILD
        LDA #<MAPSCR    ; build row address table
        STA ZPTR
        LDA #>MAPSCR
        STA ZPTR+1
        LDX #0
MB_ROW  LDA ZPTR
        STA ROWLO,X
        LDA ZPTR+1
        STA ROWHI,X
        LDY #0          ; clear this row
        LDA #T_WATER
MB_CLR  STA (ZPTR),Y
        INY
        CPY #MAPCOLS
        BNE MB_CLR
        CLC
        LDA ZPTR
        ADC #MAPCOLS
        STA ZPTR
        BCC MB_NC
        INC ZPTR+1
MB_NC   INX
        CPX #MAPROWS
        BNE MB_ROW

        LDX #0          ; draw rectangles from RECTS
MB_RECT LDA RECTS,X
        BMI MB_END      ; $FF terminates
        STA RROW
        LDA RECTS+1,X
        STA RCOL
        LDA RECTS+2,X
        STA RWID
        LDA RECTS+3,X
        STA RHGT
        LDA RECTS+4,X
        STA RTILE
        TXA
        PHA
        JSR FILLRECT
        PLA
        CLC
        ADC #5
        TAX
        BNE MB_RECT
MB_END  RTS

; ---------------------------------------------------------------------
;  FILLRECT -- fill RWID x RHGT tiles at RROW,RCOL with RTILE
; ---------------------------------------------------------------------
FILLRECT
        LDX RROW
FR_ROW  LDA ROWLO,X
        CLC
        ADC RCOL
        STA ZPTR
        LDA ROWHI,X
        ADC #0
        STA ZPTR+1
        LDY RWID
        DEY
        LDA RTILE
FR_COL  STA (ZPTR),Y
        DEY
        BPL FR_COL
        INX
        DEC RHGT
        BNE FR_ROW
        RTS

; Test islands: row, col, width, height, tile
RECTS   .BYTE 5,3,13,13,T_SAND        ; left island
        .BYTE 6,4,11,11,T_LAND
        .BYTE 9,7,4,4,T_HILL
        .BYTE 4,23,14,12,T_SAND       ; right island
        .BYTE 5,24,12,10,T_LAND
        .BYTE 8,28,4,3,T_HILL
        .BYTE $FF

; ---------------------------------------------------------------------
;  Status bar text (screen codes), 2 lines of 40
; ---------------------------------------------------------------------
STATUS1 .SBYTE " ACADIA - UTOPIA FOR THE ATARI 800XL    "
STATUS2 .SBYTE "J0:0 F0:0 J1:0 F1:0 KEY:- FRM:00        "

; Offsets of the live fields in STATUS2
ST_J0   =  3
ST_F0   =  8
ST_J1   =  13
ST_F1   =  18
ST_KEY  =  24
ST_FRM  =  30

; ---------------------------------------------------------------------
;  Display variables
; ---------------------------------------------------------------------
FRAME   .BYTE 0
ROWLO   *= *+MAPROWS
ROWHI   *= *+MAPROWS
RROW    .BYTE 0
RCOL    .BYTE 0
RWID    .BYTE 0
RHGT    .BYTE 0
RTILE   .BYTE 0

; =====================================================================
;  Fixed-address data.  Each block must stay on its own boundary:
;  font 1K aligned, display list inside one 1K page, screen inside 4K.
; =====================================================================

; ---------------------------------------------------------------------
;  Map font (mode 4: 2 bits per pixel, 00=BAK 01=PF0 10=PF1 11=PF2)
;  Only the first few characters are defined.
; ---------------------------------------------------------------------
        *= $3000
MAPFONT
        .BYTE $00,$00,$00,$00,$00,$00,$00,$00   ; 0 water
        .BYTE $55,$55,$55,$55,$55,$55,$55,$55   ; 1 grass
        .BYTE $AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA   ; 2 sand
        .BYTE $55,$5D,$7F,$FF,$5D,$55,$75,$55   ; 3 hills

; ---------------------------------------------------------------------
;  Map screen memory (MAPROWS x MAPCOLS, filled at run time)
; ---------------------------------------------------------------------
MAPSCR  =  $3400

; ---------------------------------------------------------------------
;  Display list
; ---------------------------------------------------------------------
        *= $3800
DLIST
        .BYTE DL_BLANK8,DL_BLANK8,DL_BLANK8
        .BYTE DL_LMS+DL_MODE2
        .WORD STATUS1
        .BYTE DL_DLI+DL_MODE2           ; DLI fires at end of this line
        .BYTE DL_LMS+DL_MODE4
        .WORD MAPSCR
        .BYTE DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4
        .BYTE DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4
        .BYTE DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4,DL_MODE4
        .BYTE DL_JVB
        .WORD DLIST
