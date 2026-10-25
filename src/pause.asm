; =====================================================================
;  PAUSE.ASM -- pause (R-CTL-6, D19)
;
;  P pauses and P resumes; either player may do either.  While paused
;  the game frame skips the cursors, the keys and the tic, so the round
;  clock, rounds and (later) events and the CPU player all stand still.
;  Status line 1 shows PAUSED and the map is dimmed; both come back on
;  resume, and TIC_SYNC drops the paused frames so no time is lost.
;
;  Sound: POKEY's registers can't be read back, so pausing silences
;  AUDC1-4.  The sound driver (T-SND-1) must not play while PAUSED is
;  set and rewrites its channels when play resumes.
; =====================================================================

PS_COL  =  17           ; PAUSED's column on status line 1

; ---------------------------------------------------------------------
;  PAUSE_KEY -- toggle pause if P was pressed this frame
;  Call after INPUT_POLL.  Out: A = PAUSED (0 = playing), Z set if
;  playing.  Trashes A, X, Y.
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
        RTS

; ---------------------------------------------------------------------
;  PAUSE_ON -- stop the game: keep status line 1, show PAUSED, dim the
;  map, silence POKEY.  Trashes A, X, Y.
; ---------------------------------------------------------------------
PAUSE_ON
        LDA #1
        STA PAUSED
        LDX #39         ; save status line 1, then clear it
PO_SAVE LDA STATUS1,X
        STA PSAVE,X
        LDA #0
        STA STATUS1,X
        DEX
        BPL PO_SAVE
        LDA #<PS_TXT
        LDY #>PS_TXT
        LDX #PS_COL
        JSR TXT_STR
        JSR PAL_DIM
        LDA #0          ; silence all four channels
        STA AUDC1
        STA AUDC2
        STA AUDC3
        STA AUDC4
        RTS

; ---------------------------------------------------------------------
;  PAUSE_OFF -- carry on: restore status line 1 and the map colours,
;  and forget the frames that passed.  Trashes A, X.
; ---------------------------------------------------------------------
PAUSE_OFF
        LDX #39
PF_REST LDA PSAVE,X
        STA STATUS1,X
        DEX
        BPL PF_REST
        JSR PAL_NORM
        JSR TIC_SYNC
        LDA #0
        STA PAUSED
        RTS

PS_TXT  .SBYTE "PAUSED"
        .BYTE TX_END
