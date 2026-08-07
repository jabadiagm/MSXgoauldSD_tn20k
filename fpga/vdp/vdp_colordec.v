//
//  vdp_colordec.v
//   Color decoder: combina capas (texto/grafico/sprite) y genera el RGB final
//   (paleta, GRAPHIC5/7, YJK/YAE, borde/blanking).
//   Traduccion a Verilog de vdp_colordec.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / t.hara / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_colordec.vhd.
//
//-----------------------------------------------------------------------------

`include "vdp_config.vh"

module VDP_COLORDEC (
    input  wire        RESET,
    input  wire        CLK21M,

    input  wire [1:0]  DOTSTATE,

    output wire [7:0]  PPALETTEADDR_OUT,   // V9968: 8 bits (256 entradas con EXT_PALETTE)
    input  wire [7:0]  PALETTEDATARB_OUT,
    input  wire [7:0]  PALETTEDATAG_OUT,

    // V9968 sprite mode3 alpha-blend: 2a lectura de paleta = color de FONDO
    output wire [7:0]  PPALETTEADDR_BG,    // indice del fondo (sin el sprite mode3)
    input  wire [7:0]  PALETTEDATARB_BG,
    input  wire [7:0]  PALETTEDATAG_BG,

    input  wire        VDPMODETEXT1,
    input  wire        VDPMODETEXT1Q,
    input  wire        VDPMODETEXT2,
    input  wire        VDPMODEMULTI,
    input  wire        VDPMODEMULTIQ,
    input  wire        VDPMODEGRAPHIC1,
    input  wire        VDPMODEGRAPHIC2,
    input  wire        VDPMODEGRAPHIC3,
    input  wire        VDPMODEGRAPHIC4,
    input  wire        VDPMODEGRAPHIC5,
    input  wire        VDPMODEGRAPHIC6,
    input  wire        VDPMODEGRAPHIC7,

    input  wire        WINDOW,           // JP: 有効表示領域だけ 1 になる
    input  wire        SPRITECOLOROUT,   // JP: スプライトの画素位置だけ 1 になる
    input  wire [3:0]  COLORCODET12,     // JP: TEXT1, 2 の色
    input  wire [3:0]  COLORCODEG123M,   // JP: GRAPHIC1,2,3,MOSAIC の色
    input  wire [7:0]  COLORCODEG4567,   // JP: GRAPHIC4,5,6,7 の色
    input  wire [3:0]  COLORCODESPRITE,  // JP: スプライトの色
    input  wire [5:0]  P_YJK_R,
    input  wire [5:0]  P_YJK_G,
    input  wire [5:0]  P_YJK_B,
    input  wire        P_YJK_EN,

    output wire [5:0]  PVIDEOR_VDP,      // JP: モニタへ出力する色
    output wire [5:0]  PVIDEOG_VDP,
    output wire [5:0]  PVIDEOB_VDP,
    // REGISTERS
    input  wire        REG_R1_DISP_ON,
    input  wire [7:0]  REG_R7_FRAME_COL,
    input  wire        REG_R8_COL0_ON,
    input  wire        REG_R25_YJK,
    input  wire        EXT_PALETTE,      // V9968: SCREEN8 -> paleta de 256 entradas (ya gateado por modo)
    input  wire        SM3_COLOR_EN,     // V9968 sprite mode3: dot de sprite opaco (ya gateado por modo)
    input  wire [7:0]  SM3_COLOR,        // V9968 sprite mode3: {palette_set, dot} -> paleta 256
    input  wire [1:0]  SM3_TRANSP        // V9968 sprite mode3: transparencia 0/25/50/75%
);

    // D-FLIPFLOP
    reg [5:0] FF_VIDEO_R;
    reg [5:0] FF_VIDEO_G;
    reg [5:0] FF_VIDEO_B;
    reg [7:0] FF_GRP7_COLOR_CODE;
    reg [3:0] FF_PALETTE_ADDR;
    reg [1:0] FF_PALETTE_ADDR_G5;
    reg [5:0] FF_YJK_R;
    reg [5:0] FF_YJK_G;
    reg [5:0] FF_YJK_B;
    reg       FF_YJK_EN;
    reg       FF_SPRITECOLOROUT;
    reg       FF_SM3_SPRITE;
    reg [7:0] FF_SM3_COLOR;
    reg [1:0] FF_SM3_TRANSP;
    // WIRE
    wire      W_EVEN_DOTSTATE;
    reg [7:0] W_GRP7_SPRITE_COLOR;
    wire [3:0] W_FORE_COLOR;
    wire [3:0] W_BACK_COLOR;

    // V9968 EXT_PALETTE: en SCREEN8 (GRAPHIC7) el fondo usa el byte de pixel como indice de 256;
    // los sprites usan su color de 4 bits en las entradas 0-15 (FF_PALETTE_ADDR).
    // Resto de modos: indice de 4 bits (o 2 en GRAPHIC5), extendido con ceros a 8 bits.
    assign PPALETTEADDR_OUT =
        (FF_SM3_SPRITE == 1'b1)                          ? FF_SM3_COLOR :   // mode3: {palette_set,dot} directo a paleta 256
        (VDPMODEGRAPHIC7 == 1'b1 && EXT_PALETTE == 1'b1) ? (FF_SPRITECOLOROUT ? {4'b0000, FF_PALETTE_ADDR} : FF_GRP7_COLOR_CODE) :
        (VDPMODEGRAPHIC5 == 1'b0)                        ? {4'b0000, FF_PALETTE_ADDR} :
                                                           {6'b000000, FF_PALETTE_ADDR_G5};

    // Indice de FONDO (lo que se mostraria SIN el sprite mode3): igual que
    // PPALETTEADDR_OUT pero omitiendo la rama FF_SM3_SPRITE. Alimenta la 2a
    // lectura de paleta para el alpha-blend.
    assign PPALETTEADDR_BG =
        (VDPMODEGRAPHIC7 == 1'b1 && EXT_PALETTE == 1'b1) ? (FF_SPRITECOLOROUT ? {4'b0000, FF_PALETTE_ADDR} : FF_GRP7_COLOR_CODE) :
        (VDPMODEGRAPHIC5 == 1'b0)                        ? {4'b0000, FF_PALETTE_ADDR} :
                                                           {6'b000000, FF_PALETTE_ADDR_G5};

    // El fondo es una lectura de paleta salvo en GRAPHIC7 directo (sin EPAL) o YJK.
    wire W_BG_IS_PALETTE = ~(VDPMODEGRAPHIC7 & ~EXT_PALETTE) & ~FF_YJK_EN;

    // Mezcla alpha por canal de 3 bits: (s*(4-t) + b*t) / 4   [func_sprite_mix V9968]
    function [2:0] F_MIX(input [2:0] s, input [2:0] b, input [1:0] t);
        reg [5:0] acc;
        begin
            acc   = s * (3'd4 - {1'b0, t}) + b * {1'b0, t};
            F_MIX = acc[4:2];
        end
    endfunction

    // sprite (lectura 1) y fondo (lectura 2) en canales de 3 bits
    wire [2:0] W_SPR_R = PALETTEDATARB_OUT[6:4];
    wire [2:0] W_SPR_G = PALETTEDATAG_OUT[2:0];
    wire [2:0] W_SPR_B = PALETTEDATARB_OUT[2:0];
    wire [2:0] W_BG_R  = PALETTEDATARB_BG[6:4];
    wire [2:0] W_BG_G  = PALETTEDATAG_BG[2:0];
    wire [2:0] W_BG_B  = PALETTEDATARB_BG[2:0];

`ifdef SM3_DISABLE_ALPHA
    wire       W_SM3_MIX = 1'b0;
