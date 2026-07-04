rem msx2+ internacional kanji disk fm_logo
echo ---^| ROM Configuration (Goa'uld 0.92) ^|------------------------
echo -----------------------------------------------------------------------------
echo I/O          128kB  JIS1    .ROM
echo I/O          128kB  JIS2    .ROM
echo 3-2 (4000h)  128kB  NEXTOR  .ROM
echo 0-0 (0000h)   32kB  MSX2P   .ROM
echo 3-1 (0000h)   16kB  MSX2PEXT.ROM
echo 3-1 (4000h)   16kB  FMLOGO  .ROM
echo 0-1 (4000h)   32kB  MSXKANJI.ROM
echo 0-2 (4000h)   16kB  ESP8266 .ROM
echo 0-3 (4000h)   16kB  FREE16KB.ROM
echo                6b   CONFIG  .ROM
echo -----------------------------------------------------------------------------
copy /b a1xxjis1.rom + a1xxjis2.rom + Nextor-2.1.4.WonderTANG.ROM + 32k_msx2p_int_fix.bin + 16k_msx2p_subrom.bin + 16k_msx2p_fm_logo_menu.bin + knmsxppl.rom + esp8266e.rom + 16k_ff.bin + 6b_config.bin goauld_rom_int.bin
copy /b a1xxjis1.rom + a1xxjis2.rom + Nextor-2.1.4.WonderTANG.ROM + a1wsxyen.rom + 2pextrtc.rom + 16k_msx2p_fm_logo_menu.bin + knmsxppl.rom + esp8266e.rom + 16k_ff.bin + 6b_config.bin goauld_rom_japan.bin