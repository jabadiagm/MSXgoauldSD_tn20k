//
//  vencode.v
//   Composite / S-video encoder (Y / C / V) con auto-deteccion PAL.
//   Traduccion a Verilog de vencode.vhd. (NOTA: no se instancia en este proyecto.)
//
//  Copyright (C) ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vencode.vhd.
//
//-----------------------------------------------------------------------------

module VENCODE (
    input  wire        CLK21M,
    input  wire        RESET,

    // VIDEO INPUT
    input  wire [5:0]  VIDEOR,
    input  wire [5:0]  VIDEOG,
    input  wire [5:0]  VIDEOB,
    input  wire        VIDEOHS_N,
    input  wire        VIDEOVS_N,

    // VIDEO OUTPUT
    output wire [5:0]  VIDEOY,
    output wire [5:0]  VIDEOC,
    output wire [5:0]  VIDEOV
);

    reg [5:0]  FF_VIDEOY;
    reg [5:0]  FF_VIDEOC;
    reg [5:0]  FF_VIDEOV;

    reg [2:0]  FF_SEQ;

    reg        FF_BURPHASE;
    reg [8:0]  FF_VCOUNTER;
    reg [11:0] FF_HCOUNTER;
    reg        FF_WINDOW_V;
    reg        FF_WINDOW_H;
    reg        FF_WINDOW_C;
    reg [4:0]  FF_TABLEADR;
    reg [7:0]  FF_TABLEDAT;
    reg [8:0]  FF_PAL_DET_CNT;
    reg        FF_PAL_MODE;

    reg [5:0]  FF_IVIDEOR;
    reg [5:0]  FF_IVIDEOG;
    reg [5:0]  FF_IVIDEOB;

    wire [7:0] Y;
    wire [7:0] C;
    wire [7:0] V;

    wire [7:0]  C0;
    wire [13:0] Y1, Y2, Y3;
    wire [13:0] U1, U2, U3;
    wire [13:0] V1, V2, V3;
    wire [13:0] W1, W2, W3;

    reg        FF_IVIDEOVS_N;
    reg        FF_IVIDEOHS_N;

    localparam [7:0] VREF = 8'h3B;
    localparam [7:0] CENT = 8'h80;

    reg [7:0] TABLE [0:31];
    initial begin
        TABLE[ 0]=8'h00; TABLE[ 1]=8'hFA; TABLE[ 2]=8'h0C; TABLE[ 3]=8'hEE;
        TABLE[ 4]=8'h18; TABLE[ 5]=8'hE7; TABLE[ 6]=8'h18; TABLE[ 7]=8'hE7;
        TABLE[ 8]=8'h18; TABLE[ 9]=8'hE7; TABLE[10]=8'h18; TABLE[11]=8'hE7;
        TABLE[12]=8'h18; TABLE[13]=8'hE7; TABLE[14]=8'h18; TABLE[15]=8'hE7;
        TABLE[16]=8'h18; TABLE[17]=8'hE7; TABLE[18]=8'h18; TABLE[19]=8'hEE;
        TABLE[20]=8'h0C; TABLE[21]=8'hFA; TABLE[22]=8'h00; TABLE[23]=8'h00;
        TABLE[24]=8'h00; TABLE[25]=8'h00; TABLE[26]=8'h00; TABLE[27]=8'h00;
        TABLE[28]=8'h00; TABLE[29]=8'h00; TABLE[30]=8'h00; TABLE[31]=8'h00;
    end

    assign VIDEOY = FF_VIDEOY;
    assign VIDEOC = FF_VIDEOC;
    assign VIDEOV = FF_VIDEOV;

    //  Y = +0.299R +0.587G +0.114B
    // +U = +0.615R -0.518G -0.097B (  0)
    // +V = +0.179R -0.510G +0.331B ( 60)
    // +W = -0.435R +0.007G +0.428B (120)  ... (ver original)

    assign Y = {1'b0, Y1[11:5]} + ({1'b0, Y2[11:5]} + {1'b0, Y3[11:5]}) + VREF;

    assign V = (FF_SEQ == 3'b110) ? (Y[7:0] + C0[7:0]) :   //  +U
               (FF_SEQ == 3'b101) ? (Y[7:0] + C0[7:0]) :   //  +V
               (FF_SEQ == 3'b100) ? (Y[7:0] + C0[7:0]) :   //  +W
               (FF_SEQ == 3'b010) ? (Y[7:0] - C0[7:0]) :   //  -U
               (FF_SEQ == 3'b001) ? (Y[7:0] - C0[7:0]) :   //  -V
                                    (Y[7:0] - C0[7:0]);     //  -W

    assign C = (FF_SEQ == 3'b110) ? (CENT + C0[7:0]) :
               (FF_SEQ == 3'b101) ? (CENT + C0[7:0]) :
               (FF_SEQ == 3'b100) ? (CENT + C0[7:0]) :
               (FF_SEQ == 3'b010) ? (CENT - C0[7:0]) :
               (FF_SEQ == 3'b001) ? (CENT - C0[7:0]) :
                                    (CENT - C0[7:0]);

    assign C0 = (FF_SEQ[1] == 1'b1) ? (8'h00 + {1'b0, U1[11:5]} - {1'b0, U2[11:5]} - {1'b0, U3[11:5]}) :
                (FF_SEQ[0] == 1'b1) ? (8'h00 + {1'b0, V1[11:5]} - {1'b0, V2[11:5]} + {1'b0, V3[11:5]}) :
                                      (8'h00 - {1'b0, W1[11:5]} + {1'b0, W2[11:5]} + {1'b0, W3[11:5]});

    assign Y1 = 8'h18 * FF_IVIDEOR;
    assign Y2 = 8'h2F * FF_IVIDEOG;
    assign Y3 = 8'h09 * FF_IVIDEOB;

    assign U1 = 8'h32 * FF_IVIDEOR;
    assign U2 = 8'h29 * FF_IVIDEOG;
    assign U3 = 8'h08 * FF_IVIDEOB;

    assign V1 = 8'h0F * FF_IVIDEOR;
    assign V2 = 8'h28 * FF_IVIDEOG;
    assign V3 = 8'h1A * FF_IVIDEOB;

    assign W1 = 8'h24 * FF_IVIDEOR;
    assign W2 = 8'h01 * FF_IVIDEOG;
    assign W3 = 8'h22 * FF_IVIDEOB;

    always @(posedge CLK21M) begin
        FF_IVIDEOVS_N <= VIDEOVS_N;
        FF_IVIDEOHS_N <= VIDEOHS_N;
    end

    //-------------------------------------------------------------------------
    // CLOCK PHASE : 3.58MHz(1FSC) = 21.48MHz(6FSC)/6.  FF_SEQ: (7) 654 (3) 210
    //-------------------------------------------------------------------------
    always @(posedge CLK21M) begin
        if (VIDEOHS_N == 1'b0 && FF_IVIDEOHS_N == 1'b1)
            FF_SEQ <= 3'b110;
        else if (FF_SEQ[1:0] == 2'b00)
            FF_SEQ <= FF_SEQ - 2'd2;
        else
            FF_SEQ <= FF_SEQ - 1'b1;
    end

    // HORIZONTAL COUNTER
    always @(posedge CLK21M) begin
        if (VIDEOHS_N == 1'b0 && FF_IVIDEOHS_N == 1'b1)
            FF_HCOUNTER <= 12'h000;
        else
            FF_HCOUNTER <= FF_HCOUNTER + 1'b1;
    end

    // VERTICAL COUNTER
    always @(posedge CLK21M) begin
        if (VIDEOVS_N == 1'b1 && FF_IVIDEOVS_N == 1'b0) begin
            FF_VCOUNTER <= 9'b0;
            FF_BURPHASE <= 1'b0;
        end else if (VIDEOHS_N == 1'b0 && FF_IVIDEOHS_N == 1'b1) begin
            FF_VCOUNTER <= FF_VCOUNTER + 1'b1;
            FF_BURPHASE <= FF_BURPHASE ^ (~FF_HCOUNTER[1]); // FF_HCOUNTER:1364/1367
        end
    end

    // VERTICAL DISPLAY WINDOW
    always @(posedge CLK21M) begin
        if (FF_VCOUNTER == (9'h022 - 9'h010 - 1))
            FF_WINDOW_V <= 1'b1;
        else if (((FF_VCOUNTER == 262-7) && (FF_PAL_MODE == 1'b0)) ||
                 ((FF_VCOUNTER == 312-7) && (FF_PAL_MODE == 1'b1)))
            FF_WINDOW_V <= 1'b0;
    end

    // HORIZONTAL DISPLAY WINDOW
    always @(posedge CLK21M) begin
        if (FF_HCOUNTER == (12'h100 - 12'h030 - 1))
            FF_WINDOW_H <= 1'b1;
        else if (FF_HCOUNTER == (12'h4FF + 12'h030 - 1))
            FF_WINDOW_H <= 1'b0;
    end

    // COLOR BURST WINDOW
    always @(posedge CLK21M) begin
        if ((FF_WINDOW_V == 1'b0) || (FF_HCOUNTER == 12'h0CC))
            FF_WINDOW_C <= 1'b0;
        else if (FF_WINDOW_V == 1'b1 && (FF_HCOUNTER == 12'h06C))
            FF_WINDOW_C <= 1'b1;
    end

    // COLOR BURST TABLE POINTER
    always @(posedge CLK21M) begin
        if (FF_WINDOW_C == 1'b0)
            FF_TABLEADR <= 5'b0;
        else if (FF_SEQ == 3'b101 || FF_SEQ == 3'b001)
            FF_TABLEADR <= FF_TABLEADR + 1'b1;
    end

    always @(posedge CLK21M) begin
        FF_TABLEDAT <= TABLE[FF_TABLEADR];
    end

    // VIDEO ENCODE
    always @(posedge CLK21M) begin
        if ((VIDEOVS_N ^ VIDEOHS_N) == 1'b1) begin
            FF_VIDEOY <= 6'b0;
            FF_VIDEOC <= CENT[7:2];
            FF_VIDEOV <= 6'b0;
        end else if (FF_WINDOW_V == 1'b1 && FF_WINDOW_H == 1'b1) begin
            FF_VIDEOY <= Y[7:2];
            FF_VIDEOC <= C[7:2];
            FF_VIDEOV <= V[7:2];
        end else begin
            FF_VIDEOY <= VREF[7:2];
            if (FF_SEQ[1:0] == 2'b10) begin
                FF_VIDEOC <= CENT[7:2];
                FF_VIDEOV <= VREF[7:2];
            end else if (FF_BURPHASE == 1'b1) begin
                FF_VIDEOC <= CENT[7:2] + FF_TABLEDAT[7:2];
                FF_VIDEOV <= VREF[7:2] + FF_TABLEDAT[7:2];
            end else begin
                FF_VIDEOC <= CENT[7:2] - FF_TABLEDAT[7:2];
                FF_VIDEOV <= VREF[7:2] - FF_TABLEDAT[7:2];
            end
        end
    end

    always @(posedge CLK21M) begin
        if ((VIDEOVS_N ^ VIDEOHS_N) == 1'b1) begin
            // HOLD
        end else if (FF_WINDOW_V == 1'b1 && FF_WINDOW_H == 1'b1) begin
            if (FF_HCOUNTER[0] == 1'b0) begin
                FF_IVIDEOR <= VIDEOR;
                FF_IVIDEOG <= VIDEOG;
                FF_IVIDEOB <= VIDEOB;
            end
        end
    end

    // PAL AUTO DETECTION
    always @(posedge CLK21M) begin
        if (VIDEOVS_N == 1'b1 && FF_IVIDEOVS_N == 1'b0)
            FF_PAL_DET_CNT <= 9'b0;
        else if (VIDEOHS_N == 1'b0 && FF_IVIDEOHS_N == 1'b1)
            FF_PAL_DET_CNT <= FF_PAL_DET_CNT + 1'b1;
    end

    always @(posedge CLK21M) begin
        if (VIDEOVS_N == 1'b1 && FF_IVIDEOVS_N == 1'b0) begin
            if (FF_PAL_DET_CNT > 300)
                FF_PAL_MODE <= 1'b1;
            else
                FF_PAL_MODE <= 1'b0;
        end
    end

endmodule
