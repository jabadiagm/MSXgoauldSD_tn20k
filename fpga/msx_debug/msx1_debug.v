
module msx1_debug(
    input clk_27m,
    input clk,
    input clk_enable,
    input reset_n,
	input [15:0] bus_addr,
    input [7:0] bus_data,
    input send,

    output uart_tx,
    output boot_ok
);

	reg h0000_First_byte;
    reg h0001_Second_byte;
    reg h0002_Third_byte;
    reg h0003_JP_02d7;
	reg [7:0] debug_state = 8'd0;

    always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			debug_state <= 8'd0;;
			h0000_First_byte <= 0;
            h0001_Second_byte <= 0;

        end else if (clk_enable == 1) begin
			case (debug_state)

				8'd00: begin //First byte
					if (bus_addr == 16'h0000 && bus_data == 8'hf3) begin
                        h0000_First_byte <= 1;
						debug_state <= debug_state + 1;
					end
				end
				8'd01: begin //Second byte
					if (bus_addr == 16'h0001 && bus_data == 8'hc3) begin
                        h0001_Second_byte <= 1;
						debug_state <= debug_state + 1;
					end
				end
				8'd02: begin //Third byte
					if (bus_addr == 16'h0002 && bus_data == 8'hd7) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd03: begin //jp #02D7
					if (bus_addr == 16'h0003 && bus_data == 8'h02) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd04: begin 
					if (bus_addr == 16'h02d7) begin //CHKRAM
						debug_state <= debug_state + 1;
					end
				end
				8'd05: begin //Select Slot 0
					if (bus_addr == 16'h02e7) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd06: begin //Select Slot 1
					if (bus_addr == 16'h02e7) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd07: begin //Select Slot 2
					if (bus_addr == 16'h02e7) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd08: begin //Select Slot 3
					if (bus_addr == 16'h02e7) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd09: begin //ldir - init ram
					if (bus_addr == 16'h03b5) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd09: begin //ldir - init ram
					if (bus_addr == 16'h03b5) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd10: begin //Set EXPTBL
					if (bus_addr == 16'h03b7) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd11: begin //Set SSLTLP
					if (bus_addr == 16'h03c6) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd12: begin //JP INIT
					if (bus_addr == 16'h03f8) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd13: begin //JP #7C76
					if (bus_addr == 16'h2680) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd14: begin //Init Basic
					if (bus_addr == 16'h7c76) begin
						debug_state <= debug_state + 1;
					end
				end
				8'd15: begin //Ok and mainloop
					if (bus_addr == 16'h411f) begin
						debug_state <= debug_state + 1;
					end
				end






			endcase
        end
    end

`include "print.v"
defparam tx.uart_freq=115200;
defparam tx.clk_freq=27000000;
assign print_clk = clk_27m;
assign uart_tx = uart_txp;

always @ (posedge send) begin
    //`print("Initializing HyperRAM test...\n", STR);
    `print(debug_state, HEX);
end





endmodule
