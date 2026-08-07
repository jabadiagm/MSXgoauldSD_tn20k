module svf_biquad #(
    parameter integer DW = 12,      // ancho del dato con signo
    parameter integer F  = 16,      // bits fraccionarios internos
    parameter integer FC = 122,     // 2*sin(pi*fc/fs) * 2^F
    parameter integer QC = 50166    // (1/Q) * 2^F
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 en,
    input  wire signed [DW-1:0] x,
    output wire signed [DW-1:0] y     // salida paso-bajo
);
    localparam integer G  = 4;              // bits de guarda
    localparam integer AW = DW + F + G;
    localparam integer KW = 18;             // signo + 17 bits (cabe QC)

    localparam signed [AW-1:0] SAT_MAX = (1 <<< (DW-1)) - 1;   //  2047
    localparam signed [AW-1:0] SAT_MIN = -(1 <<< (DW-1));      // -2048

    reg  signed [AW-1:0] lp, bp;
    wire signed [KW-1:0] f1 = FC;
    wire signed [KW-1:0] q1 = QC;

    wire signed [AW-1:0] x_ext = $signed(x) <<< F;

    // lp' = lp + f1*bp            (bp antiguo)
    wire signed [AW+KW-1:0] p_fbp = f1 * bp;
    wire signed [AW-1:0]    lp_n  = lp + (p_fbp >>> F);
    // hp  = x - lp' - q1*bp
    wire signed [AW+KW-1:0] p_qbp = q1 * bp;
    wire signed [AW-1:0]    hp_n  = x_ext - lp_n - (p_qbp >>> F);
    // bp' = f1*hp + bp
    wire signed [AW+KW-1:0] p_fhp = f1 * hp_n;
    wire signed [AW-1:0]    bp_n  = (p_fhp >>> F) + bp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)   begin lp <= 0; bp <= 0; end
        else if (en)  begin lp <= lp_n; bp <= bp_n; end
    end

    // parte entera + saturación (Butterworth sobrepica ~11 % en el escalón)
    wire signed [AW-1:0] lp_int = lp >>> F;
    assign y = (lp_int > SAT_MAX) ? SAT_MAX[DW-1:0] :
               (lp_int < SAT_MIN) ? SAT_MIN[DW-1:0] :
                                    lp_int[DW-1:0];
endmodule