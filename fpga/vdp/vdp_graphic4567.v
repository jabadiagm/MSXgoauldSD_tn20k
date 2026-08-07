//
//  vdp_graphic4567.v
//   GRAPHIC mode 4,5,6,7 main processing (SCREEN 5,6,7,8) + YJK/YAE color convert.
//   Traduccion a Verilog de vdp_graphic4567.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / t.hara / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_graphic4567.vhd.
//
//  Nota: la conversion YJK usa extension de signo MANUAL (concatenaciones) + suma
//  unsigned; se replican las concatenaciones exactas para conservar los bit-patterns.
//-----------------------------------------------------------------------------
// Document
//  JP: GRAPHICモード4,5,6,7のメイン処理回路です。
//-----------------------------------------------------------------------------

module VDP_GRAPHIC4567 (
    // VDP CLOCK ... 21.477MHZ
    input  wire        CLK21M,
    input  wire        RESET,

    input  wire [1:0]  DOTSTATE,
    input  wire [2:0]  EIGHTDOTSTATE,
    input  wire [8:0]  DOTCOUNTERX,
    input  wire [8:0]  DOTCOUNTERY,

    input  wire        VDPMODEGRAPHIC4,
    input  wire        VDPMODEGRAPHIC5,
    input  wire        VDPMODEGRAPHIC6,
    input  wire        VDPMODEGRAPHIC7,
    input  wire        VRAM_INTERLEAVE,   // interleave V9938 en G6/G7 (swizzle sobre VRAM lineal)

    // REGISTERS
    input  wire        REG_R1_BL_CLKS,
    input  wire [7:0]  REG_R2_PT_NAM_ADDR,   // 8 bits: bit7 = A17 (VRAM 256K, banco alto)
    input  wire [7:0]  REG_R13_BLINK_PERIOD,
    input  wire [8:3]  REG_R26_H_SCROLL,
    input  wire [2:0]  REG_R27_H_SCROLL,
    input  wire        REG_R25_YAE,
    input  wire        REG_R25_YJK,
    input  wire        REG_R25_SP2,

    //
    input  wire [7:0]  PRAMDAT,
    input  wire [7:0]  PRAMDATPAIR,
    output reg  [17:0] PRAMADR,   // 18 bits (VRAM 256K)

    output reg  [7:0]  PCOLORCODE,

    output reg  [5:0]  P_YJK_R,
    output reg  [5:0]  P_YJK_G,
    output reg  [5:0]  P_YJK_B,
    output reg         P_YJK_EN
);

    wire [17:0] LOGICALVRAMADDRG45;   // 18 bits (VRAM 256K)
    wire [17:0] LOGICALVRAMADDRG67;
    reg  [8:0]  LOCALDOTCOUNTERX;
    reg  [7:0]  LATCHEDPTNNAMETBLBASEADDR;   // 8 bits: bit7 = A17

    wire [7:0]  FIFOADDR;
    reg  [7:0]  FIFOADDR_IN;
    reg  [7:0]  FIFOADDR_OUT;
    wire        FIFOWE;
    reg         FIFOIN;
    wire [7:0]  FIFODATA_IN;
    wire [7:0]  FIFODATA_OUT;

    reg  [7:0]  FF_FIFO0;
    reg  [7:0]  FF_FIFO1;
    reg  [7:0]  FF_FIFO2;
    reg  [7:0]  FF_FIFO3;
    reg  [7:0]  FF_PIX0;
    reg  [7:0]  FF_PIX1;
    reg  [7:0]  FF_PIX2;
    reg  [7:0]  FF_PIX3;

    reg  [7:0]  COLORDATA;
    wire [8:0]  W_DOTCOUNTERX;
    wire        W_SP2_H_SCROLL;
    wire [7:0]  W_PIX;

    wire [4:0]  W_Y;
    wire [5:0]  W_K;
    wire [5:0]  W_J;
    wire [6:0]  W_R_YJK;
    wire [6:0]  W_G_YJK;
    wire [7:0]  W_B_Y;
    wire [7:0]  W_B_JK;
    wire [8:0]  W_B_YJKP;
    wire [6:0]  W_B_YJK;
    wire [5:0]  W_R;
    wire [5:0]  W_G;
    wire [5:0]  W_B;
    reg  [3:0]  FF_BLINK_CLK_CNT;
    reg         FF_BLINK_STATE;
    reg  [3:0]  FF_BLINK_PERIOD_CNT;
    wire [3:0]  W_BLINK_CNT_MAX;
    wire        W_BLINK_SYNC;

    //--------------------------------------------------------------
    // FIFO AND CONTROL SIGNALS
    //--------------------------------------------------------------
    assign FIFOADDR    = (FIFOIN == 1'b1) ? FIFOADDR_IN : FIFOADDR_OUT;
    assign FIFOWE      = (FIFOIN == 1'b1) ? 1'b1 : 1'b0;
    reg [7:0] FF_ILV_E0, FF_ILV_E1, FF_ILV_O0, FF_ILV_O1;   // buffer de reorden interleave

    // Sin interleave (V9968/mode3): ventana 1 (DS01) = PRAMDAT (byte par), ventana 2 (DS10) =
    // PRAMDATPAIR (byte impar adyacente de la misma palabra). Con interleave (G6/G7 V9938):
    // ambas ventanas emiten desde el buffer de reorden FF_ILV_* (ver abajo): las llegadas son
    // {E0,E1} (EDS1,3) y {O0,O1} (EDS2,4) y la emision E,O,E,O va corrida un dot (EDS2-5).
    assign FIFODATA_IN =
        (VRAM_INTERLEAVE == 1'b1)
            ? (((DOTSTATE == 2'b00) || (DOTSTATE == 2'b01))
                ? ((EIGHTDOTSTATE[0] == 1'b0) ? FF_ILV_E0 : FF_ILV_E1)
                : ((EIGHTDOTSTATE[0] == 1'b0) ? FF_ILV_O0 : FF_ILV_O1))
            : (((DOTSTATE == 2'b00) || (DOTSTATE == 2'b01)) ? PRAMDAT : PRAMDATPAIR);

    // Buffer de reorden del interleave: cada acceso trae 2 px de la MISMA paridad; se
    // capturan al final de DS01 del dot de llegada (EDS1-4) y se emiten en el dot siguiente.
    // La lectura del valor viejo y la sobreescritura en el mismo flanco (EDS3) es correcta
    // (no-bloqueante: el write del FIFO usa el valor previo).
    always @(posedge CLK21M) begin
        if (DOTSTATE == 2'b01 && VRAM_INTERLEAVE == 1'b1 &&
            (EIGHTDOTSTATE >= 3'd1) && (EIGHTDOTSTATE <= 3'd4)) begin
            if (EIGHTDOTSTATE[0] == 1'b1) begin
                FF_ILV_E0 <= PRAMDAT;        // EDS 1,3: llega palabra PAR {E0,E1}
                FF_ILV_E1 <= PRAMDATPAIR;
            end else begin
                FF_ILV_O0 <= PRAMDAT;        // EDS 2,4: llega palabra IMPAR {O0,O1}
                FF_ILV_O1 <= PRAMDATPAIR;
            end
        end
    end

    ram U_FIFOMEM (
        .adr (FIFOADDR),
        .clk (CLK21M),
        .we  (FIFOWE),
        .dbo (FIFODATA_IN),
        .dbi (FIFODATA_OUT)
    );

    always @(posedge CLK21M) begin
        if (DOTSTATE == 2'b01) begin
            case (EIGHTDOTSTATE[1:0])
                2'b00: FF_FIFO0 <= FIFODATA_OUT;
                2'b01: FF_FIFO1 <= FIFODATA_OUT;
                2'b10: FF_FIFO2 <= FIFODATA_OUT;
                2'b11: FF_FIFO3 <= FIFODATA_OUT;
            endcase
        end
    end

    always @(posedge CLK21M) begin
        if (DOTSTATE == 2'b00 && EIGHTDOTSTATE[1:0] == 2'b00) begin
            FF_PIX0 <= FF_FIFO0;
            FF_PIX1 <= FF_FIFO1;
            FF_PIX2 <= FF_FIFO2;
            FF_PIX3 <= FF_FIFO3;
        end
    end

    assign W_PIX = (EIGHTDOTSTATE[1:0] == 2'b00) ? FF_PIX0 :
                   (EIGHTDOTSTATE[1:0] == 2'b01) ? FF_PIX1 :
                   (EIGHTDOTSTATE[1:0] == 2'b10) ? FF_PIX2 :
                                                   FF_PIX3;

    // TWO SCREEN H-SCROLL MODE (R25 SP2 = '1'), R#13 BLINKING TO FLIP PAGES
    assign W_SP2_H_SCROLL = ((REG_R25_SP2 & LATCHEDPTNNAMETBLBASEADDR[5]) == 1'b1) ? LOCALDOTCOUNTERX[8] :
                            (FF_BLINK_STATE == 1'b0) ? LATCHEDPTNNAMETBLBASEADDR[5] : 1'b0;

    // VRAM ADDRESS MAPPINGS.
    assign LOGICALVRAMADDRG45 = {LATCHEDPTNNAMETBLBASEADDR[7], LATCHEDPTNNAMETBLBASEADDR[6], W_SP2_H_SCROLL,
                                 (LATCHEDPTNNAMETBLBASEADDR[4:0] & DOTCOUNTERY[7:3]),
                                 DOTCOUNTERY[2:0], LOCALDOTCOUNTERX[7:1]};

    assign LOGICALVRAMADDRG67 = {LATCHEDPTNNAMETBLBASEADDR[7], W_SP2_H_SCROLL,
                                 (LATCHEDPTNNAMETBLBASEADDR[4:0] & DOTCOUNTERY[7:3]),
                                 DOTCOUNTERY[2:0], LOCALDOTCOUNTERX[7:0]};

    // FIFO CONTROL
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FIFOADDR_IN <= 8'b0;
        end else begin
            if (DOTSTATE == 2'b00) begin
                if (EIGHTDOTSTATE == 3'b000 && DOTCOUNTERX == 0)
                    FIFOADDR_IN <= 8'b0;
            end else if (FIFOIN == 1'b1) begin
                FIFOADDR_IN <= FIFOADDR_IN + 1'b1;
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FIFOADDR_OUT <= 8'b0;
        end else begin
            case (DOTSTATE)
                2'b00: ;
                2'b01: begin
                    if ((VDPMODEGRAPHIC4 == 1'b0) && (VDPMODEGRAPHIC5 == 1'b0))
                        FIFOADDR_OUT <= FIFOADDR_OUT + 1'b1;
                    else if (EIGHTDOTSTATE[0] == 1'b0)
                        // GRAPHIC4, 5
                        FIFOADDR_OUT <= FIFOADDR_OUT + 1'b1;
                end
                2'b11: ;
                2'b10: begin
                    if (DOTCOUNTERX == 8'h04)
                        FIFOADDR_OUT <= 8'b0;
                end
                default: ;
            endcase
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FIFOIN <= 1'b0;
        end else begin
            case (DOTSTATE)
                2'b00: begin
                    // Con interleave la emision va corrida un dot (EDS2-5, desde FF_ILV_*);
                    // sin interleave, ventana clasica EDS1-4 (dato en vivo).
                    if (VRAM_INTERLEAVE == 1'b1)
                        FIFOIN <= ((EIGHTDOTSTATE >= 3'd2) && (EIGHTDOTSTATE <= 3'd5));
                    else if (EIGHTDOTSTATE == 3'b000)
                        FIFOIN <= 1'b0;
                    else if ((EIGHTDOTSTATE == 3'b001) || (EIGHTDOTSTATE == 3'b010) ||
                             (EIGHTDOTSTATE == 3'b011) || (EIGHTDOTSTATE == 3'b100))
                        FIFOIN <= 1'b1;
                end
                2'b01: FIFOIN <= 1'b0;
                2'b11: begin
                    if (((VDPMODEGRAPHIC6 == 1'b1) || (VDPMODEGRAPHIC7 == 1'b1)))
                        FIFOIN <= (VRAM_INTERLEAVE == 1'b1)
                                ? ((EIGHTDOTSTATE >= 3'd2) && (EIGHTDOTSTATE <= 3'd5))
                                : ((EIGHTDOTSTATE == 3'b001) || (EIGHTDOTSTATE == 3'b010) ||
                                   (EIGHTDOTSTATE == 3'b011) || (EIGHTDOTSTATE == 3'b100));
                end
                2'b10: FIFOIN <= 1'b0;
                default: ;
            endcase
        end
    end

    // FIFO OUT LATCH
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            COLORDATA  <= 8'b0;
            PCOLORCODE <= 8'b0;
        end else begin
            case (DOTSTATE)
                2'b00: ;
                2'b01: begin
                    if ((VDPMODEGRAPHIC4 == 1'b1) || (VDPMODEGRAPHIC5 == 1'b1)) begin
                        if (EIGHTDOTSTATE[0] == 1'b0) begin
                            COLORDATA        <= W_PIX;
                            PCOLORCODE[7:4]  <= 4'b0;
                            PCOLORCODE[3:0]  <= W_PIX[7:4];
                        end else begin
                            PCOLORCODE[7:4]  <= 4'b0;
                            PCOLORCODE[3:0]  <= COLORDATA[3:0];
                        end
                    end else if (VDPMODEGRAPHIC6 == 1'b1 || REG_R25_YAE == 1'b1) begin
                        COLORDATA        <= W_PIX;
                        PCOLORCODE[7:4]  <= 4'b0;
                        PCOLORCODE[3:0]  <= W_PIX[7:4];
                    end else begin
                        // GRAPHIC7
                        PCOLORCODE <= W_PIX;
                    end
                end
                2'b11: ;
                2'b10: begin
                    // HIGH RESOLUTION MODE .
                    if (VDPMODEGRAPHIC6 == 1'b1) begin
                        PCOLORCODE[7:4] <= 4'b0;
                        PCOLORCODE[3:0] <= COLORDATA[3:0];
                    end
                end
                default: ;
            endcase
        end
    end

    // YJK COLOR CONVERT
    assign W_Y     = W_PIX[7:3];                                   //  Y ( 0...31)
    assign W_J     = {FF_PIX3[2:0], FF_PIX2[2:0]};                 //  J (-32...31)
    assign W_K     = {FF_PIX1[2:0], FF_PIX0[2:0]};                 //  K (-32...31)

    assign W_R_YJK = {2'b00, W_Y} + {W_J[5], W_J};                 //  R (-32...62)
    assign W_G_YJK = {2'b00, W_Y} + {W_K[5], W_K};                 //  B (-32...62)
    assign W_B_Y   = {1'b0, W_Y, 2'b00} + {3'b000, W_Y};          //  Y * 5               ( 0...155 )
    assign W_B_JK  = {W_J[5], W_J, 1'b0} + {W_K[5], W_K[5], W_K};  //  J * 2 + K           ( -96...93 )
    assign W_B_YJKP= {1'b0, W_B_Y} - {W_B_JK[7], W_B_JK} + 9'b000000010;  // (Y*5 - (J*2+K) + 2)
    assign W_B_YJK = W_B_YJKP[8:2];                                //  (Y*5 - (J*2+K) + 2)/4 (-22...63)

    assign W_R = (W_R_YJK[6] == 1'b1) ? 6'b000000 :               // UNDER LIMIT
                 (W_R_YJK[5] == 1'b1) ? 6'b111111 :               // OVER LIMIT
                 {W_R_YJK[4:0], 1'b0};
    assign W_G = (W_G_YJK[6] == 1'b1) ? 6'b000000 :               // UNDER LIMIT
                 (W_G_YJK[5] == 1'b1) ? 6'b111111 :               // OVER LIMIT
                 {W_G_YJK[4:0], 1'b0};
    assign W_B = (W_B_YJK[6] == 1'b1) ? 6'b000000 :               // UNDER LIMIT
                 (W_B_YJK[5] == 1'b1) ? 6'b111111 :               // OVER LIMIT
                 {W_B_YJK[4:0], 1'b0};

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            P_YJK_R <= 6'b0;
            P_YJK_G <= 6'b0;
            P_YJK_B <= 6'b0;
        end else begin
            if (DOTSTATE == 2'b01) begin
                P_YJK_R <= W_R;
                P_YJK_G <= W_G;
                P_YJK_B <= W_B;
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            P_YJK_EN <= 1'b0;
        end else begin
            if (DOTSTATE == 2'b01) begin
                if (REG_R25_YAE == 1'b1 && W_PIX[3] == 1'b1)
                    // PALETTE COLOR ON SCREEN10/SCREEN11
                    P_YJK_EN <= 1'b0;
                else
                    P_YJK_EN <= REG_R25_YJK;
            end
        end
    end

    // VRAM READ ADDRESS
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            PRAMADR <= 18'b0;
        end else begin
            if (DOTSTATE == 2'b11) begin
                if ((VDPMODEGRAPHIC4 == 1'b1) || (VDPMODEGRAPHIC5 == 1'b1))
                    PRAMADR <= LOGICALVRAMADDRG45[17:0];
                else if (VRAM_INTERLEAVE == 1'b1)
                    // Interleave V9938: la memoria sirve UN acceso por dot, pero cada acceso
                    // swizzled devuelve 2 px de la MISMA paridad ({PRAMDAT,PRAMDATPAIR} =
                    // fisico {P,P+1} = logico {N,N+2}). Se alterna por dot de emision:
                    //   EDS par  -> palabra PAR:   SWZ(live)            = {E0,E1}
                    //   EDS impar-> palabra IMPAR: (SWZ(live)-1)|0x10000 = {O0,O1}
                    // (live avanza +2 por dot -> SWZ avanza +1; el -1 recentra al grupo).
                    // El reorden a E,O,E,O lo hacen FF_ILV_* + el mux del FIFO.
                    PRAMADR <= (EIGHTDOTSTATE[0] == 1'b0)
                             ? {LOGICALVRAMADDRG67[17], LOGICALVRAMADDRG67[0], LOGICALVRAMADDRG67[16:1]}
                             : (({LOGICALVRAMADDRG67[17], LOGICALVRAMADDRG67[0], LOGICALVRAMADDRG67[16:1]} - 18'd1) | 18'h10000);
                else
                    // V9968 (mode3): lineal; el par par/impar son bytes ADYACENTES
                    // (PRAMDAT=byte@X, PRAMDATPAIR=byte@X+1) de la misma palabra (X es par).
                    PRAMADR <= LOGICALVRAMADDRG67[17:0];
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            LATCHEDPTNNAMETBLBASEADDR <= 8'b0;
        end else begin
            if (DOTSTATE == 2'b00 && EIGHTDOTSTATE == 3'b000)
                LATCHEDPTNNAMETBLBASEADDR <= REG_R2_PT_NAM_ADDR;
        end
    end

    assign W_DOTCOUNTERX = {(DOTCOUNTERX[8:3] + REG_R26_H_SCROLL), 3'b000};

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            LOCALDOTCOUNTERX <= 9'b0;
        end else begin
            if (DOTSTATE == 2'b00) begin
                if (EIGHTDOTSTATE == 3'b000)
                    LOCALDOTCOUNTERX <= W_DOTCOUNTERX;
                else if ((EIGHTDOTSTATE == 3'b001) || (EIGHTDOTSTATE == 3'b010) ||
                         (EIGHTDOTSTATE == 3'b011) || (EIGHTDOTSTATE == 3'b100))
                    LOCALDOTCOUNTERX <= LOCALDOTCOUNTERX + 2'd2;
            end
        end
    end

    assign W_BLINK_CNT_MAX = (FF_BLINK_STATE == 1'b0) ? REG_R13_BLINK_PERIOD[3:0] :
                                                        REG_R13_BLINK_PERIOD[7:4];
    assign W_BLINK_SYNC = ((DOTCOUNTERX == 0) && (DOTCOUNTERY == 0) && (DOTSTATE == 2'b00) && (REG_R1_BL_CLKS == 1'b0)) ? 1'b1 :
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
                        FF_BLINK_STATE <= 1'b0;
                    else if (REG_R13_BLINK_PERIOD[3:0] == 4'b0000)
                        FF_BLINK_STATE <= 1'b1;
                    else
                        FF_BLINK_STATE <= ~FF_BLINK_STATE;
                end

            end
        end
    end

endmodule
