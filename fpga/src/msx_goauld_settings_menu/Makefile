.PHONY: all menu orig clean cleanrom

COL_RED = \e[1;31m
COL_YELLOW = \e[1;33m
COL_ORANGE = \e[1;38:5:208m
COL_BLUE = \e[1;34m
COL_GRAY = \e[1;30m
COL_WHITE = \e[1;37m
COL_RESET = \e[0m


DIRSRC = ./src
BINDIR = ./bin
DIROUT = ./out
ASSETS = ./assets

BINASM = $(BINDIR)/asmsx -z -r
BINZX7 = $(BINDIR)/zx7mini
BINZX0 = $(BINDIR)/zx0 -f
BINPLETTER = $(BINDIR)/pletter

MENUBIN = $(DIROUT)/menu.z80
MENUMAIN = $(DIROUT)/menu_main.z80
ROMBIN = ./fm_logo_menu.bin
ROMEMPTY = $(ASSETS)/16k_msx2p_fm_logo_menu.bin
ADDRESS = 0x4760
ADDRESSBIN_2 = $(shell echo "$$(( $(ADDRESS) - 0x4000 ))" | bc)
ADDRESSBIN = 1888

rom: cleanrom $(ROMBIN)

orig: $(DIRSRC)/menu_orig.asm
	@echo "$(COL_WHITE)###### Compiling $@$(COL_RESET)"
	@cp $^ $(DIROUT)/
	$(BINASM) $(DIROUT)/ $(DIROUT)/menu_orig.asm
	@rm $(DIROUT)/~tmppre.*
	@echo "###### Creating ROM"
	@cp $(ROMEMPTY) $(ROMBIN)
	@dd if="$(DIROUT)/menu_orig.z80" of="$(ROMBIN)" bs=1 seek=$(ADDRESSBIN) conv=notrunc > /dev/null

$(MENUMAIN): $(DIRSRC)/menu_main.asm
	@echo "$(COL_WHITE)###### Compiling menu_main.asm$(COL_RESET)"
	@rm -rf $(DIROUT)/menu_main.zx7
	@cp $(DIRSRC)/menu_main.asm $(DIROUT)/
	$(BINASM) $(DIROUT)/ $(DIROUT)/menu_main.asm
	@rm -rf $(DIROUT)/~tmppre.* $(DIROUT)/*.zx0  $(DIROUT)/*.zx7
	
	@echo "$(COL_WHITE)###### Compressing with ZX7$(COL_RESET)"
	@$(BINZX7) $(DIROUT)/menu_main.z80 $(DIROUT)/menu_main.zx7
	
	@echo "$(COL_WHITE)###### Compressing with ZX0$(COL_RESET)"
	@$(BINZX0) $(DIROUT)/menu_main.z80 $(DIROUT)/menu_main.zx0
	
	@echo "$(COL_WHITE)###### Compressing with PLETTER$(COL_RESET)"
	@$(BINPLETTER) $(DIROUT)/menu_main.z80 $(DIROUT)/menu_main.pletter

$(MENUBIN): $(MENUMAIN) $(DIRSRC)/menu.asm
	@echo "$(COL_WHITE)###### Compiling menu.asm$(COL_RESET)"
	@cp $(DIRSRC)/menu.asm $(DIROUT)/
	$(BINASM) $(DIROUT)/ $(DIROUT)/menu.asm
	@rm -rf $(DIROUT)/~tmppre.*

$(ROMBIN): $(MENUBIN)
	@echo "$(COL_WHITE)###### Creating ROM$(COL_RESET)"
	@cp $(ROMEMPTY) $@
	@dd if="$^" of="$@" bs=1 seek=$(ADDRESSBIN) conv=notrunc > /dev/null


test: $(ROMBIN)
	@echo "$(COL_BLUE)###### Testing with openMSX$(COL_RESET)"
	openmsx -machine msx2plus -carta $^ -script emulation/boot.tcl

menuscr:
	@echo "$(COL_BLUE)###### Editing menu screen $(COL_RESET)"
#	openmsx -machine turbor -script emulation/boot.tcl -diska assets/menu_screen
	openmsx -machine msx2plus -script emulation/boot.tcl -diska assets/menu_screen

cleanrom:
	@rm -rf $(ROMBIN)

clean: cleanrom
	@rm -rf $(DIROUT)/*