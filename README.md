# MSXgoauldSD_tn20k
MSX Goa'uld board with Tang Nano 20k and SD support

![V1.5_SMD](/pics/V1_5_smd.jpg)

MSX2+ engine in Z80 socket. It turns one MSX into an MSX2+ by replacing Z80 processor. FPGA in board contains: 
* Z80
* V9958 with hdmi output
* MSX2+ BIOS
* SD Card support + Nextor 2.1
* 4MB mapper
* 2MB megaram SCC
* RTC
* PSG
* OPLL


## Boards

Old boards V1.4 and V4.1 are compatible with Goa'uld SD. V3 is not supported, owners of V3 should use Goa'uld standard firmware (0.80).

New pcb V1.5 is same as 1.4, optimized for online PCB assembly. See [Assembly guide](/blob/main/pcba.md)


## Slot map

![Slot map](/pics/mapa_slots3.png)

Mapper and megaram can be relocated to slots 1, 2, or 3 using config menu.

## Megaram + Sofarun
Megaram is detected automatically by sofarun using default settings. When using other software you may need to indicate location, Slot 0-2 by default.


## Configuration
Config menu is showed pressing g during MSX logo. New improved menu is created by [nataliapc](https://github.com/nataliapc/msx_goauld_settings_menu)

![Config](/pics/config.png)

* Enable Mapper: On by default. Disable when having compatibility issues or to use a different mapper
* Enable Megaram: On by default. Disable when having compatibility issues or to use a different megaram
* Enable SD: On by default. Disable when using an external SD mapper
* Mapper Slot: 0 by default. Change to 1-3 to get mapper in a not expanded slot (best compatibility). Physical slot will be disabled
* Megaram Slot: 0 by default. Change to 1-3 to get megaram in a not expanded slot (best compatibility). Physical slot will be disabled
* SD Bios Slot: 3 by default. Change to 1-2 to free slot 3. Physical slot will be disabled
* Ghost SCC: Off by default. Enable to get sound from an SCC cartridge located in slot 1-3
* Enable Scanlines: On by default. Disable to get a clean hdmi picture
* Slow Device: Off by default. Enable if you experience crashes / unstabilities
* Save & Exit: store new config and continue, changes in mapper settings will be effective after pressing reset
* Save & Reset: store new config and make software reset, changes will be immediate

## Known issues
* Reset from config menu is not compatible with some hardware. Use physical reset button when possible
* Multimente: shows garbage characters. Move internal mapper to slots 1, 2 or 3
* Tape games fail: move internal mapper to slots 1, 2 or 3
* Carnivore C2+ is not compatible with Slow Device mode


## Flashing
Progamming is done in two steps:
* Flash firmware Z80_goauld.fs
![Flash1](/pics/flashing1.png)
* Flash disk rom. Goa'uld SD uses same driver as Wondertang, Nextor-2.1.1.WonderTANG.ROM.bin. Set Operation = "exFlash C Bin Erase, Program thru GAO-Bridge" and Start Address = 0x100000 
![Flash2](/pics/flashing2.png)
![Flash3](/pics/flashing3.png)

> [!WARNING]
> Not yet fully working on all MSX!
>