org #7d40
	call  CHSNS
	ret z
	call read_char
	cp a,#67
	ret nz

	;load variables in ram
	ld a,(var1_init)
	ld (var1),a
	ld a,(var2_init)
	ld (var2),a
	ld a,(var3_init)
	ld (var3),a
	ld a,(var4_init)
	ld (var4),a
	ld a,(var5_init)
	ld (var5),a
	ld a,(var6_init)
	ld (var6),a
	ld a,(var7_init)
	ld (var7),a
	ld a,(var8_init)
	ld (var8),a

	;print menu
	ld hl,#0101
	call set_cursor
	ld hl,menu1
	call print_string
	ld hl,menu2
	call print_string

	;main loop
bucle:
	;print var1
	ld hl,#1402
	call set_cursor
	ld a,(var1)
	ld hl,off
	or a
	jr z,sigue1
	ld hl,on
sigue1:
	call print_string

	;print var2
	ld hl,#1403
	call set_cursor
	ld a,(var2)
	add a,#30
	call print_char


	;print var3
	ld hl,#1404
	call set_cursor
	ld a,(var3)
	ld hl,off
	or a
	jr z,sigue3
	ld hl,on
sigue3:
	call print_string

	;print var4
	ld hl,#1405
	call set_cursor
	ld a,(var4)
	add a,#30
	call print_char


	;print var5
	ld hl,#1406
	call set_cursor
	ld a,(var5)
	ld hl,off
	or a
	jr z,sigue5
	ld hl,on
sigue5:
	call print_string

	;print var6
	ld hl,#1407
	call set_cursor
	ld a,(var6)
	ld hl,off
	or a
	jr z,sigue6
	ld hl,on
sigue6:
	call print_string

	;print var7
	ld hl,#1408
	call set_cursor
	ld a,(var7)
	ld hl,off
	or a
	jr z,sigue7
	ld hl,on
sigue7:
	call print_string

	;print var8
	ld hl,#1409
	call set_cursor
	ld a,(var8)
	add a,#30
	call print_char

	call  CHSNS
	jr z, bucle2
	call read_char
	or a
	jr z, bucle2

	cp a,#31
	jr nz,tecla2
	
	ld a,(var1)
	xor 1
	ld (var1),a
bucle2:
	jp bucle_largo

tecla2:
	cp a,#32
	jr nz,tecla3
	
	ld a,(var2)
	inc a
	cp a,4
	jr nz,no2
	xor a
no2:
	ld (var2),a
	jr bucle_largo	

tecla3:
	cp a,#33
	jr nz,tecla4
	
	ld a,(var3)
	xor 1
	ld (var3),a
	jr bucle_largo

tecla4:
	cp a,#34
	jr nz,tecla5
	
	ld a,(var4)
	inc a
	cp a,4
	jr nz,no4
	xor a
no4:
	ld (var4),a
	jr bucle_largo	

tecla5:	
	cp a,#35
	jr nz,tecla6
	
	ld a,(var5)
	xor 1
	ld (var5),a
	jr bucle_largo

tecla6:	
	cp a,#36
	jr nz,tecla7
	
	ld a,(var6)
	xor 1
	ld (var6),a
	jr bucle_largo

tecla7:	
	cp a,#37
	jr nz,tecla8
	
	ld a,(var7)
	xor 1
	ld (var7),a
	jr bucle_largo

tecla8:
	cp a,#38
	jr nz,tecla9
	
	ld a,(var8)
	inc a
	cp a,4
	jr nz,no8
	xor a
	inc a
no8:
	ld (var8),a
	jr bucle_largo	

tecla9:
	cp a,#39
	jr nz,tecla0
	call send_config
	ret

tecla0:
	cp a,#30
	jr nz,bucle_largo
	call send_config
	or a,#80
	out (#42),a
	ret	

bucle_largo:
	jp bucle

send_config:
	ld a,#48
	out (#40),a

	ld a,(var1)
	ld b,a

	ld a,(var3)
	sla a
	or b
	ld b,a

	ld a,(var5)
	sla a
	sla a
	or b
	ld b,a

	ld a,(var6)
	sla a
	sla a
	sla a
	or b
	ld b,a

	ld a,(var2)
	sla a
	sla a
	sla a
	sla a
	or b
	ld b,a

	ld a,(var4)
	sla a
	sla a
	sla a
	sla a
	sla a
	sla a
	or b

	out (#41),a

	ld a,(var7)
	ld b,a

	ld a,(var8)
	sla a
	or b
	
	out (#42),a

	ret

;msx
print_char equ #00a2
set_cursor equ #00C6
read_char equ #009f
CHSNS equ #009C

;amstrad
;print_char equ #bb5a
;set_cursor equ #bb75
;read_char equ #bb09

print_string:
	ld a,(hl)
	cp 255
	ret z
	inc hl
	call print_char
	jr print_string


var1_init: db 1	;1-Enable Mapper
var2_init: db 0 ;2-Mapper Slot
var3_init: db 1 ;3-Enable Megaram
var4_init: db 0	;4-Megaram Slot
var5_init: db 0	;5-Slot1 Ghost SCC
var6_init: db 1	;6-Enable Scanlines
var7_init: db 1 ;7-Enable SD Card
var8_init: db 3	;8-SD Card Slot


var1 equ #8000
var2 equ #8001
var3 equ #8002
var4 equ #8003
var5 equ #8004
var6 equ #8005
var7 equ #8006
var8 equ #8007


menu1: db 'Goauld Config',#0d,#0a,'1-Enable Mapper',#0d,#0a,'2-Mapper Slot',#0d,#0a,'3-Enable Megaram',#0d,#0a,'4-Megaram Slot',#0d,#0a,'5-Slot1 Ghost SCC',#0d,#0a,255
menu2: db '6-Enable Scanlines',#0d,#0a,'7-Enable SD Card',#0d,#0a,'8-SD Card Slot',#0d,#0a,'9-Save & Exit',#0d,#0a,'0-Save & Reset',255
on: db 'On ',255
off: db 'Off',255