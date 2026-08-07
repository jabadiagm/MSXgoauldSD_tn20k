//
//  vdp_ssg.v
//   Sync signal generator: H/V counters, dot/8-dot state, dot counters, windows,
//   V-sync pulse, V-blanking. Contiene VDP_HVCOUNTER.
//   Traduccion a Verilog de vdp_ssg.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / t.hara / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_ssg.vhd.
//
//  Nota (traduccion): CLOCKS_PER_LINE es wire local desde VDPR9PALMODE (antes
//  SHARED VARIABLE). Como LED_TV_X_NTSC == LED_TV_X_PAL, las comparaciones X de
//  recarga de dotcounter son iguales en PAL/NTSC -> se unifican (equivalente).
//-----------------------------------------------------------------------------

module VDP_SSG (
    input  wire        RESET,
    input  wire        CLK21M,

    output wire [10:0] H_CNT,
    output wire [10:0] H_CNT_IN_FIELD,
    output wire [10:0] V_CNT,
    output wire [1:0]  DOTSTATE,
    output wire [2:0]  EIGHTDOTSTATE,
    output wire [8:0]  PREDOTCOUNTER_X,
    output wire [8:0]  PREDOTCOUNTER_Y,
    output wire [8:0]  PREDOTCOUNTER_YP,
    output reg         PREWINDOW_Y,
    output reg         PREWINDOW_Y_SP,
    output wire        FIELD,
    output wire        WINDOW_X,
    output wire        PVIDEODHCLK,
    output wire        PVIDEODLCLK,
    output reg         IVIDEOVS_N,

    output wire        HD,
    output wire        VD,
    output wire        HSYNC,
    output reg         ENAHSYNC,
    output wire        V_BLANKING_START,

    input  wire        VDPR9PALMODE,
    input  wire        REG_R9_INTERLACE_MODE,
    input  wire        REG_R9_Y_DOTS,
    input  wire [7:0]  REG_R18_ADJ,
    input  wire [7:0]  REG_R23_VSTART_LINE,
    input  wire        REG_R25_MSK,
    input  wire [2:0]  REG_R27_H_SCROLL,
    input  wire        REG_R25_YJK,
    input  wire        CENTERYJK_R25_N,
    input  wire [6:0]  OFFSET_Y,
    output wire        HDMI_RESET
);

