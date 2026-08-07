module lpf_butter4_8k #(
    parameter integer DW = 12
)(
    input  wire                 clk,     // 27 MHz
    input  wire                 rst_n,
    input  wire                 en,      // '1' si fs = 27 MHz
    input  wire signed [DW-1:0] x_in,
    output wire signed [DW-1:0] y_out
);
    localparam integer F   = 16;
    localparam integer FC  = 122;        // fc = 8 kHz @ fs = 27 MHz
    localparam integer QC1 = 121109;     // Q = 0.54120
    localparam integer QC2 = 50166;      // Q = 1.30656

    wire signed [DW-1:0] y1;

    svf_biquad #(.DW(DW), .F(F), .FC(FC), .QC(QC1)) etapa1
        (.clk(clk), .rst_n(rst_n), .en(en), .x(x_in), .y(y1));

    svf_biquad #(.DW(DW), .F(F), .FC(FC), .QC(QC2)) etapa2
        (.clk(clk), .rst_n(rst_n), .en(en), .x(y1),   .y(y_out));
endmodule