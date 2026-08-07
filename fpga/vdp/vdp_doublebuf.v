//
//  vdp_doublebuf.v
//   Line buffer with double-buffering. Used by vga.v upscan conversion.
//   Traduccion a Verilog de vdp_doublebuf.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_doublebuf.vhd.
//
//-----------------------------------------------------------------------------
// Document
//
// JP: ダブルバッファリング機能付きラインバッファモジュール。
// JP: vga.vhdによるアップスキャンコンバートに使用します。
//
// JP: xPositionWに X座標を入れ，weを 1にすると書き込みバッファに
// JP: 書き込まれる．また，xPositionRに X座標を入れると，読み込み
// JP: バッファから読み出した色コードが qから出力される。
// JP: evenOdd信号によって，読み込みバッファと書き込みバッファが
// JP: 切り替わる。
//

module VDP_DOUBLEBUF (
    input  wire       CLK,
    input  wire [9:0] XPOSITIONW,
    input  wire [9:0] XPOSITIONR,
    input  wire       EVENODD,
    input  wire       WE,
    input  wire [5:0] DATARIN,
    input  wire [5:0] DATAGIN,
    input  wire [5:0] DATABIN,
    output wire [5:0] DATAROUT,
    output wire [5:0] DATAGOUT,
    output wire [5:0] DATABOUT
);

    wire       WE_E;
    wire       WE_O;
    wire [9:0] ADDR_E;
    wire [9:0] ADDR_O;
    wire [5:0] OUTR_E;
    wire [5:0] OUTG_E;
    wire [5:0] OUTB_E;
    wire [5:0] OUTR_O;
    wire [5:0] OUTG_O;
    wire [5:0] OUTB_O;

    // EVEN LINE
    VDP_LINEBUF U_BUF_RE (
        .ADDRESS (ADDR_E),
        .INCLOCK (CLK),
        .WE      (WE_E),
        .DATA    (DATARIN),
        .Q       (OUTR_E)
    );

    VDP_LINEBUF U_BUF_GE (
        .ADDRESS (ADDR_E),
        .INCLOCK (CLK),
        .WE      (WE_E),
        .DATA    (DATAGIN),
        .Q       (OUTG_E)
    );

    VDP_LINEBUF U_BUF_BE (
        .ADDRESS (ADDR_E),
        .INCLOCK (CLK),
        .WE      (WE_E),
        .DATA    (DATABIN),
        .Q       (OUTB_E)
    );

    // ODD LINE
    VDP_LINEBUF U_BUF_RO (
        .ADDRESS (ADDR_O),
        .INCLOCK (CLK),
        .WE      (WE_O),
        .DATA    (DATARIN),
        .Q       (OUTR_O)
    );

    VDP_LINEBUF U_BUF_GO (
        .ADDRESS (ADDR_O),
        .INCLOCK (CLK),
        .WE      (WE_O),
        .DATA    (DATAGIN),
        .Q       (OUTG_O)
    );

    VDP_LINEBUF U_BUF_BO (
        .ADDRESS (ADDR_O),
        .INCLOCK (CLK),
        .WE      (WE_O),
        .DATA    (DATABIN),
        .Q       (OUTB_O)
    );

    assign WE_E     = (EVENODD == 1'b0) ? WE : 1'b0;
    assign WE_O     = (EVENODD == 1'b1) ? WE : 1'b0;

    assign ADDR_E   = (EVENODD == 1'b0) ? XPOSITIONW : XPOSITIONR;
    assign ADDR_O   = (EVENODD == 1'b1) ? XPOSITIONW : XPOSITIONR;

    assign DATAROUT = (EVENODD == 1'b1) ? OUTR_E : OUTR_O;
    assign DATAGOUT = (EVENODD == 1'b1) ? OUTG_E : OUTG_O;
    assign DATABOUT = (EVENODD == 1'b1) ? OUTB_E : OUTB_O;

endmodule
