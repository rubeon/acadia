; =====================================================================
;  BOOTATR.ASM -- the ATR disk's boot sectors (T-INFRA-4, D94)
;
;  `make atr` writes build/acadia.atr: these sectors first (sector 1
;  on), then build/acadia.xex itself, byte for byte, from the next
;  sector on, 128 bytes a sector (TOOLS/MKATR.PY).  No DOS: at power-on
;  the OS reads the boot sectors to BA_BASE and calls BA_GO, which reads
;  the XEX's sectors one by one and loads it as DOS would: each
;  segment to its address, a JSR through INITAD after any segment
;  that sets it, then a JMP through RUNAD at the end of the file.  It
;  never returns to the OS (PLAT_INIT sets BOOT? and COLDST for RESET,
;  D76).  So the XEX's own loader does the rest as before: LDR_INIT,
;  the first INITAD, switches BASIC out (an XL boots with BASIC in
;  unless OPTION is held, and so does the MiSTer core) and puts up the
;  loading screen, and each LD_STEP grows the bar (D57, D81).
;
;  This is not game code: like DOS it runs before the game and calls
;  the OS's DSKINV to read sectors (AGENTS.md rule 3 is for the game).
;  The disk boots before the OS opens its screen, so DMA is still off:
;  after each INITAD call BA_GO turns it on (the loading screen's
;  display list is in place by then; before, ANTIC would show
;  whatever DLISTL points at).  Before the game runs it sets POKEY's
;  SKCTL and AUDCTL as they are after power-on (D95).
;
;  Memory, while it loads: code and constants $0700-$07FF; the sector
;  buffer and variables $0500-$0584; the zero page pointers $43-$46,
;  the OS's bytes for DOS (FMZSPG), unused without one.  The XEX loads
;  nothing below $2000 except the D73 pad byte at $0600.
;
;  Assembled on its own; MKATR.PY puts the XEX's length in BA_LEN.
; =====================================================================

        .INCLUDE "hw_a800.asm"

BA_BASE =  $0700        ; boot sectors load here (the usual DOS spot)
BA_BUF  =  $0500        ; one sector of the XEX
BA_SECSZ = 128          ; bytes a sector (single density)
BA_LEFT =  $0580        ; 2 bytes: XEX bytes not yet taken
BA_SEC  =  $0582        ; 2 bytes: the next sector to read
BA_POS  =  $0584        ; next byte in BA_BUF; BA_SECSZ: read again
BA_PTR  =  $43          ; 2 bytes: where the next byte loads
BA_END  =  $45          ; 2 bytes: the segment's last address

DSKINV  =  $E453        ; OS: read or write a disk sector (DCB)
DUNIT   =  $0301        ; DCB: drive number
DCOMND  =  $0302        ; DCB: command
DSTATS  =  $0303        ; DCB: status back (bit 7 set = error)
DBUFLO  =  $0304        ; DCB: buffer address
DAUX1   =  $030A        ; DCB: sector number, low
DAUX2   =  $030B        ; DCB: and high
BA_DRV  =  1            ; D1:
BA_READ =  $52          ; SIO command 'R': read sector
SOUNDR  =  $41          ; OS: 0 = SIO transfers are silent (D93)
SSKCTL  =  $0232        ; OS: SKCTL's shadow, which SIO writes back
BA_SKC  =  $03          ; SKCTL: keyboard debounce and scan, no serial

        *= BA_BASE
; the boot header, which the OS reads (ATR sector 1)
        .BYTE 0                 ; flags
        .BYTE BA_NSEC           ; boot sectors to read
        .WORD BA_BASE           ; load address
        .WORD BA_RTS            ; DOSINI until the game sets its own

; ---------------------------------------------------------------------
;  BA_GO -- boot continuation: the OS JSRs here (BA_BASE + 6) once the
;  boot sectors are in.  Loads the XEX from sector BA_FIRST on and
;  runs it.  Never returns.
; ---------------------------------------------------------------------
BA_GO   CLD             ; binary maths (IRQs stay on: SIO needs them)
        LDA #0          ; silent from here (the loader keeps it so)
        STA SOUNDR
        LDA #<BA_RTS    ; no RUNAD yet (a file without one would
        STA RUNAD       ; land on the RTS and go back to the OS)
        LDA #>BA_RTS
        STA RUNAD+1
        LDA BA_LEN      ; the whole file is left
        STA BA_LEFT
        LDA BA_LEN+1
        STA BA_LEFT+1
        LDA #BA_FIRST   ; from the first sector after these
        STA BA_SEC
        LDA #0
        STA BA_SEC+1
        LDA #BA_SECSZ   ; nothing in the buffer
        STA BA_POS

