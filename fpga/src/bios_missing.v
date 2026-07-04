// ===========================================================================
// bios_missing.v
// ROM de 256 x 8 bits con la BIOS de emergencia ("Bios Missing").
//
// El contenido se carga via $readmemh desde bios_missing.bin.hex (un byte por
// linea, generado por el Makefile de src/bios_missing a partir del .bin de 256
// bytes). $readmemh necesita texto hex; el .bin raw no se puede leer directamente,
// por eso se usa el .hex (misma convencion que logo.v / *.bin.hex del proyecto).
//
// NOTA: la ruta del $readmemh es relativa al directorio de trabajo de la sintesis
// (Gowin). Si no se resuelve, ajustar a la ruta correcta (p.ej. nombre a secas si
// el .hex esta en el dir de trabajo, como hace logo.v con "16k_logo.hex").
// ===========================================================================
module bios_missing (
    input  wire        clk,
    input  wire [7:0]  addr,
    output wire [7:0]  dout
);

    reg [7:0] mem_r [0:255];
    reg [7:0] q_r;

    initial begin
        $readmemh("bios_missing.hex", mem_r);
    end

    always @(posedge clk) begin
        q_r <= mem_r[addr];
    end

    assign dout = q_r;

endmodule
