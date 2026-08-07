//
//  vdp_graphic123m.v
//   GRAPHIC mode 1,2,3 and MULTICOLOR main processing (SCREEN 1,2,4,3).
//   Traduccion a Verilog de vdp_graphic123m.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / t.hara / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_graphic123m.vhd.
//
//-----------------------------------------------------------------------------
// Document
//  JP: GRAPHICモード1,2,3および MULTICOLORモードのメイン処理回路です。
//-----------------------------------------------------------------------------

module VDP_GRAPHIC123M (
    input  wire        CLK21M,      //  21.477MHZ
    input  wire        RESET,

    // CONTROL SIGNALS
    input  wire [1:0]  DOTSTATE,
    input  wire [2:0]  EIGHTDOTSTATE,
    input  wire [8:0]  DOTCOUNTERX,
    input  wire [8:0]  DOTCOUNTERY,

    input  wire        VDPMODEMULTI,
    input  wire        VDPMODEMULTIQ,
    input  wire        VDPMODEGRAPHIC1,
    input  wire        VDPMODEGRAPHIC2,
    input  wire        VDPMODEGRAPHIC3,

    // REGISTERS
    input  wire [6:0]  REG_R2_PT_NAM_ADDR,
    input  wire [5:0]  REG_R4_PT_GEN_ADDR,
    input  wire [10:0] REG_R10R3_COL_ADDR,
    input  wire [8:3]  REG_R26_H_SCROLL,
    input  wire [2:0]  REG_R27_H_SCROLL,
    //
    input  wire [7:0]  PRAMDAT,
    output wire [16:0] PRAMADR,

    output wire [3:0]  PCOLORCODE
);

    reg  [16:0] FF_REQ_ADDR;
    reg  [3:0]  FF_COL_CODE;
    reg  [7:0]  FF_PAT_NUM;
    reg  [7:0]  FF_PRE_PAT_GEN;
    reg  [7:0]  FF_PRE_PAT_COL;
    reg  [7:0]  FF_PAT_GEN;
    reg  [7:0]  FF_PAT_COL;

    wire [16:0] REQ_PAT_NAME_TBL_ADDR;
    wire [16:0] REQ_PAT_GEN_TBL_ADDR;
    wire [16:0] REQ_PAT_COL_TBL_ADDR;
    wire [16:0] REQ_ADDR;
    wire        COL_HL_SEL;
    wire [3:0]  COL_CODE;
    wire [3:0]  EIGHTDOTSTATE_DEC;
    wire [7:3]  W_DOTCOUNTERX;

    assign W_DOTCOUNTERX = REG_R26_H_SCROLL[7:3] + DOTCOUNTERX[7:3];

    // ADDRESS DECODE
    assign REQ_PAT_NAME_TBL_ADDR = {REG_R2_PT_NAM_ADDR, DOTCOUNTERY[7:3], W_DOTCOUNTERX};

    assign REQ_PAT_GEN_TBL_ADDR = (VDPMODEGRAPHIC1 == 1'b1) ?
                                    {REG_R4_PT_GEN_ADDR, FF_PAT_NUM, DOTCOUNTERY[2:0]} :
                                    ({REG_R4_PT_GEN_ADDR[5:2], DOTCOUNTERY[7:6], FF_PAT_NUM, DOTCOUNTERY[2:0]} &
                                     {4'b1111, REG_R4_PT_GEN_ADDR[1:0], 8'b11111111, 3'b111});

    assign REQ_PAT_COL_TBL_ADDR = (VDPMODEMULTI == 1'b1 || VDPMODEMULTIQ == 1'b1) ?
                                    {REG_R4_PT_GEN_ADDR, FF_PAT_NUM, DOTCOUNTERY[4:2]} :
                                  (VDPMODEGRAPHIC1 == 1'b1) ?
                                    {REG_R10R3_COL_ADDR, 1'b0, FF_PAT_NUM[7:3]} :
                                    ({REG_R10R3_COL_ADDR[10:7], DOTCOUNTERY[7:6], FF_PAT_NUM, DOTCOUNTERY[2:0]} &
                                     {4'b1111, REG_R10R3_COL_ADDR[6:0], 6'b111111});

    // DRAM READ REQUEST
    assign EIGHTDOTSTATE_DEC = (EIGHTDOTSTATE == 3'b000) ? 4'b0001 :
                               (EIGHTDOTSTATE == 3'b001) ? 4'b0010 :
                               (EIGHTDOTSTATE == 3'b010) ? 4'b0100 :
                               (EIGHTDOTSTATE == 3'b011) ? 4'b1000 :
                               4'b0000;

    assign REQ_ADDR = (EIGHTDOTSTATE == 3'b000) ? REQ_PAT_NAME_TBL_ADDR :
                      (EIGHTDOTSTATE == 3'b001) ? REQ_PAT_GEN_TBL_ADDR  :
                      (EIGHTDOTSTATE == 3'b010) ? REQ_PAT_COL_TBL_ADDR  :
                      FF_REQ_ADDR;

    // GENERATE PIXEL COLOR NUMBER
    assign COL_HL_SEL = (VDPMODEMULTI == 1'b1 || VDPMODEMULTIQ == 1'b1) ? ~EIGHTDOTSTATE[2] :
                                                                          FF_PAT_GEN[7];
    assign COL_CODE   = (COL_HL_SEL == 1'b1) ? FF_PAT_COL[7:4] : FF_PAT_COL[3:0];

    // OUT ASSIGNMENT
    assign PRAMADR    = FF_REQ_ADDR;
    assign PCOLORCODE = FF_COL_CODE;

    // FF
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PAT_COL <= 8'b0;
        end else begin
            if (DOTSTATE == 2'b00 && EIGHTDOTSTATE_DEC[0] == 1'b1)
                FF_PAT_COL <= FF_PRE_PAT_COL;
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PAT_GEN <= 8'b0;
        end else begin
            if (DOTSTATE == 2'b00 && EIGHTDOTSTATE_DEC[0] == 1'b1)
                FF_PAT_GEN <= FF_PRE_PAT_GEN;
            else if (DOTSTATE == 2'b01)
                FF_PAT_GEN <= {FF_PAT_GEN[6:0], 1'b0};
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PAT_NUM <= 8'b0;
        end else begin
            if (DOTSTATE == 2'b01 && EIGHTDOTSTATE_DEC[1] == 1'b1)
                FF_PAT_NUM <= PRAMDAT;
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PRE_PAT_GEN <= 8'b0;
        end else begin
            if (DOTSTATE == 2'b01 && EIGHTDOTSTATE_DEC[2] == 1'b1)
                FF_PRE_PAT_GEN <= PRAMDAT;
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PRE_PAT_COL <= 8'b0;
        end else begin
            if (DOTSTATE == 2'b01 && EIGHTDOTSTATE_DEC[3] == 1'b1)
                FF_PRE_PAT_COL <= PRAMDAT;
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_COL_CODE <= 4'b0;
        end else begin
            if (DOTSTATE == 2'b01)
                FF_COL_CODE <= COL_CODE;
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_REQ_ADDR <= 17'b0;
        end else begin
            if (DOTSTATE == 2'b11)
                FF_REQ_ADDR <= REQ_ADDR;
        end
    end

endmodule
