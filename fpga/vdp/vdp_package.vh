//
//  vdp_package.vh
//   Traduccion a Verilog del package de ESE-VDP (vdp_package.vhd).
//   Copyright (C) 2000-2006 Kunihiko Ohnaka - http://www.ohnaka.jp/ese-vdp/
//   Licencia completa (redistribucion / disclaimer) en el original vdp_package.vhd.
//
//   En VHDL esto era un PACKAGE con constantes compartidas. En Verilog se
//   distribuye como header con localparams, incluido con `include "vdp_package.vh"`
//   dentro de cada modulo que en VHDL hacia USE WORK.VDP_PACKAGE.ALL.
//
//   NOTA: en el original CLOCKS_PER_LINE/HALF eran SHARED VARIABLE mutables que
//   hvcounter reasignaba segun PAL (1728/864) y se propagaban a ssg/ntsc_pal/vga/vdp.
//   En la traduccion a Verilog NO estan aqui: cada uno de esos 5 modulos acoplados
//   las declara como wire local a partir de su señal PAL:
//       wire [11:0] CLOCKS_PER_LINE      = PAL ? 12'd1728 : 12'd1716;
//       wire [11:0] CLOCKS_PER_HALF_LINE = PAL ? 12'd864  : 12'd858;
//   (En estado estable PAL/NTSC es identico al shared variable original.)
//-----------------------------------------------------------------------------

    // LEFT-TOP POSITION OF VISIBLE AREA
    localparam [6:0] OFFSET_X = 7'b0110101; // 49

    localparam integer LED_TV_X_NTSC = -20;
    localparam integer LED_TV_Y_NTSC = 1;
    localparam integer LED_TV_X_PAL  = -20;
    localparam integer LED_TV_Y_PAL  = 3;

    localparam integer LEFT_BORDER = 255;

    localparam integer V_BLANKING_START_192_NTSC = 240;
    localparam integer V_BLANKING_START_212_NTSC = 250;
    localparam integer V_BLANKING_START_192_PAL  = 263;
    localparam integer V_BLANKING_START_212_PAL  = 273;
