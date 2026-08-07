//
//  opll_ikaopll.v
//   Wrapper que expone la MISMA interfaz que jt2413 (jtopl/jt2413.v) y por dentro
//   adapta al core IKAOPLL de Raki (ciclo-exacto, BSD-2). Objetivo: sustituir el
//   OPLL en top.v cambiando solo el nombre del modulo instanciado, de forma
//   reversible (el jt2413 se deja comentado para comparar).
//
//   Interfaz jt2413  ->  IKAOPLL
//     rst  (activo alto) -> i_IC_n = ~rst          (IC_n activo bajo)
//     clk  (27 MHz)      -> i_XIN_EMUCLK           (reloj del sistema)
//     cen  (3.58 MHz pos)-> i_phiM_PCEN_n = ~cen   (enable de phiM, logica negativa)
//     din/addr/cs_n/wr_n -> i_D/i_A0/i_CS_n/i_WR_n (bus directo)
//     snd  (signed 16b)  <- o_ACC_SIGNED           (acumulador+mixer interno, signed)
//     sample             <- o_ACC_SIGNED_STRB      (strobe de muestra)
//
//   Volumen del mixer interno (5b con signo): defaults del README (+2 melodia,
//   +3 percusion). Parametrizados para poder ajustar balance/ganancia sin tocar
//   top.v. La salida es signed 16b, igual formato que jt2413.snd.
//
//   Nota: durante el reset (i_IC_n=0) el enable phiM debe seguir pulsando; en el
//   sistema, cen (clk_enable_3m6_27) pulsa siempre, asi que ~cen tambien. El reset
//   de sistema dura de sobra los >=18 ciclos que pide con FAST_RESET=1.
//
module opll_ikaopll #(
    // Volumen del acumulador interno (5b con signo, max +15). Cada canal vale +-255 y se
    // multiplica por estos factores (IKAOPLL_dac.v:142). Los defaults del README (+2/+3)
    // dejan el OPLL a ~14% de fondo de escala = casi inaudible frente al jt2413.
    // Subidos x5 manteniendo la relacion melodia:percusion 2:3 (10:15). Nivel melodia ~70%
    // de escala (9*255*10=22950), percusion ~19k. AJUSTAR AQUI el volumen del OPLL:
    //   - mas alto:  hasta 14/15 (max; ~= nivel del jt2413).
    //   - mas bajo:  reducir ambos proporcionalmente.
    parameter signed [4:0] MOVOL = 5'sd15,  // volumen melodia (synth)
    parameter signed [4:0] ROVOL = 5'sd15   // volumen percusion (rhythm)
)(
    input                rst,        // activo alto (igual que jt2413)
    input                clk,        // reloj de sistema (27 MHz)
    input                cen,        // enable a 3.58 MHz (positivo, igual que jt2413)
    input         [ 7:0] din,
    input                addr,
    input                cs_n,
    input                wr_n,
    output signed [15:0] snd,
    output               sample
);

    IKAOPLL #(
        .FULLY_SYNCHRONOUS        (1),   // solo DFF (Gowin: evita latches)
        .FAST_RESET               (1),   // reset a ritmo de emuclk (18 ciclos phiM)
        .ALTPATCH_CONFIG_MODE     (0),   // patches YM2413 estandar (no VRC7)
        .USE_PIPELINED_MULTIPLIER (0)    // 0 = multiplicador combinacional (1 crasheaba el mapeador de GowinSynthesis; a esta tasa gateada por phi1ncen_n sobra fmax)
    ) u_ikaopll (
        .i_XIN_EMUCLK             (clk),
        .o_XOUT                   (),

        .i_phiM_PCEN_n            (~cen),          // enable de phiM (logica negativa)

        .i_IC_n                   (~rst),          // reset (IC_n activo bajo)

        .i_ALTPATCH_EN            (1'b0),          // sin patches VRC7

        .i_CS_n                   (cs_n),
        .i_WR_n                   (wr_n),
        .i_A0                     (addr),

        .i_D                      (din),
        .o_D                      (),              // read-back de status (no usado en MSX-MUSIC)
        .o_D_OE                   (),

        // salidas de DAC / raw del chip real: no usadas (usamos el acumulador interno)
        .o_DAC_EN_MO              (),
        .o_DAC_EN_RO              (),
        .o_IMP_NOFLUC_SIGN        (),
        .o_IMP_NOFLUC_MAG         (),
        .o_IMP_FLUC_SIGNED_MO     (),
        .o_IMP_FLUC_SIGNED_RO     (),

        // acumulador+mixer interno de 16b con signo = formato de jt2413.snd
        .i_ACC_SIGNED_MOVOL       (MOVOL),
        .i_ACC_SIGNED_ROVOL       (ROVOL),
        .o_ACC_SIGNED_STRB        (sample),
        .o_ACC_SIGNED             (snd)
    );

endmodule
