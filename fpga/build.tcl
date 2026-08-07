#-----------------------------------------------------------------------------
#  build.tcl - script de sintesis/PnR por linea de comandos (gw_sh)
#
#  Espejo del proyecto de la GUI (Z80_goauld.gprj). Si anades/quitas ficheros
#  en la GUI, actualiza tambien esta lista (o regenerala desde el .gprj).
#
#  Uso:   gw_sh build.tcl        (o via el Makefile: make)
#  Toolchain validado: Gowin 1.9.11.03 education (solo GowinSynthesis).
#  Salida:  impl/pnr/Z80_goauld.fs   ->  make flash
#
#  Modo del motor de comandos VDP: descomenta `define COMMAND_ACCURATE en
#  vdp/vdp_config.vh para el modo de precision (por defecto: modo rapido).
#-----------------------------------------------------------------------------

set_device GW2AR-LV18QN88C8/I7

add_file ikaopll/IKAOPLL.v
add_file ikaopll/IKAOPLL_dac.v
add_file ikaopll/IKAOPLL_eg.v
add_file ikaopll/IKAOPLL_lfo.v
add_file ikaopll/IKAOPLL_op.v
add_file ikaopll/IKAOPLL_pg.v
add_file ikaopll/IKAOPLL_primitives.v
add_file ikaopll/IKAOPLL_reg.v
add_file ikaopll/IKAOPLL_timinggen.v
add_file ikaopll/opll_ikaopll.v
add_file jtopl/jt2413.v
add_file jtopl/jtopl.v
add_file jtopl/jtopl2.v
add_file jtopl/jtopl_acc.v
add_file jtopl/jtopl_csr.v
add_file jtopl/jtopl_div.v
add_file jtopl/jtopl_eg.v
add_file jtopl/jtopl_eg_cnt.v
add_file jtopl/jtopl_eg_comb.v
add_file jtopl/jtopl_eg_ctrl.v
add_file jtopl/jtopl_eg_final.v
add_file jtopl/jtopl_eg_pure.v
add_file jtopl/jtopl_eg_step.v
add_file jtopl/jtopl_exprom.v
add_file jtopl/jtopl_lfo.v
add_file jtopl/jtopl_logsin.v
add_file jtopl/jtopl_mmr.v
add_file jtopl/jtopl_noise.v
add_file jtopl/jtopl_op.v
add_file jtopl/jtopl_pg.v
add_file jtopl/jtopl_pg_comb.v
add_file jtopl/jtopl_pg_inc.v
add_file jtopl/jtopl_pg_rhy.v
add_file jtopl/jtopl_pg_sum.v
add_file jtopl/jtopl_pm.v
add_file jtopl/jtopl_reg.v
add_file jtopl/jtopl_reg_ch.v
add_file jtopl/jtopl_sh.v
add_file jtopl/jtopl_sh_rst.v
add_file jtopl/jtopl_single_acc.v
add_file jtopl/jtopl_slot_cnt.v
add_file jtopl/jtopl_timers.v
add_file jtopl/jtopll_mmr.v
add_file jtopl/jtopll_reg.v
add_file jtopl/jtopll_reg_ch.v
add_file msx_debug/timing_debug.v
add_file pulse_min_max/pulse_max.v
add_file pulse_min_max/pulse_min.v
add_file src/bios_missing.v
add_file src/flash_rw.v
add_file src/gowin/clk_108p.v
add_file src/gowin/clk_135.v
add_file src/gowin_clkdiv/gowin_clkdiv.v
add_file src/hdmi/audio_clock_regeneration_packet.sv
add_file src/hdmi/audio_info_frame.sv
add_file src/hdmi/audio_sample_packet.sv
add_file src/hdmi/auxiliary_video_information_info_frame.sv
add_file src/hdmi/hdmi.sv
add_file src/hdmi/packet_assembler.sv
add_file src/hdmi/packet_picker.sv
add_file src/hdmi/serializer.sv
add_file src/hdmi/source_product_description_info_frame.sv
add_file src/hdmi/tmds_channel.sv
add_file src/impulse.v
add_file src/lpf_butter4_8k.v
add_file src/megaram.v
add_file src/memory.v
add_file src/msx2p_debug.v
add_file src/ocm/kanji.v
add_file src/ocm/rtc.v
add_file src/ram8k.v
add_file src/svf_biquad.v
add_file src/uart_tx.v
add_file src/wondertang/clockdiv.v
add_file src/wondertang/crc16.v
add_file src/wondertang/dpram.v
add_file src/wondertang/pinfilter.v
add_file src/wondertang/sd_reader.sv
add_file src/wondertang/sdcmd_ctrl.sv
add_file top.v
add_file vdp/ram.v
add_file vdp/vdp.v
add_file vdp/vdp_colordec.v
add_file vdp/vdp_command.v
add_file vdp/vdp_command_cache.v
add_file vdp/vdp_doublebuf.v
add_file vdp/vdp_graphic123m.v
add_file vdp/vdp_graphic4567.v
add_file vdp/vdp_hvcounter.v
add_file vdp/vdp_interrupt.v
add_file vdp/vdp_linebuf.v
add_file vdp/vdp_ntsc_pal.v
add_file vdp/vdp_register.v
add_file vdp/vdp_spinforam.v
add_file vdp/vdp_sprite.v
add_file vdp/vdp_sprite_m3.v
add_file vdp/vdp_ssg.v
add_file vdp/vdp_text12.v
add_file vdp/vdp_top.v
add_file vdp/vdp_vga.v
add_file vdp/vdp_wait_control.v
add_file vdp/vencode.v
add_file G80A/T80s.vhd
add_file G80A/g80a.vhd
add_file G80A/t80.vhd
add_file G80A/t80_alu.vhd
add_file G80A/t80_mcode.vhd
add_file G80A/t80_pack.vhd
add_file G80A/t80_reg.vhd
add_file PSG_YM2149/YM2149.vhdl
add_file denoise/denoise.vhd
add_file monostable/monostable.vhd
add_file src/gowin_clkdiv2/gowin_clkdiv2.vhd
add_file src/ocm/fifo.vhd
add_file src/ocm/lpf.vhd
add_file src/ocm/scc_wave2.vhd
add_file src/ocm/swioports.vhd
add_file src/ocm/uart_lite.vhd
add_file src/ocm/wifi_lite.vhd
add_file tang9k.cst
add_file Z80_goauld.sdc

set_option -use_sspi_as_gpio 1 -use_mspi_as_gpio 1 -top_module top -verilog_std sysv2017 -include_path "src;vdp"

run syn
run pnr
