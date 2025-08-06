
module timing_debug(
    input wire clk_27m,
    input wire clk_108m,
    input wire reset_n,
    input wire bus_iorq_n,
    input wire bus_mreq_n,
	input wire bus_rd_n,
    input wire bus_wr_n,
    input wire send,

    output wire uart_tx
);

    reg [31:0] counter_tic = 32'd0;
    reg [31:0] counter_tic_1s = 32'd0;
    wire tic;
    wire tic_1s;
    always @ (posedge clk_27m) begin
        counter_tic <= counter_tic + 1;
        counter_tic_1s <= counter_tic_1s + 1;
        if (counter_tic > 270000) begin
            counter_tic <= 32'd0;
        end
        if (counter_tic_1s > 27000000) begin
            counter_tic_1s <= 32'd0;
        end
    end
    assign tic = (counter_tic == 32'd0) ? 1: 0;
    assign tic_1s = (counter_tic_1s == 32'd0) ? 1: 0;

	wire mreq_rd;
    wire mreq_wr;
	wire iorq_rd;
    wire iorq_wr;
	assign mreq_rd = (bus_mreq_n == 0 && bus_rd_n == 0) ? 1 : 0;
    assign mreq_wr = (bus_mreq_n == 0 && bus_wr_n == 0) ? 1 : 0;
    assign iorq_rd = (bus_iorq_n == 0 && bus_rd_n == 0) ? 1 : 0;
    assign iorq_wr = (bus_iorq_n == 0 && bus_wr_n == 0) ? 1 : 0;

	wire [7:0] mreq_rd_min;
	wire [7:0] mreq_rd_max;
	wire [7:0] mreq_wr_min;
	wire [7:0] mreq_wr_max;
	wire [7:0] iorq_rd_min;
	wire [7:0] iorq_rd_max;
	wire [7:0] iorq_wr_min;
	wire [7:0] iorq_wr_max;

    wire [7:0] mreq_rd_min_1s;
    wire [7:0] mreq_rd_max_1s;
	
	//mreq
    pulse_min #(
        .N_BITS(8)
    ) mreq_rd_min1 (
        .clk(clk_108m),
        .reset(~reset_n),
        .pulse_in(mreq_rd),
        .minimum(mreq_rd_min),
        .valid( )
    );	

    pulse_max #(
        .N_BITS(8)
    ) mreq_rd_max1 (
        .clk(clk_108m),
        .reset(~reset_n),
        .pulse_in(mreq_rd),
        .maximum(mreq_rd_max),
        .valid( )
    );	

    pulse_min #(
        .N_BITS(8)
    ) mreq_wr_min1 (
        .clk(clk_108m),
        .reset(~reset_n),
        .pulse_in(mreq_wr),
        .minimum(mreq_wr_min),
        .valid( )
    );	

    pulse_max #(
        .N_BITS(8)
    ) mreq_wr_max1 (
        .clk(clk_108m),
        .reset(~reset_n),
        .pulse_in(mreq_wr),
        .maximum(mreq_wr_max),
        .valid( )
    );	

	//iorq
    pulse_min #(
        .N_BITS(8)
    ) iorq_rd_min1 (
        .clk(clk_108m),
        .reset(~reset_n),
        .pulse_in(iorq_rd),
        .minimum(iorq_rd_min),
        .valid( )
    );	

    pulse_max #(
        .N_BITS(8)
    ) iorq_rd_max1 (
        .clk(clk_108m),
        .reset(~reset_n),
        .pulse_in(iorq_rd),
        .maximum(iorq_rd_max),
        .valid( )
    );	

    pulse_min #(
        .N_BITS(8)
    ) iorq_wr_min1 (
        .clk(clk_108m),
        .reset(~reset_n),
        .pulse_in(iorq_wr),
        .minimum(iorq_wr_min),
        .valid( )
    );	

    pulse_max #(
        .N_BITS(8)
    ) iorq_wr_max1 (
        .clk(clk_108m),
        .reset(~reset_n),
        .pulse_in(iorq_wr),
        .maximum(iorq_wr_max),
        .valid( )
    );
	
    //mreq, 1s
    pulse_min #(
        .N_BITS(8)
    ) mreq_rd_min_1s1 (
        .clk(clk_108m),
        .reset(~reset_n | tic_1s),
        .pulse_in(mreq_rd),
        .minimum(mreq_rd_min_1s),
        .valid( )
    );	

	`include "print.v"
	defparam tx.uart_freq=115200;
	defparam tx.clk_freq=27000000;
	assign print_clk = clk_27m;
	assign uart_tx = uart_txp;

	reg [7:0] send_state = 8'd0;

	always @ (posedge clk_27m or negedge reset_n) begin
		if (!reset_n) begin
			send_state <= 8'd0;
		end 
		else if (tic == 1) begin
			send_state <= send_state + 1;
			case (send_state)
                8'd01: `print("Absolute timings", STR);
                8'd02: `print("\n", STR);

				8'd03: `print("mreq_rd_min=", STR);
				8'd04: `print(mreq_rd_min, HEX);
                8'd05: `print("\n", STR);

				8'd06: `print("mreq_rd_max=", STR);
				8'd07: `print(mreq_rd_max, HEX);
                8'd08: `print("\n", STR);

				8'd09: `print("mreq_wr_min=", STR);
				8'd10: `print(mreq_wr_min, HEX);
                8'd11: `print("\n", STR);

				8'd12: `print("mreq_wr_max=", STR);
				8'd13: `print(mreq_wr_max, HEX);
                8'd14: `print("\n", STR);

				8'd15: `print("iorq_rd_min=", STR);
				8'd16: `print(iorq_rd_min, HEX);
                8'd17: `print("\n", STR);

				8'd18: `print("iorq_rd_max=", STR);
				8'd19: `print(iorq_rd_max, HEX);
                8'd20: `print("\n", STR);

				8'd21: `print("iorq_wr_min=", STR);
				8'd22: `print(iorq_wr_min, HEX);
                8'd23: `print("\n", STR);

				8'd24: `print("iorq_wr_max=", STR);
				8'd25: `print(iorq_wr_max, HEX);
                8'd26: `print("\n", STR);


/*
                8'd09: `print("1s timings", STR);
                8'd10: `print("\n", STR);

				8'd11: `print("mreq_rd_min_1s=", STR);
				8'd12: `print(mreq_rd_min_1s, HEX);
                8'd13: `print("\n", STR);
*/
                8'd27: `print("\n", STR);


			endcase
            send_state <= send_state == 8'd255 ? 0 : send_state + 1;
		end
	end





endmodule
