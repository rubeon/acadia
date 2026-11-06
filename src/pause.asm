; =====================================================================
;  PAUSE.ASM -- pause (R-CTL-6, D19, D69)
;
;  P pauses and P resumes; either player may do either.  While paused
;  the game frame skips the cursors, the keys and the tic, so the round
;  clock, rounds and (later) events and the CPU player all stand still.
;  The map is dimmed and a black band across its bottom says PAUSED
;  (D69); the status bar stays as it is, so scores and time show.  Both
;  go on resume, and TIC_SYNC drops the paused frames so no time is
;  lost.
;
;  The band is the map's three bottom character rows, PB_ROW to
;  PB_ROW+2 (the wide corner rows, sea only, D67), given the pause font
;  PSFONT (FONT_PAUSE.ASM) and the band's colours: PB_VBI swaps them in
;  and out during the vertical blank, so the display never shows half
;  a band, and nothing in the game writes the map while it is up.
;  Only the odd rows set a font (DLI_R19 row 19, DLI_ROW row 21), so
;  ROWFONT's entries for PB_ROW and PB_ROW+2 change; row 20 keeps 19's.
;
;  Sound: POKEY's registers can't be read back, so pausing silences
;  AUDC1-4 (SND_OFF).  The sound driver stands still while PAUSED is
;  set and rewrites its voices every frame, so play picks up again.
; =====================================================================

; PB_ROW, PB_RLEN, PB_COL, PB_ADDR, PB_LEN, C_PBK, C_PTX: DISPLAY.ASM, as
; equates must come before their first use (a forward one made ATasm
; size the stores differently in its two passes)

; ---------------------------------------------------------------------
;  PAUSE_KEY -- toggle pause if P was pressed this frame
;  Call after INPUT_POLL.  Out: A = 0 and Z set if the game runs this
;  frame: not paused, and the band down (PB_ON clear), so that on
;  resume the game waits for the VBI to put the map rows back before
;  it can draw into them.  Trashes A, X, Y.
; ---------------------------------------------------------------------
PAUSE_KEY
        LDA PAUSEK
        BEQ PK_DONE
        LDA PAUSED
        BNE PK_GO
        JSR PAUSE_ON
        JMP PK_DONE
PK_GO   JSR PAUSE_OFF
PK_DONE LDA PAUSED
        ORA PB_ON
        RTS

; ---------------------------------------------------------------------
;  PAUSE_ON -- stop the game: dim the map, silence POKEY; the next VBI
;  shows the band (PB_VBI).  Trashes A, X, Y.
; ---------------------------------------------------------------------
PAUSE_ON
        JSR PAL_DIM
        LDA #1
        STA PAUSED
        JMP SND_OFF     ; silence all four voices

; ---------------------------------------------------------------------
;  PAUSE_OFF -- carry on: the map colours back, the next VBI takes
;  the band away (PB_VBI); forget the frames that passed.  Trashes A, X.
; ---------------------------------------------------------------------
PAUSE_OFF
        LDA #0
        STA PAUSED
        JSR PAL_NORM
        JMP TIC_SYNC

; ---------------------------------------------------------------------
;  PB_VBI -- from VBI_D: when PAUSED has changed since the last frame,
;  put the band up (save the three map rows and the rows' fonts, write
;  PAUSED in the pause font) or take it down (put them back), then the
;  rows' colours at once (VD_SHADE, which gives the band its colours
;  while PB_ON is set).  Trashes A, X, Y.
; ---------------------------------------------------------------------
PB_VBI
        LDA PAUSED
        CMP PB_ON
        BEQ PB_RTS      ; no change
        STA PB_ON
        TAX
        BEQ PB_OFF
        LDX #PB_LEN     ; up: save the rows and blank them, borders too
PB_SAVE LDA PB_ADDR-1,X
        STA PSAVE-1,X
        LDA #0
        STA PB_ADDR-1,X
        DEX
        BNE PB_SAVE
        LDX #5          ; letter n: 1+3n, 2+3n, 3+3n down its three
        LDA #3*5+1      ; rows (FONT_PAUSE.ASM)
PB_LET  STA PB_ADDR+PB_COL,X
        CLC
        ADC #1
        STA PB_ADDR+PB_RLEN+PB_COL,X
        ADC #1
        STA PB_ADDR+PB_RLEN+PB_RLEN+PB_COL,X
        SEC
        SBC #5          ; 3 + 2 back: the letter before's first
        DEX
        BPL PB_LET
        LDA ROWFONT+PB_ROW
        STA PB_FNT
        LDA ROWFONT+PB_ROW+2
        STA PB_FNT+1
        LDA #>PSFONT
        STA ROWFONT+PB_ROW
        STA ROWFONT+PB_ROW+2
        JMP VD_SHADE
PB_OFF  LDX #PB_LEN     ; down: the rows and fonts back
PB_REST LDA PSAVE-1,X
        STA PB_ADDR-1,X
        DEX
        BNE PB_REST
        LDA PB_FNT
        STA ROWFONT+PB_ROW
        LDA PB_FNT+1
        STA ROWFONT+PB_ROW+2
        JMP VD_SHADE
PB_RTS  RTS
