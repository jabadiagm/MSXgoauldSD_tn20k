.ZILOG
.BIOS

.org #4760

	;call CHSNS						; BIOS keyStatus
	;ret  z
	;call CHGET						; BIOS readChar
	;cp   a, 'g'
	di
	ld   a, ROW_G ; Selecciona renglón de “G”
	out  (PPIC), a
	in   a, (PPIB)
	bit  COL_G, a
	jr   z, enter_menu				; 'G' pulsada (activa a nivel bajo)

	; Joystick 1: Izquierda + Trigger 1
	ld   a, 15						; PSG R#15: bit 6 = 0 -> puerto de joystick 1
	out  (PSG_ADDR), a
	in   a, (PSG_READ)
	and  #BF
	out  (PSG_WRITE), a
	ld   a, 14						; PSG R#14: estado del joystick (activo a nivel bajo)
	out  (PSG_ADDR), a
	in   a, (PSG_READ)
	and  JOY_LEFT | JOY_TRIG		; Z solo si ambos pulsados
enter_menu:
	ei
	ret  nz

	ld   hl, compressed_code
	ld   de, menu_main
	push de

decompressor:
;	.include "../src/dzx7mini.asm"
	.include "../src/dzx0_standard.asm"


; -----------------------------------------------------------------------------
; Compressed main menu code:
; -----------------------------------------------------------------------------
compressed_code:
;	.incbin "menu_main.zx7"
	.incbin "menu_main.zx0"

menu_main equ #8000

PPIB    equ  0xA9
PPIC    equ  0xAA

ROW_G   equ  0xF3

; Columna de “G” en puerto A → bit4 (Eje: 0=A/S/D/F/G → columna 4)
COL_G   equ  4

PSG_ADDR  equ  0xA0
PSG_WRITE equ  0xA1
PSG_READ  equ  0xA2

; Bits del PSG R#14 (joystick)
JOY_LEFT  equ  0x04
JOY_TRIG  equ  0x10