; =====================================================================
;  PLAT_A800.ASM -- the 800 build's platform hooks (D62)
;
;  MAIN.ASM calls PLAT_INIT after VARS_INIT, and MAP_LOAD calls
;  PLAT_MAP after copying a map's block.  The OS has set the machine
;  up and the map fonts are RAM already, so PLAT_MAP has nothing to
;  do.  PLAT_INIT makes RESET come back to the title screen (D76) and
;  puts map 1 in the live tables: the XEX loads it there, but after
;  RESET they hold the last game's map.  PLAT_5200.ASM has the
;  cartridge's.
; =====================================================================

; ---------------------------------------------------------------------
;  PLAT_INIT -- RESET to the title, map 1 in the live tables.
;  RESET on the 800 is a warm start: the OS keeps RAM (but clears its
;  own, $0010-$007F and $0200-$03FF, and opens its screen), sets the
;  hardware up again and, with BOOT? bit 0 set, calls DOSINI.  Ours
;  is RESTART, which never returns, so DOS's DOSINI (if any) is not
;  chained: nothing uses DOS once the game runs.  COLDST = 0, or a
;  boot loader that never returned to the OS would leave RESET a cold
;  start.  The XEX loader keeps BASIC out on RESET (BASICF, D57).
;  Trashes A, X, Y, ZPTR, TPTR.
; ---------------------------------------------------------------------
PLAT_INIT
        LDA #<RESTART   ; RESET -> RESTART (MAIN.ASM)
        STA DOSINI
        LDA #>RESTART
        STA DOSINI+1
        LDA BOOTQ       ; call it on a warm start
        ORA #1
        STA BOOTQ
        LDA #0          ; and make RESET a warm start
        STA COLDST
        LDA #$FF        ; map 1 again, whatever the tables hold
        STA MAPLD
        LDA #0
        JMP MAP_LOAD

PLAT_MAP
        RTS
