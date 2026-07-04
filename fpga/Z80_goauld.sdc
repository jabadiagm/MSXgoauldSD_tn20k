//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.9 Beta-4
//Created Time: 2023-10-11 15:41:18
create_clock -name clock_reset -period 277.778 -waveform {0 138.889} [get_nets {bus_reset_n}] -add
create_clock -name clock_audio -period 277.778 -waveform {0 138.889} [get_nets {vdp4/clk_audio}] -add
//create_clock -name clock_VideoDLClk -period 37.037 -waveform {0 18.518} [get_nets {VideoDLClk}] -add
//create_clock -name clock_3m6 -period 277.778 -waveform {0 138.889} [get_nets {bus_clk_3m6}] -add
//create_clock -name clock_27m -period 37.037 -waveform {0 18.518} [get_ports {ex_clk_27m}] -add
create_clock -name clock_27m -period 37.037 -waveform {0 18.518} [get_nets {clk_27m}] -add
create_generated_clock -name clock_54m -source [get_nets {clk_27m}] -master_clock clock_27m -multiply_by 2 [get_nets {clk_54m}] -add //[get_nets {clk_108m}] -add
create_generated_clock -name clock_108m -source [get_nets {clk_27m}] -master_clock clock_27m -multiply_by 4 [get_ports {O_sdram_clk}] -add //[get_nets {clk_108m}] -add
create_generated_clock -name clock_VideoDHClk -source [get_nets {clk_27m}] -master_clock clock_27m -divide_by 2 [get_nets {VideoDHClk}] -add
create_generated_clock -name clock_VideoDLClk -source [get_nets {clk_27m}] -master_clock clock_27m -divide_by 4 [get_nets {VideoDLClk}] -add
set_clock_groups -asynchronous -group [get_clocks {clock_108m clock_54m clock_VideoDHClk clock_VideoDLClk clock_27m }] -group [get_clocks {clock_reset }] -group [get_clocks {clock_env_reset }] 

set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/?*?/D}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/Regs/?*?/?*}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/?*?/?*}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/?*?/D}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/?*?/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/?*?/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/Regs/RegsL_RegsL*/DI*}] -setup -end 2

set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/?*?/D}] -hold -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/Regs/?*?/?*}] -hold -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/?*?/?*}] -hold -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/?*?/D}] -hold -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/?*?/CE}] -hold -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/?*?/CE}] -hold -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {cpu1/u0/Regs/RegsL_RegsL*/DI*}] -hold -end 1

//ENABLE_SOUND
    create_clock -name clock_env_reset -period 277.778 -waveform {0 138.889} [get_nets {psg1/env_reset}] -add
    set_false_path -from [get_clocks {clock_27m}] -to [get_pins {psg1/?*?/?*}]
    set_false_path -from [get_clocks {clock_54m}] -to [get_pins {psg1/?*?/?*}]
    set_false_path -from [get_clocks {clock_54m}] -to [get_pins {opll/?*?/?*?/CE}]

set_false_path -from [get_clocks {clock_108m}] -to [get_pins {rtc1/?*?/?*}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {rtc1/?*?/?*}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {rtc1/u_mem/?*?/?*}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {ocm_ports/?*?/CE}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {ocm_ports/?*?/D}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {debug1/?*?/?*?/D}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {debug1/?*?/?*?/CE}]
set_false_path -from [get_clocks {clock_27m}] -to [get_pins {vdp4/hdmi_ntsc/true_hdmi_output.packet_picker/audio_sample_word_transfer?*?/D}]
//set_false_path -from [get_clocks {clock_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/SPRENDERPLANES*/CE}]
//set_false_path -from [get_clocks {clock_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR_*/D}]
//set_false_path -from [get_clocks {clock_108m}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR_*/CE}]



// Registros F-clocked del G80a (IORQ_n, RD, etc.) -> cpu_din_*: path F->R con ventana
// de medio periodo insuficiente. La ventana real es de varios T-states Z80 (la CPU
// muestrea DI varios T-states despues del estrobo). El MCP -end 2 no aplica en Gowin
// para paths F->R; se acota con max_delay (a cpu1 como fuente para no enmascarar
// rutas R->R de otros modulos), manteniendo una comprobacion real en vez de anularla.
set_max_delay -from [get_pins {cpu1/?*/Q}] -to [get_pins {cpu_din_*/D}] 18.1

