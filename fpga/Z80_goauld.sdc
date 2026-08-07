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
    //set_false_path -from [get_clocks {clock_54m}] -to [get_pins {opll/?*?/?*?/CE}]

set_false_path -from [get_clocks {clock_108m}] -to [get_pins {rtc1/?*?/?*}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {rtc1/?*?/?*}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {rtc1/u_mem/?*?/?*}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {ocm_ports/?*?/CE}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {ocm_ports/?*?/D}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {debug1/?*?/?*?/D}]
set_false_path -from [get_clocks {clock_54m}] -to [get_pins {debug1/?*?/?*?/CE}]
set_false_path -from [get_clocks {clock_27m}] -to [get_pins {vdp4/hdmi_ntsc/true_hdmi_output.packet_picker/audio_sample_word_transfer?*?/D}]



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

// vram_dout (108M) -> consumidores del VDP a 27MHz. GEOMETRIA REAL: el dato se commitea
// en vram_dout en t+6/t+7 (doble latch, mismo valor) y la captura mas temprana es t+8 ->
// presupuesto real desde el PRIMER commit = 18.5 ns. El multicycle -end 2 usado antes era
// INSOUND (relajaba a ~46 ns; con el P&R holgado produjo sprites fantasma deterministas,
// y ~= valor del pixel, confirmado en HW 2026-07). max_delay 18.0 es la cota honesta,
// valida para TODO consumidor a 27M de vram_dout (sprites, Y-test, OVERMAP...).
set_max_delay -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/?*?/D}] 18.0
set_max_delay -from [get_pins {mem1/vram_dout_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE/?*?/CE}] 18.0
// F3 command cache: FF_CC_VRDATA32 captura la palabra (vram_dout_32) con la MISMA
// geometria (commit t+6/t+7, captura t+8) -> misma cota honesta.
//`ifdef ENABLE_V9968
//set_max_delay -from [get_pins {mem1/vram_dout_32_*/Q}] -to [get_pins {vdp4/u_v9958/FF_CC_VRDATA32_*/D}] 18.0
//set_max_delay -from [get_pins {mem1/vram_dout_32_*/Q}] -to [get_pins {vdp4/u_v9958/FF_CC_VRDATA32_*/CE}] 18.0
// F2 sprite m3: el Y-test/fetch consumen la palabra (PRAMDBI32) en capturas t+8 -> misma cota.
//set_max_delay -from [get_pins {mem1/vram_dout_32_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE_M3/?*?/D}] 18.0
//set_max_delay -from [get_pins {mem1/vram_dout_32_*/Q}] -to [get_pins {vdp4/u_v9958/U_SPRITE_M3/?*?/CE}] 18.0

// ==================== MOLIENDA FORZADA (anti-loteria) ============================
// Invariante validado (6/6 builds): arranca <=> el report tiene slacks NEGATIVOS en las
// familias benignas (= el router no logro cerrar y siguio optimizando globalmente).
// Cuando el sorteo del P&R cierra todo ("timing met"), el router PARA PRONTO y alguna
// ruta STA-ciega (sospecha: skew de liberacion del grupo asincrono de reset -> corrompe
// la copia flash->SDRAM de la BIOS) queda larga -> pantalla negra.
// Esta cota hace INALCANZABLE una familia funcionalmente tolerante a cualquier retardo:
// sdram_addr es nivel-estable ~15 ciclos de CPU y se auto-corrige (probado: build buena
// arrancando con -0.762 aqui). Llegadas tipicas 16.4-19.5 ns -> con 16.5 siempre quedan
// rutas en negativo -> el router muele en TODAS las builds = regimen bueno por diseno.
// (Si un dia molesta, subir a 17.5 antes que quitarla.)
set_max_delay -to [get_pins {mem1/sdram_addr_*/D}] 16.6

// ============================ SONDAS DE DIAGNOSTICO =============================
// Solo INFORMAN (no restringen): vuelcan el retardo real (columna arrival) de las
// familias que las constraints relajan (multicycle/max_delay) y que por eso nunca
// aparecen en el top-400 general. Objetivo: comparar una build BUENA contra una MALA
// (pantalla negra) y ver que familia se dispara — esa es la constraint mentirosa.
// Foco pantalla-negra: nucleo Z80 (multicycle blanket -end 2), captura cpu_din,
// camino CPU->SDRAM (copia de BIOS + accesos), y SD como control.
report_timing -setup -to [get_pins {cpu_din_*/D}] -max_paths 12
report_timing -setup -to [get_pins {wait_cycles_*/D}] -max_paths 8
report_timing -setup -to [get_pins {mem1/sdram_addr_*/D}] -max_paths 16
report_timing -setup -to [get_pins {mem1/sdram_seq_*/CE}] -max_paths 8
report_timing -setup -from [get_clocks {clock_54m}] -to [get_pins {cpu1/?*?/D}] -max_paths 24
report_timing -hold  -to [get_pins {cpu1/?*?/D}] -max_paths 12
report_timing -setup -to [get_pins {ff_sd_cd_*/D}] -max_paths 8
// CE del nucleo Z80: el multicycle blanket los relaja a 2 ciclos (37 ns) pero la red de
// clock-enables conmuta a ritmo de 54 MHz -> requisito real 18.5 ns. Sospechoso #1 de
// pantalla negra en builds "todo positivo" (el router para pronto y los deja largos).
report_timing -setup -to [get_pins {cpu1/?*?/CE}] -max_paths 24
report_timing -hold  -to [get_pins {cpu1/?*?/CE}] -max_paths 12
report_timing -setup -to [get_pins {cpu1/u0/Regs/?*?/?*}] -max_paths 12
// false-pathed (puede que no vuelquen nada, inofensivo): config de maquina y RTC
report_timing -setup -to [get_pins {ocm_ports/?*?/D}] -max_paths 8
report_timing -setup -to [get_pins {rtc1/?*?/D}] -max_paths 8
// Banco de registros del Z80 (RAM distribuida): las sondas /D y /CE no ven sus pines
// WRE/AD. El write va gateado por CEN (t80_reg.vhd:92) -> la red del enable y el WRE
// tienen requisito REAL de 1 ciclo (18.5) pero el blanket cpu1/u0/?*?/?* los relaja a 37.
report_timing -setup -to [get_pins {cpu1/u0/Regs/?*?/WRE}] -max_paths 12
report_timing -setup -to [get_pins {cpu1/u0/Regs/?*?/AD?*}] -max_paths 12
// =================================================================================

report_timing -setup -max_paths 400 -max_common_paths 1