; =====================================================================
;  HW_5200.ASM -- Atari 5200 hardware and BIOS equates (D62)
;
;  The same symbol names as HW_A800.ASM, at the 5200's addresses:
;  GTIA at $C000, POKEY at $E800, ANTIC at $D400 as on the 800, and
;  no PIA.  The BIOS keeps its shadow registers in zero page and its
;  vectors at $0200 (checked against the Altirra 5200 BIOS in atari800
;  and cc65's atari5200.inc).  Game code calls no BIOS routine; it
;  writes only the shadows and vectors below.
;
;  The BIOS has no CHBASE or PRIOR shadow and no attract colour masks:
;  CHBAS, GPRIOR, COLRSH and DRKMSK are RAM bytes of the 5200 build
;  (PLATRAM, MEM_5200.ASM), which PLAT_5200.ASM looks after.
; =====================================================================

; ---------------------------------------------------------------------
;  GTIA  ($C000)
; ---------------------------------------------------------------------
HPOSP0  =  $C000        ; W  player 0 horizontal position
HPOSP1  =  $C001
HPOSP2  =  $C002
HPOSP3  =  $C003
HPOSM0  =  $C004        ; W  missile 0 horizontal position
HPOSM1  =  $C005
HPOSM2  =  $C006
HPOSM3  =  $C007
SIZEP0  =  $C008        ; W  player sizes
SIZEP1  =  $C009
SIZEP2  =  $C00A
SIZEP3  =  $C00B
SIZEM   =  $C00C
GRAFP0  =  $C00D        ; W  player graphics (direct)
GRAFP1  =  $C00E
GRAFP2  =  $C00F
GRAFP3  =  $C010
GRAFM   =  $C011
TRIG0   =  $C010        ; R  joystick 0 trigger (0 = pressed)
TRIG1   =  $C011        ; R  joystick 1 trigger
TRIG2   =  $C012        ; R  controller 3 trigger
TRIG3   =  $C013        ; R  controller 4 trigger
COLPM0  =  $C012        ; W  player/missile colours
COLPM1  =  $C013
COLPM2  =  $C014
PAL     =  $C014        ; R  bits 1-3 = 0 on a PAL machine (the 5200
                        ;    is NTSC only)
COLPM3  =  $C015
COLPF0  =  $C016        ; W  playfield colours
COLPF1  =  $C017
COLPF2  =  $C018
COLPF3  =  $C019
COLBK   =  $C01A        ; W  background / border
PRIOR   =  $C01B        ; W  priority and GTIA modes
GRACTL  =  $C01D        ; W  graphics control
HITCLR  =  $C01E        ; W  clear collisions
CONSOL  =  $C01F        ; W  bit 2: controller pots on (the BIOS sets it)

; ---------------------------------------------------------------------
;  POKEY  ($E800)
; ---------------------------------------------------------------------
AUDF1   =  $E800        ; W  audio frequency / volume+distortion
AUDC1   =  $E801
AUDF2   =  $E802
AUDC2   =  $E803
AUDF3   =  $E804
AUDC3   =  $E805
AUDF4   =  $E806
AUDC4   =  $E807
AUDCTL  =  $E808        ; W  audio control
ALLPOT  =  $E808        ; R  pot lines still counting (1 = still low)
KBCODE  =  $E809        ; R  last keypad code
STIMER  =  $E809        ; W  restart timers
RANDOM  =  $E80A        ; R  random number
POTGO   =  $E80B        ; W  start a pot scan
SKREST  =  $E80A        ; W  reset SKSTAT
IRQEN   =  $E80E        ; W  IRQ enable
IRQST   =  $E80E        ; R  IRQ status
SKCTL   =  $E80F        ; W  serial / keyboard control
SKSTAT  =  $E80F        ; R  bit 2 = 0 while a key is held

; ---------------------------------------------------------------------
;  ANTIC  ($D400)
; ---------------------------------------------------------------------
DMACTL  =  $D400        ; W  DMA control
CHACTL  =  $D401        ; W  character control
DLISTL  =  $D402        ; W  display list pointer
DLISTH  =  $D403
HSCROL  =  $D404
VSCROL  =  $D405
PMBASE  =  $D407
CHBASE  =  $D409        ; W  character set base (page)
WSYNC   =  $D40A        ; W  wait for horizontal sync
VCOUNT  =  $D40B        ; R  scan line / 2
NMIEN   =  $D40E        ; W  NMI enable ($80 DLI, $40 VBI)
NMIST   =  $D40F        ; R  NMI status

; ANTIC display list instructions
DL_BLANK8 = $70         ; 8 blank lines
DL_BLANK6 = $50         ; 6 blank lines
DL_BLANK4 = $30         ; 4 blank lines
DL_BLANK2 = $10         ; 2 blank lines
DL_LMS    = $40         ; load memory scan (OR with mode)
DL_DLI    = $80         ; display list interrupt (OR with mode)
DL_JVB    = $41         ; jump and wait for vertical blank
DL_MODE2  = $02         ; 40 col text, 8 lines
DL_MODE4  = $04         ; 40 col 4-colour text, 8 lines
DL_MODE5  = $05         ; 40 col 4-colour text, 16 lines
DL_MODE6  = $06         ; 20 col 5-colour text, 8 lines
DL_MODE7  = $07         ; 20 col 5-colour text, 16 lines
DL_MODEA  = $0A         ; 80 x 4-line pixels, 4 colours, 20 bytes
DL_MODED  = $0D         ; 160 x 2-line pixels, 4 colours, 40 bytes

; DMACTL values
DMA_OFF   = $00
DMA_NORM  = $22         ; normal playfield + DL DMA
DMA_PM    = $0C         ; player + missile DMA, double-line resolution

; GRACTL values
GR_PM     = $03         ; enable players and missiles

; PRIOR values
PRI_MAP   = $01         ; all players over the playfield (D35)
PRI_5TH   = $10         ; missiles form a fifth player in COLPF3

; NMIEN values
NMI_VBI   = $40
NMI_DLI   = $80

; ---------------------------------------------------------------------
;  BIOS shadow registers (zero page) and vectors (RAM; written, never
;  called).  The BIOS's VBI copies the shadows to hardware each frame
;  and reads the pots into PADDL0-7.
; ---------------------------------------------------------------------
POKMSK  =  $00          ; POKEY IRQs enabled (shadow of IRQEN)
RTCLOK  =  $01          ; 2-byte frame clock
CRITIC  =  $03          ; critical section: the VBI skips its work
ATRACT  =  $04          ; attract-mode timer
SDLSTL  =  $05          ; shadow DLISTL
SDLSTH  =  $06
SDMCTL  =  $07          ; shadow DMACTL
PCOLR0  =  $08          ; shadow COLPM0-3
PCOLR1  =  $09
PCOLR2  =  $0A
PCOLR3  =  $0B
COLOR0  =  $0C          ; shadow COLPF0
COLOR1  =  $0D          ; shadow COLPF1
COLOR2  =  $0E          ; shadow COLPF2
COLOR3  =  $0F          ; shadow COLPF3
COLOR4  =  $10          ; shadow COLBK
PADDL0  =  $11          ; pots 0-7: controller 1 x, y, 2 x, y, ...
VIMIRQ  =  $0200        ; IRQ vector
VVBLKI  =  $0202        ; immediate VBI vector
VVBLKD  =  $0204        ; deferred VBI vector (BIOS: its VBI exit)
VDSLST  =  $0206        ; DLI vector
VKYBDI  =  $0208        ; keypad IRQ vector
VKYBDF  =  $020A        ; keypad deferred vector

; The 800's OS shadows the BIOS lacks: RAM bytes (MEM_5200.ASM's
; PLATRAM), copied to the hardware by PLAT_VBI (PLAT_5200.ASM)
CHBAS   =  PLATRAM      ; CHBASE, each frame
GPRIOR  =  PLATRAM+1    ; PRIOR, each frame
COLRSH  =  PLATRAM+2    ; attract colour shift: 0 for now (T-5200-3)
DRKMSK  =  PLATRAM+3    ; attract luminance mask: $FF for now

; BIOS character set (used only as data by ANTIC, never as code)
ROMFONT =  $F8
