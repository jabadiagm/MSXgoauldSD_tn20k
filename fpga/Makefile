#-----------------------------------------------------------------------------
#  Makefile - build / flash del bitstream por linea de comandos (Linux)
#
#    make          sintesis + PnR (gw_sh build.tcl)  ->  impl/pnr/Z80_goauld.fs
#    make flash    graba el .fs en la Tang Nano 20K   (openFPGALoader)
#    make clean    borra impl/
#
#  Ajusta GW_SH_PATH a tu instalacion de Gowin (toolchain validado:
#  1.9.11.03 education; solo GowinSynthesis). LD_PRELOAD de libfontconfig es
#  un apaño para arrancar gw_sh en algunas distros Linux; puede sobrar.
#
#-----------------------------------------------------------------------------

GW_SH_PATH?=/home/chandler/gowin-ide/IDE/bin/gw_sh
LIBFONT_CONFIG?=lib/libfontconfig.so.1

.PHONY: all flash clean

all:
	LD_PRELOAD=$(LIBFONT_CONFIG) $(GW_SH_PATH) build.tcl

flash: impl/pnr/Z80_goauld.fs
	sudo openFPGALoader -b tangnano20k -f --verify $<

clean:
	rm -rf impl
