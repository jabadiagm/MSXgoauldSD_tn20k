//
//  vdp_hvcounter.v
//   Horizontal / vertical counters, field ID, H/V blanking, HDMI reset on mode change.
//   Traduccion a Verilog de vdp_hvcounter.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_hvcounter.vhd.
//
//  NOTA (traduccion): en el original CLOCKS_PER_LINE/HALF eran SHARED VARIABLE que
//   hvcounter reasignaba segun PAL (1728/864). Aqui se calculan como wire local a
//   partir de PAL_MODE (mismo valor en estado estable). Los otros modulos acoplados
//   (ssg/ntsc_pal/vga/vdp) hacen lo mismo con su propia señal PAL -> todos coherentes.
//-----------------------------------------------------------------------------

module VDP_HVCOUNTER (
    input  wire        RESET,
    input  wire        CLK21M,

    output wire [10:0] H_CNT,
    output wire [10:0] H_CNT_IN_FIELD,
    output wire [ 9:0] V_CNT_IN_FIELD,
    output wire [10:0] V_CNT_IN_FRAME,
    output wire        FIELD,
    output wire        H_BLANK,
    output wire        V_BLANK,

    input  wire        PAL_MODE,
    input  wire        INTERLACE_MODE,
    input  wire        Y212_MODE,
    input  wire [ 6:0] OFFSET_Y,
    output wire        HDMI_RESET,
    input  wire        BLANKING_START,
    input  wire        BLANKING_END
);

