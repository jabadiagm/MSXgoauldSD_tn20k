//
//  vdp_spinforam.v
//   Sprite information table memory.
//   Traduccion a Verilog de vdp_spinforam.vhd.
//
//  Copyright (C) 2006 Kunihiko Ohnaka - http://www.ohnaka.jp/ese-vdp/
//  Licencia completa (redistribucion / disclaimer) en el original vdp_spinforam.vhd.
//
//-----------------------------------------------------------------------------
// Document
//
// JP: 次の行で表示するスプライトの情報を保持するテーブルです。
// JP: テーブルには以下の情報を保持します。
//
// Sprite informations. (Total 31bits)
//   X        (9bit)
//   pattern  (16 bit)
//   color    (4bit)
//   cc       (1bit)
//   ic       (1bit)
//

module VDP_SPINFORAM (
    input  wire [ 3:0] ADDRESS,   // V9968 sprite16: 16 entradas (antes 3 bits / 8 entradas)
    input  wire        INCLOCK,
    input  wire        WE,
    input  wire [31:0] DATA,
    output wire [31:0] Q
);

    reg [31:0] IMEM [15:0];
    reg [ 3:0] IADDRESS;

    always @(posedge INCLOCK) begin
        if (WE == 1'b1) begin
            IMEM[ADDRESS] <= DATA;
        end
        IADDRESS <= ADDRESS;
    end

    assign Q = IMEM[IADDRESS];

endmodule
