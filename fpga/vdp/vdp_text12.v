//
//  vdp_text12.v
//   TEXT mode 1 / 2 main processing (SCREEN 0 width 40/80).
//   Traduccion a Verilog de vdp_text12.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / ESE-VDP contributors (blink por Caro/t.hara,
//  page flipping / R1 bit2 por Oduvaldo Pavan Junior).
//  Licencia completa (redistribucion / disclaimer) en el original vdp_text12.vhd.
//
//-----------------------------------------------------------------------------
// Document
//  JP: TEXTモード1,2のメイン処理回路です。
//-----------------------------------------------------------------------------

module VDP_TEXT12 (
    // VDP CLOCK ... 21.477MHZ
    input  wire        CLK21M,
    input  wire        RESET,

    input  wire [1:0]  DOTSTATE,
    input  wire [8:0]  DOTCOUNTERX,
    input  wire [8:0]  DOTCOUNTERY,
    input  wire [8:0]  DOTCOUNTERYP,

    input  wire        VDPMODETEXT1,
    input  wire        VDPMODETEXT1Q,
    input  wire        VDPMODETEXT2,

    // REGISTERS
    input  wire        REG_R1_BL_CLKS,
    input  wire [7:0]  REG_R7_FRAME_COL,
    input  wire [7:0]  REG_R12_BLINK_MODE,
    input  wire [7:0]  REG_R13_BLINK_PERIOD,

    input  wire [6:0]  REG_R2_PT_NAM_ADDR,
    input  wire [5:0]  REG_R4_PT_GEN_ADDR,
    input  wire [10:0] REG_R10R3_COL_ADDR,
    //
    input  wire [7:0]  PRAMDAT,
    output reg  [16:0] PRAMADR,
    output wire        TXVRAMREADEN,

    output wire [3:0]  PCOLORCODE
);

    reg        ITXVRAMREADEN;
    reg        ITXVRAMREADEN2;
    reg [4:0]  DOTCOUNTER24;
    reg        TXWINDOWX;
    reg        TXPREWINDOWX;

    wire [16:0] LOGICALVRAMADDRNAM;
    wire [16:0] LOGICALVRAMADDRGEN;
    wire [16:0] LOGICALVRAMADDRCOL;

    wire [11:0] TXCHARCOUNTER;
    reg  [6:0]  TXCHARCOUNTERX;
    reg  [11:0] TXCHARCOUNTERSTARTOFLINE;

    reg  [7:0]  PATTERNNUM;
    reg  [7:0]  PREPATTERN;
    reg  [7:0]  PREBLINK;
    reg  [7:0]  PATTERN;
    reg  [7:0]  BLINK;
    reg         TXCOLORCODE;            // ONLY 2 COLORS
    wire [7:0]  TXCOLOR;

    reg  [3:0]  FF_BLINK_CLK_CNT;
    reg         FF_BLINK_STATE;
    reg  [3:0]  FF_BLINK_PERIOD_CNT;
    wire [3:0]  W_BLINK_CNT_MAX;
    wire        W_BLINK_SYNC;

    // JP: RAMは DOTSTATEが"10","00"の時にアドレスを出して"01"でアクセスする。
    // JP: EIGHTDOTSTATEで見ると、
    // JP:  0-1     READ PATTERN NUM.
    // JP:  1-2     READ PATTERN
    // JP: となる。

    //--------------------------------------------------------------
    assign TXCHARCOUNTER = TXCHARCOUNTERSTARTOFLINE + TXCHARCOUNTERX;

    assign LOGICALVRAMADDRNAM = (VDPMODETEXT1 == 1'b1 || VDPMODETEXT1Q == 1'b1) ?
                                    {REG_R2_PT_NAM_ADDR, TXCHARCOUNTER[9:0]} :
                                    {REG_R2_PT_NAM_ADDR[6:2], TXCHARCOUNTER};

    assign LOGICALVRAMADDRGEN = {REG_R4_PT_GEN_ADDR, PATTERNNUM, DOTCOUNTERY[2:0]};

    assign LOGICALVRAMADDRCOL = {REG_R10R3_COL_ADDR[10:3], TXCHARCOUNTER[11:3]};

    assign TXVRAMREADEN = (VDPMODETEXT1 == 1'b1 || VDPMODETEXT1Q == 1'b1) ? ITXVRAMREADEN :
                          (VDPMODETEXT2 == 1'b1) ? (ITXVRAMREADEN | ITXVRAMREADEN2) :
                          1'b0;

    assign TXCOLOR = ((VDPMODETEXT2 == 1'b1) && (FF_BLINK_STATE == 1'b1) && (BLINK[7] == 1'b1)) ?
                        REG_R12_BLINK_MODE : REG_R7_FRAME_COL;

    assign PCOLORCODE = ((TXWINDOWX == 1'b1) && (TXCOLORCODE == 1'b1)) ? TXCOLOR[7:4] :
                        ((TXWINDOWX == 1'b1) && (TXCOLORCODE == 1'b0)) ? TXCOLOR[3:0] :
                        REG_R7_FRAME_COL[3:0];

    //---------------------------------------------------------------------------
    // TIMING GENERATOR
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            DOTCOUNTER24 <= 5'b0;
        end else begin
            if (DOTSTATE == 2'b10) begin
                if (DOTCOUNTERX == 12) begin
                    // JP: DOTCOUNTERは"10"のタイミングでは既にカウントアップしているので注意
                    DOTCOUNTER24 <= 5'b0;
                end else begin
                    // THE DOTCOUNTER24[2:0] COUNTS UP 0 TO 5,
                    // AND THE DOTCOUNTER24[4:3] COUNTS UP 0 TO 3.
                    if (DOTCOUNTER24[2:0] == 3'b101) begin
                        DOTCOUNTER24[4:3] <= DOTCOUNTER24[4:3] + 1'b1;
                        DOTCOUNTER24[2:0] <= 3'b000;
                    end else begin
                        DOTCOUNTER24[2:0] <= DOTCOUNTER24[2:0] + 1'b1;
                    end
                end
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            TXPREWINDOWX <= 1'b0;
        end else begin
            if (DOTSTATE == 2'b10) begin
                if (DOTCOUNTERX == 12)
                    TXPREWINDOWX <= 1'b1;
                else if (DOTCOUNTERX == 240+12)
                    TXPREWINDOWX <= 1'b0;
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            TXWINDOWX <= 1'b0;
        end else begin
            if (DOTSTATE == 2'b01) begin
                if (DOTCOUNTERX == 16)
                    TXWINDOWX <= 1'b1;
                else if (DOTCOUNTERX == 240+16)
                    TXWINDOWX <= 1'b0;
            end
        end
    end

    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            PATTERNNUM               <= 8'b0;
            PRAMADR                  <= 17'b0;
            ITXVRAMREADEN            <= 1'b0;
            ITXVRAMREADEN2           <= 1'b0;
            TXCHARCOUNTERX           <= 7'b0;
            PREBLINK                 <= 8'b0;
            TXCHARCOUNTERSTARTOFLINE <= 12'b0;
        end else begin
            case (DOTSTATE)
                2'b11: begin
                    if (TXPREWINDOWX == 1'b1) begin
                        // VRAM READ ADDRESS OUTPUT.
                        case (DOTCOUNTER24[2:0])
                            3'b000: begin
                                if (DOTCOUNTER24[4:3] == 2'b00) begin
                                    // READ COLOR TABLE(TEXT2 BLINK)
                                    // IT IS USED ONLY ONE TIME PER 8 CHARACTERS.
                                    PRAMADR        <= LOGICALVRAMADDRCOL;
                                    ITXVRAMREADEN2 <= 1'b1;
                                end
                            end
                            3'b001: begin
                                // READ PATTERN NAME TABLE
                                PRAMADR        <= LOGICALVRAMADDRNAM;
                                ITXVRAMREADEN  <= 1'b1;
                                TXCHARCOUNTERX <= TXCHARCOUNTERX + 1'b1;
                            end
                            3'b010: begin
                                // READ PATTERN GENERATOR TABLE
                                PRAMADR       <= LOGICALVRAMADDRGEN;
                                ITXVRAMREADEN <= 1'b1;
                            end
                            3'b100: begin
                                // READ PATTERN NAME TABLE
                                // IT IS USED IF VDPMODE IS TEST2.
                                PRAMADR        <= LOGICALVRAMADDRNAM;
                                ITXVRAMREADEN2 <= 1'b1;
                                if (VDPMODETEXT2 == 1'b1)
                                    TXCHARCOUNTERX <= TXCHARCOUNTERX + 1'b1;
                            end
                            3'b101: begin
                                // READ PATTERN GENERATOR TABLE
                                // IT IS USED IF VDPMODE IS TEST2.
                                PRAMADR        <= LOGICALVRAMADDRGEN;
                                ITXVRAMREADEN2 <= 1'b1;
                            end
                            default: ;
                        endcase
                    end
                end
                2'b10: begin
                    ITXVRAMREADEN  <= 1'b0;
                    ITXVRAMREADEN2 <= 1'b0;
                end
                2'b00: begin
                    if (DOTCOUNTERX == 11) begin
                        TXCHARCOUNTERX <= 7'b0;
                        if (DOTCOUNTERYP == 0)
                            TXCHARCOUNTERSTARTOFLINE <= 12'b0;
                    end else if ((DOTCOUNTERX == 240+11) && (DOTCOUNTERYP[2:0] == 3'b111)) begin
                        TXCHARCOUNTERSTARTOFLINE <= TXCHARCOUNTERSTARTOFLINE + TXCHARCOUNTERX;
                    end
                end
                2'b01: begin
                    case (DOTCOUNTER24[2:0])
                        3'b001: begin
                            // READ COLOR TABLE(TEXT2 BLINK)
                            // IT IS USED ONLY ONE TIME PER 8 CHARACTERS.
                            if (DOTCOUNTER24[4:3] == 2'b00)
                                PREBLINK <= PRAMDAT;
                        end
                        3'b010: begin
                            // READ PATTERN NAME TABLE
                            PATTERNNUM <= PRAMDAT;
                        end
                        3'b011: begin
                            // READ PATTERN GENERATOR TABLE
                            PREPATTERN <= PRAMDAT;
                        end
                        3'b101: begin
                            // READ PATTERN NAME TABLE (VDPMODE IS TEST2)
                            PATTERNNUM <= PRAMDAT;
                        end
                        3'b000: begin
                            // READ PATTERN GENERATOR TABLE (VDPMODE IS TEST2)
                            if (VDPMODETEXT2 == 1'b1)
                                PREPATTERN <= PRAMDAT;
                        end
                        default: ;
                    endcase
                end
                default: ;
            endcase
        end
    end

    //--------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            PATTERN     <= 8'b0;
            TXCOLORCODE <= 1'b0;
            BLINK       <= 8'b0;
        end else begin
            // COLOR CODE DECISION
            // JP: "01"と"10"のタイミングでかラーコードを出力してあげれば、
            // JP: VDPエンティティの方でパレットをデコードして色を出力してくれる。
            // JP: "01"と"10"で同じ色を出力すれば横256ドットになり、違う色を
            // JP: 出力すれば横512ドット表示となる。
            case (DOTSTATE)
                2'b00: begin
                    if (DOTCOUNTER24[2:0] == 3'b100) begin
                        // LOAD NEXT 8 DOT DATA (ver comentario original)
                        PATTERN <= PREPATTERN;
                    end else if ((DOTCOUNTER24[2:0] == 3'b001) && (VDPMODETEXT2 == 1'b1)) begin
                        // JP: TEXT2では"001"のタイミングでもロードする。
                        PATTERN <= PREPATTERN;
                    end
                    if ((DOTCOUNTER24[2:0] == 3'b100) || (DOTCOUNTER24[2:0] == 3'b001)) begin
                        // EVALUATE BLINK SIGNAL
                        if (DOTCOUNTER24[4:0] == 5'b00100)
                            BLINK <= PREBLINK;
                        else
                            BLINK <= {BLINK[6:0], 1'b0};
                    end
                end
                2'b01: begin
                    TXCOLORCODE <= PATTERN[7];
                    PATTERN     <= {PATTERN[6:0], 1'b0};
                end
                2'b11: ;
                2'b10: begin
                    if (VDPMODETEXT2 == 1'b1) begin
                        TXCOLORCODE <= PATTERN[7];
                        PATTERN     <= {PATTERN[6:0], 1'b0};
                    end
                end
                default: ;
            endcase
        end
    end

    //--------------------------------------------------------------------------
    // BLINK TIMING GENERATION FIXED BY CARO AND T.HARA
    //--------------------------------------------------------------------------
    assign W_BLINK_CNT_MAX = (FF_BLINK_STATE == 1'b0) ? REG_R13_BLINK_PERIOD[3:0] :
                                                        REG_R13_BLINK_PERIOD[7:4];
    assign W_BLINK_SYNC = ((DOTCOUNTERX == 0) && (DOTCOUNTERYP == 0) && (DOTSTATE == 2'b00) && (REG_R1_BL_CLKS == 1'b0)) ? 1'b1 :
                          ((DOTCOUNTERX == 0) && (DOTSTATE == 2'b00) && (REG_R1_BL_CLKS == 1'b1)) ? 1'b1 :
                          1'b0;

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_BLINK_CLK_CNT    <= 4'b0;
            FF_BLINK_STATE      <= 1'b0;
            FF_BLINK_PERIOD_CNT <= 4'b0;
        end else begin
            if (W_BLINK_SYNC == 1'b1) begin

                if (FF_BLINK_CLK_CNT == 4'b1001) begin
                    FF_BLINK_CLK_CNT    <= 4'b0;
                    FF_BLINK_PERIOD_CNT <= FF_BLINK_PERIOD_CNT + 1'b1;
                end else begin
                    FF_BLINK_CLK_CNT <= FF_BLINK_CLK_CNT + 1'b1;
                end

                if (FF_BLINK_PERIOD_CNT >= W_BLINK_CNT_MAX) begin
                    FF_BLINK_PERIOD_CNT <= 4'b0;
                    if (REG_R13_BLINK_PERIOD[7:4] == 4'b0000)
                        // WHEN ON PERIOD IS 0, THE PAGE SELECTED SHOULD BE ALWAYS ODD / R#2
                        FF_BLINK_STATE <= 1'b0;
                    else if (REG_R13_BLINK_PERIOD[3:0] == 4'b0000)
                        // WHEN OFF PERIOD IS 0 AND ON NOT, THE PAGE SELECT SHOULD BE ALWAYS THE R#2 EVEN PAIR
                        FF_BLINK_STATE <= 1'b1;
                    else
                        // NEITHER ARE 0, SO JUST KEEP SWITCHING WHEN PERIOD ENDS
                        FF_BLINK_STATE <= ~FF_BLINK_STATE;
                end

            end
        end
    end

endmodule
