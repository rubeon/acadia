; =====================================================================
;  SHADE.ASM -- per-row sea and grass shading, moving waves (D51)
; =====================================================================

; ---------------------------------------------------------------------
;  VD_SHADE -- ROWBK / ROWPF0: the sea and grass colours of each
;  character row (D51): MAPPAL's, luminance + SEADEL / GRNDEL (kept
;  0-14), attract mode applied.  Notes what it was built from in AP_SH,
;  AP_MSK, AP_BK, AP_GR.  Trashes A, X, Y.
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
        JSR VS_LUM
        STA ROWPF0,X
        DEX
        BPL VS_ROW
        RTS

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

; Luminance change per character row: the open sea darker at the top
; and bottom, lighter round the islands; the grass lit from the north
SEADEL  .BYTE $FE,$FE,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,$FE,$FE
GRNDEL  .BYTE 2,2,2,2,2,2,2,2,0,0,0,0,0,0,$FE,$FE,$FE,$FE,$FE,$FE,$FE,$FE

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
