//
//  vdp_vga.v
//   Upscan converter (VGA/31kHz): duplica cada linea usando doble buffer.
//   Traduccion a Verilog de vdp_vga.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / KdL / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_vga.vhd.
//
//  Nota (traduccion): CLOCKS_PER_HALF_LINE es wire local desde PALMODE (antes
//  SHARED VARIABLE del package).
//-----------------------------------------------------------------------------

module VDP_VGA (
    // VDP CLOCK ... 21.477MHZ
    input  wire        CLK21M,
    input  wire        RESET,
    // VIDEO INPUT
    input  wire [5:0]  VIDEORIN,
    input  wire [5:0]  VIDEOGIN,
    input  wire [5:0]  VIDEOBIN,
    input  wire        VIDEOVSIN_N,
    input  wire [10:0] HCOUNTERIN,
    input  wire [10:0] VCOUNTERIN,
    // MODE
    input  wire        PALMODE,
    input  wire        INTERLACEMODE,
    input  wire        LEGACY_VGA,
    // VIDEO OUTPUT
    output wire [5:0]  VIDEOROUT,
    output wire [5:0]  VIDEOGOUT,
    output wire [5:0]  VIDEOBOUT,
    output wire        VIDEOHSOUT_N,
    output wire        VIDEOVSOUT_N,
    // HDMI SUPPORT
    output wire        BLANK_O,
    // SWITCHED I/O SIGNALS
    input  wire [2:0]  RATIOMODE
);

    // CLOCKS por media linea, dependiente de PAL (antes SHARED VARIABLE)
    wire [11:0] CLOCKS_PER_HALF_LINE = (PALMODE == 1'b1) ? 12'd864 : 12'd858;

    localparam integer DISP_WIDTH   = 720;
    localparam integer DISP_START_X = 0;
    localparam integer CENTER_Y     = 12;   // based on HDMI AV output

    reg         FF_HSYNC_N;
    reg         FF_VSYNC_N;
    reg         VIDEOOUTX;

    wire [9:0]  XPOSITIONW;
    reg  [9:0]  XPOSITIONR;
    wire        EVENODD;
    wire        WE_BUF;
    wire [5:0]  DATAROUT;
    wire [5:0]  DATAGOUT;
    wire [5:0]  DATABOUT;

    assign VIDEOROUT = (VIDEOOUTX == 1'b1) ? DATAROUT : 6'b0;
    assign VIDEOGOUT = (VIDEOOUTX == 1'b1) ? DATAGOUT : 6'b0;
    assign VIDEOBOUT = (VIDEOOUTX == 1'b1) ? DATABOUT : 6'b0;

    VDP_DOUBLEBUF DBUF (
        .CLK        (CLK21M),
        .XPOSITIONW (XPOSITIONW),
        .XPOSITIONR (XPOSITIONR),
        .EVENODD    (EVENODD),
        .WE         (WE_BUF),
        .DATARIN    (VIDEORIN),
        .DATAGIN    (VIDEOGIN),
        .DATABIN    (VIDEOBIN),
        .DATAROUT   (DATAROUT),
        .DATAGOUT   (DATAGOUT),
        .DATABOUT   (DATABOUT)
    );

    assign XPOSITIONW = HCOUNTERIN[10:1];
    assign EVENODD    = VCOUNTERIN[1];
    assign WE_BUF     = 1'b1;

    // GENERATE H-SYNC SIGNAL
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_HSYNC_N <= 1'b1;
        end else begin
            if ((HCOUNTERIN == 0) || (HCOUNTERIN == CLOCKS_PER_HALF_LINE))
                FF_HSYNC_N <= 1'b0;
            else if ((HCOUNTERIN == 40) || (HCOUNTERIN == CLOCKS_PER_HALF_LINE + 40))
                FF_HSYNC_N <= 1'b1;
        end
    end

    // GENERATE V-SYNC SIGNAL (VIDEOVSIN_N no se usa)
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_VSYNC_N <= 1'b1;
        end else begin
            if (PALMODE == 1'b0) begin
                if (INTERLACEMODE == 1'b0) begin
                    if ((VCOUNTERIN == 3*2 + CENTER_Y) || (VCOUNTERIN == 524 + 3*2 + CENTER_Y))
                        FF_VSYNC_N <= 1'b0;
                    else if ((VCOUNTERIN == 6*2 + CENTER_Y) || (VCOUNTERIN == 524 + 6*2 + CENTER_Y))
                        FF_VSYNC_N <= 1'b1;
                end else begin
                    if ((VCOUNTERIN == 3*2 + CENTER_Y) || (VCOUNTERIN == 525 + 3*2 + CENTER_Y))
                        FF_VSYNC_N <= 1'b0;
                    else if ((VCOUNTERIN == 6*2 + CENTER_Y) || (VCOUNTERIN == 525 + 6*2 + CENTER_Y))
                        FF_VSYNC_N <= 1'b1;
                end
            end else begin
                if (INTERLACEMODE == 1'b0) begin
                    if ((VCOUNTERIN == 3*2 + CENTER_Y + 6) || (VCOUNTERIN == 626 + 3*2 + CENTER_Y + 6))
                        FF_VSYNC_N <= 1'b0;
                    else if ((VCOUNTERIN == 6*2 + CENTER_Y + 6) || (VCOUNTERIN == 626 + 6*2 + CENTER_Y + 6))
                        FF_VSYNC_N <= 1'b1;
                end else begin
                    if ((VCOUNTERIN == 3*2 + CENTER_Y + 6) || (VCOUNTERIN == 625 + 3*2 + CENTER_Y + 6))
                        FF_VSYNC_N <= 1'b0;
                    else if ((VCOUNTERIN == 6*2 + CENTER_Y + 6) || (VCOUNTERIN == 625 + 6*2 + CENTER_Y + 6))
                        FF_VSYNC_N <= 1'b1;
                end
            end
        end
    end

    // GENERATE DATA READ TIMING
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            XPOSITIONR <= 10'b0;
        end else begin
            if ((HCOUNTERIN == DISP_START_X) ||
                (HCOUNTERIN == DISP_START_X + CLOCKS_PER_HALF_LINE))
                XPOSITIONR <= 10'b0;
            else
                XPOSITIONR <= XPOSITIONR + 1'b1;
        end
    end

    // GENERATE VIDEO OUTPUT TIMING (los limites estan comentados en el original;
    // VIDEOOUTX queda siempre a 1)
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            VIDEOOUTX <= 1'b0;
        else
            VIDEOOUTX <= 1'b1;
    end

    assign VIDEOHSOUT_N = FF_HSYNC_N;
    assign VIDEOVSOUT_N = FF_VSYNC_N;

    // HDMI SUPPORT
    assign BLANK_O = (VIDEOOUTX == 1'b0 || FF_VSYNC_N == 1'b0) ? 1'b1 : 1'b0;

endmodule
