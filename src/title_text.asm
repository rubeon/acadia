; =====================================================================
;  TITLE_TEXT.ASM -- the title screen's text (generated)
;
;  Written by tools/gen-title.py; do not edit it by hand.
;
;  The name is a mode 7 line of 20 characters; the credits are
;  mode 2 lines of 40 characters, centred by the generator.
; =====================================================================

; the mode 7 name
TI_NAME .SBYTE "       ACADIA       "

; the mode 2 lines: the line number, then the text
TI_LIN  .BYTE 1,3,5,6,8,10,11,17
TI_LO   .BYTE <TI_T1,<TI_T2,<TI_T3,<TI_T4,<TI_T5,<TI_T6,<TI_T7,<TI_T8
TI_HI   .BYTE >TI_T1,>TI_T2,>TI_T3,>TI_T4,>TI_T5,>TI_T6,>TI_T7,>TI_T8

TI_T1  .SBYTE "AN ISLAND-BUILDING GAME FOR ATARI 8-BIT "
TI_T2  .SBYTE "      BY ERIC WILLIAMS AND CLAUDE       "
TI_T3  .SBYTE "  AFTER UTOPIA (1981) BY MATTEL, INC.   "
TI_T4  .SBYTE "    NOT AFFILIATED WITH MATTEL, INC.    "
TI_T5  .SBYTE " ALL GRAPHICS, CODE AND MUSIC ARE NEW.  "
TI_T6  .SBYTE "      KEYS 1-9 BUY ITEMS, 0 BOATS       "
TI_T7  .SBYTE "    P PAUSES, H SHOWS THE PRICE LIST    "
TI_T8  .SBYTE "      PRESS START OR FIRE TO BEGIN      "

TI_N    =  8