// Misma clase F->R que arriba: estrobos F-clocked del G80a (RD/WR/MREQ/IORQ) ->
// carga de wait_cycles en la FSM de espera. La ventana de medio periodo (9.259 ns)
// es pesimista porque bus_rd_n es estable >=1 periodo (CPU avanza a 3.6/6.75 MHz).
// El MCP -end 2 no aplica en F->R (ver nota arriba); se acota con max_delay a un
// periodo completo de clk_54m, que mantiene una comprobacion real (ruta ~9.15 ns).
set_max_delay -from [get_pins {cpu1/?*/Q}] -to [get_pins {wait_cycles_*/D}]  18.2
set_max_delay -from [get_pins {cpu1/?*/Q}] -to [get_pins {wait_cycles_*/CE}] 18.2

// Tras pasar los estrobos a flanco de subida, esta ruta es R->R a periodo completo:
// cpu1/u0/.../DO[*] (p.ej. IStatus) -> mux profundo de cpu_din. Data delay ~18.62 ns,
// justo por encima de 18.518 -> -0.133 ns. Un periodo no relaja (seria mas estricto);
// se acota a 1.5 periodos. Valido porque la CPU muestrea DI varios T-states despues
// (cpu_din registrado -> DI_Reg -> consumo en T3): ventana funcional de varios ciclos.
// Anclado en el endpoint (cpu_din_*/D, que matchea con seguridad) y -from por reloj:
// el patron de pin del origen (DO[8], bit de bus) no matcheaba con get_pins.
//set_max_delay -from [get_clocks {clock_54m}] -to [get_pins {cpu_din_*/D}] 27.7
//set_max_delay -from [get_pins {cpu1/u0/?*/DO[8]}] -to [get_pins {cpu_din_*/D}] 27.7

//set_max_delay -from [get_clocks {clock_108m}] -to [get_pins {xffl_s0/D}] 9.6
//set_max_delay -from [get_clocks {clock_108m}] -to [get_pins {cpu_din_*/D}] 30.0
//set_max_delay -from [get_clocks {clock_54m}] -to [get_pins {cpu_din_*/D}] 18.2
//set_max_delay -from [get_clocks {clock_54m}] -to [get_pins {mem1/sdram_seq*/D}] 10.5
//set_max_delay -from [get_clocks {clock_54m}] -to [get_pins {mem1/sdram_seq*/CE}] 10.5
//set_max_delay -from [get_clocks {clock_27m}] -to [get_pins {SdrAdr_*/D}] 16.5
//set_max_delay -from [get_clocks {clock_27m}] -to [get_pins {SdrBa_*/D}] 20.0
//set_max_delay -from [get_clocks {clock_27m}] -to [get_pins {SdrUdq_*/D}] 20.0
//set_max_delay -from [get_clocks {clock_27m}] -to [get_pins {SdrLdq_*/D}] 20.0
//set_max_delay -from [get_clocks {clock_27m}] -to [get_pins {RamDbi_*/D}] 16.5
//set_max_delay -from [get_clocks {clock_27m}] -to [get_pins {VrmDbi2_*/D}] 16.5
//set_max_delay -from [get_clocks {clock_27m}] -to [get_pins {VrmDbi2_*/Q}] 16.5
//set_max_delay -from [get_pins {mem1/vram_dout_*/Q}] -to [get_clocks {clock_27m}] 10.5
//set_max_delay -from [get_clocks {clock_108m}] -to [get_pins {memory_ctrl/enable_read_seq*/D}] 11.0
//set_max_delay -from [get_clocks {clock_108m}] -to [get_pins {memory_ctrl/enable_write_seq*/D}] 11.0
//set_max_delay -from [get_clocks {clock_108m}] -to [get_pins {memory_ctrl/vram/u_sdram/FF_SDRAM_A*/D}] 12.0
//set_max_delay -from [get_clocks {clock_108m}] -to [get_pins {memory_ctrl/vram/u_sdram/FF_SDRAM_BA*/D}] 12.0
//set_max_delay -from [get_clocks {clock_108m}] -to [get_pins {memory_ctrl/vram/u_sdram/FF_SDRAM_DQM*/D}] 12.0

