//
//  vdp_register.v
//   VDP register file + CPU port (ports 0..3) + palette RAM + mode decode + status.
//   Traduccion a Verilog de vdp_register.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / t.hara / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_register.vhd.
//
//-----------------------------------------------------------------------------
`include "vdp_config.vh"

module VDP_REGISTER (
    input  wire        RESET,
    input  wire        CLK21M,

    input  wire        REQ,
    output wire        ACK,
    input  wire        WRT,
    input  wire [15:0] ADR,
    output reg  [7:0]  DBI,
    input  wire [7:0]  DBO,

    input  wire [1:0]  DOTSTATE,

    input  wire        VDPCMDTRCLRACK,
    input  wire        VDPCMDREGWRACK,
    input  wire        HSYNC,

    input  wire        VDPS0SPCOLLISIONINCIDENCE,
    input  wire        VDPS0SPOVERMAPPED,
    input  wire [4:0]  VDPS0SPOVERMAPPEDNUM,
    output wire        SPVDPS0RESETREQ,
    input  wire        SPVDPS0RESETACK,
    output reg         SPVDPS5RESETREQ,
    input  wire        SPVDPS5RESETACK,

    input  wire        VDPCMDTR,
    input  wire        VD,
    input  wire        HD,
    input  wire        VDPCMDBD,
    input  wire        FIELD,
    input  wire        VDPCMDCE,
    input  wire [8:0]  VDPS3S4SPCOLLISIONX,
    input  wire [8:0]  VDPS5S6SPCOLLISIONY,
    input  wire [7:0]  VDPCMDCLR,
    input  wire [10:0] VDPCMDSXTMP,

    output reg  [7:0]  VDPVRAMACCESSDATA,
    output reg  [17:0] VDPVRAMACCESSADDRTMP,   // 18 bits: A17 (R#14 bit3) para acceso CPU a 256K
    output reg         VDPVRAMADDRSETREQ,
    input  wire        VDPVRAMADDRSETACK,
    output reg         VDPVRAMWRREQ,
    input  wire        VDPVRAMWRACK,
    input  wire [7:0]  VDPVRAMRDDATA,
    output reg         VDPVRAMRDREQ,
    input  wire        VDPVRAMRDACK,

    output reg  [4:0]  VDPCMDREGNUM,
    output reg  [7:0]  VDPCMDREGDATA,
    output reg         VDPCMDREGWRREQ,
    output reg         VDPCMDTRCLRREQ,

    input  wire [7:0]  PALETTEADDR_OUT,     // V9968: 8 bits (256 entradas); en modos clasicos solo se usan [3:0]
    output wire [7:0]  PALETTEDATARB_OUT,
    output wire [7:0]  PALETTEDATAG_OUT,

    // V9968 sprite mode3 alpha-blend: 2a lectura (indice de fondo)
    input  wire [7:0]  PALETTEADDR_BG,
    output wire [7:0]  PALETTEDATARB_BG,
    output wire [7:0]  PALETTEDATAG_BG,

    // INTERRUPT
    output reg         CLR_VSYNC_INT,
    output reg         CLR_HSYNC_INT,
    input  wire        REQ_VSYNC_INT_N,
    input  wire        REQ_HSYNC_INT_N,
    // V9968: command-end interrupt (puerto 0x9C)
    output reg         CLR_CMD_INT,
    input  wire        REQ_CMD_INT_N,

    // REGISTER VALUE
    output reg         REG_R0_HSYNC_INT_EN,
    output reg         REG_R1_SP_SIZE,
    output reg         REG_R1_SP_ZOOM,
    output reg         REG_R1_BL_CLKS,
    output reg         REG_R1_VSYNC_INT_EN,
    output reg         REG_R1_DISP_ON,
    output reg  [7:0]  REG_R2_PT_NAM_ADDR,   // 8 bits: bit7 = A17 display (VRAM 256K)
    output reg  [5:0]  REG_R4_PT_GEN_ADDR,
    output reg  [10:0] REG_R10R3_COL_ADDR,
    output reg  [10:0] REG_R11R5_SP_ATR_ADDR,   // bit10 = A17 (mode3/256K; R#11 bit2)
    output reg  [6:0]  REG_R6_SP_GEN_ADDR,      // bit6  = A17 (mode3/256K; R#6 bit6)
    output reg  [7:0]  REG_R7_FRAME_COL,
    output reg         REG_R8_SP_OFF,
    output reg         REG_R8_COL0_ON,
    output reg         REG_R9_PAL_MODE,
    output reg         REG_R9_INTERLACE_MODE,
    output reg         REG_R9_Y_DOTS,
    output reg  [7:0]  REG_R12_BLINK_MODE,
    output reg  [7:0]  REG_R13_BLINK_PERIOD,
    output wire [7:0]  REG_R18_ADJ,
    output reg  [7:0]  REG_R19_HSYNC_INT_LINE,
    output reg  [7:0]  REG_R23_VSTART_LINE,
    output reg         REG_R25_CMD,
    output reg         REG_R25_YAE,
    output reg         REG_R25_YJK,
    output reg         REG_R25_MSK,
    output reg         REG_R25_SP2,
    output reg         REG_R25_SHUFFLE,     // R#25 bit7 (V9968): sprite priority shuffle
    output reg  [8:3]  REG_R26_H_SCROLL,
    output reg  [2:0]  REG_R27_H_SCROLL,

    // V9968 EXTENSIONS
    output reg         REG_R20_HS,          // R#20 bit0: command high speed (-> turbo)
    output reg         REG_R20_SVNS,        // R#20 bit1: sprite nonR23 (sprites sin offset R#23)
    output reg         REG_R20_ILNS,        // R#20 bit2: interrupt line nonR23 (IRQ linea sin R#23)
    output reg         REG_R20_SM3,         // R#20 bit3: sprite mode3 (render paralelo dot-by-dot)
    output reg         REG_R20_EPAL,        // R#20 bit4: extended palette (SCREEN8 -> 256 entradas)
    output reg         REG_R20_CEIE,        // R#20 bit6: command-end interrupt enable
    output reg         REG_R20_S16,         // R#20 bit7: sprite16 (16 sprites por linea)
    output reg         REG_R21_V9958_MODE,  // R#21 bit0: 1=modo V9958 (reset), 0=modo V9968

    // MODE
    output wire        VDPMODETEXT1,
    output wire        VDPMODETEXT1Q,
    output wire        VDPMODETEXT2,
    output wire        VDPMODEMULTI,
    output wire        VDPMODEMULTIQ,
    output wire        VDPMODEGRAPHIC1,
    output wire        VDPMODEGRAPHIC2,
    output wire        VDPMODEGRAPHIC3,
    output wire        VDPMODEGRAPHIC4,
    output wire        VDPMODEGRAPHIC5,
    output wire        VDPMODEGRAPHIC6,
    output wire        VDPMODEGRAPHIC7,
    output wire        VDPMODEISHIGHRES,
    output wire        SPMODE2,
    output wire        VDPMODEISVRAMINTERLEAVE,

    // SWITCHED I/O SIGNALS
    input  wire        FORCED_V_MODE,
    input  wire [4:0]  VDP_ID
);

    reg        FF_ACK;

    reg        VDPP1IS1STBYTE;
    reg [1:0]  VDPP2PHASE;    // fase de escritura de paleta: 0=R/RB, 1=G, 2=B (EPAL 3 fases; clasico 2)
    reg [7:0]  VDPP1DATA;
    reg [5:0]  VDPREGPTR;
    reg        VDPREGWRPULSE;
    reg [3:0]  VDPR15STATUSREGNUM;

    reg [7:0]  VDPR16PALNUM;   // V9968: 8 bits para 256 entradas de paleta
    reg [5:0]  VDPR17REGNUM;
    reg        VDPR17INCREGNUM;

    wire [7:0] PALETTEADDR;
    wire       PALETTEWE;
    reg [7:0]  PALETTEDATARB_IN;
    reg [7:0]  PALETTEDATAG_IN;
    reg [7:0]  PALETTEWRNUM;   // V9968: 8 bits
    reg        FF_PALETTE_WR_REQ;
    reg        FF_PALETTE_WR_ACK;
    reg        FF_PALETTE_IN;
    reg [7:0]  FF_R2_PT_NAM_ADDR;   // 8 bits (bit7 = A17)
    reg        FF_R9_2PAGE_MODE;
    reg [1:0]  REG_R1_DISP_MODE;
    reg        FF_R1_DISP_ON;
    reg [1:0]  FF_R1_DISP_MODE;
    reg        FF_R25_SP2;
    reg [8:3]  FF_R26_H_SCROLL;
    reg [3:0]  REG_R18_VERT;
    reg [3:0]  REG_R18_HORZ;
    reg [3:1]  REG_R0_DISP_MODE;
    reg [3:1]  FF_R0_DISP_MODE;
    reg        FF_SPVDPS0RESETREQ;

    wire       W_EVEN_DOTSTATE;
    wire       W_IS_BITMAP_MODE;
    wire [4:0] W_DISPMODE;

    assign ACK             = FF_ACK;
    assign SPVDPS0RESETREQ = FF_SPVDPS0RESETREQ;

    assign W_DISPMODE = {REG_R0_DISP_MODE, REG_R1_DISP_MODE[0], REG_R1_DISP_MODE[1]};

    assign VDPMODEGRAPHIC1 = (W_DISPMODE == 5'b00000) ? 1'b1 : 1'b0;
    assign VDPMODETEXT1    = (W_DISPMODE == 5'b00001) ? 1'b1 : 1'b0;
    assign VDPMODEMULTI    = (W_DISPMODE == 5'b00010) ? 1'b1 : 1'b0;
    assign VDPMODEGRAPHIC2 = (W_DISPMODE == 5'b00100) ? 1'b1 : 1'b0;
    assign VDPMODETEXT1Q   = (W_DISPMODE == 5'b00101) ? 1'b1 : 1'b0;
    assign VDPMODEMULTIQ   = (W_DISPMODE == 5'b00110) ? 1'b1 : 1'b0;
    assign VDPMODEGRAPHIC3 = (W_DISPMODE == 5'b01000) ? 1'b1 : 1'b0;
    assign VDPMODETEXT2    = (W_DISPMODE == 5'b01001) ? 1'b1 : 1'b0;
    assign VDPMODEGRAPHIC4 = (W_DISPMODE == 5'b01100) ? 1'b1 : 1'b0;
    assign VDPMODEGRAPHIC5 = (W_DISPMODE == 5'b10000) ? 1'b1 : 1'b0;
    assign VDPMODEGRAPHIC6 = (W_DISPMODE == 5'b10100) ? 1'b1 : 1'b0;
    assign VDPMODEGRAPHIC7 = (W_DISPMODE == 5'b11100) ? 1'b1 : 1'b0;

    assign VDPMODEISHIGHRES = (REG_R0_DISP_MODE[3:2] == 2'b10 && REG_R1_DISP_MODE == 2'b00) ? 1'b1 : 1'b0;
    assign SPMODE2 = (REG_R1_DISP_MODE == 2'b00 && (REG_R0_DISP_MODE[3] | REG_R0_DISP_MODE[2]) == 1'b1) ? 1'b1 : 1'b0;
    assign VDPMODEISVRAMINTERLEAVE = ((REG_R0_DISP_MODE[3] & REG_R0_DISP_MODE[1]) == 1'b1) ? 1'b1 : 1'b0;

    //-------------------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            FF_ACK <= 1'b0;
        else
            FF_ACK <= REQ;
    end

    //-------------------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            REG_R1_DISP_ON   <= 1'b0;
            REG_R0_DISP_MODE <= 3'b000;
            REG_R1_DISP_MODE <= 2'b00;
            REG_R25_SP2      <= 1'b0;
            REG_R26_H_SCROLL <= 6'b0;
        end else begin
            if (HSYNC == 1'b1) begin
                REG_R1_DISP_ON   <= FF_R1_DISP_ON;
                REG_R0_DISP_MODE <= FF_R0_DISP_MODE;
                REG_R1_DISP_MODE <= FF_R1_DISP_MODE;
                if (VDP_ID != 5'b00000) begin
                    REG_R25_SP2      <= FF_R25_SP2;
                    REG_R26_H_SCROLL <= FF_R26_H_SCROLL;
                end
            end
        end
    end

    //-------------------------------------------------------------------------------------
    assign W_IS_BITMAP_MODE = (REG_R0_DISP_MODE[3] == 1'b1 || REG_R0_DISP_MODE == 3'b011) ? 1'b1 : 1'b0;

    always @(posedge CLK21M) begin
        if (W_IS_BITMAP_MODE == 1'b1 && FF_R9_2PAGE_MODE == 1'b1)
            REG_R2_PT_NAM_ADDR <= (FF_R2_PT_NAM_ADDR & 8'b11011111) | {2'b00, FIELD, 5'b00000};
        else
            REG_R2_PT_NAM_ADDR <= FF_R2_PT_NAM_ADDR;
    end

    //-----------------------------------------------------------------------
    // PALETTE REGISTER
    //-----------------------------------------------------------------------
    // V9968: extended palette efectivo (solo en modo V9968)
    wire W_EXT_PAL = REG_R20_EPAL & ~REG_R21_V9958_MODE;

    assign PALETTEADDR = (FF_PALETTE_IN == 1'b1) ? PALETTEWRNUM : PALETTEADDR_OUT;
    assign PALETTEWE   = (FF_PALETTE_IN == 1'b1) ? 1'b1 : 1'b0;
    assign W_EVEN_DOTSTATE = (DOTSTATE == 2'b00 || DOTSTATE == 2'b11) ? 1'b1 : 1'b0;

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PALETTE_IN <= 1'b0;
        end else begin
            if (W_EVEN_DOTSTATE == 1'b1)
                FF_PALETTE_IN <= 1'b0;
            else begin
                if (FF_PALETTE_WR_REQ != FF_PALETTE_WR_ACK)
                    FF_PALETTE_IN <= 1'b1;
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_PALETTE_WR_ACK <= 1'b0;
        end else begin
            if (W_EVEN_DOTSTATE == 1'b0) begin
                if (FF_PALETTE_WR_REQ != FF_PALETTE_WR_ACK)
                    FF_PALETTE_WR_ACK <= ~FF_PALETTE_WR_ACK;
            end
        end
    end

    palette_rb U_PALETTEMEMRB (
        .adr (PALETTEADDR),
        .clk (CLK21M),
        .we  (PALETTEWE),
        .dbo (PALETTEDATARB_IN),
        .dbi (PALETTEDATARB_OUT)
    );

    palette_g U_PALETTEMEMG (
        .adr (PALETTEADDR),
        .clk (CLK21M),
        .we  (PALETTEWE),
        .dbo (PALETTEDATAG_IN),
        .dbi (PALETTEDATAG_OUT)
    );

    // 2a copia de la paleta para el alpha-blend mode3: escrituras identicas
    // (mismo adr/we/datos al escribir), lectura por el indice de FONDO.
    // Solo V9968: sin el define, el alpha-blend no existe -> se ahorran 2 RAMs de paleta.
`ifdef ENABLE_V9968
    wire [7:0] PALETTEADDR_BG_MUX = (FF_PALETTE_IN == 1'b1) ? PALETTEWRNUM : PALETTEADDR_BG;

    palette_rb U_PALETTEMEMRB_BG (
        .adr (PALETTEADDR_BG_MUX),
        .clk (CLK21M),
        .we  (PALETTEWE),
        .dbo (PALETTEDATARB_IN),
        .dbi (PALETTEDATARB_BG)
    );

    palette_g U_PALETTEMEMG_BG (
        .adr (PALETTEADDR_BG_MUX),
        .clk (CLK21M),
        .we  (PALETTEWE),
        .dbo (PALETTEDATAG_IN),
        .dbi (PALETTEDATAG_BG)
    );
`else
    assign PALETTEDATARB_BG = 8'b0;
    assign PALETTEDATAG_BG  = 8'b0;
`endif

    //-----------------------------------------------------------------------
    // PROCESS OF CPU READ REQUEST
    //-----------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            DBI <= 8'b0;
        end else begin
            if (REQ == 1'b1 && WRT == 1'b0) begin
                // READ REQUEST
                case (ADR[2:0])
                    3'b000: // PORT#0 (0x98): READ VRAM
                        DBI <= VDPVRAMRDDATA;
                    3'b001: begin // PORT#1 (0x99): READ STATUS REGISTER
                        case (VDPR15STATUSREGNUM)
                            4'b0000: DBI <= {~REQ_VSYNC_INT_N, VDPS0SPOVERMAPPED, VDPS0SPCOLLISIONINCIDENCE, VDPS0SPOVERMAPPEDNUM}; // S#0
                            4'b0001: DBI <= {2'b00, (REG_R21_V9958_MODE ? 5'b00010 : VDP_ID), ~REQ_HSYNC_INT_N}; // S#1 (V9968: ID=2 en modo V9958, =3 en modo V9968)
                            4'b0010: DBI <= {VDPCMDTR, VD, HD, VDPCMDBD, 2'b11, FIELD, VDPCMDCE};       // S#2
                            4'b0011: DBI <= VDPS3S4SPCOLLISIONX[7:0];                                   // S#3
                            4'b0100: DBI <= {7'b0000000, VDPS3S4SPCOLLISIONX[8]};                       // S#4
                            4'b0101: DBI <= VDPS5S6SPCOLLISIONY[7:0];                                   // S#5
                            4'b0110: DBI <= {7'b0000000, VDPS5S6SPCOLLISIONY[8]};                       // S#6
                            4'b0111: DBI <= VDPCMDCLR;                                                  // S#7
                            4'b1000: DBI <= VDPCMDSXTMP[7:0];                                           // S#8
                            4'b1001: DBI <= {7'b1111111, VDPCMDSXTMP[8]};                               // S#9
                            default: DBI <= 8'b0;
                        endcase
                    end
                    3'b100: // PORT#4 (0x9C): V9968 INTERRUPT FLAGS {cmd_end, line, frame}
                        DBI <= (REG_R21_V9958_MODE == 1'b0) ?
                               {5'd0, ~REQ_CMD_INT_N, ~REQ_HSYNC_INT_N, ~REQ_VSYNC_INT_N} : 8'b11111111;
                    default: // PORT#2, #3 (0x9A/0x9B), 0x9D-0x9F: NOT SUPPORTED IN READ MODE
                        DBI <= 8'b11111111;
                endcase
            end
        end
    end

    //-----------------------------------------------------------------------
    // HSYNC INTERRUPT RESET CONTROL
    //-----------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            CLR_HSYNC_INT <= 1'b0;
        end else begin
            if (REQ == 1'b1 && WRT == 1'b0) begin
                if (ADR[2:0] == 3'b001 && VDPR15STATUSREGNUM == 4'b0001)
                    CLR_HSYNC_INT <= 1'b1;   // CLEAR HSYNC INT BY READ S#1
                else
                    CLR_HSYNC_INT <= 1'b0;
            end else if (REQ == 1'b1 && WRT == 1'b1 && ADR[2:0] == 3'b100 && DBO[1] == 1'b1) begin
                CLR_HSYNC_INT <= 1'b1;       // CLEAR LINE INT BY WRITE PORT 0x9C bit1 (V9968)
            end else if (VDPREGWRPULSE == 1'b1) begin
                if (VDPREGPTR == 6'b010011 || (VDPREGPTR == 6'b000000 && VDPP1DATA[4] == 1'b1))
                    CLR_HSYNC_INT <= 1'b1;   // CLEAR HSYNC INT BY WRITE R19, R0
                else
                    CLR_HSYNC_INT <= 1'b0;
            end else begin
                CLR_HSYNC_INT <= 1'b0;
            end
        end
    end

    //-----------------------------------------------------------------------
    // VSYNC INTERRUPT RESET CONTROL
    //-----------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            CLR_VSYNC_INT <= 1'b0;
        end else begin
            if (REQ == 1'b1 && WRT == 1'b0) begin
                if (ADR[2:0] == 3'b001 && VDPR15STATUSREGNUM == 4'b0000)
                    CLR_VSYNC_INT <= 1'b1;   // CLEAR VSYNC INT BY READ S#0
                else
                    CLR_VSYNC_INT <= 1'b0;
            end else if (REQ == 1'b1 && WRT == 1'b1 && ADR[2:0] == 3'b100 && DBO[0] == 1'b1) begin
                CLR_VSYNC_INT <= 1'b1;       // CLEAR FRAME INT BY WRITE PORT 0x9C bit0 (V9968)
            end else begin
                CLR_VSYNC_INT <= 1'b0;
            end
        end
    end

    //-----------------------------------------------------------------------
    // COMMAND-END INTERRUPT RESET CONTROL (V9968, puerto 0x9C bit2)
    //-----------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            CLR_CMD_INT <= 1'b0;
        end else begin
            if (REQ == 1'b1 && WRT == 1'b1 && ADR[2:0] == 3'b100 && DBO[2] == 1'b1)
                CLR_CMD_INT <= 1'b1;         // CLEAR COMMAND-END INT BY WRITE PORT 0x9C bit2
            else
                CLR_CMD_INT <= 1'b0;
        end
    end

    assign REG_R18_ADJ = {REG_R18_VERT, REG_R18_HORZ};

    //-----------------------------------------------------------------------
    // PROCESS OF CPU WRITE REQUEST
    //-----------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            VDPP1DATA               <= 8'b0;
            VDPP1IS1STBYTE          <= 1'b1;
            VDPP2PHASE              <= 2'd0;
            VDPREGWRPULSE           <= 1'b0;
            VDPREGPTR               <= 6'b0;
            VDPVRAMWRREQ            <= 1'b0;
            VDPVRAMRDREQ            <= 1'b0;
            VDPVRAMADDRSETREQ       <= 1'b0;
            VDPVRAMACCESSADDRTMP    <= 18'b0;
            VDPVRAMACCESSDATA       <= 8'b0;
            FF_R0_DISP_MODE         <= 3'b0;

            REG_R0_HSYNC_INT_EN     <= 1'b0;
            FF_R1_DISP_MODE         <= 2'b0;
            REG_R1_SP_SIZE          <= 1'b0;
            REG_R1_SP_ZOOM          <= 1'b0;
            REG_R1_BL_CLKS          <= 1'b0;
            REG_R1_VSYNC_INT_EN     <= 1'b0;
            FF_R1_DISP_ON           <= 1'b0;
            FF_R2_PT_NAM_ADDR       <= 8'b0;
            REG_R12_BLINK_MODE      <= 8'b0;
            REG_R13_BLINK_PERIOD    <= 8'b0;
            REG_R7_FRAME_COL        <= 8'b0;
            REG_R8_SP_OFF           <= 1'b0;
            REG_R8_COL0_ON          <= 1'b0;
            REG_R9_PAL_MODE         <= FORCED_V_MODE;
            FF_R9_2PAGE_MODE        <= 1'b0;
            REG_R9_INTERLACE_MODE   <= 1'b0;
            REG_R9_Y_DOTS           <= 1'b0;
            VDPR15STATUSREGNUM      <= 4'b0;
            VDPR16PALNUM            <= 8'b0;
            VDPR17REGNUM            <= 6'b0;
            VDPR17INCREGNUM         <= 1'b0;
            REG_R18_VERT            <= 4'b0;
            REG_R18_HORZ            <= 4'b0;
            REG_R19_HSYNC_INT_LINE  <= 8'b0;
            REG_R23_VSTART_LINE     <= 8'b0;
            REG_R25_CMD             <= 1'b0;
            REG_R25_YAE             <= 1'b0;
            REG_R25_YJK             <= 1'b0;
            REG_R25_MSK             <= 1'b0;
            FF_R25_SP2              <= 1'b0;
            REG_R25_SHUFFLE         <= 1'b0;
            FF_R26_H_SCROLL         <= 6'b0;
            REG_R27_H_SCROLL        <= 3'b0;
            REG_R20_HS              <= 1'b0;
            REG_R20_SVNS            <= 1'b0;
            REG_R20_ILNS            <= 1'b0;
            REG_R20_SM3             <= 1'b0;
            REG_R20_EPAL            <= 1'b0;
            REG_R20_CEIE            <= 1'b0;
            REG_R20_S16             <= 1'b0;
            REG_R21_V9958_MODE      <= 1'b1;   // arranca en modo V9958
            VDPCMDREGNUM            <= 5'b0;
            VDPCMDREGDATA           <= 8'b0;
            VDPCMDREGWRREQ          <= 1'b0;
            VDPCMDTRCLRREQ          <= 1'b0;
            SPVDPS5RESETREQ         <= 1'b0;
            FF_SPVDPS0RESETREQ      <= 1'b0;

            // PALETTE
            PALETTEDATARB_IN        <= 8'b0;
            PALETTEDATAG_IN         <= 8'b0;
            FF_PALETTE_WR_REQ       <= 1'b0;
            PALETTEWRNUM            <= 8'b0;
        end else begin
            if (REQ == 1'b1 && WRT == 1'b0) begin
                // READ REQUEST
                case (ADR[2:0])
                    3'b000: // PORT#0 (0x98): READ VRAM
                        VDPVRAMRDREQ <= ~VDPVRAMRDACK;
                    3'b001: begin // PORT#1 (0x99): READ STATUS REGISTER
                        VDPP1IS1STBYTE <= 1'b1;
                        case (VDPR15STATUSREGNUM)
                            4'b0000: FF_SPVDPS0RESETREQ <= ~SPVDPS0RESETACK; // S#0
                            4'b0001: ;                                        // S#1
                            4'b0101: SPVDPS5RESETREQ <= ~SPVDPS5RESETACK;     // S#5
                            4'b0111: VDPCMDTRCLRREQ <= ~VDPCMDTRCLRACK;       // S#7
                            default: ;
                        endcase
                    end
                    default: ; // PORT#2/3 (0x9A/0x9B), 0x9C-0x9F: SIN ACCION EN LECTURA
                endcase
            end else if (REQ == 1'b1 && WRT == 1'b1) begin
                // WRITE REQUEST
                case (ADR[2:0])
                    3'b000: begin // PORT#0 (0x98): WRITE VRAM
                        VDPVRAMACCESSDATA <= DBO;
                        VDPVRAMWRREQ <= ~VDPVRAMWRACK;
                    end
                    3'b001: begin // PORT#1 (0x99): REGISTER WRITE OR VRAM ADDR SETUP
                        if (VDPP1IS1STBYTE == 1'b1) begin
                            VDPP1IS1STBYTE <= 1'b0;
                            VDPP1DATA      <= DBO;
                        end else begin
                            VDPP1IS1STBYTE <= 1'b1;
                            case (DBO[7:6])
                                2'b01: begin // SET VRAM ACCESS ADDRESS (WRITE)
                                    VDPVRAMACCESSADDRTMP[7:0]  <= VDPP1DATA[7:0];
                                    VDPVRAMACCESSADDRTMP[13:8] <= DBO[5:0];
                                    VDPVRAMADDRSETREQ <= ~VDPVRAMADDRSETACK;
                                end
                                2'b00: begin // SET VRAM ACCESS ADDRESS (READ)
                                    VDPVRAMACCESSADDRTMP[7:0]  <= VDPP1DATA[7:0];
                                    VDPVRAMACCESSADDRTMP[13:8] <= DBO[5:0];
                                    VDPVRAMADDRSETREQ <= ~VDPVRAMADDRSETACK;
                                    VDPVRAMRDREQ <= ~VDPVRAMRDACK;
                                end
                                2'b10: begin // DIRECT REGISTER SELECTION
                                    VDPREGPTR <= DBO[5:0];
                                    VDPREGWRPULSE <= 1'b1;
                                end
                                2'b11: begin // DIRECT REGISTER SELECTION ??
                                    VDPREGPTR <= DBO[5:0];
                                    VDPREGWRPULSE <= 1'b1;
                                end
                                default: ;
                            endcase
                        end
                    end
                    3'b010: begin // PORT#2: PALETTE WRITE
                        if (W_EXT_PAL) begin
                            // V9968: formato extendido = 3 bytes/entrada (R,G,B), 5 bits/canal.
                            // Opcion A: truncamos a los 3 bits altos y los empaquetamos en el
                            // formato V9958 {0,R,R,R,0,B,B,B}/{0,0,0,0,0,G,G,G} (colordec lee [6:4]/[2:0]).
                            case (VDPP2PHASE)
                            2'd0: begin // R
                                PALETTEDATARB_IN[6:4] <= DBO[4:2];
                                VDPP2PHASE <= 2'd1;
                            end
                            2'd1: begin // G
                                PALETTEDATAG_IN[2:0] <= DBO[4:2];
                                VDPP2PHASE <= 2'd2;
                            end
                            default: begin // B -> completa la entrada y la escribe
                                PALETTEDATARB_IN[2:0] <= DBO[4:2];
                                PALETTEWRNUM <= VDPR16PALNUM;
                                FF_PALETTE_WR_REQ <= ~FF_PALETTE_WR_ACK;
                                VDPP2PHASE <= 2'd0;
                                VDPR16PALNUM <= VDPR16PALNUM + 1'b1;   // EPAL: 8 bits (wrap 256)
                            end
                            endcase
                        end else begin
                            // Formato clasico V9958: 2 bytes/entrada.
                            if (VDPP2PHASE == 2'd0) begin
                                PALETTEDATARB_IN <= DBO;
                                VDPP2PHASE <= 2'd1;
                            end else begin
                                // La paleta se reescribe de golpe cuando RGB estan listos
                                PALETTEDATAG_IN <= DBO;
                                PALETTEWRNUM <= VDPR16PALNUM;
                                FF_PALETTE_WR_REQ <= ~FF_PALETTE_WR_ACK;
                                VDPP2PHASE <= 2'd0;
                                VDPR16PALNUM <= {4'b0000, (VDPR16PALNUM[3:0] + 1'b1)};
                            end
                        end
                    end
                    3'b011: begin // PORT#3: INDIRECT REGISTER WRITE
                        if (VDPR17REGNUM != 6'b010001)
                            // REGISTER 17 CAN NOT BE MODIFIED
                            VDPREGWRPULSE <= 1'b1;
                        VDPP1DATA <= DBO;
                        VDPREGPTR <= VDPR17REGNUM;
                        if (VDPR17INCREGNUM == 1'b1)
                            VDPR17REGNUM <= VDPR17REGNUM + 1'b1;
                    end
                    default: ;
                endcase
            end else if (VDPREGWRPULSE == 1'b1) begin
                // WRITE TO REGISTER (IF PREVIOUSLY REQUESTED)
                VDPREGWRPULSE <= 1'b0;
                if (VDPREGPTR[5] == 1'b0) begin
                    // NOT A COMMAND ENGINE REGISTER
                    case (VDPREGPTR[4:0])
                        5'b00000: begin // #00
                            FF_R0_DISP_MODE <= VDPP1DATA[3:1];
                            REG_R0_HSYNC_INT_EN <= VDPP1DATA[4];
                        end
                        5'b00001: begin // #01
                            REG_R1_SP_ZOOM      <= VDPP1DATA[0];
                            REG_R1_SP_SIZE      <= VDPP1DATA[1];
                            REG_R1_BL_CLKS      <= VDPP1DATA[2];
                            FF_R1_DISP_MODE     <= VDPP1DATA[4:3];
                            REG_R1_VSYNC_INT_EN <= VDPP1DATA[5];
                            FF_R1_DISP_ON       <= VDPP1DATA[6];
                        end
                        5'b00010: FF_R2_PT_NAM_ADDR <= VDPP1DATA[7:0];              // #02 (bit7 = A17, 256K)
                        5'b00011: REG_R10R3_COL_ADDR[7:0] <= VDPP1DATA[7:0];       // #03
                        5'b00100: REG_R4_PT_GEN_ADDR <= VDPP1DATA[5:0];            // #04
                        5'b00101: REG_R11R5_SP_ATR_ADDR[7:0] <= VDPP1DATA;         // #05
                        5'b00110: REG_R6_SP_GEN_ADDR <= VDPP1DATA[6:0];            // #06 (bit6 = A17, mode3)
                        5'b00111: REG_R7_FRAME_COL <= VDPP1DATA[7:0];             // #07
                        5'b01000: begin // #08
                            REG_R8_SP_OFF  <= VDPP1DATA[1];
                            REG_R8_COL0_ON <= VDPP1DATA[5];
                        end
                        5'b01001: begin // #09
                            REG_R9_PAL_MODE       <= VDPP1DATA[1];
                            FF_R9_2PAGE_MODE      <= VDPP1DATA[2];
                            REG_R9_INTERLACE_MODE <= VDPP1DATA[3];
                            REG_R9_Y_DOTS         <= VDPP1DATA[7];
                        end
                        5'b01010: REG_R10R3_COL_ADDR[10:8] <= VDPP1DATA[2:0];      // #10
                        5'b01011: REG_R11R5_SP_ATR_ADDR[10:8] <= VDPP1DATA[2:0];   // #11 (bit2 = A17, mode3)
                        5'b01100: REG_R12_BLINK_MODE <= VDPP1DATA;                 // #12
                        5'b01101: REG_R13_BLINK_PERIOD <= VDPP1DATA;               // #13
                        5'b01110: begin // #14
                            VDPVRAMACCESSADDRTMP[17:14] <= VDPP1DATA[3:0];   // #14 (bit3 = A17, 256K)
                            VDPVRAMADDRSETREQ <= ~VDPVRAMADDRSETACK;
                        end
                        5'b01111: VDPR15STATUSREGNUM <= VDPP1DATA[3:0];            // #15
                        5'b10000: begin // #16
                            // EPAL: R#16 de 8 bits (256 entradas). Clasico: solo 4 bits (compat V9958).
                            VDPR16PALNUM <= W_EXT_PAL ? VDPP1DATA[7:0] : {4'b0000, VDPP1DATA[3:0]};
                            VDPP2PHASE <= 2'd0;
                        end
                        5'b10001: begin // #17
                            VDPR17REGNUM <= VDPP1DATA[5:0];
                            VDPR17INCREGNUM <= ~VDPP1DATA[7];
                        end
                        5'b10010: begin // #18
                            REG_R18_VERT <= VDPP1DATA[7:4];
                            REG_R18_HORZ <= VDPP1DATA[3:0];
                        end
                        5'b10011: REG_R19_HSYNC_INT_LINE <= VDPP1DATA;             // #19
`ifdef ENABLE_V9968
                        5'b10100: begin // #20 (V9968): high speed / nonR23 / ext palette / command-end int enable
                            REG_R20_HS   <= VDPP1DATA[0];
                            REG_R20_SVNS <= VDPP1DATA[1];
                            REG_R20_ILNS <= VDPP1DATA[2];
                            REG_R20_SM3  <= VDPP1DATA[3];
                            REG_R20_EPAL <= VDPP1DATA[4];
                            REG_R20_CEIE <= VDPP1DATA[6];
                            REG_R20_S16  <= VDPP1DATA[7];
                        end
                        5'b10101: REG_R21_V9958_MODE <= VDPP1DATA[0];             // #21 (V9968): 0=modo V9968
`endif
                        // Sin ENABLE_V9968: R#20/R#21 no se escriben. REG_R21_V9958_MODE queda
                        // fijo a su reset (1'b1 = modo V9958) y REG_R20_* a 0 -> W_V9968_MODE
                        // se pliega a 0 en vdp.v y todo el datapath V9968 se poda.
                        5'b10111: REG_R23_VSTART_LINE <= VDPP1DATA;               // #23
                        5'b11001: begin // #25
                            if (VDP_ID != 5'b00000) begin
                                REG_R25_CMD <= VDPP1DATA[6];
                                REG_R25_YAE <= VDPP1DATA[4];
                                REG_R25_YJK <= VDPP1DATA[3];
                                REG_R25_MSK <= VDPP1DATA[1];
                                FF_R25_SP2  <= VDPP1DATA[0];
                                REG_R25_SHUFFLE <= VDPP1DATA[7];
                            end
                        end
                        5'b11010: begin // #26
                            if (VDP_ID != 5'b00000)
                                FF_R26_H_SCROLL <= VDPP1DATA[5:0];
                        end
                        5'b11011: begin // #27
                            if (VDP_ID != 5'b00000)
                                REG_R27_H_SCROLL <= VDPP1DATA[2:0];
                        end
                        default: ;
                    endcase
                end else begin
                    // REGISTERS FOR VDP COMMAND (R#32-63; V9968 usa hasta R#50 para reg_vx/vy)
                    VDPCMDREGNUM <= VDPREGPTR[4:0];
                    VDPCMDREGDATA <= VDPP1DATA;
                    VDPCMDREGWRREQ <= ~VDPCMDREGWRACK;
                end
            end
        end
    end

endmodule
