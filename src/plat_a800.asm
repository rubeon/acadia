; =====================================================================
;  PLAT_A800.ASM -- the 800 build's platform hooks (D62)
;
;  MAIN.ASM calls PLAT_INIT after VARS_INIT, and MAP_LOAD calls
;  PLAT_MAP after copying a map's block.  The 800 needs neither: the
;  OS has set the machine up, the XEX loads the live tables as map 1's
;  (MAPLD = 0 is right), and the map fonts are RAM already.
;  PLAT_5200.ASM has the cartridge's.
; =====================================================================

PLAT_INIT
PLAT_MAP
        RTS
