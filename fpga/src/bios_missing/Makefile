.PHONY: all clean cleanbin

COL_WHITE = \e[1;37m
COL_RESET = \e[0m

DIRSRC = ./src
BINDIR = ./bin
DIROUT = ./out

BINASM = $(BINDIR)/asmsx -z -r

BIOSBIN  = ./bios_missing.bin
BIOSHEX  = ./bios_missing.hex
MENUMAIN = $(DIROUT)/main.z80

all: $(BIOSBIN) $(BIOSHEX)

# Compila main.asm (se copia a ./out para no ensuciar ./src; asMSX deja la
# salida junto al fuente).
$(MENUMAIN): $(DIRSRC)/main.asm
	@echo "$(COL_WHITE)###### Compiling main.asm$(COL_RESET)"
	@cp $(DIRSRC)/main.asm $(DIROUT)/
	$(BINASM) $(DIROUT)/ $(DIROUT)/main.asm
	@rm -rf $(DIROUT)/~tmppre.*

# BIOS de emergencia rellenada con 00 hasta 256 bytes: se parte de 256 ceros y se
# sobreescribe el binario compilado al principio (conv=notrunc mantiene el tamano).
$(BIOSBIN): $(MENUMAIN)
	@echo "$(COL_WHITE)###### Generating $(BIOSBIN) (256 bytes, zero-padded)$(COL_RESET)"
	@head -c 256 /dev/zero > $@
	@dd if=$(MENUMAIN) of=$@ bs=1 conv=notrunc 2>/dev/null

# Version hex (un byte por linea) para el $readmemh del modulo bios_missing.v
$(BIOSHEX): $(BIOSBIN)
	@echo "$(COL_WHITE)###### Generating $(BIOSHEX)$(COL_RESET)"
	@xxd -p -c1 $(BIOSBIN) > $@

cleanbin:
	@rm -rf $(BIOSBIN) $(BIOSHEX)

clean: cleanbin
	@rm -rf $(DIROUT)/*
