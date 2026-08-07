//
//  ram.v
//   256 bytes of block memory (+ palette_rb / palette_g con paleta MSX por defecto).
//   Traduccion a Verilog de ram.vhd.
//
//  Copyright (c) 2006 Kazuhiro Tsujikawa (ESE Artists' factory)
//  Licencia completa (redistribucion / disclaimer) en el original ram.vhd.
//
//  Nota: en el original palette_rb/palette_g usaban std_logic_vector(0 to 7) (bit
//  ascendente) pero el round-trip escritura/lectura y los valores init son
//  identicos a una RAM 8-bit normal; aqui son [7:0].
//-----------------------------------------------------------------------------

module ram (
    input  wire [7:0] adr,
    input  wire       clk,
    input  wire       we,
    input  wire [7:0] dbo,
    output wire [7:0] dbi
);
    reg [7:0] blkram [0:255];
    reg [7:0] iadr;

    always @(posedge clk) begin
        if (we == 1'b1)
            blkram[adr] <= dbo;
        iadr <= adr;
    end

    assign dbi = blkram[iadr];
endmodule


// Line buffer de sprites de 9 bits (V9968 sprite16): dato = {valido, plano[3:0], color[3:0]}.
// Igual que 'ram' pero 9 bits de ancho para alojar el numero de plano de 4 bits (16 planos).
module ram9 (
    input  wire [7:0] adr,
    input  wire       clk,
    input  wire       we,
    input  wire [8:0] dbo,
    output wire [8:0] dbi
);
    reg [8:0] blkram [0:255];
    reg [7:0] iadr;

    always @(posedge clk) begin
        if (we == 1'b1)
            blkram[adr] <= dbo;
        iadr <= adr;
    end

    assign dbi = blkram[iadr];
endmodule


module palette_rb (
    input  wire [7:0] adr,
    input  wire       clk,
    input  wire       we,
    input  wire [7:0] dbo,
    output wire [7:0] dbi
);
    reg [7:0] blkram [0:255];
    reg [7:0] iadr;
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1) blkram[i] = 8'h00;
        blkram[ 2]=8'h11; blkram[ 3]=8'h33; blkram[ 4]=8'h26; blkram[ 5]=8'h37;
        blkram[ 6]=8'h52; blkram[ 7]=8'h27; blkram[ 8]=8'h62; blkram[ 9]=8'h63;
        blkram[10]=8'h52; blkram[11]=8'h63; blkram[12]=8'h11; blkram[13]=8'h55;
        blkram[14]=8'h55; blkram[15]=8'h77;
    end

    always @(posedge clk) begin
        if (we == 1'b1)
            blkram[adr] <= dbo;
        iadr <= adr;
    end

    assign dbi = blkram[iadr];
endmodule


module palette_g (
    input  wire [7:0] adr,
    input  wire       clk,
    input  wire       we,
    input  wire [7:0] dbo,
    output wire [7:0] dbi
);
    reg [7:0] blkram [0:255];
    reg [7:0] iadr;
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1) blkram[i] = 8'h00;
        blkram[ 2]=8'h05; blkram[ 3]=8'h06; blkram[ 4]=8'h02; blkram[ 5]=8'h03;
        blkram[ 6]=8'h02; blkram[ 7]=8'h06; blkram[ 8]=8'h02; blkram[ 9]=8'h03;
        blkram[10]=8'h05; blkram[11]=8'h06; blkram[12]=8'h04; blkram[13]=8'h02;
        blkram[14]=8'h05; blkram[15]=8'h07;
    end

    always @(posedge clk) begin
        if (we == 1'b1)
            blkram[adr] <= dbo;
        iadr <= adr;
    end

    assign dbi = blkram[iadr];
endmodule