`include "vdp_package.vh"

    // CLOCKS por linea, dependientes de PAL (antes SHARED VARIABLE mutado aqui)
    wire [11:0] CLOCKS_PER_LINE      = (PAL_MODE == 1'b1) ? 12'd1728 : 12'd1716;
    wire [11:0] CLOCKS_PER_HALF_LINE = (PAL_MODE == 1'b1) ? 12'd864  : 12'd858;

    // FLIP FLOP
    reg [10:0] FF_H_CNT;
    reg [10:0] FF_H_CNT_IN_FIELD;
    reg [ 9:0] FF_V_CNT_IN_FIELD;
    reg        FF_FIELD;
    reg [10:0] FF_V_CNT_IN_FRAME;
    reg        FF_H_BLANK;
    reg        FF_V_BLANK;
    reg        FF_PAL_MODE;
    reg        FF_INTERLACE_MODE;
    reg        FF_FIELD_END;
    reg        FF_HDMI_RESET;

    // WIRE
    wire       W_H_CNT_HALF;
    wire       W_H_CNT_END;
    wire       W_FIELD_END;
    wire       W_H_BLANK_START;
    wire       W_H_BLANK_END;

    assign H_CNT          = FF_H_CNT;
    assign H_CNT_IN_FIELD = FF_H_CNT_IN_FIELD;
    assign V_CNT_IN_FIELD = FF_V_CNT_IN_FIELD;
    assign FIELD          = FF_FIELD;
    assign V_CNT_IN_FRAME = FF_V_CNT_IN_FRAME;
    assign H_BLANK        = FF_H_BLANK;
    assign V_BLANK        = FF_V_BLANK;
    assign HDMI_RESET     = FF_HDMI_RESET;

    //--------------------------------------------------------------------------
    //  V SYNCHRONIZE MODE CHANGE
    //--------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PAL_MODE       <= 1'b0;
            FF_INTERLACE_MODE <= 1'b0;
            FF_HDMI_RESET     <= 1'b0;
        end else begin
            if ( ((W_H_CNT_HALF | W_H_CNT_END) & W_FIELD_END & FF_FIELD) == 1'b1 ) begin
                FF_PAL_MODE       <= PAL_MODE;
                FF_INTERLACE_MODE <= INTERLACE_MODE;
                if (FF_PAL_MODE == PAL_MODE)
                    FF_HDMI_RESET <= 1'b0;
                else
                    FF_HDMI_RESET <= 1'b1;
            end else begin
                FF_HDMI_RESET <= 1'b0;
            end
        end
    end

    // (El proceso original que reasignaba CLOCKS_PER_LINE/HALF a 1728/864 en PAL era
    //  codigo muerto en sintesis; se omite. Ver NOTA IMPORTANTE en la cabecera.)

    //--------------------------------------------------------------------------
    //  HORIZONTAL COUNTER
    //--------------------------------------------------------------------------
    assign W_H_CNT_HALF = (FF_H_CNT == (CLOCKS_PER_HALF_LINE - 1)) ? 1'b1 : 1'b0;
    assign W_H_CNT_END  = (FF_H_CNT == (CLOCKS_PER_LINE - 1))      ? 1'b1 : 1'b0;

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_H_CNT <= 11'b0;
        end else begin
            if (W_H_CNT_END == 1'b1 || (W_FIELD_END == 1'b1 && W_H_CNT_HALF == 1'b1 && FF_INTERLACE_MODE == 1'b0))
                FF_H_CNT <= 11'b0;
            else
                FF_H_CNT <= FF_H_CNT + 1'b1;
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_H_CNT_IN_FIELD <= 11'b0;
        end else begin
            if (W_H_CNT_END == 1'b1 || W_H_CNT_HALF == 1'b1)
                FF_H_CNT_IN_FIELD <= 11'b0;
            else
                FF_H_CNT_IN_FIELD <= FF_H_CNT_IN_FIELD + 1'b1;
        end
    end

    //--------------------------------------------------------------------------
    //  VERTICAL COUNTER
    //--------------------------------------------------------------------------
    assign W_FIELD_END = FF_FIELD_END;

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_FIELD_END <= 1'b0;
        end else begin
            if (
                (FF_FIELD == 1'b0 && FF_INTERLACE_MODE == 1'b0 && FF_PAL_MODE == 1'b0 && FF_V_CNT_IN_FIELD == 10'd524) ||
                (FF_FIELD == 1'b0 && FF_INTERLACE_MODE == 1'b0 && FF_PAL_MODE == 1'b1 && FF_V_CNT_IN_FIELD == 10'd624) ||
                (FF_FIELD == 1'b1 && FF_INTERLACE_MODE == 1'b0 && FF_PAL_MODE == 1'b0 && FF_V_CNT_IN_FIELD == 10'd524) ||
                (FF_FIELD == 1'b1 && FF_INTERLACE_MODE == 1'b0 && FF_PAL_MODE == 1'b1 && FF_V_CNT_IN_FIELD == 10'd624) ||
                (FF_FIELD == 1'b0 && FF_INTERLACE_MODE == 1'b1 && FF_PAL_MODE == 1'b0 && FF_V_CNT_IN_FIELD == 10'd524) ||
                (FF_FIELD == 1'b0 && FF_INTERLACE_MODE == 1'b1 && FF_PAL_MODE == 1'b1 && FF_V_CNT_IN_FIELD == 10'd624) ||
                (FF_FIELD == 1'b1 && FF_INTERLACE_MODE == 1'b1 && FF_PAL_MODE == 1'b0 && FF_V_CNT_IN_FIELD == 10'd524) ||
                (FF_FIELD == 1'b1 && FF_INTERLACE_MODE == 1'b1 && FF_PAL_MODE == 1'b1 && FF_V_CNT_IN_FIELD == 10'd624) )
                FF_FIELD_END <= 1'b1;
            else
                FF_FIELD_END <= 1'b0;
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_V_CNT_IN_FIELD <= 10'b0;
        end else begin
            if ((W_H_CNT_HALF | W_H_CNT_END) == 1'b1) begin
                if (W_FIELD_END == 1'b1)
                    FF_V_CNT_IN_FIELD <= 10'b0;
                else
                    FF_V_CNT_IN_FIELD <= FF_V_CNT_IN_FIELD + 1'b1;
            end
        end
    end

    //--------------------------------------------------------------------------
    //  FIELD ID
    //--------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_FIELD <= 1'b0;
        end else begin
            // GENERATE FF_FIELD SIGNAL
            if ((W_H_CNT_HALF | W_H_CNT_END) == 1'b1) begin
                if (W_FIELD_END == 1'b1)
                    FF_FIELD <= ~FF_FIELD;
            end
        end
    end

    //--------------------------------------------------------------------------
    //  VERTICAL COUNTER IN FRAME
    //--------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_V_CNT_IN_FRAME <= 11'b0;
        end else begin
            if ((W_H_CNT_HALF | W_H_CNT_END) == 1'b1) begin
                if (W_FIELD_END == 1'b1 && (FF_FIELD == 1'b1 || FF_INTERLACE_MODE == 1'b0))
                    FF_V_CNT_IN_FRAME <= 11'b0;
                else
                    FF_V_CNT_IN_FRAME <= FF_V_CNT_IN_FRAME + 1'b1;
            end
        end
    end

    //---------------------------------------------------------------------------
    // H BLANKING
    //---------------------------------------------------------------------------
    assign W_H_BLANK_START = W_H_CNT_END;
    assign W_H_BLANK_END   = (FF_H_CNT == LEFT_BORDER) ? 1'b1 : 1'b0;

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_H_BLANK <= 1'b0;
        end else begin
            if (W_H_BLANK_START == 1'b1)
                FF_H_BLANK <= 1'b1;
            else if (W_H_BLANK_END == 1'b1)
                FF_H_BLANK <= 1'b0;
        end
    end

    //---------------------------------------------------------------------------
    // V BLANKING
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_V_BLANK <= 1'b0;
        end else begin
            if (W_H_BLANK_END == 1'b1) begin
                if (BLANKING_END == 1'b1)
                    FF_V_BLANK <= 1'b0;
                else if (BLANKING_START == 1'b1)
                    FF_V_BLANK <= 1'b1;
            end
        end
    end

endmodule
