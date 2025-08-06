module psg_filter
(
	input wire clk_27m,
	input wire reset,
    input wire [7:0] data_in,
	output wire [7:0] data_out
);

wire [11:0] opll_wav;
wire [11:0] opll_wav1;
wire [11:0] opll_wav2;
wire [11:0] opll_wav3;
wire [11:0] opll_wav4;


//generated clocks

reg clk_enable_2m7;
reg clk_enable_270k;
reg [3:0] clk_2m7_counter = 4'd0;
reg [7:0] clk_270k_counter = 4'd0;

always @ (posedge clk_27m) begin
    clk_enable_2m7 <= 0;
    clk_enable_270k <= 0;
    clk_2m7_counter <= clk_2m7_counter + 1;
    clk_270k_counter <= clk_270k_counter + 1;
    if (clk_2m7_counter >= 10) begin
        clk_enable_2m7 <= 1;
        clk_2m7_counter <= 0;
    end
    if (clk_270k_counter >= 100) begin
        clk_enable_270k <= 1;
        clk_270k_counter <= 0;
    end
end

assign opll_wav = data_in << 4;

lpf2 #(
	.MSBI(11)
	) filter1 (
        .clk21m (clk_27m),
        .reset (reset),
        .clkena (1'b1),
        .idata (opll_wav),
        .odata  (opll_wav1)
	);

lpf2 #(
	.MSBI(11)
	) filter2 (
        .clk21m (clk_27m),
        .reset (reset),
        .clkena (clk_enable_2m7),
        .idata (opll_wav1),
        .odata  (opll_wav2)
	);

lpf2 #(
	.MSBI(11)
	) filter3 (
        .clk21m (clk_27m),
        .reset (reset),
        .clkena (clk_enable_270k),
        .idata (opll_wav2),
        .odata  (opll_wav3)
	);

lpf1 #(
	.MSBI(11)
	) filter4 (
        .clk21m (clk_27m),
        .reset (reset),
        .clkena (clk_enable_270k),
        .idata (opll_wav3),
        .odata  (opll_wav4)
	);


assign data_out = opll_wav4 >> 4;



endmodule
