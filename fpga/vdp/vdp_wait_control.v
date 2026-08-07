//
//  vdp_wait_control.v
//   VDP command engine wait (timing) control.
//   Traduccion a Verilog de vdp_wait_control.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_wait_control.vhd.
//
//-----------------------------------------------------------------------------

module VDP_WAIT_CONTROL (
    input  wire        RESET,
    input  wire        CLK21M,

    input  wire [7:4]  VDP_COMMAND,

    input  wire        VDPR9PALMODE,   // 0=60Hz (NTSC), 1=50Hz (PAL)
    input  wire        REG_R1_DISP_ON, // 0=Display Off, 1=Display On
    input  wire        REG_R8_SP_OFF,  // 0=Sprite On, 1=Sprite Off
    input  wire        REG_R9_Y_DOTS,  // 0=192 Lines, 1=212 Lines

    input  wire        VDPSPEEDMODE,
    input  wire        DRIVE,

    output wire        ACTIVE
);

    reg [15:0] FF_WAIT_CNT;

    //-------------------------------------------------------------------------
    //   "STOP",  "XXXX",  "XXXX",  "XXXX", "POINT",  "PSET",  "SRCH",  "LINE",
    //   "LMMV",  "LMMM",  "LMCM",  "LMMC",  "HMMV",  "HMMM",  "YMMM",  "HMMC"
    //-------------------------------------------------------------------------
    reg [15:0] C_WAIT_TABLE_501 [0:15];   // Sprite On,  212 Lines, 50Hz
    reg [15:0] C_WAIT_TABLE_502 [0:15];   // Sprite On,  192 Lines, 50Hz
    reg [15:0] C_WAIT_TABLE_503 [0:15];   // Sprite Off, 212 Lines, 50Hz
    reg [15:0] C_WAIT_TABLE_504 [0:15];   // Sprite Off, 192 Lines, 50Hz
    reg [15:0] C_WAIT_TABLE_505 [0:15];   // Blank, 50Hz (Test: Sprite On, 212 Lines)
    reg [15:0] C_WAIT_TABLE_601 [0:15];   // Sprite On,  212 Lines, 60Hz
    reg [15:0] C_WAIT_TABLE_602 [0:15];   // Sprite On,  192 Lines, 60Hz
    reg [15:0] C_WAIT_TABLE_603 [0:15];   // Sprite Off, 212 Lines, 60Hz
    reg [15:0] C_WAIT_TABLE_604 [0:15];   // Sprite Off, 192 Lines, 60Hz
    reg [15:0] C_WAIT_TABLE_605 [0:15];   // Blank, 60Hz (Test: Sprite On, 212 Lines)

    initial begin
        // Sprite On, 212 Lines, 50Hz
        C_WAIT_TABLE_501[ 0]=16'h8000; C_WAIT_TABLE_501[ 1]=16'h8000; C_WAIT_TABLE_501[ 2]=16'h8000; C_WAIT_TABLE_501[ 3]=16'h8000;
        C_WAIT_TABLE_501[ 4]=16'h8000; C_WAIT_TABLE_501[ 5]=16'h8000; C_WAIT_TABLE_501[ 6]=16'h132C; C_WAIT_TABLE_501[ 7]=16'h0B3F;
        C_WAIT_TABLE_501[ 8]=16'h0C91; C_WAIT_TABLE_501[ 9]=16'h0DB9; C_WAIT_TABLE_501[10]=16'h8000; C_WAIT_TABLE_501[11]=16'h8000;
        C_WAIT_TABLE_501[12]=16'h0D0A; C_WAIT_TABLE_501[13]=16'h12CD; C_WAIT_TABLE_501[14]=16'h0FF8; C_WAIT_TABLE_501[15]=16'h8000;
        // Sprite On, 192 Lines, 50Hz
        C_WAIT_TABLE_502[ 0]=16'h8000; C_WAIT_TABLE_502[ 1]=16'h8000; C_WAIT_TABLE_502[ 2]=16'h8000; C_WAIT_TABLE_502[ 3]=16'h8000;
        C_WAIT_TABLE_502[ 4]=16'h8000; C_WAIT_TABLE_502[ 5]=16'h8000; C_WAIT_TABLE_502[ 6]=16'h125A; C_WAIT_TABLE_502[ 7]=16'h0ABD;
        C_WAIT_TABLE_502[ 8]=16'h0BEB; C_WAIT_TABLE_502[ 9]=16'h0D1C; C_WAIT_TABLE_502[10]=16'h8000; C_WAIT_TABLE_502[11]=16'h8000;
        C_WAIT_TABLE_502[12]=16'h0C5B; C_WAIT_TABLE_502[13]=16'h11FB; C_WAIT_TABLE_502[14]=16'h0F9C; C_WAIT_TABLE_502[15]=16'h8000;
        // Sprite Off, 212 Lines, 50Hz
        C_WAIT_TABLE_503[ 0]=16'h8000; C_WAIT_TABLE_503[ 1]=16'h8000; C_WAIT_TABLE_503[ 2]=16'h8000; C_WAIT_TABLE_503[ 3]=16'h8000;
        C_WAIT_TABLE_503[ 4]=16'h8000; C_WAIT_TABLE_503[ 5]=16'h8000; C_WAIT_TABLE_503[ 6]=16'h10A3; C_WAIT_TABLE_503[ 7]=16'h0773;
        C_WAIT_TABLE_503[ 8]=16'h098B; C_WAIT_TABLE_503[ 9]=16'h0C58; C_WAIT_TABLE_503[10]=16'h8000; C_WAIT_TABLE_503[11]=16'h8000;
        C_WAIT_TABLE_503[12]=16'h095F; C_WAIT_TABLE_503[13]=16'h1045; C_WAIT_TABLE_503[14]=16'h0FA5; C_WAIT_TABLE_503[15]=16'h8000;
        // Sprite Off, 192 Lines, 50Hz
        C_WAIT_TABLE_504[ 0]=16'h8000; C_WAIT_TABLE_504[ 1]=16'h8000; C_WAIT_TABLE_504[ 2]=16'h8000; C_WAIT_TABLE_504[ 3]=16'h8000;
        C_WAIT_TABLE_504[ 4]=16'h8000; C_WAIT_TABLE_504[ 5]=16'h8000; C_WAIT_TABLE_504[ 6]=16'h1015; C_WAIT_TABLE_504[ 7]=16'h0767;
        C_WAIT_TABLE_504[ 8]=16'h093B; C_WAIT_TABLE_504[ 9]=16'h0BD6; C_WAIT_TABLE_504[10]=16'h8000; C_WAIT_TABLE_504[11]=16'h8000;
        C_WAIT_TABLE_504[12]=16'h0927; C_WAIT_TABLE_504[13]=16'h0FB6; C_WAIT_TABLE_504[14]=16'h0F08; C_WAIT_TABLE_504[15]=16'h8000;
        // Blank, 50Hz (Test: Sprite On, 212 Lines)
        C_WAIT_TABLE_505[ 0]=16'h8000; C_WAIT_TABLE_505[ 1]=16'h8000; C_WAIT_TABLE_505[ 2]=16'h8000; C_WAIT_TABLE_505[ 3]=16'h8000;
        C_WAIT_TABLE_505[ 4]=16'h8000; C_WAIT_TABLE_505[ 5]=16'h8000; C_WAIT_TABLE_505[ 6]=16'h0EA3; C_WAIT_TABLE_505[ 7]=16'h0689;
        C_WAIT_TABLE_505[ 8]=16'h0974; C_WAIT_TABLE_505[ 9]=16'h0AAB; C_WAIT_TABLE_505[10]=16'h8000; C_WAIT_TABLE_505[11]=16'h8000;
        C_WAIT_TABLE_505[12]=16'h0962; C_WAIT_TABLE_505[13]=16'h0E74; C_WAIT_TABLE_505[14]=16'h0DF7; C_WAIT_TABLE_505[15]=16'h8000;
        // Sprite On, 212 Lines, 60Hz
        C_WAIT_TABLE_601[ 0]=16'h8000; C_WAIT_TABLE_601[ 1]=16'h8000; C_WAIT_TABLE_601[ 2]=16'h8000; C_WAIT_TABLE_601[ 3]=16'h8000;
        C_WAIT_TABLE_601[ 4]=16'h8000; C_WAIT_TABLE_601[ 5]=16'h8000; C_WAIT_TABLE_601[ 6]=16'h13D2; C_WAIT_TABLE_601[ 7]=16'h0C8B;
        C_WAIT_TABLE_601[ 8]=16'h0EB5; C_WAIT_TABLE_601[ 9]=16'h1012; C_WAIT_TABLE_601[10]=16'h8000; C_WAIT_TABLE_601[11]=16'h8000;
        C_WAIT_TABLE_601[12]=16'h0F66; C_WAIT_TABLE_601[13]=16'h1373; C_WAIT_TABLE_601[14]=16'h11E6; C_WAIT_TABLE_601[15]=16'h8000;
        // Sprite On, 192 Lines, 60Hz
        C_WAIT_TABLE_602[ 0]=16'h8000; C_WAIT_TABLE_602[ 1]=16'h8000; C_WAIT_TABLE_602[ 2]=16'h8000; C_WAIT_TABLE_602[ 3]=16'h8000;
        C_WAIT_TABLE_602[ 4]=16'h8000; C_WAIT_TABLE_602[ 5]=16'h8000; C_WAIT_TABLE_602[ 6]=16'h126F; C_WAIT_TABLE_602[ 7]=16'h0BAA;
        C_WAIT_TABLE_602[ 8]=16'h0DAA; C_WAIT_TABLE_602[ 9]=16'h0EEA; C_WAIT_TABLE_602[10]=16'h8000; C_WAIT_TABLE_602[11]=16'h8000;
        C_WAIT_TABLE_602[12]=16'h0E24; C_WAIT_TABLE_602[13]=16'h1210; C_WAIT_TABLE_602[14]=16'h1105; C_WAIT_TABLE_602[15]=16'h8000;
        // Sprite Off, 212 Lines, 60Hz
        C_WAIT_TABLE_603[ 0]=16'h8000; C_WAIT_TABLE_603[ 1]=16'h8000; C_WAIT_TABLE_603[ 2]=16'h8000; C_WAIT_TABLE_603[ 3]=16'h8000;
        C_WAIT_TABLE_603[ 4]=16'h8000; C_WAIT_TABLE_603[ 5]=16'h8000; C_WAIT_TABLE_603[ 6]=16'h10A0; C_WAIT_TABLE_603[ 7]=16'h07EA;
        C_WAIT_TABLE_603[ 8]=16'h0A78; C_WAIT_TABLE_603[ 9]=16'h0DD9; C_WAIT_TABLE_603[10]=16'h8000; C_WAIT_TABLE_603[11]=16'h8000;
        C_WAIT_TABLE_603[12]=16'h0A5B; C_WAIT_TABLE_603[13]=16'h1042; C_WAIT_TABLE_603[14]=16'h118D; C_WAIT_TABLE_603[15]=16'h8000;
        // Sprite Off, 192 Lines, 60Hz
        C_WAIT_TABLE_604[ 0]=16'h8000; C_WAIT_TABLE_604[ 1]=16'h8000; C_WAIT_TABLE_604[ 2]=16'h8000; C_WAIT_TABLE_604[ 3]=16'h8000;
        C_WAIT_TABLE_604[ 4]=16'h8000; C_WAIT_TABLE_604[ 5]=16'h8000; C_WAIT_TABLE_604[ 6]=16'h0FD7; C_WAIT_TABLE_604[ 7]=16'h0797;
        C_WAIT_TABLE_604[ 8]=16'h09FC; C_WAIT_TABLE_604[ 9]=16'h0D16; C_WAIT_TABLE_604[10]=16'h8000; C_WAIT_TABLE_604[11]=16'h8000;
        C_WAIT_TABLE_604[12]=16'h09E1; C_WAIT_TABLE_604[13]=16'h0F78; C_WAIT_TABLE_604[14]=16'h10A6; C_WAIT_TABLE_604[15]=16'h8000;
        // Blank, 60Hz (Test: Sprite On, 212 Lines)
        C_WAIT_TABLE_605[ 0]=16'h8000; C_WAIT_TABLE_605[ 1]=16'h8000; C_WAIT_TABLE_605[ 2]=16'h8000; C_WAIT_TABLE_605[ 3]=16'h8000;
        C_WAIT_TABLE_605[ 4]=16'h8000; C_WAIT_TABLE_605[ 5]=16'h8000; C_WAIT_TABLE_605[ 6]=16'h0DAD; C_WAIT_TABLE_605[ 7]=16'h069E;
        C_WAIT_TABLE_605[ 8]=16'h09E1; C_WAIT_TABLE_605[ 9]=16'h0B18; C_WAIT_TABLE_605[10]=16'h8000; C_WAIT_TABLE_605[11]=16'h8000;
        C_WAIT_TABLE_605[12]=16'h09CA; C_WAIT_TABLE_605[13]=16'h0D4E; C_WAIT_TABLE_605[14]=16'h0EAF; C_WAIT_TABLE_605[15]=16'h8000;
    end

    always @(posedge CLK21M) begin
        if (RESET == 1'b1) begin
            FF_WAIT_CNT <= 16'b0;
        end else begin
            if (DRIVE == 1'b1) begin
                // 50Hz (PAL)
                if (VDPR9PALMODE == 1'b1) begin
                    // Display On
                    if (REG_R1_DISP_ON == 1'b1) begin
                        // Sprite On
                        if (REG_R8_SP_OFF == 1'b0) begin
                            // 212 Lines
                            if (REG_R9_Y_DOTS == 1'b1)
                                FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_501[VDP_COMMAND];
                            // 192 Lines
                            else
                                FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_502[VDP_COMMAND];
                        // Sprite Off
                        end else begin
                            // 212 Lines
                            if (REG_R9_Y_DOTS == 1'b1)
                                FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_503[VDP_COMMAND];
                            // 192 Lines
                            else
                                FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_504[VDP_COMMAND];
                        end
                    // Display Off (Blank)
                    end else begin
                        FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_505[VDP_COMMAND];
                    end
                // 60Hz (NTSC)
                end else begin
                    // Display On
                    if (REG_R1_DISP_ON == 1'b1) begin
                        // Sprite On
                        if (REG_R8_SP_OFF == 1'b0) begin
                            // 212 Lines
                            if (REG_R9_Y_DOTS == 1'b1)
                                FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_601[VDP_COMMAND];
                            // 192 Lines
                            else
                                FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_602[VDP_COMMAND];
                        // Sprite Off
                        end else begin
                            // 212 Lines
                            if (REG_R9_Y_DOTS == 1'b1)
                                FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_603[VDP_COMMAND];
                            // 192 Lines
                            else
                                FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_604[VDP_COMMAND];
                        end
                    // Display Off (Blank)
                    end else begin
                        FF_WAIT_CNT <= {1'b0, FF_WAIT_CNT[14:0]} + C_WAIT_TABLE_605[VDP_COMMAND];
                    end
                end
            end
        end
    end

    assign ACTIVE = FF_WAIT_CNT[15] | VDPSPEEDMODE;

endmodule
