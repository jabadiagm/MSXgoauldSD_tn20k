.ZILOG
.BIOS

.org #4760

	call CHSNS						; BIOS keyStatus
	ret  z
	call CHGET						; BIOS readChar
	cp   a, 'g'
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
