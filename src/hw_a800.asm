; =====================================================================
;  HW_A800.ASM -- Atari 400/800/XL/XE hardware and OS equates
;
;  All machine-specific addresses live here so that a later Atari 5200
;  build can swap in an HW_5200.ASM with the same symbol names.
;  Game code must not call OS ROM routines; it may only touch the
;  shadow registers and vectors defined below.
; =====================================================================

; ---------------------------------------------------------------------
;  GTIA  ($D000)
; ---------------------------------------------------------------------
HPOSP0  =  $D000        ; W  player 0 horizontal position
HPOSP1  =  $D001
HPOSP2  =  $D002
HPOSP3  =  $D003
HPOSM0  =  $D004        ; W  missile 0 horizontal position
HPOSM1  =  $D005
HPOSM2  =  $D006
HPOSM3  =  $D007
SIZEP0  =  $D008        ; W  player sizes
SIZEP1  =  $D009
SIZEP2  =  $D00A
SIZEP3  =  $D00B
SIZEM   =  $D00C
GRAFP0  =  $D00D        ; W  player graphics (direct)
GRAFP1  =  $D00E
GRAFP2  =  $D00F
GRAFP3  =  $D010
GRAFM   =  $D011
TRIG0   =  $D010        ; R  joystick 0 trigger (0 = pressed)
TRIG1   =  $D011        ; R  joystick 1 trigger
TRIG2   =  $D012        ; R  (400/800 only)
TRIG3   =  $D013        ; R  (400/800 only; XL: cart sense)
COLPM0  =  $D012        ; W  player/missile colours
COLPM1  =  $D013
COLPM2  =  $D014
PAL     =  $D014        ; R  bits 1-3 = 0 on a PAL machine
COLPM3  =  $D015
COLPF0  =  $D016        ; W  playfield colours
COLPF1  =  $D017
COLPF2  =  $D018
COLPF3  =  $D019
COLBK   =  $D01A        ; W  background / border
PRIOR   =  $D01B        ; W  priority and GTIA modes
GRACTL  =  $D01D        ; W  graphics control
HITCLR  =  $D01E        ; W  clear collisions
CONSOL  =  $D01F        ; R  START/SELECT/OPTION (0 = pressed)

; ---------------------------------------------------------------------
;  POKEY  ($D200)
; ---------------------------------------------------------------------
AUDF1   =  $D200        ; W  audio frequency / volume+distortion
AUDC1   =  $D201
AUDF2   =  $D202
AUDC2   =  $D203
AUDF3   =  $D204
AUDC3   =  $D205
AUDF4   =  $D206
AUDC4   =  $D207
AUDCTL  =  $D208        ; W  audio control
ALLPOT  =  $D208        ; R  pot lines still counting (1 = still low)
KBCODE  =  $D209        ; R  last keyboard code
STIMER  =  $D209        ; W  restart timers
RANDOM  =  $D20A        ; R  random number
POTGO   =  $D20B        ; W  start a pot scan
SKREST  =  $D20A        ; W  reset SKSTAT
IRQEN   =  $D20E        ; W  IRQ enable
IRQST   =  $D20E        ; R  IRQ status
SKCTL   =  $D20F        ; W  serial / keyboard control
SKSTAT  =  $D20F        ; R  bit 2 = 0 while a key is held

; ---------------------------------------------------------------------
;  PIA  ($D300)
; ---------------------------------------------------------------------
PORTA   =  $D300        ; R  joysticks: lo nibble stick 0, hi stick 1
PORTB   =  $D301        ; XL/XE: memory control
PACTL   =  $D302
PBCTL   =  $D303

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
DL_LMS    = $40         ; load memory scan (OR with mode)
DL_DLI    = $80         ; display list interrupt (OR with mode)
DL_JVB    = $41         ; jump and wait for vertical blank
DL_MODE2  = $02         ; 40 col text, 8 lines
DL_MODE4  = $04         ; 40 col 4-colour text, 8 lines
DL_MODE5  = $05         ; 40 col 4-colour text, 16 lines
DL_MODE6  = $06         ; 20 col 5-colour text, 8 lines
DL_MODE7  = $07         ; 20 col 5-colour text, 16 lines
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
;  OS shadow registers and vectors (RAM; written, never called)
;  The OS VBI copies these to hardware each frame.
; ---------------------------------------------------------------------
RTCLOK  =  $12          ; 3-byte frame clock (LSB at $14)
ATRACT  =  $4D          ; attract-mode timer
DRKMSK  =  $4E          ; attract-mode luminance mask (OS)
COLRSH  =  $4F          ; attract-mode colour shift (OS)
VDSLST  =  $0200        ; DLI vector
VVBLKI  =  $0222        ; immediate VBI vector
VVBLKD  =  $0224        ; deferred VBI vector
SDMCTL  =  $022F        ; shadow DMACTL
SDLSTL  =  $0230        ; shadow DLISTL
SDLSTH  =  $0231
GPRIOR  =  $026F        ; shadow PRIOR
STICK0  =  $0278
STICK1  =  $0279
STRIG0  =  $0284
STRIG1  =  $0285
PCOLR0  =  $02C0        ; shadow COLPM0-3
PCOLR1  =  $02C1
PCOLR2  =  $02C2
PCOLR3  =  $02C3
COLOR0  =  $02C4        ; shadow COLPF0
COLOR1  =  $02C5        ; shadow COLPF1
COLOR2  =  $02C6        ; shadow COLPF2
COLOR3  =  $02C7        ; shadow COLPF3
COLOR4  =  $02C8        ; shadow COLBK
CHBAS   =  $02F4        ; shadow CHBASE
CH      =  $02FC        ; last key pressed ($FF = none)

; DOS load-file run vector
RUNAD   =  $02E0
INITAD  =  $02E2

; OS character set (used only as data by ANTIC, never as code)
ROMFONT =  $E0
