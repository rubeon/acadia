; =====================================================================
;  DEMO.ASM -- the attract-mode demo (T-REL-1, D47)
;
;  After DM_IDLE seconds on the title screen with nothing touched, a
;  1-player game starts by itself: the CPU (level 3) plays the right
;  island as usual, and player 1's stick and keys come from a short
;  script (DEMOSCR) that builds a fort, crops and a fishing boat on the
;  left island.  After DM_LEN seconds, or as soon as any stick, fire
;  button, console key or key is touched, it goes back to the title
;  screen.  The setup values are kept aside meanwhile and put back.
; =====================================================================

DM_IDLE =  30           ; seconds on the title screen before the demo
DM_LEN  =  15           ; seconds the demo plays
DM_SECS =  30           ; its round length (no round end within DM_LEN)
DM_LVL  =  3            ; CPU level in the demo
DM_NONE =  $FF          ; script: no key

; ---------------------------------------------------------------------
;  DEMO_GO -- start the demo game (from the title screen).
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
DEMO_GO
        LDX #SU_NF-1    ; the setup values aside
DG_SAV  LDA SU_VAL,X
        STA DM_SAV,X
        DEX
        BPL DG_SAV
        LDA #1          ; 1 round, 1 player against the CPU
        STA SU_VAL
        STA NUMTRN
        STA SU_VAL+SU_FPLY
        LDA #DM_SECS
        STA SU_VAL+1
        STA TRNLEN
        LDA #DM_LVL
        STA SU_VAL+SU_FLVL
        LDA #0          ; no keypad
        STA SU_VAL+SU_FKP
        STA MAPNO       ; map 1: the script is made for it (D56)
        LDA #1
        STA DEMO
        STA DM_CNT      ; the first script step at the next frame
        LDA #0
        STA DM_POS
        STA DM_J
        LDA #<DLIST     ; same page as TDLIST: one store switches
        STA SDLSTL
        JMP GAME_START

; ---------------------------------------------------------------------
;  DEMO_FRAME -- each frame of the demo, after INPUT_POLL: back to the
;  title on any input or when the time is up (C set: nothing more to
;  do this frame); else player 1's stick and key from the script
;  (C clear).  Trashes A, Y.
; ---------------------------------------------------------------------
DEMO_FRAME
        LDA FIRE0       ; anything touched: back to the title
        ORA FIRE1
        ORA JOY0
        ORA JOY1
        ORA KEYDOWN
        ORA CONKEY
        BNE DF_END
        LDA REMSEC      ; time up?
        CMP #DM_SECS-DM_LEN+1
        BCS DF_RUN
DF_END  JSR DEMO_END
        SEC
        RTS
DF_RUN  LDA #DM_NONE    ; no key unless a step starts with one
        STA KEY
        DEC DM_CNT
        BNE DF_HOLD
        LDY DM_POS      ; the next step: frames, stick, key
        LDA DEMOSCR,Y
        BEQ DF_IDLE     ; script done: stand still
        STA DM_CNT
        LDA DEMOSCR+1,Y
        STA DM_J
        LDA DEMOSCR+2,Y
        STA KEY
        INY
        INY
        INY
        STY DM_POS
DF_HOLD LDA DM_J
        STA JOY0
        CLC
        RTS
DF_IDLE LDA #1
        STA DM_CNT
        LDA #0
        STA DM_J
        BEQ DF_HOLD

; ---------------------------------------------------------------------
;  DEMO_END -- leave the demo: setup values back, quiet, title screen.
;  Trashes A, X, Y.
; ---------------------------------------------------------------------
DEMO_END
        LDA #0
        STA DEMO
        LDX #SU_NF-1
DE_SAV  LDA DM_SAV,X
        STA SU_VAL,X
        DEX
        BPL DE_SAV
        JSR SND_INIT    ; no effect left playing
        JMP TITLE_ENTER

; Player 1's script: frames, stick (J_ bits), key (digit, DM_NONE) on
; the first frame.  The cursor starts on square 4, 5 and moves 1 pixel
; a frame, 8 a square.  Fort 50 + 4 crops 12 + fishing boat 25 = 87
; of the 100 gold; then it takes the boat out (2 pixels in 3 frames).
DEMOSCR .BYTE 45,0,DM_NONE
        .BYTE 1,0,I_FORT            ; fort on 4, 5
        .BYTE 40,0,DM_NONE
        .BYTE 8,J_RIGHT,DM_NONE     ; to 5, 5
        .BYTE 30,0,DM_NONE
        .BYTE 1,0,I_CROP
        .BYTE 30,0,DM_NONE
        .BYTE 8,J_UP,DM_NONE        ; to 5, 4
        .BYTE 30,0,DM_NONE
        .BYTE 1,0,I_CROP
        .BYTE 30,0,DM_NONE
        .BYTE 8,J_LEFT,DM_NONE      ; to 4, 4
        .BYTE 30,0,DM_NONE
        .BYTE 1,0,I_CROP
        .BYTE 45,0,DM_NONE
        .BYTE 1,0,I_FSBT            ; fishing boat into the harbour
        .BYTE 60,0,DM_NONE
        .BYTE 16,J_DOWN,DM_NONE     ; to 4, 6
        .BYTE 30,0,DM_NONE
        .BYTE 1,0,I_CROP
        .BYTE 30,0,DM_NONE
        .BYTE 24,J_LEFT,DM_NONE     ; to 1, 6
        .BYTE 16,J_UP,DM_NONE       ; to the harbour, 1, 4
        .BYTE 20,0,DM_NONE
        .BYTE 1,0,0                 ; key 0: lift the boat
        .BYTE 20,0,DM_NONE
        .BYTE 60,J_DOWN,DM_NONE     ; sail south of the island
        .BYTE 120,J_RIGHT,DM_NONE   ; and east along it
        .BYTE 1,0,0                 ; park
        .BYTE 0
