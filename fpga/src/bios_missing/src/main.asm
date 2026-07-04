.ZILOG
.BIOS
.BIOSVARS

.org #0000

; ############## Initialization

bios_missing:
	di
	in   a, (#99)				; resetea el latch de registro/direccion del VDP

	; --- Programa R0..R7 del VDP para TEXT1 (SCREEN 0), pantalla apagada ---
	ld   hl, vdp_init_tab
	ld   c, 0
.reg_loop:
	ld   a, (hl)
	inc  hl
	out  (#99), a				; dato del registro
	ld   a, c
	or   #80
	out  (#99), a				; 0x80 | nº de registro
	inc  c
	ld   a, c
	cp   8
	jr   nz, .reg_loop

	; --- Carga las 8 glifos en la tabla de patrones @ 0x0800 ---
	ld   a, #00					; direccion VRAM = 0x0800, modo escritura
	out  (#99), a
	ld   a, #48					; 0x40 (write) | 0x08 (byte alto)
	out  (#99), a
	ld   hl, font_data
	ld   b, 8*8					; 8 glifos x 8 bytes
.font_loop:
	ld   a, (hl)
	out  (#98), a
	inc  hl
	djnz .font_loop

	; --- Limpia la tabla de nombres (40x24 = 960) con el glifo 0 (espacio) ---
	xor  a						; direccion VRAM = 0x0000, modo escritura
	out  (#99), a
	ld   a, #40
	out  (#99), a
	ld   bc, 960
.clear_loop:
	xor  a
	out  (#98), a
	dec  bc
	ld   a, b
	or   c
	jr   nz, .clear_loop

	; --- Escribe "Bios Missing" centrado (fila 11, col 14 -> 0x01C6) ---
	ld   a, #C6
	out  (#99), a
	ld   a, #41					; 0x40 (write) | 0x01 (byte alto)
	out  (#99), a
	ld   hl, msg
	ld   b, msg_len
.msg_loop:
	ld   a, (hl)
	out  (#98), a
	inc  hl
	djnz .msg_loop

	; --- Enciende la pantalla (R1 bit6) ---
	ld   a, #D0					; 16K + display ON + M1 (text)
	out  (#99), a
	ld   a, #81					; 0x80 | 1
	out  (#99), a

.hang:
	jr   .hang

; R0..R7 (R1 con display OFF; se enciende tras cargar la VRAM)
vdp_init_tab:
	.db #00		; R0: TEXT1
	.db #90		; R1: 16K + M1 (text), display OFF
	.db #00		; R2: tabla de nombres @ 0x0000
	.db #00		; R3: (tabla de color, no usada en TEXT1)
	.db #01		; R4: generador de patrones @ 0x0800
	.db #00		; R5: (atrib. sprites, no usado)
	.db #00		; R6: (gen. sprites, no usado)
	.db #F2		; R7: texto blanco (F) sobre el fondo actual (indice 2 = tu rojo)

; Indices de glifo: 0=espacio 1=B 2=i 3=o 4=s 5=M 6=n 7=g
msg:
	.db 1,2,3,4, 0, 5,2,4,4,2,6,7	; "Bios Missing"
msg_len equ 12

; Fuente 8x8 (bit7 = pixel izquierdo)
font_data:
	.db #00,#00,#00,#00,#00,#00,#00,#00	; 0 espacio
	.db #F8,#84,#84,#F8,#84,#84,#F8,#00	; 1 B
	.db #10,#00,#10,#10,#10,#10,#10,#00	; 2 i
	.db #00,#00,#78,#84,#84,#84,#78,#00	; 3 o
	.db #00,#00,#7C,#80,#78,#04,#F8,#00	; 4 s
	.db #84,#CC,#AC,#84,#84,#84,#84,#00	; 5 M  (6px: barra dcha en bit2, no bit1)
	.db #00,#00,#B8,#C4,#84,#84,#84,#00	; 6 n
	.db #00,#00,#7C,#84,#84,#7C,#04,#78	; 7 g

