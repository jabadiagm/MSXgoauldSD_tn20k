//
//  vdp_ntsc_pal.v
//   Converts ESE-VDP core video into NTSC/PAL sync + video signals.
//   Inserts the equalization pulses into the H-Sync.
//   Traduccion a Verilog de vdp_ntsc_pal.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / t.hara / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_ntsc_pal.vhd.
//
//-----------------------------------------------------------------------------

module VDP_NTSC_PAL (
    input  wire        CLK21M,
    input  wire        RESET,
    // MODE
    input  wire        PALMODE,
    input  wire        INTERLACEMODE,
    // VIDEO INPUT
    input  wire [5:0]  VIDEORIN,
    input  wire [5:0]  VIDEOGIN,
    input  wire [5:0]  VIDEOBIN,
    input  wire        VIDEOVSIN_N,
    input  wire [10:0] HCOUNTERIN,
    input  wire [10:0] VCOUNTERIN,
    // VIDEO OUTPUT
    output wire [5:0]  VIDEOROUT,
    output wire [5:0]  VIDEOGOUT,
    output wire [5:0]  VIDEOBOUT,
    output wire        VIDEOHSOUT_N,
    output wire        VIDEOVSOUT_N
);

    // CLOCKS por linea, dependientes de PAL (antes SHARED VARIABLE del package)
    wire [11:0] CLOCKS_PER_LINE      = (PALMODE == 1'b1) ? 12'd1728 : 12'd1716;
    wire [11:0] CLOCKS_PER_HALF_LINE = (PALMODE == 1'b1) ? 12'd864  : 12'd858;

    // Estados de sincronismo (enum TYPSSTATE en el original)
    localparam [1:0] SSTATE_A = 2'd0,
                     SSTATE_B = 2'd1,
                     SSTATE_C = 2'd2,
                     SSTATE_D = 2'd3;

    reg  [1:0]  FF_SSTATE;
    reg         FF_HSYNC_N;

    wire [1:0]  W_MODE;
    reg  [10:0] W_STATE_A1_FULL;
    reg  [10:0] W_STATE_A2_FULL;
    reg  [10:0] W_STATE_B_FULL;
    reg  [10:0] W_STATE_C_FULL;

    // MODE
    assign W_MODE = {PALMODE, INTERLACEMODE};

    always @(*) begin
        case (W_MODE)
            2'b00:   W_STATE_A1_FULL = 11'b01000001100;  // 524
            2'b01:   W_STATE_A1_FULL = 11'b01000001101;  // 525
            2'b10:   W_STATE_A1_FULL = 11'b01001110010;  // 626
            2'b11:   W_STATE_A1_FULL = 11'b01001110001;  // 625
            default: W_STATE_A1_FULL = 11'bx;
        endcase
    end

    always @(*) begin
        case (W_MODE)
            2'b00:   W_STATE_A2_FULL = 11'b01000011000;  // 524+12
            2'b01:   W_STATE_A2_FULL = 11'b01000011001;  // 525+12
            2'b10:   W_STATE_A2_FULL = 11'b01001111110;  // 626+12
            2'b11:   W_STATE_A2_FULL = 11'b01001111101;  // 625+12
            default: W_STATE_A2_FULL = 11'bx;
        endcase
    end

    always @(*) begin
        case (W_MODE)
            2'b00:   W_STATE_B_FULL = 11'b01000010010;   // 524+6
            2'b01:   W_STATE_B_FULL = 11'b01000010011;   // 525+6
            2'b10:   W_STATE_B_FULL = 11'b01001111000;   // 626+6
            2'b11:   W_STATE_B_FULL = 11'b01001110111;   // 625+6
            default: W_STATE_B_FULL = 11'bx;
        endcase
    end

    always @(*) begin
        case (W_MODE)
            2'b00:   W_STATE_C_FULL = 11'b01000011110;   // 524+18
            2'b01:   W_STATE_C_FULL = 11'b01000011111;   // 525+18
            2'b10:   W_STATE_C_FULL = 11'b01010000100;   // 626+18
            2'b11:   W_STATE_C_FULL = 11'b01010000011;   // 625+18
            default: W_STATE_C_FULL = 11'bx;
        endcase
    end

    // STATE
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_SSTATE <= SSTATE_A;
        end else begin
            if ( (VCOUNTERIN == 0) ||
                 (VCOUNTERIN == 12) ||
                 (VCOUNTERIN == W_STATE_A1_FULL) ||
                 (VCOUNTERIN == W_STATE_A2_FULL) ) begin
                FF_SSTATE <= SSTATE_A;
            end else if ( (VCOUNTERIN == 6) ||
                          (VCOUNTERIN == W_STATE_B_FULL) ) begin
                FF_SSTATE <= SSTATE_B;
            end else if ( (VCOUNTERIN == 18) ||
                          (VCOUNTERIN == W_STATE_C_FULL) ) begin
                FF_SSTATE <= SSTATE_C;
            end
        end
    end

    // GENERATE H SYNC PULSE
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_HSYNC_N <= 1'b0;
        end else begin
            if (FF_SSTATE == SSTATE_A) begin
                if ( (HCOUNTERIN == 1) || (HCOUNTERIN == CLOCKS_PER_HALF_LINE+1) )
                    FF_HSYNC_N <= 1'b0;                       // PULSE ON
                else if ( (HCOUNTERIN == 51) || (HCOUNTERIN == CLOCKS_PER_HALF_LINE+51) )
                    FF_HSYNC_N <= 1'b1;                       // PULSE OFF
            end else if (FF_SSTATE == SSTATE_B) begin
                if ( (HCOUNTERIN == CLOCKS_PER_LINE-100+1) || (HCOUNTERIN == CLOCKS_PER_HALF_LINE-100+1) )
                    FF_HSYNC_N <= 1'b0;                       // PULSE ON
                else if ( (HCOUNTERIN == 1) || (HCOUNTERIN == CLOCKS_PER_HALF_LINE+1) )
                    FF_HSYNC_N <= 1'b1;                       // PULSE OFF
            end else if (FF_SSTATE == SSTATE_C) begin
                if (HCOUNTERIN == 1)
                    FF_HSYNC_N <= 1'b0;                       // PULSE ON
                else if (HCOUNTERIN == 101)
                    FF_HSYNC_N <= 1'b1;                       // PULSE OFF
            end
        end
    end

    assign VIDEOHSOUT_N = FF_HSYNC_N;
    assign VIDEOVSOUT_N = VIDEOVSIN_N;
    assign VIDEOROUT    = VIDEORIN;
    assign VIDEOGOUT    = VIDEOGIN;
    assign VIDEOBOUT    = VIDEOBIN;

endmodule
