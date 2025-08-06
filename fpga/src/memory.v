`define SDRAM_32

module memory_ctrl (
    input wire clk_27m,
	input wire clk_108m,
	input wire bus_reset_n,
	input wire video_dhclk,
	input wire video_dlclk,

	input wire [7:0] mapper_din,
    input wire mapper_req,
    input wire mapper_write,
	input wire megaram_req,
	input wire megaram_write,
	input wire [21:0] mapper_addr,
	input wire [20:0] megaram_addr,
	input wire [7:0] vram_din,
	input wire vram_write,
	input wire [16:0] vram_addr,
    input wire bus_rfsh_n,
	
	output reg [7:0] mapper_dout,
    output reg [7:0] megaram_dout,
	output reg [15:0] vram_dout,

    // Magic ports for SDRAM to be inferred
    output wire O_sdram_clk,
    output wire O_sdram_cke,
    output wire O_sdram_cs_n, // chip select
    output wire O_sdram_cas_n, // columns address select
    output wire O_sdram_ras_n, // row address select
    output wire O_sdram_wen_n, // write enable
    inout wire [31:0] IO_sdram_dq, // 32 bit bidirectional data bus
    output wire [10:0] O_sdram_addr, // 11 bit multiplexed address bus
    output wire [1:0] O_sdram_ba, // two banks
    output wire [3:0] O_sdram_dqm // 32/4
);

	//`default_nettype none
	
    assign O_sdram_clk = clk_108m;
    assign O_sdram_cke = 1;
    assign O_sdram_cs_n = SdrCmd[3];
    assign O_sdram_ras_n = SdrCmd[2];
    assign O_sdram_cas_n = SdrCmd[1];
    assign O_sdram_wen_n = SdrCmd[0];

    assign O_sdram_dqm[3] = SdrHUdq;
    assign O_sdram_dqm[2] = SdrHLdq;
    assign O_sdram_dqm[1] = SdrUdq;
    assign O_sdram_dqm[0] = SdrLdq;
    assign O_sdram_ba[1] = SdrBa[1];
    assign O_sdram_ba[0] = SdrBa[0];

    assign O_sdram_addr = SdrAdr;
    assign IO_sdram_dq = SdrDat;


`ifndef SDRAM_32
    reg [21:0] sdram_addr;
`else
    reg [22:0] sdram_addr;