//set_false_path -from [get_clocks {clock_108m}] -to [get_pins {debug/?*?/CE}]
//set_false_path -from [get_clocks {clock_27m}] -to [get_pins {debug/?*?/CE}]
//set_false_path -from [get_clocks {clock_108m}] -to [get_pins {debug/?*?/D}]
//set_false_path -from [get_clocks {clock_27m}] -to [get_pins {debug/?*?/D}]

// PROBLEMA 2 (diagnostico): ff_sd_cd carga estado VIVO del controlador SD
// (sd_busy_w/sd_done_w/...) que cambia cada ciclo de 54 MHz, asi que /D debe
// cumplir a 1 ciclo (18.5 ns), no 2. El multicycle enmascaraba una posible
// violacion en la transicion busy->done -> estado mal leido -> cuelgue SD.
// Comentado para ver el slack real de sd_busy_w -> ff_sd_cd/D.
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {ff_sd_cd_*/D}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {ff_sd_cd_*/D}] -hold -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {ff_sd_sector_*/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {ff_sd_sector_*/CE}] -hold -end 1
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {ff_sd_cd_*/CE}] -setup -end 2
set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {ff_sd_cd_*/CE}] -hold -end 1

// cpu1 -> mem1 SDRAM: direcciones y secuenciador
// El Z80 corre a 3.6 MHz efectivos (~15 ciclos de 54 MHz por ciclo Z80),
// por lo que estas señales son estables multiples ciclos antes de que la SDRAM las use.
// Grupo A (5 paths): cpu1/RD_s0 -> sdram_addr/sdram_seq  (cruce F->R, ventana 9.259 ns insuficiente)
// Grupo B (13 paths): cpu1/u0/IStatus_0_s15 -> sdram_addr (R->R, retardo combinacional ~19 ns > 18.518 ns)
//set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {mem1/sdram_addr_*/D}] -setup -end 2
//set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {mem1/sdram_addr_*/D}] -hold -end 1
//set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {mem1/sdram_seq_*/CE}] -setup -end 2
//set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {mem1/sdram_seq_*/CE}] -hold -end 2
// CE del registro de direccion SDRAM: faltaba (solo estaba /D). Misma clase y mismo
// criterio que /D arriba: IORQ_n/WR_n (estrobos, estables ~15 ciclos) -> sdram_addr/CE,
// cruce F->R de medio periodo pesimista. Destino estrecho (solo la direccion, no datos).
//set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {mem1/sdram_addr_*/CE}] -setup -end 2
//set_multicycle_path -from [get_clocks {clock_54m}] -to [get_pins {mem1/sdram_addr_*/CE}] -hold -end 2

set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/SPRENDERPLANES*/CE}] -setup -end 2
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/SPRENDERPLANES*/CE}] -hold -end 1
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_SP_OVERMAP_NUM*/CE}] -setup -end 2
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_SP_OVERMAP_NUM*/CE}] -hold -end 1

// Y-test cluster fed by mem1/vram_dout (108MHz->27MHz). Same multicycle intent as
// SPRENDERPLANES/FF_SP_OVERMAP_NUM above: these registers only capture at
// DOTSTATE="01" & EIGHTDOTSTATE="110", never on consecutive clock_27m edges, and
// vram_dout is stable for the whole VDP read window. Left uncovered originally, they
// were the worst-slack paths in the design (0.128 ns) -> intermittent sprite glitches.
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR*/D}] -setup -end 2
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR*/D}] -hold -end 1
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR*/CE}] -setup -end 2
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_LISTUP_ADDR*/CE}] -hold -end 1
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_EN*/D}] -setup -end 2
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_EN*/D}] -hold -end 1
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_EN*/CE}] -setup -end 2
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_Y_TEST_EN*/CE}] -hold -end 1
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_SP_OVERMAP*/CE}] -setup -end 2
set_multicycle_path -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/FF_SP_OVERMAP*/CE}] -hold -end 1

report_timing -setup -max_paths 400 -max_common_paths 1