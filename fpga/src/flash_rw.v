module flash
#(
  parameter STARTUP_WAIT = 32'd10000000
)
(
    input clk,
    input reset_n,
    output SCLK,
    output CS,
    input  MISO,
    output MOSI,

    input [23:0] addr,
    input rd,
    output [7:0] dout,
    output data_ready,
    output busy,
    input terminate,

    input write_enable,
    input [7:0] write_din,
    input [23:0] write_addr,
    output write_busy,
    output write_terminate,
    output [7:0] write_counter
);


  localparam STATE_INIT_POWER = 8'd0;
  localparam STATE_LOAD_CMD_TO_SEND = 8'd1;
  localparam STATE_SEND = 8'd2;
  localparam STATE_LOAD_ADDRESS_TO_SEND = 8'd3;
  localparam STATE_READ_DATA = 8'd4;
  localparam STATE_DATA_END = 8'd5;
  localparam STATE_WAIT_NEXT = 8'd6;
  localparam STATE_DONE = 8'd7;

  localparam STATE_READ_DATA2 = 8'h30;
  localparam STATE_SEND_SLOW1 = 8'h2c;
  localparam STATE_SEND_SLOW2 = 8'h2d;
  localparam STATE_SEND_SLOW3 = 8'h2e;
  localparam STATE_DELAY = 8'h2f;
  localparam STATE_06_1 = 8'h71;
  localparam STATE_06_2 = 8'h72;
  localparam STATE_06_3 = 8'h73;
  localparam STATE_05_1 = 8'h31;
  localparam STATE_05_2 = 8'h32;
  localparam STATE_05_3 = 8'h33;
  localparam STATE_20_1 = 8'h81;
  localparam STATE_20_2 = 8'h82;
  localparam STATE_20_3 = 8'h83;
  localparam STATE_05b_1 = 8'h91;
  localparam STATE_05b_2 = 8'h92;
  localparam STATE_05b_3 = 8'h93;
  localparam STATE_06b_1 = 8'hb1;
  localparam STATE_06b_2 = 8'hb2;
  localparam STATE_06b_3 = 8'hb3;
  localparam STATE_02_1 = 8'hc1;
  localparam STATE_02_2 = 8'hc2;
  localparam STATE_02_3 = 8'hc3;
  localparam STATE_02_4 = 8'hc4;
  localparam STATE_02_5 = 8'hc5;

  localparam CMD_READ_DATA_BYTES = 8'h03;
  localparam CMD_WRITE_ENABLE = 8'h06;
  localparam CMD_SECTOR_ERASE = 8'h20;
  localparam CMD_BLOCK_ERASE = 8'hd8;
  localparam CMD_READ_STATUS = 8'h05;
  localparam CMD_READ_STATUS2 = 8'h35;
  localparam CMD_READ_STATUS3 = 8'h15;
  localparam CMD_PAGE_PROGRAM = 8'h02;
  localparam CMD_WRITE_STATUS3 = 8'h11;

  localparam DELAY_SHORT = 8'd4;
  localparam DELAY_LONG = 8'd15;

  reg r_MOSI = 0;
  reg r_CS = 1;
  reg r_SCLK = 0;
  reg r_busy = 1;
  reg r_write_busy = 0;

  reg [23:0] readAddress = 0;
  reg [7:0] command = CMD_READ_DATA_BYTES;
  reg [7:0] currentByteOut = 0;
  reg [7:0] currentByteNum = 0;
  reg [7:0] dataIn = 0;
  reg [7:0] dataInBuffer = 0;

  reg [23:0] dataToSend = 0;
  reg [8:0] bitsToSend = 0;

  reg [32:0] counter = 0;
  reg [7:0] state = STATE_INIT_POWER;
  reg [7:0] returnState = 0;
  reg [7:0] return_delay = 0;

  reg r_data_ready = 0;

  reg [7:0] r_write_counter = 0;
  reg [23:0] writeAddress = 0;
  reg [7:0] status_reg = 0;

  always @(posedge clk or negedge reset_n) begin
    if (~reset_n) begin
        state <= STATE_INIT_POWER;
        counter <= 0;
        r_busy <= 1;
        r_write_busy <= 0;
        r_CS <= 1;
        r_SCLK <= 0;
        r_MOSI <= 0;
        r_data_ready <= 0;
        r_write_counter <= 0;
    end else begin
        case (state)

          STATE_INIT_POWER: begin
            if (counter > STARTUP_WAIT) begin
              state <= STATE_LOAD_CMD_TO_SEND;
              counter <= 32'b0;

              currentByteNum <= 0;
              currentByteOut <= 0;
              r_busy <= 0;
              r_write_counter <= 0;
            end
            else begin
              counter <= counter + 1;
            end
          end

          STATE_LOAD_CMD_TO_SEND: begin
              r_CS <= 1;
              r_busy <= 0;
              r_data_ready <= 0;
              if (write_enable == 1) begin
                  r_write_busy <= 1;
                  state <= STATE_06_1;
              end else if (rd == 1) begin
                  r_CS <= 0;
                  r_busy <= 1;
                  r_data_ready <= 0;
                  readAddress <= addr;
                  dataToSend[23-:8] <= command;
                  bitsToSend <= 8;
                  state <= STATE_SEND;
                  returnState <= STATE_LOAD_ADDRESS_TO_SEND;
              end
          end

          STATE_SEND: begin
            if (counter == 32'd0) begin
              r_SCLK <= 0;
              r_MOSI <= dataToSend[23];
              dataToSend <= {dataToSend[22:0],1'b0};
              bitsToSend <= bitsToSend - 1;
              counter <= 32'd1;
            end
            else begin
              counter <= 32'd0;
              r_SCLK <= 1;
              if (bitsToSend == 0)
                state <= returnState;
            end
          end

          STATE_SEND_SLOW1: begin
            r_SCLK <= 0;
            r_MOSI <= dataToSend[23];
            counter <= counter + 32'd1;
            if (counter == DELAY_SHORT) begin
              dataToSend <= {dataToSend[22:0],1'b0};
              bitsToSend <= bitsToSend - 1;
              counter <= 32'd0;
              state <= STATE_SEND_SLOW2;
            end
            else begin
                state <= STATE_SEND_SLOW1;
            end
          end

          STATE_SEND_SLOW2: begin
            r_SCLK <= 1;
            counter <= counter + 1;
            if (counter == DELAY_SHORT) begin
              counter <= 32'd0;
              if (bitsToSend == 0) begin
                counter <= 0;
                state <= STATE_SEND_SLOW3;
              end
              else begin
                state <= STATE_SEND_SLOW1;
              end
            end
            else begin
                state <= STATE_SEND_SLOW2;
            end
          end

          STATE_SEND_SLOW3: begin
            r_SCLK <= 0;
            counter <= 0;
            return_delay <= returnState;
            state <= STATE_DELAY;
          end

          STATE_DELAY: begin
            counter <= counter + 1;
            if (counter == DELAY_SHORT) begin
                counter <= 0;
                state <= return_delay;
            end
            else begin
                state <= STATE_DELAY;
            end
          end

          STATE_LOAD_ADDRESS_TO_SEND: begin
            dataToSend <= readAddress;
            bitsToSend <= 24;
            state <= STATE_SEND;
            returnState <= STATE_READ_DATA;
          end

          STATE_READ_DATA: begin
            if (counter[0] == 1'd0) begin
              r_SCLK <= 0;
              counter <= counter + 1;
              if (counter[3:0] == 0 && counter > 0) begin
                  dataIn <= currentByteOut;
                  state <= STATE_DATA_END;
              end
            end
            else begin
              r_SCLK <= 1;
              currentByteOut <= {currentByteOut[6:0], MISO};
              counter <= counter + 1;
            end
          end 

          STATE_READ_DATA2: begin
            if (counter[0] == 1'd0) begin
              r_SCLK <= 0;
              counter <= counter + 1;
              if (counter[3:0] == 0 && counter > 0) begin
                  dataIn <= currentByteOut;
                  counter <= 0;
                  state <= returnState;
              end
            end
            else begin
              r_SCLK <= 1;
              currentByteOut <= {currentByteOut[6:0], MISO};
              counter <= counter + 1;
            end
          end 

          STATE_DATA_END: begin
            r_data_ready <= 1;
            dataInBuffer <= dataIn;
            counter <= 32'd0;
            state <= STATE_WAIT_NEXT;
          end

          STATE_WAIT_NEXT: begin
              r_busy <= 0;
              if (rd == 1) begin
                  r_busy <= 1;
                  r_data_ready <= 0;
                  state <= STATE_READ_DATA;
              end else if (terminate == 1) begin
                  state <= STATE_DONE;
              end
          end

          STATE_DONE: begin
            r_CS <= 1;
            r_busy <= 1;
            counter <= STARTUP_WAIT;
            state <= STATE_INIT_POWER;
          end

          STATE_06_1: begin
            r_CS <= 0;
            r_data_ready <= 0;
            counter <= 0;
            dataToSend[23-:8] <= CMD_WRITE_ENABLE;
            bitsToSend <= 8;
            state <= STATE_SEND;
            returnState <= STATE_06_2;
          end

          STATE_06_2: begin
            r_SCLK <= 0;
            state <= STATE_06_3;
          end

          STATE_06_3: begin
            r_CS <= 1;
            counter <= 0;
            return_delay = STATE_05_1;
            state <= STATE_DELAY;
          end

          STATE_05_1: begin
            r_CS <= 0;
            r_data_ready <= 0;
            counter <= 0;
            dataToSend[23-:8] <= CMD_READ_STATUS;
            bitsToSend <= 8;
            state <= STATE_SEND;
            returnState <= STATE_05_2;
          end

          STATE_05_2: begin
            counter <= 0;
            dataIn <= 0;
            state <= STATE_READ_DATA2;
            returnState <= STATE_05_3;
          end

          STATE_05_3: begin
            r_CS <= 1;
            counter <= counter + 1;
            if (counter == DELAY_LONG) begin
                r_CS <= 0;
                counter <= 0;
                state <= STATE_20_1;
            end
            else begin
                state <= STATE_05_3;
            end
          end

          STATE_20_1: begin
            r_CS <= 0;
            r_data_ready <= 0;
            counter <= 0;
            dataToSend[23-:8] <= CMD_SECTOR_ERASE;
            bitsToSend <= 8;
            state <= STATE_SEND_SLOW1;
            returnState <= STATE_20_2;
          end

          STATE_20_2: begin
            counter <= 0;
            dataToSend <= write_addr;
            bitsToSend <=24;
            state <= STATE_SEND_SLOW1;
            returnState <= STATE_20_3;
          end

          STATE_20_3: begin
            r_CS <= 1;
            counter <= counter + 1;
            if (counter == DELAY_LONG) begin
                counter <= 0;
                state <= STATE_05b_1;
            end
            else begin
                state <= STATE_20_3;
            end
          end

          STATE_05b_1: begin
            r_CS <= 0;
            r_data_ready <= 0;
            counter <= 0;
            dataToSend[23-:8] <= CMD_READ_STATUS;
            bitsToSend <= 8;
            state <= STATE_SEND;
            returnState <= STATE_05b_2;
          end

          STATE_05b_2: begin
            counter <= 0;
            dataIn <= 0;
            state <= STATE_READ_DATA2;
            returnState <= STATE_05b_3;
          end

          STATE_05b_3: begin
            r_CS <= 1;
            counter <= counter + 1;
            if (counter == DELAY_SHORT) begin
                counter <= 0;
                if (dataIn[0] == 0) begin
                    state <= STATE_06b_1;
                end
                else begin
                    state <= STATE_05b_1;
                end
            end
            else begin
                state <= STATE_05b_3;
            end
          end

          STATE_06b_1: begin
            r_CS <= 0;
            r_data_ready <= 0;
            counter <= 0;
            dataToSend[23-:8] <= CMD_WRITE_ENABLE;
            bitsToSend <= 8;
            state <= STATE_SEND;
            returnState <= STATE_06b_2;
          end

          STATE_06b_2: begin
            r_SCLK <= 0;
            state <= STATE_06b_3;
          end

          STATE_06b_3: begin
            r_CS <= 1;
            counter <= counter + 1;
            if (counter == DELAY_SHORT) begin
                counter <= 0;
                state <= STATE_02_1;
            end
            else begin
                state <= STATE_06b_3;
            end
          end

          STATE_02_1: begin
            r_CS <= 0;
            r_data_ready <= 0;
            counter <= 0;
            dataToSend[23-:8] <= CMD_PAGE_PROGRAM;
            bitsToSend <= 8;
            state <= STATE_SEND_SLOW1;
            returnState <= STATE_02_2;
          end

          STATE_02_2: begin
            counter <= 0;
            dataToSend <= write_addr;
            bitsToSend <=24;
            state <= STATE_SEND_SLOW1;
            returnState <= STATE_02_3;
          end

          STATE_02_3: begin
            counter <= 0;
            dataToSend[23-:8] <= write_din;
            bitsToSend <=8;
            state <= STATE_SEND_SLOW1;
            returnState <= STATE_02_4;
          end

          STATE_02_4: begin
            r_write_counter <= r_write_counter + 1;
            if (r_write_counter != 8'd255 && write_terminate == 0) begin
                state <= STATE_02_3;
            end
            else begin
                state <= STATE_02_5;
            end

          end

          STATE_02_5: begin
            r_CS <= 1;
            counter <= counter + 1;
            if (counter == DELAY_LONG) begin
                r_write_busy <= 0;
                r_write_counter <= 0;
                counter <= 0;
                state <= STATE_LOAD_CMD_TO_SEND;
            end
            else begin
                state <= STATE_02_5;
            end
          end

        endcase
    end
  end

  assign MOSI = r_MOSI;
  assign CS =  r_CS;
  assign SCLK = r_SCLK;
  assign data_ready = r_data_ready;
  assign busy = r_busy;
  assign write_busy = r_write_busy;

  assign dout = dataInBuffer;
  assign write_counter = r_write_counter;

endmodule
