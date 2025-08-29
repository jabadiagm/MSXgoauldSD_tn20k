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