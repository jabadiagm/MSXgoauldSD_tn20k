//
//  vdp_command.v
//   VDP command engine (blitter): HMMC/YMMM/HMMM/HMMV/LMMC/LMCM/LMMM/LMMV/
//   LINE/SRCH/PSET/POINT.
//   Traduccion a Verilog de vdp_command.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / Alex Wulms / t.hara / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_command.vhd.
//
//  Nota (traduccion): todo es UN proceso clockeado con VARIABLES de VHDL. Se modelan
//  como reg de modulo con BLOCKING (=); las SEÑALES con non-blocking (<=). Las
//  variables recalculadas al inicio de cada ciclo (NXCOUNT, COLMASK, RDPOINT,
//  LOGOPDESTCOL, ...) leen el valor ACTUAL de las señales (aun sin actualizar por <=),
//  igual que en VHDL.
//-----------------------------------------------------------------------------

module VDP_COMMAND (
    input  wire        RESET,
    input  wire        CLK21M,

    input  wire        VDPMODEGRAPHIC4,
    input  wire        VDPMODEGRAPHIC5,
    input  wire        VDPMODEGRAPHIC6,
    input  wire        VDPMODEGRAPHIC7,
    input  wire        VDPMODEISHIGHRES,

    input  wire        VRAMWRACK,
    input  wire        VRAMRDACK,
    input  wire        VRAMREADINGR,
    input  wire        VRAMREADINGA,
    input  wire [7:0]  VRAMRDDATA,
    input  wire        REGWRREQ,
    input  wire        TRCLRREQ,
    input  wire [4:0]  REGNUM,
    input  wire [7:0]  REGDATA,
    output wire        PREGWRACK,
    output wire        PTRCLRACK,
    output wire        PVRAMWRREQ,
    output wire        PVRAMRDREQ,
    output wire [17:0] PVRAMACCESSADDR,
    output wire [7:0]  PVRAMWRDATA,
    output wire [7:0]  PCLR,    // R44, S#7
    output wire        PCE,     // S#2 (BIT 0)
    output wire        PBD,     // S#2 (BIT 4)
    output wire        PTR,     // S#2 (BIT 7)
    output wire [10:0] PSXTMP,  // S#8, S#9

    output wire [7:4]  CUR_VDP_COMMAND,

    input  wire        REG_R25_CMD,
    input  wire [7:0]  REG_R12,        // V9968: back color para LFMM/LFMC (R#12)
    input  wire        MODE_V9968      // 1 = modo V9968 (habilita comandos LFMM/LFMC/LRMM)
);

    // VDP COMMAND SIGNALS - CAN BE SET BY CPU
    reg signed [11:0] SX;   // R33,32  (12 bits CON SIGNO: origen LRMM puede ser negativo, como reg_sx del V9968)
    reg signed [12:0] SY;   // R35,34  (13 bits CON SIGNO, como reg_sy del V9968: origen LRMM puede ser negativo)
    reg [8:0]  DX;      // R37,36
    reg [10:0] DY;      // R39,38  (11 bits para VRAM 256K)
    reg [9:0]  NX;      // R41,40
    reg [9:0]  NY;      // R43,42
    reg        MM;      // R45 BIT 0
    reg        EQ;      // R45 BIT 1
    reg        DIX;     // R45 BIT 2
    reg        DIY;     // R45 BIT 3
    reg [7:0]  CMR;     // R46

    // VDP COMMAND SIGNALS - INTERNAL REGISTERS
    reg [9:0]  DXTMP;
    reg [9:0]  NXTMP;
    reg        REGWRACK;
    reg        TRCLRACK;
    reg        CMRWR;

    // COMMUNICATION WITH MEMORY INTERFACE
    reg        VRAMWRREQ;
    reg        VRAMRDREQ;
    reg [17:0] VRAMACCESSADDR;   // 18 bits (VRAM 256K, bit17)
    reg [7:0]  VRAMWRDATA;

    reg [7:0]  CLR;     // R44, S#7
    // CAN BE READ BY CPU
    reg        CE;      // S#2 (BIT 0)
    reg        BD;      // S#2 (BIT 4)
    reg        TR;      // S#2 (BIT 7)
    reg [10:0] SXTMP;   // S#8, S#9

    wire       W_VDPCMD_EN;

    // VDP COMMAND STATE REGISTER (enum TYPSTATE)
    localparam [4:0]
        STIDLE            = 5'd0,
        STCHKLOOP         = 5'd1,
        STRDCPU           = 5'd2,
        STWAITCPU         = 5'd3,
        STRDVRAM          = 5'd4,
        STWAITRDVRAM      = 5'd5,
        STPOINTWAITRDVRAM = 5'd6,
        STSRCHWAITRDVRAM  = 5'd7,
        STPRERDVRAM       = 5'd8,
        STWAITPRERDVRAM   = 5'd9,
        STWRVRAM          = 5'd10,
        STWAITWRVRAM      = 5'd11,
        STLINENEWPOS      = 5'd12,
        STLINECHKLOOP     = 5'd13,
        STSRCHCHKLOOP     = 5'd14,
        STEXECEND         = 5'd15,
        // V9968 comandos nuevos (1bpp blit)
        STLF_PIX          = 5'd16,   // fija el color del pixel = PATBYTE[BITCNT] ? FORE : BACK
        STLFMM_RDFONT     = 5'd17,   // pide lectura LINEAL del byte de font (LFMM)
        STLFMM_WAITFONT   = 5'd18,   // latch del byte de font
        STLRMM_RDSRC      = 5'd19,   // LRMM: lee origen en (LR_SX,LR_SY) por coordenada
        STLRMM_WAITSRC    = 5'd20;   // LRMM: latch origen y avanza el vector por pixel
    reg [4:0] STATE;

    localparam [3:0] HMMC = 4'b1111, YMMM = 4'b1110, HMMM = 4'b1101, HMMV = 4'b1100,
                     LMMC = 4'b1011, LMCM = 4'b1010, LMMM = 4'b1001, LMMV = 4'b1000,
                     LINE = 4'b0111, SRCH = 4'b0110, PSET = 4'b0101, POINT = 4'b0100,
                     LRMM = 4'b0011, LFMC = 4'b0010, LFMM = 4'b0001,   // V9968 comandos nuevos
                     STOP = 4'b0000;

    localparam [2:0] IMPB210 = 3'b000, ANDB210 = 3'b001, ORB210 = 3'b010,
                     EORB210 = 3'b011, NOTB210 = 3'b100;

    // VARIABLES del proceso (ver nota de cabecera): blocking (=)
    reg        INITIALIZING;
    reg [9:0]  NXCOUNT;
    reg [10:0] XCOUNTDELTA;
    reg signed [12:0] YCOUNTDELTA;   // 13 bits con signo (ancho de SY); complemento a 2 para DIY
    reg        NXLOOPEND;
    reg        DYEND;
    reg        SYEND;
    reg        NYLOOPEND;
    reg [9:0]  NX_MINUS_ONE;
    reg [1:0]  RDXLOW;
    reg [7:0]  RDPOINT;
    reg [7:0]  COLMASK;
    reg [1:0]  MAXXMASK;
    reg [7:0]  LOGOPDESTCOL;
    reg        GRAPHIC4_OR_6;
    reg        SRCHEQRSLT;
    reg [10:0] VDPVRAMACCESSY;   // 11 bits (Y 256K)
    reg [8:0]  VDPVRAMACCESSX;

    // V9968 comandos nuevos (LFMM/LFMC/LRMM)
    reg [16:0] FONTADR;      // direccion LINEAL de fuente (LFMM), sombra de R#32-34
    reg        LINEARADDR;   // 1 = usar FONTADR directo en vez de conversion X/Y (blocking, default 0)
    reg [2:0]  BITCNT;       // bit actual del patron 1bpp (7..0, MSB primero)
    reg [7:0]  PATBYTE;      // byte de patron 1bpp (de CPU en LFMC, de VRAM en LFMM)
    reg [7:0]  FORECOLOR;    // color de primer plano latcheado al iniciar el comando (CLR)
    // LFMM transpuesto: la fuente font.bin esta en column-major (byte k = columna*NY + fila), pero
    // nuestro destino itera row-major. Para leer el byte correcto en dest (col,fila) leemos
    // font[base + col*NY + fila]: FONTADR avanza +NY_ORIG por byte (columna) y se reinicia a
    // FONTADR_ROW (=base+fila) al final de cada fila destino.
    reg [16:0] FONTADR_ROW;  // FONTADR al inicio de la fila destino actual
    reg [9:0]  NY_ORIG;      // NY original (stride de columna de la fuente), latcheado al inicio

    // V9968 LRMM (afin/rotozoom): vectores 8.8 con signo (R#47-50) y coords de origen fraccionarias.
    reg        XHR;                     // R#45 bit6 & modo V9968: media resolucion X (SCREEN 6/7)
    reg        FG4;                     // R#45 bit7 & modo V9968: forzar direccionamiento Graphic4
                                        // (SCREEN5, 4bpp) aunque la pantalla este en otro modo.
                                        // Uso: procesar patrones de sprite mode3 con el blitter.
    wire       W_CMD_G4 = VDPMODEGRAPHIC4 | FG4;   // "es Graphic4" efectivo para el comando
    reg signed [15:0] REG_VX, REG_VY;   // incremento de origen por paso (formato 8.8)
    reg signed [20:0] LR_SX, LR_SY;     // origen fraccionario actual (13 ent . 8 frac)
    reg signed [20:0] LR_SX2, LR_SY2;   // origen fraccionario al inicio de la linea
    // Ventana de recorte del origen (R#51-58): fuera de ella se rellena con el color de borde (CLR)
    reg [8:0]  REG_WSX;   // R#51-52
    reg [10:0] REG_WSY;   // R#53-54
    reg [8:0]  REG_WEX;   // R#55-56
    reg [10:0] REG_WEY;   // R#57-58
    // Origen (parte entera, con signo) fuera de la ventana
    wire signed [12:0] W_LRMM_SX = LR_SX[20:8];
    // En xhr la Y se muestrea a media resolucion (LR_SY >> 1)
    wire signed [12:0] W_LRMM_SY = XHR ? $signed({LR_SY[20], LR_SY[20:9]}) : $signed(LR_SY[20:8]);
    wire W_LRMM_OUTSIDE = (W_LRMM_SX < $signed({4'd0, REG_WSX})) || (W_LRMM_SY < $signed({2'd0, REG_WSY})) ||
                          (W_LRMM_SX > $signed({4'd0, REG_WEX})) || (W_LRMM_SY > $signed({2'd0, REG_WEY}));

    assign PREGWRACK       = REGWRACK;
    assign PTRCLRACK       = TRCLRACK;
    assign PVRAMWRREQ      = (W_VDPCMD_EN == 1'b1) ? VRAMWRREQ : VRAMWRACK;
    assign PVRAMRDREQ      = VRAMRDREQ;
    assign PVRAMACCESSADDR = VRAMACCESSADDR;
    assign PVRAMWRDATA     = VRAMWRDATA;
    assign PCLR            = CLR;
    assign PCE             = CE;
    assign PBD             = BD;
    assign PTR             = TR;
    assign PSXTMP          = SXTMP;

    assign CUR_VDP_COMMAND = CMR[7:4];

    // R25 CMD BIT: 0=normal, 1=VDP command on TEXT/G1/G2/G3/MOSAIC mode
    // FG4 tambien habilita el comando (fuerza direccionamiento G4 en modos no-bitmap).
    assign W_VDPCMD_EN = ((VDPMODEGRAPHIC4 | VDPMODEGRAPHIC5 | VDPMODEGRAPHIC6) == 1'b0) ?
                            (VDPMODEGRAPHIC7 | REG_R25_CMD | FG4) :
                            (VDPMODEGRAPHIC4 | VDPMODEGRAPHIC5 | VDPMODEGRAPHIC6);

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            STATE          <= STIDLE;    // VERY IMPORTANT FOR XST
            INITIALIZING    = 1'b0;
            NXCOUNT         = 10'b0;
            NXLOOPEND       = 1'b0;
            XCOUNTDELTA     = 11'b0;
            YCOUNTDELTA     = 13'sd0;
            COLMASK         = 8'b11111111;
            RDXLOW          = 2'b00;
            SX             <= 12'sd0; // R32
            SY             <= 13'sd0; // R34
            DX             <= 9'b0;   // R36
            DY             <= 11'b0;  // R38
            NX             <= 10'b0;  // R40
            NY             <= 10'b0;  // R42
            CLR            <= 8'b0;   // R44
            MM             <= 1'b0;   // R45 BIT 0
            EQ             <= 1'b0;   // R45 BIT 1
            DIX            <= 1'b0;   // R45 BIT 2
            DIY            <= 1'b0;   // R45 BIT 3
            CMR            <= 8'b0;   // R46
            SXTMP          <= 11'b0;
            DXTMP          <= 10'b0;
            CMRWR          <= 1'b0;
            REGWRACK       <= 1'b0;
            VRAMWRREQ      <= 1'b0;
            VRAMRDREQ      <= 1'b0;
            VRAMWRDATA     <= 8'b0;

            TR             <= 1'b1;   // TRANSFER READY
            CE             <= 1'b0;   // COMMAND EXECUTING
            BD             <= 1'b0;   // BORDER COLOR FOUND
            TRCLRACK       <= 1'b0;
            VDPVRAMACCESSY  = 11'b0;
            VDPVRAMACCESSX  = 9'b0;
            VRAMACCESSADDR <= 18'b0;
            FONTADR        <= 17'b0;
            FONTADR_ROW    <= 17'b0;
            NY_ORIG        <= 10'b0;
            LINEARADDR      = 1'b0;
            BITCNT         <= 3'd7;
            PATBYTE        <= 8'b0;
            FORECOLOR      <= 8'b0;
            XHR            <= 1'b0;
            FG4            <= 1'b0;
            REG_VX         <= 16'sd0;
            REG_VY         <= 16'sd0;
            LR_SX          <= 21'sd0;
            LR_SY          <= 21'sd0;
            LR_SX2         <= 21'sd0;
            LR_SY2         <= 21'sd0;
            REG_WSX        <= 9'd0;
            REG_WSY        <= 11'd0;
            REG_WEX        <= 9'h1FF;
            REG_WEY        <= 11'h7FF;
        end else begin
            // Por defecto, direccion por coordenada (X/Y). Los estados de font lineal lo ponen a 1.
            LINEARADDR = 1'b0;

            if ((W_CMD_G4 == 1'b1) || (VDPMODEGRAPHIC6 == 1'b1))   // FG4 fuerza G4
                GRAPHIC4_OR_6 = 1'b1;
            else
                GRAPHIC4_OR_6 = 1'b0;

            case (CMR[7:6])
                2'b11: begin
                    // BYTE COMMAND
                    if (GRAPHIC4_OR_6 == 1'b1) begin
                        // GRAPHIC4,6 (SCREEN 5, 7)
                        NXCOUNT = {1'b0, NX[9:1]};
                        if (DIX == 1'b0) XCOUNTDELTA = 11'b00000000010; // +2
                        else             XCOUNTDELTA = 11'b11111111110; // -2
                    end else if (VDPMODEGRAPHIC5 == 1'b1) begin
                        // GRAPHIC5 (SCREEN 6)
                        NXCOUNT = {2'b00, NX[9:2]};
                        if (DIX == 1'b0) XCOUNTDELTA = 11'b00000000100; // +4
                        else             XCOUNTDELTA = 11'b11111111100; // -4
                    end else begin
                        // GRAPHIC7 (SCREEN 8) AND OTHER
                        NXCOUNT = NX;
                        if (DIX == 1'b0) XCOUNTDELTA = 11'b00000000001; // +1
                        else             XCOUNTDELTA = 11'b11111111111; // -1
                    end
                    COLMASK = 8'b11111111;
                end
                default: begin
                    // DOT COMMAND
                    NXCOUNT = NX;
                    if (DIX == 1'b0) XCOUNTDELTA = 11'b00000000001; // +1
                    else             XCOUNTDELTA = 11'b11111111111; // -1
                    if (GRAPHIC4_OR_6 == 1'b1)      COLMASK = 8'b00001111;
                    else if (VDPMODEGRAPHIC5 == 1'b1) COLMASK = 8'b00000011;
                    else                             COLMASK = 8'b11111111;
                end
            endcase

            // V9968 LFMM/LFMC: la fuente es 1bpp y NX cuenta BYTES de fuente; cada byte se expande
            // a 8 pixeles destino (1 bit -> 1 pixel). Por eso el bucle X debe recorrer NX*8 pixeles
            // (DEVCON pone NX=224>>3=28 para una tira de 224 px). XCOUNTDELTA sigue a +1 (por pixel);
            // FONTADR avanza 1 cada 8 pixeles (BITCNT wrap). Sin esto la tira sale a 1/8 de ancho y
            // con la fuente desalineada entre filas -> manchas.
            if (CMR[7:4] == LFMM || CMR[7:4] == LFMC)
                NXCOUNT = {NX[6:0], 3'b000};   // NX * 8

            if (DIY == 1'b0) YCOUNTDELTA = 13'sd1;    // +1
            else             YCOUNTDELTA = -13'sd1;   // -1 (complemento a 2, 13 bits)

            if (VDPMODEISHIGHRES == 1'b1) MAXXMASK = 2'b10; // G5,6 (SCREEN 6,7)
            else                          MAXXMASK = 2'b01;

            // DETERMINE IF X-LOOP IS FINISHED
            case (CMR[7:4])
                HMMV, HMMC, LMMV, LMMC:
                    if ((NXTMP == 0) || ((DXTMP[9:8] & MAXXMASK) == MAXXMASK))
                        NXLOOPEND = 1'b1;
                    else
                        NXLOOPEND = 1'b0;
                YMMM:
                    if ((DXTMP[9:8] & MAXXMASK) == MAXXMASK)
                        NXLOOPEND = 1'b1;
                    else
                        NXLOOPEND = 1'b0;
                HMMM, LMMM:
                    if ((NXTMP == 0) || ((SXTMP[9:8] & MAXXMASK) == MAXXMASK) || ((DXTMP[9:8] & MAXXMASK) == MAXXMASK))
                        NXLOOPEND = 1'b1;
                    else
                        NXLOOPEND = 1'b0;
                LMCM:
                    if ((NXTMP == 0) || ((SXTMP[9:8] & MAXXMASK) == MAXXMASK))
                        NXLOOPEND = 1'b1;
                    else
                        NXLOOPEND = 1'b0;
                SRCH:
                    if ((SXTMP[9:8] & MAXXMASK) == MAXXMASK)
                        NXLOOPEND = 1'b1;
                    else
                        NXLOOPEND = 1'b0;
                // V9968: LRMM/LFMM/LFMC son comandos "dot" con destino DX/NX (como LMMV).
                // El bucle X termina cuando se agota NX o desborda DX. (LRMM excluye el chequeo de SX,
                // igual que el V9968 real, porque el origen es fraccionario.)
                LRMM, LFMM, LFMC:
                    if ((NXTMP == 0) || ((DXTMP[9:8] & MAXXMASK) == MAXXMASK))
                        NXLOOPEND = 1'b1;
                    else
                        NXLOOPEND = 1'b0;
                default:
                    NXLOOPEND = 1'b1;
            endcase

            // RETRIEVE THE 'POINT' OUT OF THE BYTE MOST RECENTLY READ
            if (GRAPHIC4_OR_6 == 1'b1) begin
                // SCREEN 5, 7
                if (RDXLOW[0] == 1'b0) RDPOINT = {4'b0000, VRAMRDDATA[7:4]};
                else                   RDPOINT = {4'b0000, VRAMRDDATA[3:0]};
            end else if (VDPMODEGRAPHIC5 == 1'b1) begin
                // SCREEN 6
                case (RDXLOW)
                    2'b00: RDPOINT = {6'b000000, VRAMRDDATA[7:6]};
                    2'b01: RDPOINT = {6'b000000, VRAMRDDATA[5:4]};
                    2'b10: RDPOINT = {6'b000000, VRAMRDDATA[3:2]};
                    default: RDPOINT = {6'b000000, VRAMRDDATA[1:0]};
                endcase
            end else begin
                // SCREEN 8 AND OTHER MODES
                RDPOINT = VRAMRDDATA;
            end

            // LOGICAL OPERATION ON READ POINT AND POINT TO BE WRITTEN
            if ((CMR[3] == 1'b0) || ((VRAMWRDATA & COLMASK) != 8'b00000000)) begin
                case (CMR[2:0])
                    IMPB210: LOGOPDESTCOL = (VRAMWRDATA & COLMASK);
                    ANDB210: LOGOPDESTCOL = (VRAMWRDATA & COLMASK) & RDPOINT;
                    ORB210:  LOGOPDESTCOL = (VRAMWRDATA & COLMASK) | RDPOINT;
                    EORB210: LOGOPDESTCOL = (VRAMWRDATA & COLMASK) ^ RDPOINT;
                    NOTB210: LOGOPDESTCOL = ~(VRAMWRDATA & COLMASK);
                    default: LOGOPDESTCOL = RDPOINT;
                endcase
            end else begin
                LOGOPDESTCOL = RDPOINT;
            end

            // PROCESS REGISTER UPDATE / CLEAR TR / ONGOING COMMAND
            if (REGWRREQ != REGWRACK) begin
                REGWRACK <= ~REGWRACK;
                case (REGNUM)
                    4'b0000: begin SX[7:0] <= REGDATA;      FONTADR[7:0]  <= REGDATA;    end // #32 (+ font addr LFMM)
                    4'b0001: begin SX[11:8] <= REGDATA[3:0]; FONTADR[15:8] <= REGDATA;   end // #33 (SX 12b con signo + font addr LFMM)
                    4'b0010: begin SY[7:0] <= REGDATA;      FONTADR[16]   <= REGDATA[0]; end // #34 (+ font addr LFMM)
                    4'b0011: SY[12:8] <= REGDATA[4:0];    // #35 (SY 13b con signo, como reg_sy V9968)
                    4'b0100: DX[7:0]  <= REGDATA;         // #36
                    4'b0101: DX[8]    <= REGDATA[0];      // #37
                    4'b0110: DY[7:0]  <= REGDATA;         // #38
                    4'b0111: DY[10:8] <= REGDATA[2:0];    // #39 (bit10 = 256K, page4+)
                    4'b1000: NX[7:0]  <= REGDATA;         // #40
                    4'b1001: NX[9:8]  <= REGDATA[1:0];    // #41
                    4'b1010: NY[7:0]  <= REGDATA;         // #42
                    4'b1011: NY[9:8]  <= REGDATA[1:0];    // #43
                    4'b1100: begin                        // #44
                        if (CE == 1'b1) CLR <= REGDATA & COLMASK;
                        else            CLR <= REGDATA;
                        TR <= 1'b0; // DATA TRANSFERRED FROM CPU TO VDP COLOR REGISTER
                    end
                    4'b1101: begin                        // #45
                        MM  <= REGDATA[0];
                        EQ  <= REGDATA[1];
                        DIX <= REGDATA[2];
                        DIY <= REGDATA[3];
                        XHR <= REGDATA[6] & MODE_V9968;   // V9968: media resolucion X (LRMM)
                        FG4 <= REGDATA[7] & MODE_V9968;   // V9968: forzar Graphic4 en el comando
                    end
                    4'b1110: begin                        // #46
                        // INITIALIZE NEW COMMAND (ABORTS ANY ONGOING COMMAND!)
                        CMR   <= REGDATA;
                        CMRWR <= W_VDPCMD_EN;
                        STATE <= STIDLE;
                    end
                    5'b01111: REG_VX[7:0]  <= REGDATA;   // #47 reg_vx low  (V9968 LRMM)
                    5'b10000: REG_VX[15:8] <= REGDATA;   // #48 reg_vx high
                    5'b10001: REG_VY[7:0]  <= REGDATA;   // #49 reg_vy low
                    5'b10010: REG_VY[15:8] <= REGDATA;   // #50 reg_vy high
                    5'b10011: REG_WSX[7:0] <= REGDATA;   // #51 window start X low
                    5'b10100: REG_WSX[8]   <= REGDATA[0];// #52 window start X high
                    5'b10101: REG_WSY[7:0] <= REGDATA;   // #53 window start Y low
                    5'b10110: REG_WSY[10:8]<= REGDATA[2:0];// #54 window start Y high
                    5'b10111: REG_WEX[7:0] <= REGDATA;   // #55 window end X low
                    5'b11000: REG_WEX[8]   <= REGDATA[0];// #56 window end X high
                    5'b11001: REG_WEY[7:0] <= REGDATA;   // #57 window end Y low
                    5'b11010: REG_WEY[10:8]<= REGDATA[2:0];// #58 window end Y high
                    default: ;
                endcase
            end else if (TRCLRREQ != TRCLRACK) begin
                // RESET THE DATA TRANSFER REGISTER (CPU HAS READ THE COLOR REGISTER)
                TRCLRACK <= ~TRCLRACK;
                TR <= 1'b0;
            end else begin
                // PROCESS THE VDP COMMAND STATE
                case (STATE)
                    STIDLE: begin
                        if (CMRWR == 1'b0) begin
                            CE <= 1'b0;
                        end else if ((CMR[7:4] == LFMM || CMR[7:4] == LFMC || CMR[7:4] == LRMM) && MODE_V9968 == 1'b0) begin
                            // Comando V9968 pedido en modo V9958: no-op (como en un V9958 real)
                            CMRWR <= 1'b0;
                            CE <= 1'b0;
                        end else begin
                            // EXEC NEW VDP COMMAND
                            CMRWR <= 1'b0;
                            CE <= 1'b1;
                            BD <= 1'b0;
                            if (CMR[7:4] == LINE) begin
                                // LINE requires special SXTMP and NXTMP set-up
                                NX_MINUS_ONE = NX - 1'b1;
                                SXTMP <= {2'b00, NX_MINUS_ONE[9:1]};
                                NXTMP <= 10'b0;
                            end else begin
                                if (CMR[7:4] == YMMM)
                                    // FOR YMMM, SXTMP = DXTMP = DX
                                    SXTMP <= {2'b00, DX};
                                else
                                    SXTMP <= {2'b00, SX[8:0]};
                                NXTMP <= NXCOUNT;
                            end
                            DXTMP <= {1'b0, DX};
                            INITIALIZING = 1'b1;
                            // V9968 LFMM/LFMC: latch fore = CLR y arranca bit MSB (font address ya
                            // en FONTADR desde R#32-34; inofensivo para el resto de comandos).
                            FORECOLOR <= CLR;
                            BITCNT    <= 3'd7;
                            // LFMM transpuesto: base de fila = FONTADR inicial; stride de columna = NY.
                            FONTADR_ROW <= FONTADR;
                            NY_ORIG     <= NY;
                            // LRMM: origen fraccionario inicial = (SX,SY) << 8 (8 bits de fraccion).
                            // xhr: la Y se lleva a doble escala (<<1) para media resolucion X.
                            LR_SX  <= $signed({SX, 8'b0});            // SX con signo -> sign-extend a 21 bits
                            LR_SY  <= $signed({SY, 8'b0}) << XHR;     // SY con signo -> sign-extend; xhr dobla la escala
                            LR_SX2 <= $signed({SX, 8'b0});
                            LR_SY2 <= $signed({SY, 8'b0}) << XHR;
                            STATE <= STCHKLOOP;
                        end
                    end

                    STRDCPU: begin
                        // HMMC, LMMC, LFMC
                        if (TR == 1'b0) begin
                            if (CMR[7:4] == LFMC) begin
                                // LFMC: el byte de CPU es un PATRON 1bpp (no se marca TR hasta
                                // consumir los 8 bits; eso ocurre en STWAITWRVRAM).
                                PATBYTE <= CLR;
                                STATE   <= STLF_PIX;
                            end else begin
                                TR <= 1'b1;  // VDP ready for next transfer
                                VRAMWRDATA <= CLR;
                                if (CMR[6] == 1'b0) STATE <= STPRERDVRAM;  // LMMC
                                else                STATE <= STWRVRAM;     // HMMC
                            end
                        end
                    end

                    STLF_PIX: begin
                        // V9968 1bpp: color del pixel = bit ? fore : back. Sigue por la ruta RMW.
                        VRAMWRDATA <= PATBYTE[BITCNT] ? FORECOLOR : REG_R12;
                        STATE <= STPRERDVRAM;
                    end

                    STLFMM_RDFONT: begin
                        // LFMM: lectura LINEAL del byte de font en FONTADR
                        LINEARADDR = 1'b1;
                        VRAMRDREQ <= ~VRAMRDACK;
                        STATE <= STLFMM_WAITFONT;
                    end

                    STLFMM_WAITFONT: begin
                        // Mantener la direccion LINEAL fija mientras se espera el ack de lectura
                        LINEARADDR = 1'b1;
                        if (VRAMRDREQ == VRAMRDACK) begin
                            PATBYTE <= VRAMRDDATA;
                            STATE <= STLF_PIX;
                        end
                    end

                    STLRMM_RDSRC: begin
                        // LRMM: lee el pixel de origen en la parte ENTERA de (LR_SX, LR_SY).
                        // xhr: la Y se muestrea a media resolucion (LR_SY >> 1).
                        VDPVRAMACCESSY = XHR ? LR_SY[19:9] : LR_SY[18:8];   // 11 bits (Y 256K)
                        VDPVRAMACCESSX = LR_SX[16:8];
                        RDXLOW         = LR_SX[9:8];
                        VRAMRDREQ <= ~VRAMRDACK;
                        STATE <= STLRMM_WAITSRC;
                    end

                    STLRMM_WAITSRC: begin
                        if (VRAMRDREQ == VRAMRDACK) begin
                            // color de origen -> destino (por la ruta RMW con operacion logica).
                            // Fuera de la ventana de recorte: color de borde (CLR).
                            VRAMWRDATA <= W_LRMM_OUTSIDE ? CLR : RDPOINT;
                            // avanza el vector de origen por pixel (eje X)
                            LR_SX <= LR_SX + REG_VX;
                            LR_SY <= LR_SY + REG_VY;
                            STATE <= STPRERDVRAM;
                        end
                    end

                    STWAITCPU: begin
                        // LMCM
                        if (TR == 1'b0)
                            STATE <= STRDVRAM;
                    end

                    STRDVRAM: begin
                        // YMMM, HMMM, LMCM, LMMM, SRCH, POINT
                        VDPVRAMACCESSY = SY[10:0];   // Y de dirección 11b (origen positivo)
                        VDPVRAMACCESSX = SXTMP[8:0];
                        RDXLOW = SXTMP[1:0];
                        VRAMRDREQ <= ~VRAMRDACK;
                        case (CMR[7:4])
                            POINT: STATE <= STPOINTWAITRDVRAM;
                            SRCH:  STATE <= STSRCHWAITRDVRAM;
                            default: STATE <= STWAITRDVRAM;
                        endcase
                    end

                    STPOINTWAITRDVRAM: begin
                        // POINT
                        if (VRAMRDREQ == VRAMRDACK) begin
                            CLR <= RDPOINT;
                            STATE <= STEXECEND;
                        end
                    end

                    STSRCHWAITRDVRAM: begin
                        // SRCH
                        if (VRAMRDREQ == VRAMRDACK) begin
                            if (RDPOINT == CLR) SRCHEQRSLT = 1'b0;
                            else                SRCHEQRSLT = 1'b1;
                            if (EQ == SRCHEQRSLT) begin
                                BD <= 1'b1;
                                STATE <= STEXECEND;
                            end else begin
                                SXTMP <= SXTMP + XCOUNTDELTA;
                                STATE <= STSRCHCHKLOOP;
                            end
                        end
                    end

                    STWAITRDVRAM: begin
                        // YMMM, HMMM, LMCM, LMMM
                        if (VRAMRDREQ == VRAMRDACK) begin
                            SXTMP <= SXTMP + XCOUNTDELTA;
                            case (CMR[7:4])
                                LMMM: begin
                                    VRAMWRDATA <= RDPOINT;
                                    STATE <= STPRERDVRAM;
                                end
                                LMCM: begin
                                    CLR <= RDPOINT;
                                    TR <= 1'b1;
                                    NXTMP <= NXTMP - 1'b1;
                                    STATE <= STCHKLOOP;
                                end
                                default: begin // YMMM, HMMM
                                    VRAMWRDATA <= VRAMRDDATA;
                                    STATE <= STWRVRAM;
                                end
                            endcase
                        end
                    end

                    STPRERDVRAM: begin
                        // LMMC, LMMM, LMMV, LINE, PSET
                        VDPVRAMACCESSY = DY;
                        VDPVRAMACCESSX = DXTMP[8:0];
                        RDXLOW = DXTMP[1:0];
                        VRAMRDREQ <= ~VRAMRDACK;
                        STATE <= STWAITPRERDVRAM;
                    end

                    STWAITPRERDVRAM: begin
                        // LMMC, LMMM, LMMV, LINE, PSET
                        if (VRAMRDREQ == VRAMRDACK) begin
                            if (GRAPHIC4_OR_6 == 1'b1) begin
                                // SCREEN 5, 7
                                if (RDXLOW[0] == 1'b0)
                                    VRAMWRDATA <= {LOGOPDESTCOL[3:0], VRAMRDDATA[3:0]};
                                else
                                    VRAMWRDATA <= {VRAMRDDATA[7:4], LOGOPDESTCOL[3:0]};
                            end else if (VDPMODEGRAPHIC5 == 1'b1) begin
                                // SCREEN 6
                                case (RDXLOW)
                                    2'b00: VRAMWRDATA <= {LOGOPDESTCOL[1:0], VRAMRDDATA[5:0]};
                                    2'b01: VRAMWRDATA <= {VRAMRDDATA[7:6], LOGOPDESTCOL[1:0], VRAMRDDATA[3:0]};
                                    2'b10: VRAMWRDATA <= {VRAMRDDATA[7:4], LOGOPDESTCOL[1:0], VRAMRDDATA[1:0]};
                                    default: VRAMWRDATA <= {VRAMRDDATA[7:2], LOGOPDESTCOL[1:0]};
                                endcase
                            end else begin
                                // SCREEN 8 AND OTHER MODES
                                VRAMWRDATA <= LOGOPDESTCOL;
                            end
                            STATE <= STWRVRAM;
                        end
                    end

                    STWRVRAM: begin
                        // HMMC, YMMM, HMMM, HMMV, LMMC, LMMM, LMMV, LINE, PSET
                        VDPVRAMACCESSY = DY;
                        VDPVRAMACCESSX = DXTMP[8:0];
                        VRAMWRREQ <= ~VRAMWRACK;
                        STATE <= STWAITWRVRAM;
                    end

                    STWAITWRVRAM: begin
                        if (VRAMWRREQ == VRAMWRACK) begin
                            case (CMR[7:4])
                                PSET: STATE <= STEXECEND;
                                LINE: begin
                                    SXTMP <= SXTMP - NY;
                                    if (MM == 1'b0) DXTMP <= DXTMP + XCOUNTDELTA[9:0];
                                    else            DY    <= DY + YCOUNTDELTA;
                                    STATE <= STLINENEWPOS;
                                end
                                LFMC: begin
                                    // 1bpp: avanza destino y bit; al consumir el byte (bit 0) pide
                                    // el siguiente byte a la CPU (TR<=1).
                                    DXTMP <= DXTMP + XCOUNTDELTA[9:0];
                                    NXTMP <= NXTMP - 1'b1;
                                    if (BITCNT == 3'd0) begin BITCNT <= 3'd7; TR <= 1'b1; end
                                    else                     BITCNT <= BITCNT - 1'b1;
                                    STATE <= STCHKLOOP;
                                end
                                LFMM: begin
                                    // 1bpp: avanza destino y bit; al consumir el byte avanza la
                                    // direccion de font por COLUMNA (+NY_ORIG), porque font.bin
                                    // esta en column-major y el destino va row-major (transpuesto).
                                    DXTMP <= DXTMP + XCOUNTDELTA[9:0];
                                    NXTMP <= NXTMP - 1'b1;
                                    if (BITCNT == 3'd0) begin BITCNT <= 3'd7; FONTADR <= FONTADR + NY_ORIG; end
                                    else                     BITCNT <= BITCNT - 1'b1;
                                    STATE <= STCHKLOOP;
                                end
                                default: begin
                                    DXTMP <= DXTMP + XCOUNTDELTA[9:0];
                                    NXTMP <= NXTMP - 1'b1;
                                    STATE <= STCHKLOOP;
                                end
                            endcase
                        end
                    end

                    STLINENEWPOS: begin
                        // LINE
                        if (SXTMP[10] == 1'b1) begin
                            SXTMP <= {1'b0, (SXTMP[9:0] + NX)};
                            if (MM == 1'b0) DY    <= DY + YCOUNTDELTA;
                            else            DXTMP <= DXTMP + XCOUNTDELTA[9:0];
                        end
                        STATE <= STLINECHKLOOP;
                    end

                    STLINECHKLOOP: begin
                        // LINE
                        if ((NXTMP == NX) || ((DXTMP[9:8] & MAXXMASK) == MAXXMASK)) begin
                            STATE <= STEXECEND;
                        end else begin
                            VRAMWRDATA <= CLR;
                            // RE-MASK COLOR IN CASE SCREENMODE CHANGED
                            CLR <= CLR & COLMASK;
                            STATE <= STPRERDVRAM;
                        end
                        NXTMP <= NXTMP + 1'b1;
                    end

                    STSRCHCHKLOOP: begin
                        // SRCH
                        if (NXLOOPEND == 1'b1) begin
                            STATE <= STEXECEND;
                        end else begin
                            CLR <= CLR & COLMASK;
                            STATE <= STRDVRAM;
                        end
                    end

                    STCHKLOOP: begin
                        // DETERMINE NYLOOPEND
                        DYEND = 1'b0;
                        SYEND = 1'b0;
                        if (DIY == 1'b1) begin
                            if ((DY == 0) && (CMR[7:4] != LMCM))
                                DYEND = 1'b1;
                            if ((SY == 0) && (CMR[5] != CMR[4]))
                                // BIT5 /= BIT4 TRUE FOR YMMM, HMMM, LMCM, LMMM
                                SYEND = 1'b1;
                        end
                        if ((NY == 1) || (DYEND == 1'b1) || (SYEND == 1'b1))
                            NYLOOPEND = 1'b1;
                        else
                            NYLOOPEND = 1'b0;

                        if ((INITIALIZING == 1'b0) && (NXLOOPEND == 1'b1) && (NYLOOPEND == 1'b1)) begin
                            STATE <= STEXECEND;
                        end else begin
                            // NOT YET FINISHED OR INITIALIZING. DETERMINE NEXT/FIRST STEP
                            // (LFMC no enmascara CLR: es el patron 1bpp de la CPU, no un color)
                            if (CMR[7:4] != LFMC) CLR <= CLR & COLMASK;
                            case (CMR[7:4])
                                HMMC: STATE <= STRDCPU;
                                YMMM: STATE <= STRDVRAM;
                                HMMM: STATE <= STRDVRAM;
                                HMMV: begin VRAMWRDATA <= CLR; STATE <= STWRVRAM; end
                                LMMC: STATE <= STRDCPU;
                                LMCM: STATE <= STWAITCPU;
                                LMMM: STATE <= STRDVRAM;
                                LMMV, LINE, PSET: begin VRAMWRDATA <= CLR; STATE <= STPRERDVRAM; end
                                SRCH: STATE <= STRDVRAM;
                                POINT: STATE <= STRDVRAM;
                                // V9968 1bpp blit: byte nuevo cada 8 pixeles (BITCNT==7), si no sigue bit
                                LFMC: STATE <= (BITCNT == 3'd7) ? STRDCPU      : STLF_PIX;
                                LFMM: STATE <= (BITCNT == 3'd7) ? STLFMM_RDFONT : STLF_PIX;
                                LRMM: STATE <= STLRMM_RDSRC;   // afin: lee origen fraccionario
                                default: STATE <= STEXECEND;
                            endcase
                        end
                        if ((INITIALIZING == 1'b0) && (NXLOOPEND == 1'b1)) begin
                            NXTMP <= NXCOUNT;
                            if (CMR[7:4] == YMMM) SXTMP <= {2'b00, DX};
                            else                  SXTMP <= {2'b00, SX[8:0]};
                            DXTMP <= {1'b0, DX};
                            NY <= NY - 1'b1;
                            // LFMM transpuesto: la siguiente fila destino empieza en base+fila+1.
                            if (CMR[7:4] == LFMM) begin
                                FONTADR     <= FONTADR_ROW + 1'b1;
                                FONTADR_ROW <= FONTADR_ROW + 1'b1;
                            end
                            if (CMR[5] != CMR[4])
                                // BIT5 /= BIT4 TRUE FOR YMMM, HMMM, LMCM, LMMM
                                SY <= SY + YCOUNTDELTA;
                            if (CMR[7:4] != LMCM)
                                DY <= DY + YCOUNTDELTA;
                            // LRMM: rota el vector de inicio de linea (eje Y perpendicular).
                            // xhr duplica los vectores perpendiculares (reg_vx/vy << 1).
                            if (CMR[7:4] == LRMM) begin
                                LR_SX2 <= LR_SX2 - (XHR ? {{4{REG_VY[15]}}, REG_VY, 1'b0} : {{5{REG_VY[15]}}, REG_VY});
                                LR_SY2 <= LR_SY2 + (XHR ? {{4{REG_VX[15]}}, REG_VX, 1'b0} : {{5{REG_VX[15]}}, REG_VX});
                                LR_SX  <= LR_SX2 - (XHR ? {{4{REG_VY[15]}}, REG_VY, 1'b0} : {{5{REG_VY[15]}}, REG_VY});
                                LR_SY  <= LR_SY2 + (XHR ? {{4{REG_VX[15]}}, REG_VX, 1'b0} : {{5{REG_VX[15]}}, REG_VX});
                            end
                        end else begin
                            SXTMP[10] <= 1'b0;
                        end
                        INITIALIZING = 1'b0;
                    end

                    default: begin
                        STATE <= STIDLE;
                        CE <= 1'b0;
                        CMR <= 8'b0;
                    end
                endcase
            end

            // Direccion de 18 bits (VRAM 256K). Y aporta el bit17:
            //   G4/G5 (128 B/linea): Y[10] es el bit17 -> Y usa 11 bits.
            //   G6/G7 (256 B/linea): Y[9]  es el bit17 -> Y usa 10 bits.
            if (LINEARADDR == 1'b1)
                // V9968: direccion LINEAL directa (LFMM font). FONTADR 17 bits -> banco bajo.
                VRAMACCESSADDR <= {1'b0, FONTADR};
            else if (W_CMD_G4 == 1'b1)   // FG4 fuerza layout G4 (SCREEN5, 128 B/linea, 2 px/byte)
                VRAMACCESSADDR <= {VDPVRAMACCESSY[10:0], VDPVRAMACCESSX[7:1]};
            else if (VDPMODEGRAPHIC5 == 1'b1)
                VRAMACCESSADDR <= {VDPVRAMACCESSY[10:0], VDPVRAMACCESSX[8:2]};
            else if (VDPMODEGRAPHIC6 == 1'b1)
                VRAMACCESSADDR <= {VDPVRAMACCESSY[9:0], VDPVRAMACCESSX[8:1]};
            else
                VRAMACCESSADDR <= {VDPVRAMACCESSY[9:0], VDPVRAMACCESSX[7:0]};

        end
    end

endmodule