`endif
    wire sdram_read;
    reg sdram_write;
    wire sdram_dout;
    reg [2:0] sdram_seq;
    reg enable_sdram;

    always @ (posedge clk_27m) begin
        if ( bus_reset_n == 0) begin
            sdram_seq <= 3'd0;
            enable_sdram <= 0;
            sdram_addr <= 0;
            sdram_write <= 0;
        end
        else begin
            enable_sdram <= 0;
            case ( sdram_seq )
                3'd0 : begin
                    sdram_write <= 0;
                    if ( mapper_req == 1 || megaram_req == 1 )begin
                        sdram_seq <= 3'd1;
                    end
                end
                3'd1 : begin
                    enable_sdram <= 1;
                    if ( mapper_req == 1 ) begin
    `ifndef SDRAM_32
                        sdram_addr <= mapper_addr[21:0];
    `else
                        sdram_addr <= { 1'b0, mapper_addr[21:0] };
    `endif
                        sdram_write <= mapper_write;
                    end
                    else begin
    `ifndef SDRAM_32
                        sdram_addr <= { 2'b10, megaram_addr[19:0] };
    `else
                        sdram_addr <= { 3'b10, megaram_addr[20:0] };
    `endif
                        sdram_write <= megaram_write;
                    end
                    sdram_seq <= 3'd2;
                end
                3'd2 : begin
                    enable_sdram <= 1;
                    if ( video_dlclk == 0 && video_dhclk == 1 ) begin
                        sdram_write <= 0;
                        sdram_seq <= 3'd3;
                    end
                end
                3'd3 : begin
                    enable_sdram <= 1;
                    sdram_write <= 0;
                    if ( mapper_req == 1 ) begin
                        mapper_dout <= RamDbi;
                    end
                    else begin
                        megaram_dout <= RamDbi;
                    end
                    sdram_seq <= 3'd4;
                end
                3'd4 : begin
                    if ( mapper_req == 0 && megaram_req == 0 ) begin
                        sdram_seq <= 3'd0;
                    end
                end
                default: begin
                    sdram_seq <= 3'd0;
                end
            endcase
        end
    end

    reg [2:0] ff_sdr_seq;
    reg [4:0]  RstSeq = 0;
    // SDRAM control signals
    reg  [2:0] SdrSta;
    reg  [3:0] SdrCmd;
    reg  [1:0] SdrBa = 2'b00;
    reg  SdrUdq;
    reg  SdrLdq;
    reg  SdrHUdq;
    reg  SdrHLdq;
    reg  [10:0] SdrAdr = 0;
    reg  [31:0] SdrDat;
    reg  [1:0] SdrSize = 2'b11;

    localparam [3:0] SdrCmd_de = 4'b1111;            //-- deselect
    localparam [3:0] SdrCmd_pr = 4'b0010;            //-- precharge all
    localparam [3:0] SdrCmd_re = 4'b0001;            //-- refresh
    localparam [3:0] SdrCmd_ms = 4'b0000;            //-- mode register set

    localparam [3:0] SdrCmd_xx = 4'b0111;            //-- no operation
    localparam [3:0] SdrCmd_ac = 4'b0011;            //-- activate
    localparam [3:0] SdrCmd_rd = 4'b0101;            //-- read
    localparam [3:0] SdrCmd_wr = 4'b0100;            //-- write

    reg [7:0]  RamDbi;
    reg [1:0] ff_mem_seq;
    reg [15:0] FreeCounter = 0;

//    ----------------------------------------------------------------
//    -- SDRAM access
//    ----------------------------------------------------------------
//    --   SdrSta = "000" => idle
//    --   SdrSta = "001" => precharge all
//    --   SdrSta = "010" => refresh
//    --   SdrSta = "011" => mode register set
//    --   SdrSta = "100" => read cpu
//    --   SdrSta = "101" => write cpu
//    --   SdrSta = "110" => read vdp
//    --   SdrSta = "111" => write vdp
//    ----------------------------------------------------------------

    always @ ( posedge clk_108m ) begin
        //-- 00 > 01 > 11 > 10
        ff_mem_seq <= { ff_mem_seq[0], (~ ff_mem_seq[1]) } ;
    end

    always @ ( posedge clk_108m ) begin
        if ( bus_reset_n == 0 ) begin
            FreeCounter <= 0;
        end
        else if( ff_mem_seq == 2'b00 ) begin
            FreeCounter <= FreeCounter + 1;
        end
    end

    reg [19:0] FreeCounter2;
    always @ ( posedge clk_108m ) begin
        if ( RstSeq < 5'b01000 ) begin
            FreeCounter2 <= 0;
        end
        else if( ff_mem_seq == 2'b00 ) begin
            FreeCounter2 <= FreeCounter2 + 1;
        end
    end

    //-- RstSeq count
    always @ ( posedge clk_108m ) begin
        if ( bus_reset_n == 0 ) begin
            RstSeq <= 0;
        end
        if( ff_mem_seq == 2'b00 && FreeCounter[15:0] == 16'hFFFF && RstSeq != 5'b11111 ) begin
            RstSeq <= RstSeq + 1;                                                   //-- 3ms (= 65536 / 21.48MHz)
        end
    end

    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq == 3'b111 ) begin
            if( RstSeq[4:2] == 3'b000 ) begin
                SdrSta <= 3'b000;                                                //-- idle
            end
            else if( RstSeq[4:2] == 3'b001 ) begin
            //--  case RstSeq(1 downto 0) is
            //--      when "00"       => SdrSta <= "000";                         -- idle
            //--      when "01"       => SdrSta <= "001";                         -- precharge all
            //--      when "10"       => SdrSta <= "010";                         -- refresh (more than 8 cycles)
            //--      when others     => SdrSta <= "011";                         -- mode register set
            //--  end case;
                SdrSta <= { 1'b0, RstSeq[1:0] };
            end
//            else if( RstSeq[4:3] != 2'b11 ) begin
//                SdrSta <= 3'b101;                                                //-- Write (Initialize memory content)
//            end
            else if( bus_rfsh_n == 0 && video_dlclk == 1 ) begin
                SdrSta <= 3'b010;                                                //-- refresh
            end
            else begin
                //--  Normal memory access mode
                SdrSta[2] <= 1;                                               //-- read/write cpu/vdp
            end
        end
        else if( ff_sdr_seq == 3'b001 && SdrSta[2] == 1 && RstSeq[4:3] == 2'b11 )begin
            SdrSta[1] <= video_dlclk;                                            //-- 0:cpu, 1:vdp
            if( video_dlclk == 0 ) begin
                SdrSta[0] <= sdram_write;         //-- for cpu
            end
            else begin
                SdrSta[0] <= vram_write;       //-- for vdp
            end
        end
    end

    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000:
                if( SdrSta[2] == 1 ) begin               //-- cpu/vdp read/write
                    SdrCmd <= SdrCmd_ac;
                end
                else if( SdrSta[1:0] == 2'b00 ) begin  //-- idle
                    SdrCmd <= SdrCmd_xx;
                end
                else if( SdrSta[1:0] == 2'b01 ) begin  //-- precharge all
                    SdrCmd <= SdrCmd_pr;
                end
                else if( SdrSta[1:0] == 2'b10 ) begin  //-- refresh
                    SdrCmd <= SdrCmd_re;
                end
                else begin                                   //-- mode register set
                    SdrCmd <= SdrCmd_ms;
                end
            3'b001:
                SdrCmd <= SdrCmd_xx;
            3'b010:
                if( SdrSta[2] == 1 ) begin
                    if( SdrSta[0] == 0 ) begin
                        SdrCmd <= SdrCmd_rd;            //-- "100"(cpu read) / "110"(vdp read)
                    end
                    else begin
                        SdrCmd <= SdrCmd_wr;            //-- "101"(cpu write) / "111"(vdp write)
                    end
                end
            3'b011:
                SdrCmd <= SdrCmd_xx;
            default: ;
                //null;
        endcase
    end

    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000: begin
                SdrUdq <= 1;
                SdrLdq <= 1;
                SdrHUdq <= 1;
                SdrHLdq <= 1;
            end
            3'b010: begin
                if( SdrSta[2] == 1 ) begin
                    if( SdrSta[0] == 0 ) begin
                        SdrUdq <= 0;
                        SdrLdq <= 0;
                        SdrHUdq <= 0;
                        SdrHLdq <= 0;
                    end
                    else begin
                        /*if( RstSeq[4:3] != 2'b11 ) begin
                            SdrUdq <= 0;
                            SdrLdq <= 0;
                            SdrHUdq <= 0;
                            SdrHLdq <= 0;
                        end
                        else*/ if( video_dlclk == 0 ) begin
`ifndef SDRAM_32
                            SdrUdq <= ~ sdram_addr[0];
                            SdrLdq <= sdram_addr[0];
                            SdrHUdq <= 1; //~ sdram_addr[0];
                            SdrHLdq <= 1; //sdram_addr[0];
`else
                            if ( sdram_addr[1] == 0 ) begin
                                SdrUdq <= ~ sdram_addr[0];
                                SdrLdq <= sdram_addr[0];
                                SdrHUdq <= 1; //~ sdram_addr[0];
                                SdrHLdq <= 1; //sdram_addr[0];
                            end
                            else begin
                                SdrUdq <= 1;
                                SdrLdq <= 1;
                                SdrHUdq <= ~ sdram_addr[0];
                                SdrHLdq <= sdram_addr[0];
                            end
`endif
                        end
                        else begin
                            SdrUdq <= ~vram_addr[16];
                            SdrLdq <=  vram_addr[16];
                            SdrHUdq <= 1; //~ vram_addr[16];
                            SdrHLdq <= 1; //vram_addr[16];
                        end
                    end
                end
            end
            3'b011: begin
                SdrUdq <= 1;
                SdrLdq <= 1;
                SdrHUdq <= 1;
                SdrHLdq <= 1;
            end
            default: ; //null;
        endcase
    end

    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000: begin
                if( SdrSta[2] == 0 ) begin                                       //-- set [command mode]
                    //--           WBL=single TM=off CL=2 WT=0(seq) BL=1
                    SdrAdr <= { 3'b010, 1'b0, 3'b010, 1'b0, 3'b000 };
                    SdrBa  <= 2'b00;                                             //-- bank A
                end
                else begin                                                           //-- set [row address]
                    /*if( RstSeq[4:3] != 2'b11 ) begin
                        SdrAdr <= FreeCounter2[10:0];                              //-- clear "AB" mark (ESE-SCC2 >> ESE-SCC1 >> ESE-RAM)
                        SdrBa  <= { 1'b1, 1'b0 };                              //-- bank C+D
                    end
                    else*/ if( video_dlclk == 0 ) begin
`ifndef SDRAM_32
                        SdrAdr <= sdram_addr[11:1];   //-- cpu read/write
                        SdrBa  <= sdram_addr[21:20];                         //-- bank A+B+C+D
`else
                        SdrAdr <= sdram_addr[12:2];   //-- cpu read/write
                        SdrBa  <= sdram_addr[22:21];                         //-- bank A+B+C+D
`endif
                    end
                    else begin
                        SdrAdr <= vram_addr[10:0];                   //-- vdp read/write
                        SdrBa  <= 2'b11;                                         //-- bank D
                    end
                end
            end
            3'b010: begin                                                                             //-- set [column address]
                SdrAdr[10:8] <= 3'b100;                                                            //-- A10=1 => enable auto precharge
                //-- when A10=1, SdrBa is ignored and all banks are selected
                //-- be careful not to assign SdrBa during auto precharge, otherwise it will cause instability
                /*if( RstSeq[4:3] != 2'b11 ) begin
                    SdrAdr[7:0] <= FreeCounter2[18:11] ; //{ RstSeq[0], 8'b00000000 };                                       //-- clear ESE-SCC2 >> ESE-SCC1
                end
                else if( RstSeq[4:1] == 4'b0111 ) begin
                    SdrAdr[7:0] <= 0;                                              //-- clear ESE-RAM
                end
                else*/ if( video_dlclk == 0 ) begin
`ifndef SDRAM_32
                    SdrAdr[7:0] <= sdram_addr[19:12];                                         //-- cpu read/write
`else
                    SdrAdr[7:0] <= sdram_addr[20:13];                                         //-- cpu read/write
`endif
                end
                else begin
                    SdrAdr[7:0] <= { 3'b000, vram_addr[15:11] };
                end
            end
            default: ; //null;
        endcase
    end

    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq == 3'b010 ) begin
            if( SdrSta[2] == 1 ) begin
                if( SdrSta[0] == 0 ) begin
                    SdrDat <= 32'bzzzz_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz;
                end
                else begin
                    /*if( RstSeq[4:3] != 2'b11 ) begin
                        SdrDat <= 32'hffff_ffff;
                    end
                    else*/ if( video_dlclk == 0 ) begin
                        SdrDat <= { mapper_din, mapper_din, mapper_din, mapper_din };                //-- "101"(cpu write)
                    end
                    else begin
                        SdrDat <= { vram_din, vram_din, vram_din, vram_din };          //-- "111"(vdp write)
                    end
                end
            end
        end
        else begin
            SdrDat <= 32'bzzzz_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz;
        end
    end

    //-- Data read latch for CPU
    reg ff_sdr_seq_5;
    always @ ( posedge clk_108m ) begin
        ff_sdr_seq_5 <= 0;
        if( ff_sdr_seq == 3'b100 ) begin
            ff_sdr_seq_5 <= 1;
        end
    end
    reg ff_sdr_seq_6;
    always @ ( posedge clk_108m ) begin
        ff_sdr_seq_6 <= 0;
        if( ff_sdr_seq == 3'b101 ) begin
            ff_sdr_seq_6 <= 1;
        end
    end
    reg SdrSta_4;
    always @ ( posedge clk_108m ) begin
        SdrSta_4 <= 0;
        if( SdrSta[2:0] == 3'b100 ) begin
            SdrSta_4 <= 1;
        end
    end
//    reg SdrSta_6;
//    always @ ( posedge clk_108m ) begin
//        SdrSta_6 <= 0;
//        if( SdrSta[2:0] == 3'b100 ) begin
//            SdrSta_6 <= 1;
//        end
//    end

    always @ ( posedge clk_108m ) begin
        if( ff_sdr_seq_5 == 1 || ff_sdr_seq_6 == 1 ) begin
            if( SdrSta_4 == 1 ) begin                        //-- read cpu
`ifndef SDRAM_32
                if( sdram_addr[0] == 0 ) begin
                    RamDbi <= SdrDat[7:0];
                end
                else begin
                    RamDbi <= SdrDat[15:8];
                end
`else
                if( sdram_addr[1:0] == 2'b00 )
                    RamDbi <= SdrDat[7:0];
                else if( sdram_addr[1:0] == 2'b01 )
                    RamDbi <= SdrDat[15:8];
                else if( sdram_addr[1:0] == 2'b10 )
                    RamDbi <= SdrDat[23:16];
                else
                    RamDbi <= SdrDat[31:24];
`endif
            end
        end
    end


    //-- Data read latch for VDP
    always @ ( posedge clk_108m ) begin
            if( ff_sdr_seq_5 == 1 || ff_sdr_seq_6 == 1 ) begin
                if( SdrSta == 3'b110 ) begin                        //-- read vdp
                    vram_dout <= { SdrDat[15:8], SdrDat[7:0] };
                end
            end
    end

    //SDRAM controller state
    always @ ( posedge clk_108m ) begin
        case (ff_sdr_seq)
            3'b000: begin
                if( video_dhclk == 1 ) begin //|| RstSeq[4:3] != 2'b11 ) begin
                    ff_sdr_seq <= 3'b001;
                end
            end
            3'b111: begin
                if( video_dhclk == 0 ) begin //|| RstSeq[4:3] != 2'b11 )begin
                    ff_sdr_seq <= 3'b000;
                end
            end
            default: begin
                ff_sdr_seq <= ff_sdr_seq + 1;
            end
        endcase
    end
	
endmodule