`else
    wire       W_SM3_MIX = FF_SM3_SPRITE & (FF_SM3_TRANSP != 2'b00) & W_BG_IS_PALETTE;
`endif

    assign PVIDEOR_VDP = FF_VIDEO_R;
    assign PVIDEOG_VDP = FF_VIDEO_G;
    assign PVIDEOB_VDP = FF_VIDEO_B;

    assign W_EVEN_DOTSTATE = (DOTSTATE == 2'b00 || DOTSTATE == 2'b11) ? 1'b1 : 1'b0;

    // OUTPUT DATA LATCH
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_VIDEO_R <= 6'b000000;
            FF_VIDEO_G <= 6'b000000;
            FF_VIDEO_B <= 6'b000000;
        end else begin
            if (W_EVEN_DOTSTATE == 1'b1) begin
                if (VDPMODEGRAPHIC7 == 1'b1 && FF_YJK_EN == 1'b1 && FF_SPRITECOLOROUT == 1'b0 && FF_SM3_SPRITE == 1'b0) begin
                    //  YJK MODE
                    FF_VIDEO_R <= FF_YJK_R;
                    FF_VIDEO_G <= FF_YJK_G;
                    FF_VIDEO_B <= FF_YJK_B;
                end else if (W_SM3_MIX == 1'b1) begin
                    //  V9968 sprite mode3 con alpha-blend: mezcla con el fondo (paleta)
                    FF_VIDEO_R <= {F_MIX(W_SPR_R, W_BG_R, FF_SM3_TRANSP), 3'b000};
                    FF_VIDEO_G <= {F_MIX(W_SPR_G, W_BG_G, FF_SM3_TRANSP), 3'b000};
                    FF_VIDEO_B <= {F_MIX(W_SPR_B, W_BG_B, FF_SM3_TRANSP), 3'b000};
                end else if (VDPMODEGRAPHIC7 == 1'b0 || REG_R25_YJK == 1'b1 || EXT_PALETTE == 1'b1 || FF_SM3_SPRITE == 1'b1) begin
                    //  PALETTE COLOR (NOT GRAPHIC7, SPRITE ON YJK MODE, YAE COLOR ON YJK MODE,
                    //  o V9968 EXT_PALETTE en SCREEN8 -> 256 entradas)
                    FF_VIDEO_R <= {PALETTEDATARB_OUT[6:4], 3'b000};
                    FF_VIDEO_G <= {PALETTEDATAG_OUT[2:0],  3'b000};
                    FF_VIDEO_B <= {PALETTEDATARB_OUT[2:0], 3'b000};
                end else begin
                    //  GRAPHIC7
                    FF_VIDEO_R <= {FF_GRP7_COLOR_CODE[4:2], 3'b000};
                    FF_VIDEO_G <= {FF_GRP7_COLOR_CODE[7:5], 3'b000};
                    FF_VIDEO_B <= {FF_GRP7_COLOR_CODE[1:0], FF_GRP7_COLOR_CODE[1], 3'b000};
                end
            end
        end
    end

    // FOR GRAPHIC7
    always @(*) begin
        case (COLORCODESPRITE)
            4'b0000: W_GRP7_SPRITE_COLOR = {3'b000, 3'b000, 2'b00};
            4'b0001: W_GRP7_SPRITE_COLOR = {3'b000, 3'b000, 2'b01};
            4'b0010: W_GRP7_SPRITE_COLOR = {3'b000, 3'b011, 2'b00};
            4'b0011: W_GRP7_SPRITE_COLOR = {3'b000, 3'b011, 2'b01};
            4'b0100: W_GRP7_SPRITE_COLOR = {3'b011, 3'b000, 2'b00};
            4'b0101: W_GRP7_SPRITE_COLOR = {3'b011, 3'b000, 2'b01};
            4'b0110: W_GRP7_SPRITE_COLOR = {3'b011, 3'b011, 2'b00};
            4'b0111: W_GRP7_SPRITE_COLOR = {3'b011, 3'b011, 2'b01};
            4'b1000: W_GRP7_SPRITE_COLOR = {3'b100, 3'b111, 2'b01};
            4'b1001: W_GRP7_SPRITE_COLOR = {3'b000, 3'b000, 2'b11};
            4'b1010: W_GRP7_SPRITE_COLOR = {3'b000, 3'b111, 2'b00};
            4'b1011: W_GRP7_SPRITE_COLOR = {3'b000, 3'b111, 2'b11};
            4'b1100: W_GRP7_SPRITE_COLOR = {3'b111, 3'b000, 2'b00};
            4'b1101: W_GRP7_SPRITE_COLOR = {3'b111, 3'b000, 2'b11};
            4'b1110: W_GRP7_SPRITE_COLOR = {3'b111, 3'b111, 2'b00};
            4'b1111: W_GRP7_SPRITE_COLOR = {3'b111, 3'b111, 2'b11};
            default: W_GRP7_SPRITE_COLOR = 8'b0;
        endcase
    end

    // FOR OTHERS
    assign W_FORE_COLOR = ((VDPMODETEXT1 | VDPMODETEXT1Q | VDPMODETEXT2) == 1'b1) ? COLORCODET12    :
                          (SPRITECOLOROUT == 1'b1)                                ? COLORCODESPRITE :
                          ((VDPMODEGRAPHIC1 | VDPMODEGRAPHIC2 | VDPMODEGRAPHIC3 | VDPMODEMULTI | VDPMODEMULTIQ) == 1'b1) ? COLORCODEG123M :
                          COLORCODEG4567[3:0];
    assign W_BACK_COLOR = REG_R7_FRAME_COL[3:0];

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PALETTE_ADDR <= 4'b0;
        end else begin
            if (W_EVEN_DOTSTATE == 1'b1) begin
                if (WINDOW == 1'b0 || REG_R1_DISP_ON == 1'b0 || (W_FORE_COLOR == 4'b0000 && REG_R8_COL0_ON == 1'b0))
                    FF_PALETTE_ADDR <= W_BACK_COLOR;
                else
                    FF_PALETTE_ADDR <= W_FORE_COLOR;
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PALETTE_ADDR_G5 <= 2'b0;
        end else begin
            if (W_EVEN_DOTSTATE == 1'b1) begin
                if ( WINDOW == 1'b0 || REG_R1_DISP_ON == 1'b0 ||
                     (DOTSTATE[1] == 1'b0 && W_FORE_COLOR[1:0] == 2'b00 && REG_R8_COL0_ON == 1'b0) ||
                     (DOTSTATE[1] == 1'b1 && W_FORE_COLOR[3:2] == 2'b00 && REG_R8_COL0_ON == 1'b0) ) begin
                    if (DOTSTATE[1] == 1'b0)
                        FF_PALETTE_ADDR_G5 <= W_BACK_COLOR[1:0];
                    else
                        FF_PALETTE_ADDR_G5 <= W_BACK_COLOR[3:2];
                end else begin
                    if (DOTSTATE[1] == 1'b0)
                        FF_PALETTE_ADDR_G5 <= W_FORE_COLOR[1:0];
                    else
                        FF_PALETTE_ADDR_G5 <= W_FORE_COLOR[3:2];
                end
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_GRP7_COLOR_CODE <= 8'b0;
        end else begin
            if (W_EVEN_DOTSTATE == 1'b1) begin
                if (SPRITECOLOROUT == 1'b1)
                    FF_GRP7_COLOR_CODE <= W_GRP7_SPRITE_COLOR;
                else
                    FF_GRP7_COLOR_CODE <= COLORCODEG4567;
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_SPRITECOLOROUT <= 1'b0;
            FF_SM3_SPRITE     <= 1'b0;
            FF_SM3_COLOR      <= 8'b0;
            FF_SM3_TRANSP     <= 2'b0;
            FF_YJK_R          <= 6'b0;
            FF_YJK_G          <= 6'b0;
            FF_YJK_B          <= 6'b0;
            FF_YJK_EN         <= 1'b0;
        end else begin
            if (W_EVEN_DOTSTATE == 1'b1) begin
                FF_SPRITECOLOROUT <= SPRITECOLOROUT & WINDOW & REG_R1_DISP_ON;
                FF_SM3_SPRITE     <= SM3_COLOR_EN & WINDOW & REG_R1_DISP_ON;
                FF_SM3_COLOR      <= SM3_COLOR;
                FF_SM3_TRANSP     <= SM3_TRANSP;
                if (WINDOW == 1'b1 && REG_R1_DISP_ON == 1'b1) begin
                    FF_YJK_R  <= P_YJK_R;
                    FF_YJK_G  <= P_YJK_G;
                    FF_YJK_B  <= P_YJK_B;
                    FF_YJK_EN <= P_YJK_EN;
                end else if ((WINDOW == 1'b0 || REG_R1_DISP_ON == 1'b0) && REG_R25_YJK == 1'b1) begin
                    FF_YJK_EN <= 1'b0;
                end else begin
                    FF_YJK_R  <= {REG_R7_FRAME_COL[4:2], 3'b000};
                    FF_YJK_G  <= {REG_R7_FRAME_COL[7:5], 3'b000};
                    FF_YJK_B  <= {REG_R7_FRAME_COL[1:0], REG_R7_FRAME_COL[1], 3'b000};
                    FF_YJK_EN <= 1'b1;
                end
            end
        end
    end

endmodule
