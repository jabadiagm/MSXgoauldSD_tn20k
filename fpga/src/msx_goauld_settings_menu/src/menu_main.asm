.ZILOG
.BIOS
.BIOSVARS

.org #8000

; ############## Initialization

	; Screen 0 / 80 columns
	ld   a, 80
	ld   (LINL40), a
	call INITXT
	; Blink mode on
	ld   bc, #4f0c
	call WRTVDP
	ld   bc, #100d
	call WRTVDP

	; Print menu title
	ld   hl,#1a02
	call POSIT						; BIOS setCursor
	ld   hl,menuTitleStr
	call print_string
	; clear area
	ld   a, #00
	ld   bc, 240
	ld   hl, #0800
	call FILVRM
	; Top header line
	ld   a, #ff
	ld   bc, 30
	ld   hl, #0800
	call FILVRM						; BIOS fill VRAM
	; FW version
	ld   hl, #1518
	call POSIT						; BIOS setCursor
	ld   hl, #7D40
	call print_string

	; Print menu options
	ld   ix, structs_start
	ld   (var_currentStruct), ix
.printmenu_loop:
	ld   a, (ix)
	or   a
	jr   z, .printmenu_loop_end
	call print_struct
	ld   bc, STRUCT_SIZE
	add  ix, bc
	jr   .printmenu_loop
