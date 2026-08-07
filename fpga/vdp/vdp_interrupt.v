//
//  vdp_interrupt.v
//   VDP interrupt request generator (V-SYNC / H-SYNC).
//   Traduccion a Verilog de vdp_interrupt.vhd.
//
//  Copyright (C) 2006 Kunihiko Ohnaka - http://www.ohnaka.jp/ese-vdp/
//  Licencia completa (redistribucion / disclaimer) en el original vdp_interrupt.vhd.
//
//-----------------------------------------------------------------------------

module VDP_INTERRUPT (
    input  wire        RESET,
    input  wire        CLK21M,

    input  wire [10:0] H_CNT,
    input  wire [ 7:0] Y_CNT,
    input  wire        ACTIVE_LINE,
    input  wire        V_BLANKING_START,
    input  wire        CLR_VSYNC_INT,
    input  wire        CLR_HSYNC_INT,
    output wire        REQ_VSYNC_INT_N,
    output wire        REQ_HSYNC_INT_N,
    input  wire [ 7:0] REG_R19_HSYNC_INT_LINE,

    // V9968: command-end interrupt
    input  wire        CMD_CE,          // command executing (S#2 bit0)
    input  wire        CLR_CMD_INT,
    output wire        REQ_CMD_INT_N
);

`include "vdp_package.vh"

    reg  FF_VSYNC_INT_N;
    reg  FF_HSYNC_INT_N;
    wire W_VSYNC_INTR_TIMING;

    reg  FF_CMD_INT_N;
    reg  FF_CMD_CE_D;                    // CE retardado, para detectar flanco 1->0

    assign REQ_VSYNC_INT_N = FF_VSYNC_INT_N;
    assign REQ_HSYNC_INT_N = FF_HSYNC_INT_N;
    assign REQ_CMD_INT_N   = FF_CMD_INT_N;

    //---------------------------------------------------------------------------
    // VSYNC INTERRUPT REQUEST
    //---------------------------------------------------------------------------
    assign W_VSYNC_INTR_TIMING = (H_CNT == LEFT_BORDER) ? 1'b1 : 1'b0;

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_VSYNC_INT_N <= 1'b1;
        end else begin
            if (CLR_VSYNC_INT == 1'b1) begin
                // V-BLANKING INTERRUPT CLEAR
                FF_VSYNC_INT_N <= 1'b1;
            end else if (W_VSYNC_INTR_TIMING == 1'b1 && V_BLANKING_START == 1'b1) begin
                // V-BLANKING INTERRUPT REQUEST
                FF_VSYNC_INT_N <= 1'b0;
            end
        end
    end

    //------------------------------------------------------------------------
    //  W_HSYNC INTERRUPT REQUEST
    //------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_HSYNC_INT_N <= 1'b1;
        end else begin
            if (CLR_HSYNC_INT == 1'b1 || (W_VSYNC_INTR_TIMING == 1'b1 && V_BLANKING_START == 1'b1)) begin
                // H-BLANKING INTERRUPT CLEAR
                FF_HSYNC_INT_N <= 1'b1;
            end else if (ACTIVE_LINE == 1'b1 && Y_CNT == REG_R19_HSYNC_INT_LINE) begin
                // H-BLANKING INTERRUPT REQUEST
                FF_HSYNC_INT_N <= 1'b0;
            end
        end
    end

    //------------------------------------------------------------------------
    //  COMMAND-END INTERRUPT REQUEST (V9968)
    //   Se dispara en el flanco CE 1->0 (comando finalizado).
    //------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_CMD_INT_N <= 1'b1;
            FF_CMD_CE_D  <= 1'b0;
        end else begin
            FF_CMD_CE_D <= CMD_CE;
            if (CLR_CMD_INT == 1'b1) begin
                // COMMAND-END INTERRUPT CLEAR (escritura en puerto 0x9C, bit2)
                FF_CMD_INT_N <= 1'b1;
            end else if (FF_CMD_CE_D == 1'b1 && CMD_CE == 1'b0) begin
                // COMMAND-END INTERRUPT REQUEST (flanco de bajada de CE)
                FF_CMD_INT_N <= 1'b0;
            end
        end
    end

endmodule
