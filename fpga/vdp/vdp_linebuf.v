//
//  vdp_linebuf.v
//   Line buffer memory (used by the sprite / YJK line rendering).
//   Traduccion a Verilog de vdp_linebuf.vhd.
//
//  Copyright (C) 2006 Kunihiko Ohnaka - http://www.ohnaka.jp/ese-vdp/
//  Licencia completa (redistribucion / disclaimer) en el original vdp_linebuf.vhd.
//
//-----------------------------------------------------------------------------

module VDP_LINEBUF (
    input  wire [9:0] ADDRESS,
    input  wire       INCLOCK,
    input  wire       WE,
    input  wire [5:0] DATA,
    output wire [5:0] Q
);

    // Nota: solo se almacenan 5 bits (4:0); el bit bajo se descarta y se reintroduce
    // como '0' a la salida. Rango de datos requerido por el modo YJK.
    reg [4:0] IMEM [639:0];
    reg [9:0] IADDRESS;

    always @(posedge INCLOCK) begin
        if (WE == 1'b1) begin
            IMEM[ADDRESS] <= DATA[5:1];    // data range required by YJK mode
        end
        IADDRESS <= ADDRESS;
    end

    assign Q = { IMEM[IADDRESS], 1'b0 };

endmodule
