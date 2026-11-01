; =====================================================================
;  LDRINIT.ASM -- INITAD for the loader segment (D57), its own file so
;  it loads after LOADER.ASM's code (see there)
; =====================================================================

        .INCLUDE "hw_a800.asm"

LDR_INIT = $8730        ; LDRBASE in LOADER.ASM

        *= INITAD
        .WORD LDR_INIT