`include "vdp_package.vh"

    // CLOCKS por linea, dependiente de PAL (antes SHARED VARIABLE)
    wire [11:0] CLOCKS_PER_LINE = (VDPR9PALMODE == 1'b1) ? 12'd1728 : 12'd1716;

    // FLIP FLOP
    reg [1:0]  FF_DOTSTATE;
    reg [2:0]  FF_EIGHTDOTSTATE;
    reg [8:0]  FF_PRE_X_CNT;
    reg [8:0]  FF_X_CNT;
    reg [8:0]  FF_PRE_Y_CNT;
    reg [8:0]  FF_MONITOR_LINE;
    reg        FF_VIDEO_DH_CLK;
    reg        FF_VIDEO_DL_CLK;
    reg [5:0]  FF_PRE_X_CNT_START1;
    reg [8:0]  FF_RIGHT_MASK;
    reg        FF_WINDOW_X;
    reg [8:0]  FF_TOP_BORDER_LINES;

    // WIRE
    wire [10:0] W_H_CNT;
    wire [10:0] W_H_CNT_IN_FIELD;
    wire [10:0] W_V_CNT_IN_FRAME;
    wire [9:0]  W_V_CNT_IN_FIELD;
    wire        W_FIELD;
    wire        W_H_BLANK;
    wire        W_V_BLANK;
    wire [4:0]  W_PRE_X_CNT_START0;
    wire [8:0]  W_PRE_X_CNT_START2;
    wire        W_HSYNC;
    wire [8:0]  W_LEFT_MASK;
    wire [8:0]  W_Y_ADJ;
    wire [1:0]  W_LINE_MODE;
    wire        W_V_BLANKING_START;
    wire        W_V_BLANKING_END;
    wire [8:0]  W_V_SYNC_INTR_START_LINE;

    // Variables persistentes del proceso Y
    reg [8:0]  PREDOTCOUNTER_YP_V;
    reg [8:0]  PREDOTCOUNTERYPSTART;

    // Comparaciones de recarga del dotcounter X (OFFSET_X + LED_TV_X {+4} - {~CENTER,00})
    // 49 + (-20) = 29 ; +4 = 33 (LED_TV_X_NTSC == LED_TV_X_PAL == -20 -> igual PAL/NTSC)
    wire [10:0] W_HCMP_C4  = {2'b00, (7'd33 - {2'b00, ~CENTERYJK_R25_N, 2'b00}), 2'b10};
    wire [10:0] W_HCMP_NO4 = {2'b00, (7'd29 - {2'b00, ~CENTERYJK_R25_N, 2'b00}), 2'b10};
    wire        W_XCNT_RELOAD = ((W_H_CNT == W_HCMP_C4)  && (REG_R25_YJK == 1'b1) && (CENTERYJK_R25_N == 1'b1)) ||
                                ((W_H_CNT == W_HCMP_NO4) && ((REG_R25_YJK == 1'b0) || (CENTERYJK_R25_N == 1'b0)));

    //---------------------------------------------------------------------------
    //  PORT ASSIGNMENT
    //---------------------------------------------------------------------------
    assign H_CNT            = W_H_CNT;
    assign H_CNT_IN_FIELD   = W_H_CNT_IN_FIELD;
    assign V_CNT            = W_V_CNT_IN_FRAME;
    assign DOTSTATE         = FF_DOTSTATE;
    assign EIGHTDOTSTATE    = FF_EIGHTDOTSTATE;
    assign FIELD            = W_FIELD;
    assign WINDOW_X         = FF_WINDOW_X;
    assign PVIDEODHCLK      = FF_VIDEO_DH_CLK;
    assign PVIDEODLCLK      = FF_VIDEO_DL_CLK;
    assign PREDOTCOUNTER_X  = FF_PRE_X_CNT;
    assign PREDOTCOUNTER_Y  = FF_PRE_Y_CNT;
    assign PREDOTCOUNTER_YP = FF_MONITOR_LINE;
    assign HD               = W_H_BLANK;
    assign VD               = W_V_BLANK;
    assign HSYNC            = (W_H_CNT[1:0] == 2'b10 && FF_PRE_X_CNT == 9'b111111111) ? 1'b1 : 1'b0;
    assign V_BLANKING_START = W_V_BLANKING_START;

    //---------------------------------------------------------------------------
    //  SUB COMPONENTS
    //---------------------------------------------------------------------------
    VDP_HVCOUNTER U_HVCOUNTER (
        .RESET          (RESET),
        .CLK21M         (CLK21M),

        .H_CNT          (W_H_CNT),
        .H_CNT_IN_FIELD (W_H_CNT_IN_FIELD),
        .V_CNT_IN_FIELD (W_V_CNT_IN_FIELD),
        .V_CNT_IN_FRAME (W_V_CNT_IN_FRAME),
        .FIELD          (W_FIELD),
        .H_BLANK        (W_H_BLANK),
        .V_BLANK        (W_V_BLANK),

        .PAL_MODE       (VDPR9PALMODE),
        .INTERLACE_MODE (REG_R9_INTERLACE_MODE),
        .Y212_MODE      (REG_R9_Y_DOTS),
        .OFFSET_Y       (OFFSET_Y),
        .HDMI_RESET     (HDMI_RESET),
        .BLANKING_START (W_V_BLANKING_START),
        .BLANKING_END   (W_V_BLANKING_END)
    );

    //---------------------------------------------------------------------------
    //  DOT STATE
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_DOTSTATE     <= 2'b00;
            FF_VIDEO_DH_CLK <= 1'b0;
            FF_VIDEO_DL_CLK <= 1'b0;
        end else begin
            if (W_H_CNT == CLOCKS_PER_LINE - 1) begin
                FF_DOTSTATE     <= 2'b00;
                FF_VIDEO_DH_CLK <= 1'b1;
                FF_VIDEO_DL_CLK <= 1'b1;
            end else begin
                case (FF_DOTSTATE)
                    2'b00: begin FF_DOTSTATE <= 2'b01; FF_VIDEO_DH_CLK <= 1'b0; FF_VIDEO_DL_CLK <= 1'b1; end
                    2'b01: begin FF_DOTSTATE <= 2'b11; FF_VIDEO_DH_CLK <= 1'b1; FF_VIDEO_DL_CLK <= 1'b0; end
                    2'b11: begin FF_DOTSTATE <= 2'b10; FF_VIDEO_DH_CLK <= 1'b0; FF_VIDEO_DL_CLK <= 1'b0; end
                    2'b10: begin FF_DOTSTATE <= 2'b00; FF_VIDEO_DH_CLK <= 1'b1; FF_VIDEO_DL_CLK <= 1'b1; end
                    default: ;
                endcase
            end
        end
    end

    //---------------------------------------------------------------------------
    //  8DOT STATE
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_EIGHTDOTSTATE <= 3'b000;
        end else begin
            if (W_H_CNT[1:0] == 2'b11) begin
                if (FF_PRE_X_CNT == 0)
                    FF_EIGHTDOTSTATE <= 3'b000;
                else
                    FF_EIGHTDOTSTATE <= FF_EIGHTDOTSTATE + 1'b1;
            end
        end
    end

    //---------------------------------------------------------------------------
    //  GENERATE DOTCOUNTER
    //---------------------------------------------------------------------------
    assign W_PRE_X_CNT_START0 = {REG_R18_ADJ[3], REG_R18_ADJ[3:0]} + 5'b11000; // (-8..7)-8

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            FF_PRE_X_CNT_START1 <= 6'b0;
        else
            FF_PRE_X_CNT_START1 <= {W_PRE_X_CNT_START0[4], W_PRE_X_CNT_START0} - {3'b000, REG_R27_H_SCROLL};
    end

    assign W_PRE_X_CNT_START2[8:6] = {3{FF_PRE_X_CNT_START1[5]}};
    assign W_PRE_X_CNT_START2[5:0] = FF_PRE_X_CNT_START1;

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            FF_PRE_X_CNT <= 9'b0;
        else begin
            if (W_XCNT_RELOAD)
                FF_PRE_X_CNT <= W_PRE_X_CNT_START2;
            else if (W_H_CNT[1:0] == 2'b10)
                FF_PRE_X_CNT <= FF_PRE_X_CNT + 1'b1;
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            FF_X_CNT <= 9'b0;
        else begin
            if (W_XCNT_RELOAD) begin
                // HOLD
            end else if (W_H_CNT[1:0] == 2'b10) begin
                if (FF_PRE_X_CNT == 9'b111111111)
                    FF_X_CNT <= 9'b111111000; // -8
                else
                    FF_X_CNT <= FF_X_CNT + 1'b1;
            end
        end
    end

    //---------------------------------------------------------------------------
    // GENERATE V-SYNC PULSE
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            IVIDEOVS_N <= 1'b1;
        else begin
            if (W_V_CNT_IN_FIELD == 6)
                IVIDEOVS_N <= 1'b0;   // SSTATE_B
            else if (W_V_CNT_IN_FIELD == 12)
                IVIDEOVS_N <= 1'b1;   // SSTATE_A
        end
    end

    //---------------------------------------------------------------------------
    //  DISPLAY WINDOW
    //---------------------------------------------------------------------------
    // LEFT MASK (R25 MSK)
    assign W_LEFT_MASK = (REG_R25_MSK == 1'b0) ? 9'b0 :
                         {5'b00000, ({1'b0, ~REG_R27_H_SCROLL} + 1'b1)};

    always @(posedge CLK21M) begin
        // MAIN WINDOW: DOTCOUNTER_X = 0
        if (W_H_CNT[1:0] == 2'b01 && FF_X_CNT == W_LEFT_MASK)
            FF_RIGHT_MASK <= 9'b100000000 - {6'b000000, REG_R27_H_SCROLL};
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            FF_WINDOW_X <= 1'b0;
        else begin
            if (W_H_CNT[1:0] == 2'b01 && FF_X_CNT == W_LEFT_MASK)
                FF_WINDOW_X <= 1'b1;         // DOTCOUNTER_X = 0
            else if (W_H_CNT[1:0] == 2'b01 && FF_X_CNT == FF_RIGHT_MASK)
                FF_WINDOW_X <= 1'b0;         // DOTCOUNTER_X = 256
        end
    end

    //---------------------------------------------------------------------------
    // Y
    //---------------------------------------------------------------------------
    assign W_HSYNC = (W_H_CNT[1:0] == 2'b10 && FF_PRE_X_CNT == 9'b111111111) ? 1'b1 : 1'b0;

    assign W_Y_ADJ = {{5{REG_R18_ADJ[7]}}, REG_R18_ADJ[7:4]};

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PRE_Y_CNT    <= 9'b0;
            FF_MONITOR_LINE <= 9'b0;
            PREWINDOW_Y     <= 1'b0;
        end else begin
            if (W_HSYNC == 1'b1) begin
                if (W_V_BLANKING_END == 1'b1) begin
                    if      (REG_R9_Y_DOTS == 1'b0 && VDPR9PALMODE == 1'b0) PREDOTCOUNTERYPSTART = 9'b111100110; // -26
                    else if (REG_R9_Y_DOTS == 1'b1 && VDPR9PALMODE == 1'b0) PREDOTCOUNTERYPSTART = 9'b111110000; // -16
                    else if (REG_R9_Y_DOTS == 1'b0 && VDPR9PALMODE == 1'b1) PREDOTCOUNTERYPSTART = 9'b111001011; // -53
                    else                                                    PREDOTCOUNTERYPSTART = 9'b111010101; // -43
                    FF_MONITOR_LINE     <= PREDOTCOUNTERYPSTART + W_Y_ADJ;
                    FF_TOP_BORDER_LINES <= 9'b000000000 - PREDOTCOUNTERYPSTART - W_Y_ADJ;
                    PREWINDOW_Y_SP      <= 1'b1;
                end else begin
                    if (PREDOTCOUNTER_YP_V == 255)
                        PREDOTCOUNTER_YP_V = FF_MONITOR_LINE;
                    else
                        PREDOTCOUNTER_YP_V = FF_MONITOR_LINE + 1'b1;
                    if (PREDOTCOUNTER_YP_V == 0) begin
                        ENAHSYNC    <= 1'b1;
                        PREWINDOW_Y <= 1'b1;
                    end else if ((REG_R9_Y_DOTS == 1'b0 && PREDOTCOUNTER_YP_V == 192) ||
                                 (REG_R9_Y_DOTS == 1'b1 && PREDOTCOUNTER_YP_V == 212)) begin
                        PREWINDOW_Y    <= 1'b0;
                        PREWINDOW_Y_SP <= 1'b0;
                    end else if ((REG_R9_Y_DOTS == 1'b0 && VDPR9PALMODE == 1'b0 && PREDOTCOUNTER_YP_V == 235) ||
                                 (REG_R9_Y_DOTS == 1'b1 && VDPR9PALMODE == 1'b0 && PREDOTCOUNTER_YP_V == 245) ||
                                 (REG_R9_Y_DOTS == 1'b0 && VDPR9PALMODE == 1'b1 && PREDOTCOUNTER_YP_V == 259) ||
                                 (REG_R9_Y_DOTS == 1'b1 && VDPR9PALMODE == 1'b1 && PREDOTCOUNTER_YP_V == 269)) begin
                        ENAHSYNC <= 1'b0;
                    end
                    FF_MONITOR_LINE <= PREDOTCOUNTER_YP_V;
                end
            end

            FF_PRE_Y_CNT <= FF_MONITOR_LINE + {1'b0, REG_R23_VSTART_LINE};
        end
    end

    //---------------------------------------------------------------------------
    // VSYNC INTERRUPT REQUEST
    //---------------------------------------------------------------------------
    assign W_LINE_MODE = {REG_R9_Y_DOTS, VDPR9PALMODE};

    assign W_V_SYNC_INTR_START_LINE =
        (W_LINE_MODE == 2'b00) ? (9'd193 + {2'b00, OFFSET_Y}) :   // 192 + OFFSET_Y + LED_TV_Y_NTSC(1)
        (W_LINE_MODE == 2'b10) ? (9'd213 + {2'b00, OFFSET_Y}) :   // 212 + OFFSET_Y + 1
        (W_LINE_MODE == 2'b01) ? (9'd195 + {2'b00, OFFSET_Y}) :   // 192 + OFFSET_Y + LED_TV_Y_PAL(3)
                                 (9'd215 + {2'b00, OFFSET_Y});    // 212 + OFFSET_Y + 3

    assign W_V_BLANKING_END = ((W_V_CNT_IN_FIELD == {2'b00, (OFFSET_Y + 7'd1), (W_FIELD & REG_R9_INTERLACE_MODE)}) && VDPR9PALMODE == 1'b0) ||
                              ((W_V_CNT_IN_FIELD == {2'b00, (OFFSET_Y + 7'd3), (W_FIELD & REG_R9_INTERLACE_MODE)}) && VDPR9PALMODE == 1'b1) ? 1'b1 : 1'b0;

    assign W_V_BLANKING_START = (W_V_CNT_IN_FIELD == {(W_V_SYNC_INTR_START_LINE + FF_TOP_BORDER_LINES), (W_FIELD & REG_R9_INTERLACE_MODE)}) ? 1'b1 : 1'b0;

endmodule
