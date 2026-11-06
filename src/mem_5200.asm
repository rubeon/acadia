; =====================================================================
;  MEM_5200.ASM -- memory map of the Atari 5200 build (32K cartridge)
;
;  The same symbols as MEM_A800.ASM (T-5200-0), at the cartridge's
;  addresses (D62).  RAM is $0000-$3FFF (16K): everything the game
;  writes is there.  The cartridge is $4000-$BFFF (32K ROM, the header
;  at $BFE8-$BFFF): code, fonts, logo, display lists, map blocks and
;  constants.  ARCHITECTURE.md section 3 has the table; keep the two
;  in step.
;
;  Include after HW_5200.ASM and before any module.
; =====================================================================

; ---------------------------------------------------------------------
;  RAM ($0000-$3FFF)
;    $0000-$0018  BIOS shadows; $0080-$0091, $00CB-$00CE game (MAIN.ASM)
;    $0100-$01FF  stack
;    $0200-$021B  BIOS vectors
; ---------------------------------------------------------------------
PLATRAM =  $0220        ; the 5200's own bytes (HW_5200.ASM: CHBAS ...;
                        ; PLAT_5200.ASM: PV_OLD, PM_ORG ...;
                        ; INPUT5200.ASM: IN_CTL ...), PLATSZ bytes
PLATSZ  =  32           ; $0220-$023F
PMAREA  =  $0400        ; P/M graphics, 1K aligned (double-line)
RMFONT0 =  $0800        ; the live map's fonts: RAM copies of the map's
RMFONT1 =  $0C00        ; ROM fonts, made by PLAT_MAP, so WAVE_ANI can
RMFONT2 =  $1000        ; write them (1K aligned)
MAPSCR  =  $1400        ; map screen memory, 928 bytes (DISPLAY.ASM, D67)
HELPSCR =  $1800        ; 11 x 40 help screen (440)
ISLDATA =  $1A00        ; the live map's tables (ISL_LIVE5200.ASM),
                        ; $1A00-$203F
VARBASE =  $2100        ; RAM variables (VARS.ASM), cleared by VARS_INIT
VARPAGES = 7            ; $2100-$27FF
CTBM0   =  $2800        ; stats chart lines 0-24 (D61), 1K
CTBM1   =  $2C00        ; lines 25-49, 1K
CTBM2   =  MAPSCR       ; lines 50-63: the map, drawn again later
CTTXT   =  HELPSCR      ; three mode 4 lines: the help screen's memory
RAMEND  =  $4000        ; $3000-$3FFF free

; ---------------------------------------------------------------------
;  Cartridge ROM ($4000-$BFE7)
; ---------------------------------------------------------------------
CODE1   =  $4000        ; start-up, services, map, stats part 1, display
MFAC    =  $5000        ; the corner font (D65; 1K aligned, as below)
MFA00   =  $5400        ; STANDARD fonts 0-2
MFA01   =  $5800
MFA02   =  $5C00
MFA10   =  $6000        ; RANDOM font
PSFONTA =  $6400        ; pause band font PSFONT (D69)
TTFONTA =  $6800        ; title screen font TTFONT (D70)
HLPFNTA =  $6C00        ; help font HLPFONT, then the wave frames WVDATA
STFONTA =  $7000        ; status bar font STFONT (D54)
DLBASE  =  $7400        ; display list page (DISPLAY.ASM); island
                        ; constants (ISLANDS.ASM) follow, to ~$752F
MAPSRC  =  $7540        ; each map's data block MAPS0 ...; then code
                        ; block 2 (ACADIA5200.ASM)
TITLEGFX = $B800        ; title graphics (D70): logo, scene, colour
                        ; tables, 1808 bytes, to $BF0F (one 4K block)
CARTHDR =  $BFE8        ; cartridge header (ACADIA5200.ASM)