.printmenu_loop_end:

	; Read Goauld settings
	di								; Set initial variables values

	ld   a, #48						; Set I/O device to Goauld (#48)
	out  (#40), a
	in   a, (#41)

	ld   b, a
	and  #01						; Bit 0: mapper enable
	ld   (var_mapper), a
	ld   a, b
	and  #02						; Bit 1: megaram enable
	rrca
	ld   (var_megram), a
	ld   a, b
	and  #04						; Bit 2: ghost scc enable
	rrca
	rrca
	ld   (var_ghtscc), a
	ld   a, b
	and  #08						; Bit 3: scanlines enable
	rrca
	rrca
	rrca
	ld   (var_scanln), a
	ld   a, b
	and  #30						; Bits5,4: mapper slot
	rrca
	rrca
	rrca
	rrca
	ld   (var_mapslt), a
	ld   a, b
	and  #c0						; Bits7,6: megaram slot
	rlca
	rlca
	ld   (var_megslt), a

	in   a, (#42)
	ld   b, a
	and  #01						; Bit 0: SD card enable
	ld   (var_sdcard), a
	ld   a, b
	and  #06						; Bits1,2: SD card slot
	rrca
	ld   (var_sdcslt), a
	ld   a, b
	and  #08						; Bit 3: slow device
	rrca
	rrca
	rrca
	ld   (var_slowdv), a
	ld   a, b
	and  #10						; Bit 4: turbo
	rrca
	rrca
	rrca
	rrca
	ld   (var_turbo), a

	ei

; ############## Main loop

bucle_repaint_selection:
	ld   a, #ff						; Print selection
	call print_selection

ONOFF_Y = 5
bucle:
	ld   hl,#2b00 + ONOFF_Y			; Print Enable Mapper
	ld   a,(var_mapper)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#2b00 + ONOFF_Y			; Print Enable Megaram
	ld   a,(var_megram)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#2b00 + ONOFF_Y			; Print Enable SD Card
	ld   a,(var_sdcard)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#2b00 + ONOFF_Y			; Print Ghost SCC
	ld   a,(var_ghtscc)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#2b00 + ONOFF_Y			; Print Enable Scanlines
	ld   a,(var_scanln)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#2b00 + ONOFF_Y			; Print Slow Device
	ld   a,(var_slowdv)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#2b00 + ONOFF_Y			; Print Turbo
	ld   a,(var_turbo)
	call print_on_off
ONOFF_Y = ONOFF_Y + 2

ONOFF_Y = 5
	ld   hl,#3c00 + ONOFF_Y			; Print Mapper Slot
	call POSIT						; BIOS setCursor
	ld   a,(var_mapslt)
	add  a,#30
	call CHPUT						; BIOS printChar
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#3c00 + ONOFF_Y			; Print MegaRam Slot
	call POSIT						; BIOS setCursor
	ld   a,(var_megslt)
	add  a,#30
	call CHPUT						; BIOS printChar
ONOFF_Y = ONOFF_Y + 2

	ld   hl,#3c00 + ONOFF_Y			; Print SD Card Slot
	call POSIT						; BIOS setCursor
	ld   a,(var_sdcslt)
	add  a,#30
	call CHPUT						; BIOS printChar
ONOFF_Y = ONOFF_Y + 2

	; Wait for a key
wait_for_a_key:
	ei
	halt
	call CHSNS						; BIOS keyStatus
	jr   z, wait_for_a_key
	call CHGET						; BIOS readChar
	or   a
	jr   z, wait_for_a_key

; ############## Keys handling

.key_lateral:
	sub  VT_RIGHT
	jr   z, .key_lateral_ok
	dec  a
	jr   nz, .key_up
.key_lateral_ok:
	ld   e, (ix+STRUCT_KEY_LATERAL)
	ld   d, (ix+STRUCT_KEY_LATERAL+1)
.new_selection:
	ld   a, 0						; Remove selection print
	call print_selection
	ld   ixl, e
	ld   ixh, d
	ld   (var_currentStruct), ix
	jp   bucle_repaint_selection

.key_up:
	dec  a
	jr   nz, .key_down
	ld   e, (ix+STRUCT_KEY_UP)
	ld   d, (ix+STRUCT_KEY_UP+1)
	jR   .new_selection

.key_down:
	dec  a
	jr   nz, .key_space
	ld   e, (ix+STRUCT_KEY_DOWN)
	ld   d, (ix+STRUCT_KEY_DOWN+1)
	jr   .new_selection

.key_space:
	ld   hl, bucle
	push hl
	dec  a
	ret  nz

	ld   l, (ix+STRUCT_SEL_ACTION)
	ld   h, (ix+STRUCT_SEL_ACTION+1)
	jp   (hl)

; ############## Actions

selected_mapper:
	ld   hl, var_mapper
	call .selected_on_off
	or   a
	ret  nz
	ld   a, 3
	ld   (var_mapslt), a
	ret

selected_megaRam:
	ld   hl, var_megram
	call .selected_on_off
	or   a
	ret  nz
	ld   a, 3
	ld   (var_megslt), a
	ret

selected_sdCard:
	ld   hl, var_sdcard
	call .selected_on_off
	ret

selected_slowdevice:
	ld   hl, var_slowdv
	call .selected_on_off
	ret

selected_slot1Ghost:
	ld   hl, var_ghtscc
	jp   .selected_on_off

selected_scanlines:
	ld   hl, var_scanln

.selected_on_off:
	ld   a, (hl)
	xor  1
	ld   (hl), a
	ret

selected_mapperSlot:
	ld   a, (var_mapper)				; If disabled then don't modify
	or   a
	ret  z
	ld   a, (var_megslt)				; Increase slot if not used by MegaRam
	cp   3
	jr   nz, .mp_skip
	xor  a
.mp_skip:
	ld   b, a
	ld   a, (var_mapslt)
.mp_used:
	inc  a
.mp_no_inc:
	cp   b
	jr   z, .mp_used

.mapperSlot_check:
	cp   4
	jr   nz, .mp_no4
	ld   a, #1
	jr   .mp_no_inc
.mp_no4:
	ld   (var_mapslt), a
	ret

selected_megaRamSlot:
	ld   a, (var_megram)				; If disabled then don't modify
	or   a
	ret  z
	ld   a, (var_mapslt)				; Increase slot if not used by Mapper
	cp   3
	jr   nz, .mr_skip
	xor  a
.mr_skip:
	ld   b, a
	ld   a, (var_megslt)
.mr_used:
	inc  a
.mr_no_inc:
	cp   b
	jr   z, .mr_used

.megaramSlot_check:
	cp   4
	jr   nz, .mr_no4
	ld   a, #1
	jr   .mr_no_inc
.mr_no4:
	ld   (var_megslt), a
	ret

selected_sdCardSlot:
	ret
	ld   a, (var_sdcard)				; If disabled then don't modify
	or   a
	ret  z
	ld   a, (var_mapslt)				; Increase slot if not used by Mapper nor MegaRam
	ld   b, a
	ld   a, (var_megslt)
	ld   c, a
	ld   a, (var_sdcslt)
.sd_used:
	inc  a
.sd_used_no_inc:
	cp   b
	jr   z, .sd_used
	cp   c
	jr   z, .sd_used
	cp   4
	jr   nz, .sd_no4
	ld   a, #1
	jr   .sd_used_no_inc
.sd_no4:
	ld   (var_sdcslt), a
	ret

selected_turbo:
	ld   hl, var_turbo
	ld   a, (hl)
	xor  1
	ld   (hl), a
	ret

selected_saveReset:
	pop  hl							; Remove ret to bucle
	call config_var2byte
	di
	ld   a, #48						; Set I/O device to Goauld (#48)
	out  (#40),a
	in   a, (#42)
	or   #C0						; Bit 7: reset, Bit 6: save config in flash
	out  (#42), a
	ei
	ret

selected_saveExit:
	pop  hl							; Remove ret to bucle

config_var2byte:
	ld   a, (var_mapper)			; #41 Bit 0: mapper enable
	ld   b, a
	ld   a, (var_megram)			; #41 Bit 1: megaram enable
	rlca
	or   b
	ld   b, a
	ld   a, (var_ghtscc)			; #41 Bit 2: ghost scc enable
	rlca
	rlca
	or   b
	ld   b, a
	ld   a, (var_scanln)			; #41 Bit 3: scanlines enable
	rlca
	rlca
	rlca
	or   b
	ld   b, a
	ld   a, (var_mapslt)			; #41 Bits5,4: mapper slot
	rlca
	rlca
	rlca
	rlca
	or   b
	ld   b, a
	ld   a, (var_megslt)			; #41 Bits7,6: megaram slot
	rlca
	rlca
	rlca
	rlca
	rlca
	rlca
	or   b
	ld   b, a

	ld   c, #41
	call set_settings

	ld   a, (var_sdcard)			; #42 Bit 0: SD Card enable
	ld   b, a
	ld   a, (var_sdcslt)			; #42 Bits2,1: SD Card slot
	rlca
	or   b
	ld   b, a

	ld   a, (var_slowdv)			; #42 Bit 3: slow device
	rlca
	rlca
	rlca
	or   b
	ld   b, a
	ld   a, (var_turbo)			; #42 Bit 4: turbo
	rlca
	rlca
	rlca
	rlca
	or   b
	or   #40						; Bit 6: save config in flash
	ld   b, a

	ld   c, #42
	call set_settings

	call INITXT						; BIOS clearScreen
	ld   bc, #000d					; Blink mode off
	jp   WRTVDP

set_settings:
	di
	ld   a, #48						; Set I/O device to Goauld (#48)
	out  (#40),a
	ld   a, b
	out  (c),a
	reti

; Prints characters from memory until a 0 is found.
; Input    : HL - The text address
print_string:
	ld   a,(hl)
	or   a
	ret  z
	inc  hl
	call CHPUT						; BIOS printChar
	jr   print_string

; Set the cursor to L,H position and prints 'Off'/'On ' if A is 0 or not.
; Input    : H  - Y coordinate of cursor
;            L  - X coordinate of cursor
;            A  - Value to print (0:Off 1:On)
print_on_off:
	ld   b, a
	call POSIT						; BIOS setCursor
	ld   a, b
	ld   hl,offStr
	or   a
	jr   z,print_on_off_end
	ld   hl,onStr
print_on_off_end:
	jr   print_string

; Print the text of a struct
; Input    : IX - Struct address
print_struct:
	ld   l, (ix+STRUCT_POSXY+1)
	ld   h, (ix+STRUCT_POSXY)
	call POSIT						; BIOS setCursor
	ld   l, (ix+STRUCT_TEXT)
	ld   h, (ix+STRUCT_TEXT+1)
	jr   print_string

; Print the selection highlight on/off
; Input    : A  - 0:off #ff:on
print_selection:
	ld   ix, (var_currentStruct)
	ld   b, 0
	ld   c, (ix+STRUCT_SEL_LEN)
	ld   l, (ix+STRUCT_SEL_START)
	ld   h, (ix+STRUCT_SEL_START+1)
	jp   FILVRM


; ############## Constants

menuTitleStr:
	.db "MSX Goa'uld Settings Menu v1.24",0
enableMapperStr:
	.db "Enable Mapper",0
enableMegaRamStr:
	.db "Enable MegaRam SCC",0
enableSDStr:
	.db "Enable SD",0
slot1GhostStr:
	.db "Ghost SCC",0
enableScanlinesStr:
	.db "Enable Scanlines",0
slowDeviceStr:
	.db "Compatible Mode",0
turboStr:
	.db "Turbo",0
saveExitStr:
	.db "Save & Exit",0
saveResetStr:
	.db "Save & Reset",0
slotStr:
	.db "Slot",0

onStr:
	.db "On ",0
offStr:
	.db "Off",0


; ############## Structs

STRUCT_POSXY		equ		0
STRUCT_TEXT			equ		STRUCT_POSXY + 2
STRUCT_KEY_UP		equ		STRUCT_TEXT + 2
STRUCT_KEY_DOWN		equ		STRUCT_KEY_UP + 2
STRUCT_KEY_LATERAL	equ		STRUCT_KEY_DOWN + 2
STRUCT_SEL_START	equ		STRUCT_KEY_LATERAL + 2
STRUCT_SEL_LEN		equ		STRUCT_SEL_START + 2
STRUCT_SEL_ACTION	equ		STRUCT_SEL_LEN + 1

STRUCT_SIZE			equ		STRUCT_SEL_ACTION + 2	; Struct size

POS_Y = 4

structs_start:
struct_EnableMapper:
	.db 21, POS_Y+1
	.dw enableMapperStr
	.dw struct_SaveReset, struct_EnableMegaRam, struct_MapperSlot
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_mapper
POS_Y = POS_Y + 2

struct_EnableMegaRam:
	.db 21, POS_Y+1
	.dw enableMegaRamStr
	.dw struct_EnableMapper, struct_EnableSD, struct_MegaRamSlot
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_megaRam
POS_Y = POS_Y + 2

struct_EnableSD:
	.db 21, POS_Y+1
	.dw enableSDStr
	.dw struct_EnableMegaRam, struct_Slot1GhostSCC, struct_SDSlot
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_sdCard
POS_Y = POS_Y + 2

struct_Slot1GhostSCC:
	.db 21, POS_Y+1
	.dw slot1GhostStr
	.dw struct_EnableSD, struct_EnableScanlines, struct_Slot1GhostSCC
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_slot1Ghost
POS_Y = POS_Y + 2

struct_EnableScanlines:
	.db 21, POS_Y+1
	.dw enableScanlinesStr
	.dw struct_Slot1GhostSCC, struct_SlowDevice, struct_EnableScanlines
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_scanlines
POS_Y = POS_Y + 2

struct_SlowDevice:
	.db 21, POS_Y+1
	.dw slowDeviceStr
	.dw struct_EnableScanlines, struct_Turbo, struct_SlowDevice
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_slowdevice
POS_Y = POS_Y + 2

struct_Turbo:
	.db 21, POS_Y+1
	.dw turboStr
	.dw struct_SlowDevice, struct_SaveExit, struct_Turbo
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_turbo
POS_Y = POS_Y + 2

struct_SaveExit:
	.db 21, POS_Y+1
	.dw saveExitStr
	.dw struct_Turbo, struct_SaveReset, struct_SaveExit
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_saveExit
POS_Y = POS_Y + 2

struct_SaveReset:
	.db 21, POS_Y+1
	.dw saveResetStr
	.dw struct_SaveExit, struct_EnableMapper, struct_SaveReset
	.dw #0800 + POS_Y*10 + 2
	.db 4
	.dw selected_saveReset
POS_Y = POS_Y + 2

POS_Y = 4

struct_MapperSlot:
	.db 54, POS_Y+1
	.dw slotStr
	.dw struct_SaveReset, struct_MegaRamSlot, struct_EnableMapper
	.dw #0800 + POS_Y*10 + 6
	.db 2
	.dw selected_mapperSlot
POS_Y = POS_Y + 2

struct_MegaRamSlot:
	.db 54, POS_Y+1
	.dw slotStr
	.dw struct_MapperSlot, struct_SDSlot, struct_EnableMegaRam
	.dw #0800 + POS_Y*10 + 6
	.db 2
	.dw selected_megaRamSlot
POS_Y = POS_Y + 2

struct_SDSlot:
	.db 54, POS_Y+1
	.dw slotStr
	.dw struct_MegaRamSlot, struct_Slot1GhostSCC, struct_EnableSD
	.dw #0800 + POS_Y*10 + 6
	.db 2
	.dw selected_sdCardSlot
POS_Y = POS_Y + 2

structs_end:
	.db 0


; ############## Variables

	var_mapper: ds 1
	var_megram: ds 1
	var_sdcard: ds 1
	var_ghtscc: ds 1
	var_scanln: ds 1
	var_mapslt: ds 1
	var_slowdv: ds 1
	var_turbo: ds 1
	var_megslt: ds 1
	var_sdcslt: ds 1

	var_currentStruct: ds 2


; ############## MSX VT-52 Character Codes

VT_BEEP    equ	#07		; A beep sound
VT_RETURN  equ	#0d		; 13,"M"	; Carriage return
VT_RIGHT   equ	#1c		; 27,"C"	; Cursor right
VT_LEFT    equ	#1d		; 27,"D"	; Cursor left
VT_UP      equ	#1e		; 27,"A"	; Cursor up
VT_DOWN    equ	#1f		; 27,"B"	; Cursor down
VT_SPACE   equ	#20		; Space
VT_CLRSCR  equ	#0c		; 27,"E"	; Clear screen:	Clears the screen and moves the cursor to home
VT_HOME    equ	#0b		; 27,"H"	; Cursor home:	Move cursor to the upper left corner.
