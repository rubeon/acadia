; =====================================================================
;  SOUND.ASM -- sound effects (stubs until T-SND-1/T-SND-2)
;
;  Game code calls these hooks where the original plays a sound; the
;  POKEY driver (VBI) and the real effects arrive with M5.  Each hook
;  keeps A, X and Y.
; =====================================================================

; SND_BUY -- an item was bought
SND_BUY
        RTS

; SND_REFUSE -- a purchase was refused (the original's "razz")
SND_REFUSE
        RTS