BA_SEG  LDA BA_LEFT     ; the end of the file: run it
        ORA BA_LEFT+1
        BEQ BA_RUN
        JSR BA_BYTE     ; the segment's start (or $FFFF)
        STA BA_PTR
        JSR BA_BYTE
        STA BA_PTR+1
        AND BA_PTR      ; $FFFF: a header, read the start again
        CMP #$FF
        BEQ BA_SEG
        JSR BA_BYTE     ; its end
        STA BA_END
        JSR BA_BYTE
        STA BA_END+1
        LDA #<BA_RTS    ; INITAD to the RTS: a segment that loads
        STA INITAD      ; one changes it
        LDA #>BA_RTS
        STA INITAD+1

BA_LD   JSR BA_BYTE     ; one byte of the segment
        LDY #0
        STA (BA_PTR),Y
        LDA BA_PTR      ; carry clear while BA_PTR < BA_END
        CMP BA_END
        LDA BA_PTR+1
        SBC BA_END+1
        INC BA_PTR      ; (INC keeps the carry)
        BNE BA_LD1
        INC BA_PTR+1
BA_LD1  BCC BA_LD

        LDA INITAD      ; INITAD set by this segment?
        CMP #<BA_RTS
        BNE BA_INI
        LDA INITAD+1
        CMP #>BA_RTS
        BEQ BA_SEG      ; no
BA_INI  JSR BA_JINI     ; yes: call it
        LDA #DMA_NORM   ; and the screen on (see the header)
        STA SDMCTL
        STA DMACTL
        JMP BA_SEG

BA_RUN  LDA #0          ; POKEY as after power-on: SIO leaves SKCTL
        STA AUDCTL      ; in its serial mode, which ties up voices 3
        STA SKCTL       ; and 4 (the game never sets it); 0 first
        LDA #BA_SKC     ; resets the counters, then keyboard scan
        STA SKCTL       ; and debounce on
        STA SSKCTL
BA_JRUN JMP (RUNAD)     ; the game

BA_JINI JMP (INITAD)    ; JSR BA_JINI: call through INITAD

; ---------------------------------------------------------------------
;  BA_BYTE -- the XEX's next byte, reading the next sector when the
;  buffer is used up.
;  In: BA_POS, BA_SEC, BA_LEFT.  Out: A = the byte; BA_LEFT one less.
;  Trashes X, Y.
; ---------------------------------------------------------------------
BA_BYTE LDX BA_POS
        CPX #BA_SECSZ   ; buffer used up?
        BCC BA_BY1
        JSR BA_RDS      ; read the next sector, X = 0
BA_BY1  LDA BA_BUF,X
        INX
        STX BA_POS
        LDY BA_LEFT     ; BA_LEFT - 1
        BNE BA_BY2
        DEC BA_LEFT+1
BA_BY2  DEC BA_LEFT
BA_RTS  RTS

; ---------------------------------------------------------------------
;  BA_RDS -- read sector BA_SEC of D1: into BA_BUF, trying again until
;  it reads, and step BA_SEC on.
;  In: BA_SEC.  Out: X = 0.  Trashes A, Y.
; ---------------------------------------------------------------------
BA_RDS  LDA #BA_DRV     ; the DCB: D1:, read, into BA_BUF
        STA DUNIT
        LDA #BA_READ
        STA DCOMND
        LDA #<BA_BUF
        STA DBUFLO
        LDA #>BA_BUF
        STA DBUFLO+1
        LDA BA_SEC
        STA DAUX1
        LDA BA_SEC+1
        STA DAUX2
        JSR DSKINV      ; SIO (it retries a few times itself)
        LDA DSTATS
        BMI BA_RDS      ; failed: again
        INC BA_SEC      ; the next one
        BNE BA_RD1
        INC BA_SEC+1
BA_RD1  LDX #0
        RTS

; the XEX's length in bytes (MKATR.PY writes it here)
BA_LEN  .WORD 0

BA_EOC
BA_NSEC =  [BA_EOC-BA_BASE+BA_SECSZ-1]/BA_SECSZ
BA_FIRST = BA_NSEC+1    ; the XEX's first sector
