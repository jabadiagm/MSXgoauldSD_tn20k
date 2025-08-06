`define ENABLE_V9958
`define ENABLE_BIOS
`define ENABLE_SOUND //v9958, bios required
`define ENABLE_MAPPER //bios required
`define ENABLE_SCAN_LINES
`define ENABLE_SDCARD
`define ENABLE_CONFIG
`define SDRAM_32
`define ENABLE_WAIT //extra wait state for mreq+wr

module top(
    input wire ex_clk_27m,
    input wire s1,
    input wire s2,

    input wire ex_bus_wait_n,
    input wire ex_bus_int_n,
    input wire ex_bus_reset_n,
    input wire ex_bus_clk_3m6,

    inout wire [7:0] ex_bus_data,
    
    output wire [1:0] ex_msel,
    output wire ex_bus_m1_n,
    output wire ex_bus_rfsh_n,
    output wire ex_bus_mreq_n,
    output wire ex_bus_iorq_n,
    output wire ex_bus_rd_n,
    output wire ex_bus_wr_n,

    output wire ex_bus_data_reverse_n,
    //output wire ex_bus_data_reverse,
    output wire [7:0] ex_bus_mp,

    //hdmi out
    output wire [2:0] data_p,
    output wire [2:0] data_n,
    output wire clk_p,
    output wire clk_n,

    // flash
    output wire mspi_cs,
    output wire mspi_sclk,
    inout wire mspi_miso,
    inout wire mspi_mosi,

    // MicroSD
    output wire sd_sclk,
    inout wire sd_cmd,      // MOSI
    inout  wire sd_dat0,     // MISO
    output wire sd_dat1,     // 1
    output wire sd_dat2,     // 1
    output wire sd_dat3,     // 1

    //uart
    output wire uart_tx,

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

    //output wire SLTSL3

);

initial begin

end
    //`default_nettype none

    //assign SLTSL3 = bus_mreq_disable ^ bus_iorq_disable ^ xffh ^ xffl ^ mapper_read ^ exp_slotx_req_r ^ bios_req ^ subrom_req ^ vdp_csr_n;

    //clocks
    wire clk_108m;
    wire clk_108m_n;
    CLK_108P clk_main (
        .clkout(clk_108m), //output clkout
        .lock(), //output lock
        .clkoutp(clk_108m_n), //output clkoutp
        .reset(0), //input reset
        .clkin(ex_clk_27m) //input clkin
    );

    wire clk_enable_27m;
    wire clk_enable_54m;
    reg [1:0] cnt_clk_enable_27m;
    always @ (posedge clk_108m) begin
        cnt_clk_enable_27m <= cnt_clk_enable_27m + 1;
    end
    assign clk_enable_27m = ( cnt_clk_enable_27m == 2'b00 ) ? 1: 0;
    assign clk_enable_54m = ( cnt_clk_enable_27m[0] == 1 ) ? 1: 0;

    wire clk_27m;
//    BUFG buf1 (
//        .O(clk_27m),
//        .I(ex_clk_27m)
//    );
//    assign clk_27m = ex_clk_27m;
    Gowin_CLKDIV div4(
        .clkout(clk_27m), //output clkout
        .hclkin(clk_108m), //input hclkin
        .resetn(1) //input resetn
    );

//    wire clk_54m;
//    wire clk_54m_buf;
//    Gowin_rPLL pll(
//        .clkout(clk_54m_buf), //output clkout
//        .clkin(ex_clk_27m) //input clkin
//    );

//    BUFG buf2(
//        .O(clk_54m),
//        .I(clk_54m_buf)
//    );

    wire bus_clk_3m6;
    PINFILTER dn1(
        .clk(clk_54m),
        .reset_n(1),
        .din(ex_bus_clk_3m6),
        .dout(bus_clk_3m6)
    );

//    wire clk_enable_3m6;
//    wire clk_falling_3m6;
//    reg bus_clk_3m6_prev;
//    always @ (posedge clk_54m) begin
//        bus_clk_3m6_prev <= bus_clk_3m6;
//    end
//    assign clk_enable_3m6 = (bus_clk_3m6_prev == 0 && bus_clk_3m6 == 1);
//    assign clk_falling_3m6 = (bus_clk_3m6_prev == 1 && bus_clk_3m6 == 0);

    reg bus_clk_3m6_27;
    reg bus_clk_3m6_27_0;
    reg bus_clk_3m6_27_1;
    reg bus_clk_3m6_27_2;
    reg bus_clk_3m6_27_3;
    reg bus_clk_3m6_27_4;
    reg bus_clk_3m6_27_5;
    reg bus_clk_3m6_27_6;
//    PINFILTER dn5(
//        .clk(clk_27m),
//        .reset_n(1),
//        .din(ex_bus_clk_3m6),
//        .dout(bus_clk_3m6_27)
//    );
    always @ (posedge clk_27m) begin
        bus_clk_3m6_27_6 <= bus_clk_3m6;
        bus_clk_3m6_27_5 <= bus_clk_3m6_27_6;
        bus_clk_3m6_27_4 <= bus_clk_3m6_27_5;
        bus_clk_3m6_27_3 <= bus_clk_3m6_27_4;
        bus_clk_3m6_27_2 <= bus_clk_3m6_27_3;
        bus_clk_3m6_27_1 <= bus_clk_3m6_27_2;
        bus_clk_3m6_27_0 <= bus_clk_3m6_27_1;
        bus_clk_3m6_27 <= bus_clk_3m6_27_0;
    end

    wire clk_enable_3m6_27;
    wire clk_falling_3m6_27;
    reg bus_clk_3m6_prev_27;
    always @ (posedge clk_27m) begin
        bus_clk_3m6_prev_27 <= bus_clk_3m6_27;
    end
    assign clk_enable_3m6_27 = (bus_clk_3m6_prev_27 == 0 && bus_clk_3m6_27 == 1);
    assign clk_falling_3m6_27 = (bus_clk_3m6_prev_27 == 1 && bus_clk_3m6_27 == 0);

    wire clk_54m;
    Gowin_CLKDIV2 div2(
        .clkout(clk_54m), //output clkout
        .hclkin(clk_108m), //input hclkin
        .resetn(1) //input resetn
    );

    wire clk_enable_3m6_54;
    wire clk_falling_3m6_54;
    reg bus_clk_3m6_54;
    reg bus_clk_3m6_prev_54;
    always @ (posedge clk_54m) begin
        bus_clk_3m6_54 <= bus_clk_3m6;
        bus_clk_3m6_prev_54 <= bus_clk_3m6_54;
    end
    assign clk_enable_3m6_54 = (bus_clk_3m6_prev_54 == 0 && bus_clk_3m6_54 == 1);
    assign clk_falling_3m6_54 = (bus_clk_3m6_prev_54 == 1 && bus_clk_3m6_54 == 0);

    wire bus_wait_n;
    PINFILTER dn2(
        .clk(clk_54m),
        .reset_n(1),
        .din(ex_bus_wait_n),
        .dout(bus_wait_n)
    );

    wire bus_reset_n;
    PINFILTER dn3(
        .clk(clk_54m),
        .reset_n(1),
        .din(ex_bus_reset_n & ~config_reset),
        .dout(bus_reset_n)
    );

    wire bus_int_n;
//    PINFILTER dn4(
//        .clk(clk_108m),
//        .reset_n(1),
//        .din(ex_bus_int_n),
//        .dout(bus_int_n)
//    );
    denoise dn4 (
		.data_in (ex_bus_int_n),
		.clock(clk_54m),
		.data_out (bus_int_n)
    );

    reg [7:0] bus_data;
    genvar i;
    generate
        for (i = 0; i <= 7; i++)
        begin: bus_din
            PINFILTER dn(
                .clk(clk_54m),
                .reset_n(1),
                .din(ex_bus_data[i]),
                .dout(bus_data[i])
            );
//            denoise2 dn (
//                .data_in (ex_bus_data[i]),
//                .clock(clk_108m),
//                .data_out (bus_data[i])
//            );
        end
    endgenerate

//    always @ (posedge clk_108m) begin
//        bus_data <= ex_bus_data;
//    end

    //startup logic
    reg reset1_n_ff;
    reg reset2_n_ff;
    reg reset3_n_ff;
    wire reset1_n;
    wire reset2_n;
    wire reset3_n;

    reg [20:0] counter_reset = 0;
    reg [1:0] rst_seq;
    reg rst_step;

    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if (bus_reset_n == 0) begin
            rst_step <= 0;
            counter_reset <= 0;
        end
        else begin
            rst_step <= 0;
            if ( counter_reset <= 21'b100000000000000000000 ) 
                counter_reset <= counter_reset + 1;
            else begin
                rst_step <= 1;
                counter_reset <= 0;
            end
        end
    end

    always @ (posedge clk_27m or negedge bus_reset_n ) begin
        if (bus_reset_n == 0 ) begin
            rst_seq <= 2'b00;
            reset1_n_ff <= 0;
            reset2_n_ff <= 0;
            reset3_n_ff <= 0;
        end
        else begin
            case ( rst_seq )
                2'b00: 
                    if (rst_step == 1 ) begin
                        reset1_n_ff <= 1;
                        rst_seq <= 2'b01;
                    end
                2'b01: 
                    if (rst_step == 1) begin
                        reset2_n_ff <= 1;
                        rst_seq <= 2'b10;
                    end
                2'b10:
                    if (rst_step == 1) begin
                        reset3_n_ff <= 1;
                        rst_seq <= 2'b11;
                    end
            endcase
        end
    end
    assign reset1_n = reset1_n_ff;
    assign reset2_n = reset2_n_ff;
    assign reset3_n = reset3_n_ff;

    //bus demux
    reg [1:0] msel;
    reg [7:0] bus_mp;
//    reg msel_ff = 0;
    reg [4:0] mp_cnt;
    wire [15:0] bus_addr;
    assign ex_msel = msel;
    assign ex_bus_mp = bus_mp;
//    assign msel = { msel_ff, ~ msel_ff };
//    assign bus_mp = ( msel[1] == 1 ) ? bus_addr[15:8] : bus_addr[7:0];

//    always @ (posedge clk_108m) begin
//        if (cnt_clk_enable_27m == 1) begin
//            msel_ff <= ~ msel_ff;
//        end
//    end

    localparam IDLE = 2'd0;
    localparam LATCH = 2'd1;
    localparam FINISH1 = 2'd3;
    localparam FINISH2 = 2'd2;
    localparam [3:0] TON = 4'd3;
    localparam [3:0] TP = 4'd1; //prefetch time
    reg [1:0] state_demux;
    reg [3:0] counter_demux;
    //reg [15:0] bus_addr_demux;
    reg low_byte_demux;
    wire update_demux;
    assign bus_mp = ( low_byte_demux == 0 ) ? bus_addr[15:8] : bus_addr[7:0];
    always @ (posedge clk_108m) begin
        if (~bus_reset_n) begin
            state_demux <= LATCH;
            counter_demux <= 4'd0;
            //bus_addr_demux <= ~ bus_addr;
            low_byte_demux <= 0;
        end 
        else begin
            counter_demux = counter_demux + 4'd1;
            casex ({state_demux, counter_demux})
                {IDLE, 4'bxxxx}: begin
                    msel <= 2'b00;
                    counter_demux <= 4'd0;
                    low_byte_demux <= 0;
                    if (update_addr == 1 ) begin
                        state_demux <= LATCH;
                    end
                end
                {LATCH, 4'd1} : begin
                    //bus_addr_demux <= bus_addr;
                    msel[1] <= 1;
                end
                {LATCH, 4'd1 + TON} : begin
                    msel[1] <= 0;
                end
                {LATCH, 4'd1 + TON + TP} : begin
                    low_byte_demux <= 1;
                end
                {LATCH, 4'd1 + TON + TP + TP} : begin
                    msel[0] <= 1;
                end
                {LATCH, 4'd1 + TON + TP + TP + TON} : begin
                    msel[0] <= 0;
                    msel[1] <= 0;
                    state_demux <= FINISH1;
                end
                {FINISH1, 4'bxxxx}: begin
                    if (update_addr == 0 ) begin
                        state_demux <= IDLE;
                    end
                end
                {FINISH2, 4'bxxxx}: begin
                    if (update_addr == 0 ) begin
                        state_demux <= IDLE;
                    end
                end
            endcase
        end
    end




    //bus isolation
    wire bus_data_reverse;
    wire bus_m1_n;
    wire bus_mreq_n;
    wire bus_iorq_n;
    wire bus_rd_n;
    wire bus_wr_n;
    wire bus_rfsh_n;
    reg [7:0] cpu_din;
    wire [7:0] cpu_dout;
    wire bus_mreq_disable;
    wire bus_iorq_disable;
    wire bus_disable;
    assign ex_bus_m1_n = bus_m1_n;
    assign ex_bus_rfsh_n = bus_rfsh_n;
    assign ex_bus_data_reverse_n = ~ bus_data_reverse;
    //assign ex_bus_data_reverse = bus_data_reverse;
    //assign ex_bus_mreq_n = bus_mreq_n;
    //assign ex_bus_iorq_n = bus_iorq_n;
    //assign ex_bus_rd_n = bus_rd_n;
    //assign ex_bus_wr_n = bus_wr_n;

    assign bus_mreq_disable = 0;
    assign bus_iorq_disable = (
                                0
                        `ifdef ENABLE_V9958
                                || vdp_csr_n == 0 || vdp_csw_n == 0 
                        `endif 
                                ) ? 1 : 0;

    assign bus_disable = bus_mreq_disable | bus_iorq_disable;
//    assign ex_bus_data = ( bus_data_reverse == 1 && slot0_req_w == 0 ) ? cpu_dout : 
//                         ( slot0_req_w == 1 ) ? 8'hff :  8'hzz;
    assign ex_bus_data =  ( bus_data_reverse == 1 ) ? cpu_dout : 8'hzz;

    always @ (posedge clk_54m) begin
        cpu_din <= 
                `ifdef ENABLE_V9958
                     ( vdp_csr_n == 0) ? vdp_dout :
                `endif
                `ifdef ENABLE_MAPPER
                     ( mapper_read == 1) ? mapper_dout :
                `endif
                `ifdef ENABLE_BIOS
                     ( exp_slotx_req_r == 1) ? ~exp_slotx  :
                     ( bios_req == 1) ? bios_dout : 
                     ( subrom_req == 1) ? subrom_dout :
                     ( msx_logo_req == 1 ) ? msx_logo_dout :
                `endif
                `ifdef ENABLE_SDCARD
                     ( sd_busreq_w == 1) ? sd_cd_w :
                     ( sram_busreq_w == 1) ? sram_cd_w :
                     ( megarom_req == 1) ? ff_rom_dout :
                     ( slot_sd_req_r == 1) ? 8'hff :
                 `endif
                `ifdef ENABLE_SOUND
                     //( scc_req0_r == 1 ) ? scc_dout:
                     ( megaram_req == 1 ) ? megaram_dout:
                `endif
                     //( slot0_req_r == 1 || slot3_req_r == 1) ? 8'hff :
                `ifdef ENABLE_CONFIG
                     ( config_req == 1 && config_ok == 1) ? config_dout :
                     ( config_req == 1 && config_ok == 0) ? swio_dout :
                `endif
                     ( rtc_req_r == 1 ) ? rtc_dout :
                `ifdef ENABLE_BIOS
                     ( slot0_req_r == 1 ) ? 8'hff :
                `endif
                      bus_data;
    end


//    wire ex_bus_rd_n_test;
//    wire ex_bus_wr_n_test;
//    wire ex_bus_iorq_n_test;
//    wire ex_bus_mreq_n_test;
    reg ex_bus_rd_n_ff;
    reg ex_bus_wr_n_ff;
    reg ex_bus_iorq_n_ff;
    reg ex_bus_mreq_n_ff;
    localparam IDLE_ISO = 2'd0;
    localparam ACTIVE_ISO = 2'd1;
    localparam WAIT_ISO = 2'd2;
    reg [1:0] state_iso;
    reg [2:0] counter_iso;
    wire io_active;

    //assign ex_bus_rd_n = ( bus_rd_n | ex_bus_rd_n_ff | bus_disable);
    assign ex_bus_rd_n = bus_rd_n;
    //assign ex_bus_wr_n = ( bus_wr_n | ex_bus_wr_n_ff | bus_disable);
    assign ex_bus_wr_n = bus_wr_n;
    assign ex_bus_iorq_n = ( bus_iorq_n | bus_iorq_disable );
    assign ex_bus_mreq_n = ( bus_mreq_n | bus_mreq_disable );
    assign io_active = ( state_iso != IDLE_ISO ) ? 1 : 0;

    always @ ( posedge clk_108m ) begin
        if (~bus_reset_n) begin
            state_iso <= IDLE_ISO;
            ex_bus_rd_n_ff <= 1;
            ex_bus_wr_n_ff <= 1;
        end 
        else begin
            counter_iso = counter_iso + 3'd1;
            casex ({state_iso, counter_iso})
                {IDLE_ISO, 3'bxxx}: begin
                    ex_bus_rd_n_ff <= 1;
                    ex_bus_wr_n_ff <= 1;
                    counter_iso <= 3'd0;
                    if (bus_rd_n == 0 || bus_wr_n == 0 ) begin
                        state_iso <= ACTIVE_ISO;
                    end
                end
                {ACTIVE_ISO, 3'd2} : begin
                    ex_bus_rd_n_ff <= bus_rd_n;
                    ex_bus_wr_n_ff <= bus_wr_n;
                    state_iso <= WAIT_ISO;
                end
                {WAIT_ISO, 3'bxxx} : begin
                    if ( bus_rd_n == 1 && bus_wr_n == 1 ) begin
                        state_iso <= IDLE_ISO;
                    end
                end
            endcase
        end
    end

`ifdef ENABLE_WAIT
    wire wait_io;
    reg wait_io_ff = 1;
    reg [6:0] state_wait;
    localparam WAIT_IDLE = 7'd0;
    localparam WAIT_STATE1 = 7'd1;
    localparam WAIT_STATE2 = 7'd3;
    localparam WAIT_STATE3 = 7'd2;

    assign wait_io = wait_io_ff;
    always @ (posedge clk_27m) begin
        if (~bus_reset_n) begin
            state_wait <= IDLE;
            wait_io_ff <= 1;
        end 
        else begin
            case (state_wait)
                WAIT_IDLE: begin
                    if ( (ex_bus_iorq_n == 0 || ( config_enable_wait == 1 && ex_bus_mreq_n == 0 ) )&& (bus_rd_n == 0 || bus_wr_n == 0) ) begin
                        wait_io_ff <= 0;
                        state_wait <= WAIT_STATE1;
                    end
                end
                WAIT_STATE1: begin
                    if ( clk_enable_3m6_27 == 1 ) begin
                        state_wait <= WAIT_STATE2;
                    end
                end
                WAIT_STATE2: begin
                    if ( clk_falling_3m6_27 == 1 ) begin
                        wait_io_ff <= 1;
                        state_wait <= WAIT_STATE3;
                    end
                end
                WAIT_STATE3: begin
                    if ( bus_rd_n == 1 && bus_wr_n == 1) begin
                        state_wait <= WAIT_IDLE;
                    end
                end
            endcase
        end
    end
`endif

    wire update_addr;
    G80a  #(
        .Mode    (0),     // 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
        //.T2Write (0),     //0 => WR_n active in T3, /=0 => WR_n active in T2
        .IOWait   (1)      // 0 => Single I/O cycle, 1 => Std I/O cycle
    ) cpu1 (
        .RESET_n   (bus_reset_n & reset3_n),
        .CLK_n     (clk_54m),
`ifdef ENABLE_WAIT
		.clk_enable (clk_enable_3m6_54 & wait_io),
		.clk_falling (clk_falling_3m6_54 & wait_io),
`else
        .clk_enable (clk_enable_3m6_54),
		.clk_falling (clk_falling_3m6_54),
`endif
`ifdef ENABLE_SDCARD
        .WAIT_n    (bus_wait_n & flash_wait_n),
`else
        .WAIT_n    (bus_wait_n),
`endif
    `ifdef ENABLE_V9958
        .INT_n     (bus_int_n & vdp_int),
    `else
        .INT_n     (bus_int_n),
    `endif
        .NMI_n     (1),
        .BUSRQ_n   (1),
        .M1_n      (bus_m1_n),
        .MREQ_n    (bus_mreq_n),
        .IORQ_n    (bus_iorq_n),
        .RD_n      (bus_rd_n),
        .WR_n      (bus_wr_n),
        .RFSH_n    (bus_rfsh_n),
        .HALT_n    ( ),
        .BUSAK_n   ( ),
        .A         (bus_addr),
        .update_addr(update_addr),
        .DI         (cpu_din),
        .DO         (cpu_dout),
        .Data_Reverse (bus_data_reverse)
    );

    //slots decoding
    reg [7:0] ppi_port_a;
    wire ppi_req;
    wire [1:0] pri_slot;
    wire [3:0] pri_slot_num;
    wire [3:0] page_num;

    //----------------------------------------------------------------
    //-- PPI(8255) / primary-slot
    //----------------------------------------------------------------
    assign ppi_req = (bus_addr[7:0] == 8'ha8 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;

    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if ( bus_reset_n == 0)
            ppi_port_a <= 8'h00;
        else begin
            if (ppi_req == 1 ) begin
                ppi_port_a <= cpu_dout;
            end
        end
    end

    //expanded slot 3
    reg [7:0] exp_slotx;
    wire [1:0] exp_slotx_page;
    wire [3:0] exp_slotx_num;
    reg exp_slotx_req_r;
    reg exp_slotx_req_w;
    wire xffff;
    reg xffh;
    reg xffl;
    always @ (posedge clk_27m) begin
        xffh <= bus_addr[15:8] == 8'hff;
        xffl <= bus_addr[7:0] == 8'hff;
        exp_slotx_req_w <= ( bus_mreq_n == 0 && bus_wr_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
        exp_slotx_req_r <= ( bus_mreq_n == 0 && bus_rd_n == 0 && xffh == 1 && xffl == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
    end
    //assign xffff = ( bus_addr == 16'hffff ) ? 1 : 0;
    assign xffff = xffh & xffl;

//    assign exp_slotx_req_w = ( bus_mreq_n == 0 && bus_wr_n == 0 && xffff == 1 && pri_slot_num[0] == 1 ) ? 1: 0;
//    assign exp_slotx_req_r = ( bus_mreq_n == 0 && bus_rd_n == 0 && xffff == 1 && pri_slot_num[0] == 1 ) ? 1: 0;

    // slot #3
    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if ( bus_reset_n == 0 )
            exp_slotx <= 8'h00;
        else begin
            if (exp_slotx_req_w == 1 ) begin
                exp_slotx <= cpu_dout;
            end
        end
    end

    // slots decoding
    assign pri_slot = ( bus_addr[15:14] == 2'b00) ? ppi_port_a[1:0] :
                      ( bus_addr[15:14] == 2'b01) ? ppi_port_a[3:2] :
                      ( bus_addr[15:14] == 2'b10) ? ppi_port_a[5:4] :
                                             ppi_port_a[7:6];

    assign pri_slot_num = ( pri_slot == 2'b00 ) ? 4'b0001 :
                          ( pri_slot == 2'b01 ) ? 4'b0010 :
                          ( pri_slot == 2'b10 ) ? 4'b0100 :
                                                  4'b1000;

    assign page_num = ( bus_addr[15:14] == 2'b00) ? 4'b0001 :
                      ( bus_addr[15:14] == 2'b01) ? 4'b0010 :
                      ( bus_addr[15:14] == 2'b10) ? 4'b0100 :
                                                    4'b1000;

    assign exp_slotx_page = ( bus_addr[15:14] == 2'b00) ? exp_slotx[1:0] :
                            ( bus_addr[15:14] == 2'b01) ? exp_slotx[3:2] :
                            ( bus_addr[15:14] == 2'b10) ? exp_slotx[5:4] :
                                                          exp_slotx[7:6];

    assign exp_slotx_num = ( exp_slotx_page == 2'b00 ) ? 4'b0001 :
                           ( exp_slotx_page == 2'b01 ) ? 4'b0010 :
                           ( exp_slotx_page == 2'b10 ) ? 4'b0100 :
                                                         4'b1000;

    reg slot0_req_r;
    wire slot0_req_w;
    wire slot3_req_r;
    wire slot3_req_w;
    reg slot_sd_req_r;
    always @ (posedge clk_27m) begin
        slot0_req_r <= ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 ) ? 1 : 0;
    end
`ifdef ENABLE_BIOS
    assign slot0_req_w = ( bus_mreq_n == 0 && bus_wr_n == 0 && pri_slot_num[0] == 1 ) ? 1 : 0;
`endif
    assign slot3_req_r = ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[3] == 1 ) ? 1 : 0;
    assign slot3_req_w = ( bus_mreq_n == 0 && bus_wr_n == 0 && pri_slot_num[3] == 1 ) ? 1 : 0;
    always @ (posedge clk_27m) begin
        //slot_sd_req_r <= ( config_enable_sdcard == 1 && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot == config_sdcard_slot && xffh == 1 && xffl == 1) ? 1 : 0;
        slot_sd_req_r <= ( config_enable_sdcard == 1 && bus_rfsh_n == 1 && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot == config_sdcard_slot ) ? 1 : 0;
    end

`ifdef ENABLE_BIOS
    //bios
    reg bios_req;
    wire [7:0] bios_dout;
    wire [7:0] bios_int_dout;
    wire [7:0] key_bra_dout;
    wire keyboard_area;
    always @ (posedge clk_27m) begin
        bios_req <= ( bus_addr[15] == 0 && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 && exp_slotx_num[0] == 1 ) ? 1 : 0;
    end
    //assign bios_req = ( bus_addr[15] == 0 && bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 ) ? 1 : 0;
    assign keyboard_area = ( bus_addr[14:8] == 7'hd || bus_addr[14:8] == 7'he ) ? 1 : 0;

    bios_msx2p bios1 (
        .address (bus_addr[14:0]),
        .clock (clk_27m),
        .data (8'h00),
        .wren (0),
        .q (bios_dout)
    );

//    keyboard_bra key_bra1 (
//        .address ( { ~bus_addr[8], bus_addr[7:0] } ),
//        .clock (clk_108m),
//        .data (8'h00),
//        .wren (0),
//        .q (key_bra_dout)
//    );
//    assign bios_dout = ( config_keyboard != 2'b01 || keyboard_area == 0 ) ? bios_int_dout : key_bra_dout;

    //subrom
    reg subrom_req;
    wire [7:0] subrom_dout;
    always @ (posedge clk_27m) begin
        subrom_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 && page_num[0] == 1 && exp_slotx_num[1] == 1 ) ? 1 : 0;
    end
    //assign subrom_req = ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[2] == 1 && page_num[0] == 1 ) ? 1 : 0;

    subrom_msx2p subrom1 (
        .address (bus_addr[13:0]),
        .clock (clk_27m),
        .data (8'h00),
        .wren (0),
        .q (subrom_dout)
    );

    //msx logo
    reg msx_logo_req;
    wire [7:0] msx_logo_dout;
    always @ (posedge clk_27m) begin
        msx_logo_req <= ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[0] == 1 && page_num[1] == 1 && exp_slotx_num[1] == 1 ) ? 1 : 0;
    end
    //assign msx_logo_req = ( bus_mreq_n == 0 && bus_rd_n == 0 && pri_slot_num[2] == 1 && page_num[1] == 1 ) ? 1 : 0;

    logo_fm logo1 (
        .address (bus_addr[13:0]),
        .clock (clk_27m),
        .data (8'h00),
        .wren (0),
        .q (msx_logo_dout)
    );

`else

    wire bios_req;
    wire subrom_req;

`endif

    //rtc
    wire rtc_req_r;
    wire rtc_req_w;
    wire [7:0] rtc_dout;
    assign rtc_req_w = (bus_addr[7:1] == 7'b1011010 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1 : 0; // I/O:B4-B5h   / RTC
    assign rtc_req_r = (bus_addr[7:1] == 7'b1011010 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1 : 0; // I/O:B4-B5h   / RTC

    rtc rtc1(
        .clk21m(clk_27m),
        .reset(0),
        .clkena(1),
        .req(rtc_req_w | rtc_req_r),
        .ack(),
        .wrt(rtc_req_w),
        .adr(bus_addr),
        .dbi(rtc_dout),
        .dbo(cpu_dout)
    );

    //vdp
	wire vdp_csw_n; //VDP write request
	wire vdp_csr_n; //VDP read request	
    wire [7:0] vdp_dout;
    wire vdp_int;
    wire WeVdp_n;
    wire [16:0] VdpAdr;
    wire [15:0] VrmDbi;
    wire [7:0] VrmDbo;
    wire VideoDHClk;
    wire VideoDLClk;
    assign vdp_csw_n = (bus_addr[7:2] == 6'b100110 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 0:1; // I/O:98-9Bh   / VDP (V9938/V9958)
    assign vdp_csr_n = (bus_addr[7:2] == 6'b100110 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 0:1; // I/O:98-9Bh   / VDP (V9938/V9958)

    v9958_top vdp4 (
        .clk (clk_27m),
        .s1 (0),
        .clk_50 (0),
        .clk_125 (0),

    `ifdef ENABLE_V9958
        .reset_n (bus_reset_n ),
    `else
        .reset_n (0),
    `endif
        .mode    (bus_addr[1:0]),
        .csw_n   (vdp_csw_n),
        .csr_n   (vdp_csr_n),

        .int_n   (vdp_int),
        .gromclk (),
        .cpuclk  (),
        .cdi     (vdp_dout),
        .cdo     (cpu_dout),

        .audio_sample   (audio_sample),

        .adc_clk  (),
        .adc_cs   (),
        .adc_mosi (),
        .adc_miso (0),

        .maxspr_n    (1),
    `ifdef ENABLE_SCAN_LINES
        .scanlin_n   (~config_enable_scanlines),
    `else
        .scanlin_n   (1),
    `endif
        .gromclk_ena_n (1),
        .cpuclk_ena_n  (1),

        .WeVdp_n(WeVdp_n),
        .VdpAdr(VdpAdr),
        .VrmDbi(VrmDbi2),
        .VrmDbo(VrmDbo),

        .VideoDHClk(VideoDHClk),
        .VideoDLClk(VideoDLClk),

        .tmds_clk_p    (clk_p),
        .tmds_clk_n    (clk_n),
        .tmds_data_p   (data_p),
        .tmds_data_n   (data_n)
    );

`ifdef ENABLE_MAPPER
    //mapper
    wire mapper_read;
    wire mapper_write;
    wire mapper_req;
    reg mapper_req0;
    reg mapper_req123;
    reg [7:0] mapper_dout;
    wire [21:0] mapper_addr;
    reg [7:0] mapper_reg0;
    reg [7:0] mapper_reg1;
    reg [7:0] mapper_reg2;
    reg [7:0] mapper_reg3;
    wire mapper_reg_write;

    assign mapper_addr = (bus_addr [15:14] == 2'b00 ) ? { mapper_reg0, bus_addr[13:0] } :
                         (bus_addr [15:14] == 2'b01 ) ? { mapper_reg1, bus_addr[13:0] } :
                         (bus_addr [15:14] == 2'b10 ) ? { mapper_reg2, bus_addr[13:0] } :
                                                        { mapper_reg3, bus_addr[13:0] };

    always @ (posedge clk_27m) begin
        mapper_req0 <= ( bus_rfsh_n == 1 && config_enable_mapper0 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_mapper_slot && exp_slotx_num[3] == 1 && xffff == 0) ? 1 : 0;
        mapper_req123 <= ( config_enable_mapper123 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_mapper_slot ) ? 1 : 0;
    end
    assign mapper_req = mapper_req0 | mapper_req123;
    assign mapper_read = mapper_req & ~bus_rd_n;
    assign mapper_write = mapper_req & ~bus_wr_n;
    assign mapper_reg_write = ( (bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0) && (bus_addr [7:2] == 6'b111111) )?1:0;

    always @(posedge clk_27m or negedge bus_reset_n) begin
        if (bus_reset_n == 0) begin
            mapper_reg0	<= 8'b00000011;
            mapper_reg1	<= 8'b00000010;
            mapper_reg2	<= 8'b00000001;
            mapper_reg3	<= 8'b00000000;
        end
        else if (mapper_reg_write == 1) begin
            case (bus_addr[1:0])
`ifndef SDRAM_32
                2'b00: mapper_reg0 <= { 1'b0, cpu_dout[6:0] };
                2'b01: mapper_reg1 <= { 1'b0, cpu_dout[6:0] };
                2'b10: mapper_reg2 <= { 1'b0, cpu_dout[6:0] };
                2'b11: mapper_reg3 <= { 1'b0, cpu_dout[6:0] };
`else
                2'b00: mapper_reg0 <= cpu_dout[7:0];
                2'b01: mapper_reg1 <= cpu_dout[7:0];
                2'b10: mapper_reg2 <= cpu_dout[7:0];
                2'b11: mapper_reg3 <= cpu_dout[7:0];
`endif
            endcase
        end
    end
`else
    wire mapper_read;
    wire mapper_write;
    wire mapper_req;
    reg [7:0] mapper_dout;
    wire [21:0] mapper_addr;
    assign mapper_read = 0;
    assign mapper_write = 0;
    assign mapper_addr = 22'd0;
`endif

reg [15:0] VrmDbi2;
reg [7:0] megaram_dout;

memory_ctrl mem1 (
    .clk_27m(clk_27m),
    .clk_108m(clk_108m),
    .bus_reset_n(bus_reset_n ),
    .video_dhclk(VideoDHClk),
    .video_dlclk(VideoDLClk),

    .mapper_din(cpu_dout),
    .mapper_req(mapper_req),
    .mapper_write(mapper_write),
    .megaram_req(megaram_req),
    .megaram_write(megaram_wrt),
    .mapper_addr(mapper_addr),
    .megaram_addr(megaram_addr),
    .vram_din(VrmDbo),
    .vram_write(~WeVdp_n),
    .vram_addr(VdpAdr),
    .bus_rfsh_n(bus_rfsh_n),

    .mapper_dout(mapper_dout),
    .megaram_dout(megaram_dout),
    .vram_dout(VrmDbi2),

    .O_sdram_clk(O_sdram_clk),
    .O_sdram_cke(O_sdram_cke),
    .O_sdram_cs_n(O_sdram_cs_n),
    .O_sdram_cas_n(O_sdram_cas_n),
    .O_sdram_ras_n(O_sdram_ras_n),
    .O_sdram_wen_n(O_sdram_wen_n),
    .IO_sdram_dq(IO_sdram_dq),
    .O_sdram_addr(O_sdram_addr),
    .O_sdram_ba(O_sdram_ba),
    .O_sdram_dqm(O_sdram_dqm)
);




`ifdef ENABLE_SOUND

    //YM219 PSG
    wire psgBdir;
    wire psgBc1;
    wire iorq_wr_n;
    wire iorq_rd_n;
    wire [7:0] psg_dout;
    wire [7:0] psgSound1;
    wire [7:0] psgPA;
    wire [7:0] psgPB;
    reg clk_1m8;
    assign iorq_wr_n = bus_iorq_n | bus_wr_n;
    assign iorq_rd_n = bus_iorq_n | bus_rd_n;
    assign psgBdir = ( bus_addr[7:3]== 5'b10100 && iorq_wr_n == 0 && bus_addr[1]== 0 ) ?  1 : 0; // I/O:A0-A2h / PSG(AY-3-8910) bdir = 1 when writing to &HA0-&Ha1
    assign psgBc1 = ( bus_addr[7:3]== 5'b10100 && ((iorq_rd_n==0 && bus_addr[1]== 1) || (bus_addr[1]==0 && iorq_wr_n==0 && bus_addr[0]==0))) ? 1 : 0; // I/O:A0-A2h / PSG(AY-3-8910) bc1 = 1 when writing A0 or reading A2
    assign psgPA =8'h00;
    reg psgPB = 8'hff;

    wire clk_enable_1m8;
    reg clk_1m8_prev;
    always @ (posedge clk_27m) begin
        if (clk_enable_3m6_27) begin
            clk_1m8 <= ~clk_1m8;
        end
    end
    assign clk_enable_1m8 = (clk_enable_3m6_27 == 1 && clk_1m8 == 1);

    YM2149 psg1 (
        .I_DA(cpu_dout),
        .O_DA(),
        .O_DA_OE_L(),
        .I_A9_L(0),
        .I_A8(1),
        .I_BDIR(psgBdir),
        .I_BC2(1),
        .I_BC1(psgBc1),
        .I_SEL_L(1),
        .O_AUDIO(psgSound1),
        .I_IOA(psgPA),
        .O_IOA(),
        .O_IOA_OE_L(),
        .I_IOB(psgPB),
        .O_IOB(psgPB),
        .O_IOB_OE_L(),
        
        .ENA(clk_enable_1m8), // clock enable for higher speed operation
        .RESET_L(bus_reset_n),
        .CLK(clk_27m),
        .clkHigh(clk_27m),
        .debug ()
    );

    wire [7:0] psgSound3;
    psg_filter filter1 (
        .clk_27m (clk_27m),
        .reset (~bus_reset_n),
        .data_in (psgSound1),
        .data_out (psgSound3)
    );

    //opll
    wire opll_req_n; 
    wire [9:0] opll_mo;
    wire [9:0] opll_ro;
    reg [11:0] opll_mix;
    wire [15:0] jt2413_wav;

    assign opll_req_n = ( bus_iorq_n == 1'b0 && bus_addr[7:1] == 7'b0111110  &&  bus_wr_n == 1'b0 )  ? 1'b0 : 1'b1;    // I/O:7C-7Dh   / OPLL (YM2413)
  
    jt2413 opll(
        .rst (~bus_reset_n),        // rst should be at least 6 clk&cen cycles long
        .clk (clk_27m),        // CPU clock
        .cen (clk_enable_3m6_27),        // optional clock enable, if not needed leave as 1'b1
        .din (cpu_dout),
        .addr (bus_addr[0]),
        .cs_n (opll_req_n),
        .wr_n (1'b0),
        // combined output
        .snd (jt2413_wav),
        .sample   ( )
    ); 

    //scc & ghost scc
    wire [14:0] scc_wav;
    wire [7:0] scc_dout;
    wire scc_req;
    reg scc_req0;
    wire scc_req0_r;
    reg scc_req123;

    wire scc_wrt;
    
    reg x98h;
    always @ (posedge clk_27m) begin
        x98h <= ( bus_addr[15:8] == 8'h98 ) ? 1 : 0;
    end

    reg [7:0] scc_bank2;
    reg scc_enable_req0;
    reg scc_enable_req123;
    wire scc_enable_req;
    always @ (posedge clk_27m) begin
        scc_enable_req0 <= ( bus_addr[15:11] == 5'b10010 && bus_mreq_n == 0 && bus_wr_n == 0 && pri_slot_num[0] == 1 && exp_slotx_num[2] == 1 ) ? 1 : 0;
        scc_enable_req123 <= ( config_enable_megaram123 == 1 && bus_addr[15:11] == 5'b10010 && bus_mreq_n == 0 && bus_wr_n == 0 && pri_slot == config_megaram_slot ) ? 1 : 0;
    end
    assign scc_enable_req = scc_enable_req0 | scc_enable_req123;

    always @ (posedge clk_27m or negedge bus_reset_n) begin
        if ( bus_reset_n == 0)
            scc_bank2 <= 8'h00;
        else begin
            if (scc_enable_req == 1 ) begin
                scc_bank2 <= cpu_dout;
            end
        end
    end

    wire scc_enable;
    assign scc_enable = ( scc_bank2 == 8'h3f ) ? 1 : 0;

    always @ (posedge clk_27m) begin
        scc_req0 <= ( config_enable_megaram0 == 1 && scc_enable == 1 && x98h == 1 && bus_mreq_n == 0 && (bus_wr_n == 0 || bus_rd_n == 0 ) && pri_slot == config_megaram_slot && exp_slotx_num[2] == 1  ) ? 1 : 0;
        scc_req123 <= ( config_enable_megaram123 == 1 && scc_sound_disable == 0 && scc_enable == 1 && x98h == 1 && bus_mreq_n == 0 && (bus_wr_n == 0 || bus_rd_n == 0 ) && pri_slot == config_megaram_slot ) ? 1 : 0;
    end
    assign scc_req = scc_req0 | scc_req123;
    assign scc_req0_r = ( scc_req0 == 1 && bus_rd_n == 0 ) ? 1 : 0;
    assign scc_wrt = ( scc_req == 1 && bus_wr_n == 0 ) ? 1 : 0;

    scc_wave2 SccCh (
        .clk21m (clk_27m),
        .reset (~bus_reset_n),
        .clkena (clk_enable_3m6_27),
        .req ( scc_req),
        .ack (),
        .wrt (scc_wrt),
        .adr (bus_addr[7:0]),
        .dbi (scc_dout),
        .dbo (cpu_dout),
        .wave (scc_wav)
    );

    reg scc2_req0;
    reg scc2_req123;
    reg scc2_req;
    wire scc2_req_r;
    wire scc2_wrt;
    wire [7:0] scc2_dout;
    wire [14:0] scc2_wav;
    wire megaram_req;
    wire megaram_wrt;
    wire [20:0] megaram_addr;
    wire megaram_enabled;

    always @ (posedge clk_27m) begin
        scc2_req0 <= ( config_enable_ghost_scc == 0 && config_enable_megaram0 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_megaram_slot && exp_slotx_num[2] == 1  && xffff == 0) ? 1 : 0;
        scc2_req123 <= ( config_enable_ghost_scc == 0 && config_enable_megaram123 == 1 && bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot == config_megaram_slot ) ? 1 : 0;
//        scc2_req <= ( bus_mreq_n == 0 && (bus_rd_n == 0 || bus_wr_n == 0 ) && pri_slot_num[2] == 1 ) ? 1 : 0;
    end
    assign scc2_req = scc2_req0 | scc2_req123;
    assign scc2_req_r = ( scc2_req == 1 && bus_rd_n == 0 ) ? 1 : 0;
    assign scc2_wrt = ( scc2_req == 1 && bus_wr_n == 0 ) ? 1 : 0;

    wire [1:0] map_sel;
    wire map_linear;
    assign map_sel = Slot2Mode;
    assign map_linear = iSlt2_linear;

    megaram_scc megaram1 (
        .clk_27m (clk_27m),
        .bus_reset_n (bus_reset_n),
        .bus_addr (bus_addr),
        .cpu_dout (cpu_dout),
        .bus_rd_n (bus_rd_n),
        .bus_wr_n (bus_wr_n),
        .scc_req (scc2_req),
        .scc_wrt (scc2_wrt),
        .map_sel (map_sel),
        .map_linear (map_linear),

        .megaram_req (megaram_req),
        .megaram_wrt (megaram_wrt), 
        .megaram_addr (megaram_addr),
        .scc_sound_disable (scc_sound_disable)
    );


    //mixer
    reg [23:0] fm_wav;
    reg [16:0] fm_mix;
    reg [14:0] scc_wav2;
	reg [15:0] audio_sample;

    always @ (posedge clk_27m) begin
        if (clk_enable_3m6_27 == 1 ) begin
            if (map_sel[0] == 0)
                audio_sample <= { 2'b0 , psgSound3 , 6'b000000 } + { scc_wav, 1'b0 } + jt2413_wav;
            else
                audio_sample <= { 2'b0 , psgSound3 , 6'b000000 } + jt2413_wav;
        end
    end

`else

    wire scc2_req;
    wire [14:0] scc2_wav;
    wire megaram_req;
    wire [22:0] megaram_addr;
    wire megaram_enabled;
    reg [15:0] audio_sample;
    wire megaram_wrt;

`endif


`ifdef ENABLE_CONFIG
    //config
    reg [7:0] config0_ff = 8'h00;
    reg [7:0] config1_ff = 8'h0b;
    reg [7:0] config1_temp_ff;
    reg [7:0] config2_ff = 8'h07;
    reg [7:0] config2_temp_ff;
    reg [1:0] config_mapper_slot_ff = 2'b00;
    reg [1:0] config_megaram_slot_ff = 2'b00;
    reg [1:0] config_sdcard_slot_ff = 2'b11;
    reg config_enable_mapper0;
    reg config_enable_mapper123;
    wire config_enable_megaram;
    wire config_enable_megaram0;
    wire config_enable_megaram123;
    wire config_enable_ghost_scc;
    reg config_enable_sdcard;
    wire config_enable_wait;
    reg config_reset_ff;
    reg config_update;
    wire config_enable_scanlines;
    wire [1:0] config_mapper_slot;
    wire [1:0] config_megaram_slot;
    wire [1:0] config_sdcard_slot;
    wire [1:0] config_keyboard;
    wire config0_req;
    wire config1_req;
    wire config2_req;
    wire config_reset;
    wire config_ok;
    wire [7:0] config_dout;
    wire config_req;

    always @ (posedge clk_27m) begin
        config_reset_ff <= 0;
        config_update <= 0;
        if (clk_enable_3m6_27 == 1 ) begin
            if (config0_req == 1 ) begin
                config0_ff <= ~cpu_dout;
            end

            if (config1_req == 1 ) begin
                config_update <= 1;
                config1_temp_ff <= cpu_dout;
            end
            if (config2_req == 1 ) begin
                config_update <= 1;
                config2_temp_ff <= cpu_dout[6:0];
                if ( cpu_dout[7] == 1) begin
                    config_reset_ff <= 1;
                end
            end
        end
    end

    reg [2:0] ocm_slot2_prev; //bit2 = linear ,bits 1,0 = mode
    reg ocm_update;
    always @ (posedge clk_27m) begin
        ocm_update <= 0;
        if ( { iSlt2_linear, Slot2Mode } != ocm_slot2_prev ) begin
            ocm_update <= 1;
        end
    end

    always @ (posedge clk_27m) begin
        if (config_update == 1) begin
            config1_ff <= config1_temp_ff;
            config2_ff <= config2_temp_ff;
        end
        if (ocm_update == 1) begin
            config1_ff[7:6] <= 2'b10;
            config1_ff[1] <= 1;
            ocm_slot2_prev <= { iSlt2_linear, Slot2Mode };
        end
    end

    monostable mono (
        .pulse_in(config_reset_ff),
        .clock(clk_27m),
        .pulse_out(config_reset)
    );

    assign config_ok = (config0_ff == 8'hb7) ? 1 : 0;
    assign config0_req = (bus_addr[7:0] == 8'h40 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config1_req = (config_ok == 1 && bus_addr[7:0] == 8'h41 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config2_req = (config_ok == 1 && bus_addr[7:0] == 8'h42 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign config_enable_scanlines = config1_ff[3];
    //assign config_keyboard = config2_ff[4:3];
    assign config_enable_wait = config2_ff[3];
    assign config_req = (bus_addr[7:4] == 4'h4 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign config_dout = ( bus_addr[3:0] == 4'h0 ) ? config0_ff :
                         ( bus_addr[3:0] == 4'h1 ) ? config1_ff :
                         ( bus_addr[3:0] == 4'h2 ) ? config2_ff : 8'hff;


    always_latch begin
        if (~bus_reset_n) begin
            config_mapper_slot_ff <= config1_ff[5:4];
            //config_megaram_slot_ff <= config1_ff[7:6];
            config_enable_mapper0 <= (config1_ff[0] == 1 && config1_ff[5:4] == 2'b00);
            config_enable_mapper123 <= (config1_ff[0] == 1 && config1_ff[5:4] != 2'b00);
            config_enable_sdcard <= config2_ff[0];
            config_sdcard_slot_ff <= config2_ff[2:1];
        end
    end
    assign config_mapper_slot = config_mapper_slot_ff;
    assign config_megaram_slot = config1_ff[7:6];;
    assign config_sdcard_slot = config_sdcard_slot_ff;
    assign config_enable_megaram = config1_ff[1];
    assign config_enable_megaram0 = (config1_ff[1] == 1 && config1_ff[7:6] == 2'b00);
    assign config_enable_megaram123 = (config1_ff[1] == 1 && config1_ff[7:6] != 2'b00);
    assign config_enable_ghost_scc = config1_ff[2];

`else

    wire config_enable_mapper0;
    wire config_enable_mapper123;
    wire config_enable_megaram;
    wire config_enable_megaram0;
    wire config_enable_megaram123;
    wire config_enable_ghost_scc;
    wire config_enable_sdcard;
    wire config_enable_scanlines;
    wire [1:0] config_mapper_slot;
    wire [1:0] config_megaram_slot;
    wire [1:0] config_sdcard_slot;
    wire config_reset;
    assign config_enable_mapper0 = 1;
    assign config_enable_mapper123 = 0;
    assign config_enable_megaram = 1;
    assign config_enable_megaram0 = 1;
    assign config_enable_megaram123 = 0;
    assign config_enable_ghost_scc = 0;
    assign config_enable_sdcard = 0;
    assign config_enable_scanlines = 1;
    assign config_mapper_slot = 2'b00;
    assign config_megaram_slot = 2'b00;
    assign config_sdcard_slot= 2'b11;
    assign config_reset = 0;

`endif

`ifdef ENABLE_SDCARD

    //megarom
    reg megarom_req;
    wire [24:0] megarom_addr;
    reg [2:0] megarom_page_ff;
    reg megarom_page_req;
    wire [2:0] megarom_page;

    always @ (posedge clk_27m) begin
        megarom_req <=     ( config_enable_sdcard == 1 && bus_mreq_n == 0 && bus_rfsh_n == 1 && bus_rd_n == 0 && pri_slot == config_sdcard_slot && (page_num[1] == 1 || page_num[2] == 1) ) ? 1 : 0;
        megarom_page_req <= ( bus_mreq_n == 0 && bus_rfsh_n == 1 && bus_wr_n == 0 && pri_slot == config_sdcard_slot && bus_addr == 16'h6000 ) ? 1 : 0;
    end
    assign megarom_page = megarom_page_ff;
    assign megarom_addr = { 8'b00001000, megarom_page, bus_addr[13:0] };

    always @(posedge clk_27m or negedge bus_reset_n) begin
        if (bus_reset_n == 0) begin
           megarom_page_ff <= 3'b0;
        end 
        else begin
            if (bus_clk_3m6_27 == 1) begin
                if (megarom_page_req == 1) begin
                    megarom_page_ff <= cpu_dout[2:0]; // select page
                end
            end
        end
    end

//flash
    reg [23:0] ff_flash_addr = 24'd0;
    reg ff_flash_rd = 0;
    reg ff_flash_terminate = 0;
    reg [7:0] ff_rom_dout;
    reg flash_wait_n;
    wire[7:0] flash_dout;
    wire flash_data_ready;
    wire flash_busy;

    flash # (
        .STARTUP_WAIT(1)
    )
    flash1
    (
        .clk(clk_27m),
        .reset_n(bus_reset_n),
        .SCLK(mspi_sclk),
        .CS(mspi_cs),
        .MISO(mspi_miso),
        .MOSI(mspi_mosi),
        .addr(ff_flash_addr),
        .rd(ff_flash_rd),
        .dout(flash_dout),
        .data_ready(flash_data_ready),
        .busy(flash_busy),
        .terminate(ff_flash_terminate)
    );

    reg [7:0] ff_flash_state = 8'd0;

    localparam STATE_RESET          = 8'd0;
    localparam STATE_READ_START     = 8'd1;
    localparam STATE_READ_WAIT      = 8'd2;
    localparam STATE_READ_LOOP      = 8'd3;
    localparam STATE_IDLE           = 8'd4;

    always @(posedge clk_27m, negedge bus_reset_n) begin
    if (bus_reset_n == 0) begin
        ff_flash_state = STATE_RESET;
        ff_flash_rd <= 0;
        flash_wait_n <= 1;
    end else
        case (ff_flash_state)
            STATE_RESET: begin   // reset
                ff_flash_state <= STATE_READ_START;
                ff_flash_rd <= 0;
                ff_flash_terminate <= 1;
            end
            STATE_READ_START: begin  // start read
                if (flash_busy == 0) begin
                    ff_flash_addr <= 24'h100000;
                    ff_flash_state = STATE_READ_WAIT;
                end
            end
            STATE_READ_WAIT: begin  // start read
                if (megarom_req == 1) begin
                    flash_wait_n <= 0;
                    ff_flash_addr <= megarom_addr ;
                    ff_flash_rd <= 1;
                    ff_flash_terminate <= 0;
                    ff_flash_state = STATE_READ_LOOP;
                end
            end
            STATE_READ_LOOP: begin  // loop read
                if (flash_busy == 0 && ff_flash_rd <= 0) begin
                    ff_rom_dout <= flash_dout; 
                    ff_flash_state <= STATE_IDLE;
                end
                else begin
                    ff_flash_rd <= 0;
                end
            end
            STATE_IDLE: begin  // idle
                flash_wait_n <= 1;
                ff_flash_terminate <= 1;
                if (megarom_req == 0) begin
                    ff_flash_state <= STATE_READ_START;
                end
            end
        endcase
    end


    //sd card
    localparam int SDC_SDATA		=  16'h7C00;		 	// rw: 7C00h-7Dff - sector transfer area
    localparam int SDC_ENABLE  	    =  16'h7E00;		    // wo: 1: enable SDC register, 0: disable
    localparam int SDC_CMD			=  SDC_ENABLE+1; 		// wo: cmd to SDC fpga: 1=sd read, 2=sd write
    localparam int SDC_STATUS		=  SDC_CMD+1;	 		// ro: SDC status bits
    localparam int SDC_SADDR		=  SDC_STATUS+1;	 	// wo: 4 bytes: sector addr for read/write
    localparam int SDC_C_SIZE  	    =  SDC_SADDR+4;			// ro: 3 bytes: device size blocks
    localparam int SDC_C_SIZE_MULT	=  SDC_C_SIZE+3;		// ro: 3 bits size multiplier
    localparam int SDC_RD_BL_LEN	=  SDC_C_SIZE_MULT+1;	// ro: 4 bits block length
    localparam int SDC_CTYPE		=  SDC_RD_BL_LEN+1;		// ro: SDC Card type: 0=unknown, 1=SDv1, 2=SDv2, 3=SDHCv2 
    localparam int SDC_MID		    =  SDC_CTYPE+1;		    // ro: manufacture ID: 8 bits unsigned
    localparam int SDC_OID		    =  SDC_MID+1;		    // ro: oem id: 2 character
    localparam int SDC_PNM		    =  SDC_OID+2;		    // ro: product name: 5 character
    localparam int SDC_PSN		    =  SDC_PNM+5;		    // ro: serial number: 32 bits unsigned
    localparam int SCC_ENABLE       =  16'h7E80;            // wo: enable disable SCC+
    localparam int SDC_END          =  16'h7EFF; 
    
    wire [8:0] sram_addr_w;
    reg ff_sram_we = 0;
    reg [7:0] ff_sram_cdin;
    reg [7:0] ff_sram_cdout;
    //
    reg ff_sd_en = 0;
    reg sram_cs_w;
    wire sram_busreq_w;
    wire [7:0] sram_cd_w;
    
    wire [3:0] sd_card_stat_w;
    wire [1:0] sd_card_type_w;
    reg ff_sd_rstart;
    reg ff_sd_init;
    reg [31:0] ff_sd_sector;
    wire sd_busy_w;
    wire sd_done_w;
    wire sd_outen_w;
    wire [8:0] sd_outaddr_w;
    wire [7:0] sd_outbyte_w;
    reg ff_sd_wstart;
    wire [7:0] sd_inbyte_w;
    
    wire [21:0] sd_c_size_w;
    wire [2:0] sd_c_size_mult_w;
    wire [3:0] sd_read_bl_len_w;
    
    wire [7:0] sd_mid_w;
    wire [15:0] sd_oid_w;
    wire [39:0] sd_pnm_w;
    wire [31:0] sd_psn_w;
    wire sd_crc_error_w;
    wire sd_timeout_error_w;
    //reg ff_scc_enable;
    //wire scc_enable_w;
    //assign scc_enable_w = ff_scc_enable;
    always @ (posedge clk_27m) begin
        sram_cs_w <= config_enable_sdcard == 1 && bus_reset_n && ff_sd_en && bus_iorq_n == 1 && bus_m1_n == 1 && bus_mreq_n == 0 && pri_slot == config_sdcard_slot && ( bus_addr >= SDC_SDATA && bus_addr < SDC_ENABLE) ? 1 : 0;
    end
    assign sram_busreq_w = sram_cs_w && ~bus_rd_n;
    
    dpram#(
        .widthad_a(9),
        .width_a(8)
    ) dpram1 (
        .clock_a(clk_27m),
        .wren_a(bus_clk_3m6_27 && sram_cs_w && ~bus_wr_n),
        .rden_a(bus_clk_3m6_27 && sram_cs_w && ~bus_rd_n),
        .address_a(bus_addr[8:0]),
        .data_a(cpu_dout),
        .q_a(sram_cd_w),
    
        .clock_b(clk_27m),
        .wren_b(ff_sd_rstart && sd_outen_w),
        .rden_b(ff_sd_wstart && sd_outen_w),
        .address_b(sd_outaddr_w),
        .data_b(sd_outbyte_w),
        .q_b(sd_inbyte_w)
    );
    
    sd_reader #(
        .CLK_DIV(3'd2),
        .SIMULATE(0)
    ) sd1 (
        .rstn(bus_reset_n),
        .clk(clk_27m),
        .sdclk(sd_sclk),
        .sdcmd(sd_cmd),
        .sddat0(sd_dat0),                  
        .card_stat(sd_card_stat_w),        // show the sdcard initialize status
        .card_type(sd_card_type_w),        // 0=UNKNOWN    , 1=SDv1    , 2=SDv2  , 3=SDHCv2
        .rstart(ff_sd_rstart), 
        .rsector(ff_sd_sector),
        .rbusy(sd_busy_w),
        .rdone(sd_done_w),
        .outen(sd_outen_w),                // when outen=1, a byte of sector content is read out from outbyte
        .outaddr(sd_outaddr_w),            // outaddr from 0 to 511, because the sector size is 512
        .outbyte(sd_outbyte_w),            // a byte of sector content
        .wstart(ff_sd_wstart), 
        .inbyte(sd_inbyte_w),
        .c_size(sd_c_size_w),
        .c_size_mult(sd_c_size_mult_w),
        .read_bl_len(sd_read_bl_len_w),
        .mid(sd_mid_w),
        .oid(sd_oid_w),
        .pnm(sd_pnm_w),
        .psn(sd_psn_w),
        .crc_error(sd_crc_error_w),
        .timeout_error(sd_timeout_error_w),
        .init(ff_sd_init)
    );
    
    assign sd_dat1 = 1;
    assign sd_dat2 = 1;
    assign sd_dat3 = 1; // Must set sddat1~3 to 1 to avoid SD card from entering SPI mode
    
    
    always @(posedge clk_27m or negedge bus_reset_n) begin
        if (~bus_reset_n) begin
            ff_sd_en <= 0;
        end else begin
            if (config_enable_sdcard == 1 && pri_slot == config_sdcard_slot && bus_addr == SDC_ENABLE && ~bus_wr_n && bus_iorq_n && bus_m1_n) 
                ff_sd_en <= cpu_dout[0];
        end
    end
    
    reg sd_cs_w;
    always @ (posedge clk_27m) begin
        sd_cs_w <= config_enable_sdcard == 1 && bus_reset_n && ff_sd_en && bus_iorq_n && bus_m1_n && bus_mreq_n == 0 && pri_slot == config_sdcard_slot && (bus_addr >= SDC_ENABLE && bus_addr <= SDC_END) ? 1 : 0;
    end
    wire sd_busreq_w;
    assign sd_busreq_w = sd_cs_w && ~bus_rd_n;
    reg [7:0] ff_sd_cd;
    wire [7:0] sd_cd_w;
    assign sd_cd_w = ff_sd_cd;
    
    always @(posedge clk_27m or negedge bus_reset_n) begin
        if (~bus_reset_n) begin
            ff_sd_rstart <= '0;
            ff_sd_wstart <= '0;
            ff_sd_init <= '0;
        end else begin
            if (sd_done_w) begin
                ff_sd_rstart <= '0;
                ff_sd_wstart <= '0;
            end
    
            if (sd_cs_w) begin
                if (~bus_wr_n) begin
                    case(bus_addr) 
                        SDC_CMD: begin
                            ff_sd_rstart <= ff_sd_rstart | cpu_dout[0];
                            ff_sd_wstart <= ff_sd_wstart | cpu_dout[1];
                            ff_sd_init   <= ff_sd_init   | cpu_dout[7];
                            //ff_sms_init  <= ff_sms_init  | cdin_w[7];
                        end
                        SDC_SADDR+0:    ff_sd_sector[ 7: 0] <= cpu_dout;
                        SDC_SADDR+1:    ff_sd_sector[15: 8] <= cpu_dout;
                        SDC_SADDR+2:    ff_sd_sector[23:16] <= cpu_dout;
                        SDC_SADDR+3:    ff_sd_sector[31:24] <= cpu_dout;
                    endcase
                end else
                if (~bus_rd_n) begin
                    case(bus_addr) 
                        SDC_ENABLE:     ff_sd_cd <= { 7'b0, ff_sd_en };
                        SDC_STATUS:     ff_sd_cd <= { sd_busy_w, 5'b0, sd_timeout_error_w, sd_crc_error_w };
                        SDC_C_SIZE+0:   ff_sd_cd <= sd_c_size_w[7:0];
                        SDC_C_SIZE+1:   ff_sd_cd <= sd_c_size_w[15:8];
                        SDC_C_SIZE+2:   ff_sd_cd <= { 2'b0, sd_c_size_w[21:16] };
                        SDC_C_SIZE_MULT:ff_sd_cd <= { 5'b0, sd_c_size_mult_w };
                        SDC_RD_BL_LEN:  ff_sd_cd <= { 4'b0, sd_read_bl_len_w };
                        SDC_CTYPE:      ff_sd_cd <= { 6'b0, sd_card_type_w };
                        SDC_MID:        ff_sd_cd <= sd_mid_w;
                        SDC_OID+0:      ff_sd_cd <= sd_oid_w[7:0];
                        SDC_OID+1:      ff_sd_cd <= sd_oid_w[15:8];
                        SDC_PNM+0:      ff_sd_cd <= sd_pnm_w[7:0];
                        SDC_PNM+1:      ff_sd_cd <= sd_pnm_w[15:8];
                        SDC_PNM+2:      ff_sd_cd <= sd_pnm_w[23:16];
                        SDC_PNM+3:      ff_sd_cd <= sd_pnm_w[31:24];
                        SDC_PNM+4:      ff_sd_cd <= sd_pnm_w[39:32];
                        SDC_PSN+0:      ff_sd_cd <= sd_psn_w[7:0];
                        SDC_PSN+1:      ff_sd_cd <= sd_psn_w[15:8];
                        SDC_PSN+2:      ff_sd_cd <= sd_psn_w[23:16];
                        SDC_PSN+3:      ff_sd_cd <= sd_psn_w[31:24];
                        default:        ff_sd_cd <= '1;
                    endcase
                end
            end
        end
    end

`else

    wire sd_busreq_w;
    wire sram_busreq_w;
    wire megarom_req;
    wire megarom_page_req;
    wire sram_cs_w;
    wire sd_cs_w;

`endif

    // Switched I/O ports
    reg [1:0] Slot2Mode;
    wire  swio_req;
    wire [7:0] io42_id212;
    wire iSlt2_linear;
    wire swio_req;
    wire swio_req_r;
    wire swio_req_w;
    wire [7:0] swio_dout;
    assign swio_req_r = (config_enable_megaram == 1 && bus_addr[7:4] == 4'b0100 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_rd_n == 0)? 1:0;
    assign swio_req_w = (config_enable_megaram == 1 && bus_addr[7:4] == 4'b0100 && bus_iorq_n == 0 && bus_m1_n == 1 && bus_wr_n == 0)? 1:0;
    assign swio_req = swio_req_r | swio_req_w;

    switched_io_ports ocm_ports (
            .clk21m        (clk_27m),
            .reset         (~bus_reset_n) ,
            .power_on_reset(1),
            .req           (swio_req   ),
            .ack           (           ),
            .wrt           (~bus_wr_n ),
            .adr           (bus_addr   ),
            .dbi           (swio_dout     ),
            .dbo           (cpu_dout      ),
            .io42_id212    (io42_id212    ),
            .iSlt2_linear  (iSlt2_linear  )
        );

    // virtual DIP-SW assignment (2/2)
    always @ ( posedge clk_27m )  begin
        Slot2Mode[1]    <=  io42_id212[4];
        Slot2Mode[0]    <=  io42_id212[5];
    end

//    wire send;
//    monostable mono2 (
//        .pulse_in(s2),
//        .clock(clk_27m),
//        .pulse_out(send)
//    );

//    msx2p_debug debug (
//        .clk_27m(clk_27m),
//        .clk (clk_27m),
//        .reset_n ( bus_reset_n ),
//        .clk_enable (clk_enable_3m6_27),
//        .bus_addr(bus_addr),
//        .bus_data(cpu_din),
//        .bus_iorq_n(bus_iorq_n),
//        .bus_mreq_n(bus_mreq_n),
//        .bus_wr_n(bus_wr_n),
//        .send(send),
//        .uart_tx(uart_tx),
//        .boot_ok( )
//    );

    timing_debug debug1(
        .clk_27m(clk_27m),
        .clk_108m(clk_108m),
        .reset_n(bus_reset_n),
        .bus_iorq_n(ex_bus_iorq_n),
        .bus_mreq_n(ex_bus_mreq_n),
        .bus_rd_n(ex_bus_rd_n),
        .bus_wr_n(ex_bus_wr_n),
        .send(send),

        .uart_tx(uart_tx)
    );

endmodule