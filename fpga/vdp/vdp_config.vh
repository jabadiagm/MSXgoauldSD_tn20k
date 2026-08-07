//
//  vdp_config.vh
//   Interruptor maestro de compilacion del nucleo VDP.
//
//   ENABLE_V9968 definido  => se compila toda la logica exclusiva del V9968
//     (sprite mode3, command cache, sprite16, paleta extendida 256 + alpha-blend,
//      nonR23, registros R#20/R#21). Sigue siendo seleccionable en runtime por
//      R#21.0 (arranca en modo V9958 por reset).
//
//   ENABLE_V9968 comentado => nucleo V9958 puro. El bit de modo R#21 queda fijo a
//     "V9958" en tiempo de compilacion, con lo que TODO el datapath V9968 se pliega
//     a constante y el sintetizador lo poda (libera FF/LUT/BSRAM). Se CONSERVA la
//     nueva distribucion de VRAM (palabra lineal 32b + interleave G6/G7), que es
//     ortogonal e incondicional.
//
//   NOTA: un `define en top.v NO llega a los ficheros del VDP (se compilan antes que
//   top.v). Por eso el interruptor vive en este header, incluido por vdp.v y
//   vdp_register.v (donde reside el bit maestro de modo).
//-----------------------------------------------------------------------------
`ifndef VDP_CONFIG_VH
`define VDP_CONFIG_VH

//`define ENABLE_V9968

// DIAGNOSTICO: descomenta la linea siguiente (o compila con -DSM3_DISABLE_ALPHA)
// para forzar los sprites mode3 OPACOS (ignora la transparencia) y ver los
// patrones/colores reales.
//`define SM3_DISABLE_ALPHA


`endif
