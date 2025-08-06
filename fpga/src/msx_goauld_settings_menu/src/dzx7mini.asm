; -----------------------------------------------------------------------------
; ZX7 mini by Einar Saukas, Antonio Villena
; "Standard" version (43/39 bytes only)
; -----------------------------------------------------------------------------
; Parameters:
;   HL: source address (compressed data)
;   DE: destination address (decompressing)
; -----------------------------------------------------------------------------
dzx7:
	ld      a, $80
.copyby:
	ldi
.mainlo:
	call    .getbit
	jr      nc, .copyby
	ld      bc, 1
.lenval:
	call    .getbit
	rl      c
	ret     c
	call    .getbit
	jr      nc, .lenval
	push    hl
	ld      l, (hl)
	ld      h, b
	push    de
	ex      de, hl
	sbc     hl, de
	pop     de
	ldir
	pop     hl
	inc     hl
	jr      .mainlo
.getbit:
	add     a, a
	ret     nz
	ld      a, (hl)
	inc     hl
	adc     a, a
	ret
