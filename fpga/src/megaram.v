module megaram_scc(
    input wire clk_27m,
    input wire bus_reset_n,
    input wire [15:0] bus_addr,
    input wire [7:0] cpu_dout,
    input wire bus_rd_n,
    input wire bus_wr_n,
    input wire scc_req,
    input wire scc_wrt,
    input wire [1:0] map_sel,
    input wire map_linear,

    output wire megaram_req,
    output wire megaram_wrt,
    output wire [20:0] megaram_addr,

    output wire scc_sound_disable

);

	//`default_nettype none

    assign scc_sound_disable = megaram_mode_b[4];

    //Mapped I/O port access on 7FFE-7FFFh / BFFE-BFFFh ... Write protect / SPC mode register
    wire megaram_3fe;
    wire megaram_1ffe;
    assign megaram_3fe = ( bus_addr[10:1] == 10'b1111111111) ? 1 : 0;
    assign megaram_1ffe = ( megaram_3fe == 1 && bus_addr[12:11] == 2'b11 ) ? 1 : 0;

    //Mapped I/O port access on 9800-9FFFh ... Wave memory
    wire megaram_scc_a;
    assign megaram_scc_a = ( bus_addr[15:11] == 5'b10011 && megaram_mode_b[5] == 0 && megaram_reg2[5:0] == 6'b111111  ) ? 1 : 0;

    //Mapped I/O port access on B800-BFFFh ... Wave memory
    wire megaram_scc_b;
    assign megaram_scc_b = ( bus_addr[15:11] == 5'b10111 && megaram_mode_b[5] == 1 && megaram_reg3[7] == 1  ) ? 1 : 0;

    //SCC address decoder
    wire megaram_sel_wave;
    reg megaram_sel_memory;
    assign megaram_sel_wave = ( bus_addr[8] == 0 && megaram_mode_b[4] == 0 && (megaram_scc_a == 1 || megaram_scc_b == 1) ) ? 1 : 0;
    assign megaram_sel_memory = ( megaram_sel_wave == 1 ) ? 0 :
                                ( bus_rd_n == 0 ) ? 1 :
                                ( bus_wr_n == 0 && bus_addr[15:13] == 3'b010 && megaram_mode_a[4] == 1 ) ? 1 : 
                                ( bus_wr_n == 0 && bus_addr[15:13] == 3'b011 && megaram_mode_a[4] == 1 && megaram_1ffe == 0 ) ? 1 : 
                                ( bus_wr_n == 0 && bus_addr[15:14] == 2'b01 && megaram_mode_b[4] == 1 ) ? 1 : 
                                ( bus_wr_n == 0 && bus_addr[15:13] == 3'b100 && megaram_mode_b[4] == 1 ) ? 1 : 
                                ( bus_wr_n == 0 && bus_addr[15:13] == 3'b101 && megaram_mode_b[4] == 1 && megaram_1ffe == 0 ) ? 1 : 
                                    0;

    //RAM request
    assign megaram_req = ( megaram_sel_memory == 1 ) ? scc_req : 0;
    assign megaram_wrt = ( megaram_req == 1 && scc_wrt == 1 ) ? 1 : 0;

    assign megaram_addr =  (map_linear == 1) ? { 5'b00000, bus_addr} :
                          (bus_addr [14:13] == 2'b10 ) ? { megaram_reg0, bus_addr[12:0] } :
                          (bus_addr [14:13] == 2'b11 ) ? { megaram_reg1, bus_addr[12:0] } :
                          (bus_addr [14:13] == 2'b00 ) ? { megaram_reg2, bus_addr[12:0] } :
                                                         { megaram_reg3, bus_addr[12:0] };

    reg [7:0] megaram_reg0;
    reg [7:0] megaram_reg1;
    reg [7:0] megaram_reg2;
    reg [7:0] megaram_reg3;
    reg megaram_reg_H;
    reg megaram_reg_L;
    reg [7:0] megaram_mode_a;
    reg [7:0] megaram_mode_b;

    always @( posedge clk_27m ) begin
        if (bus_reset_n == 0) begin
            megaram_reg0	<= 8'h00;
            megaram_reg1	<= 8'h01;
            megaram_reg2	<= 8'h02;
            megaram_reg3	<= 8'h03;
            megaram_mode_a  <= 8'h00;
            megaram_mode_b  <= 8'h00;
        end
        else if (scc_wrt == 1) begin
            if (map_sel[0] == 0) begin
                case (bus_addr[15:11])
                    //Mapped I/O port access on 5000-57FFh ... Bank register write
                    5'b01010: begin
                        if (megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_b[4] == 0 ) begin
                            megaram_reg0 <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on 7000-77FFh ... Bank register write
                    5'b01110: begin
                        if (megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_b[4] == 0 ) begin
                            megaram_reg1 <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on 9000-97FFh ... Bank register write
                    5'b10010: begin
                        if (megaram_mode_b[4] == 0 ) begin
                            megaram_reg2 <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on B000-B7FFh ... Bank register write
                    5'b10110: begin
                        if (megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 && megaram_mode_b[4] == 0 ) begin
                            megaram_reg3 <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on 7FFE-7FFFh ... Register write
                    5'b01111: begin
                        if ( megaram_3fe == 1 && megaram_mode_b[5:4] == 2'b00 ) begin
                            megaram_mode_a <= cpu_dout;
                        end
                    end
                    //Mapped I/O port access on BFFE-BFFFh ... Register write
                    5'b10111: begin
                        if ( megaram_3fe == 1 && megaram_mode_a[6] == 0 && megaram_mode_a[4] == 0 ) begin
                            megaram_mode_b <= cpu_dout;
                        end
                    end
                endcase
            end
            else begin
                case (bus_addr[15:12])
                    //Mapped I/O port access on 6000-6FFFh ... Bank register write
                    4'b0110: begin
                        //ASC8K / 6000-67FFh
                        if (map_sel[1] == 0 && bus_addr[11] == 0) begin
                            megaram_reg0 <= cpu_dout;
                        end
                        //ASC8K / 6800-6FFFh
                        else if (map_sel[1] == 0 && bus_addr[11] == 1) begin
                            megaram_reg1 <= cpu_dout;
                        end
                        //ASC16K / 6000-67FFh
                        else if (bus_addr[11] == 0) begin
                            megaram_reg_L <= cpu_dout[6];
                            megaram_reg0 <= { cpu_dout[7], cpu_dout[5:0], 1'b0 };
                            megaram_reg1 <= { cpu_dout[7], cpu_dout[5:0], 1'b1 };
                        end
                    end
                    //Mapped I/O port access on 7000-7FFFh ... Bank register write
                    4'b0111: begin
                        //ASC8K / 7000-77FFh
                        if (map_sel[1] == 0 && bus_addr[11] == 0) begin
                            megaram_reg2 <= cpu_dout;
                        end
                        //ASC8K / 7800-7FFFh
                        else if (map_sel[1] == 0 && bus_addr[11] == 1) begin
                            megaram_reg3 <= cpu_dout;
                        end
                        //ASC16K / 7000-77FFh
                        else if (bus_addr[11] == 0) begin
                            megaram_reg_H <= cpu_dout[6];
                            megaram_reg2 <= { cpu_dout[7], cpu_dout[5:0], 1'b0 };
                            megaram_reg3 <= { cpu_dout[7], cpu_dout[5:0], 1'b1 };
                        end
                    end
                endcase
            end
        end
    end

endmodule
