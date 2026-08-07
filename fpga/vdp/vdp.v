//
//  vdp.v
//   ESE-VDP top entity: interfaz CPU, generacion de timing, registros VDP,
//   arbitro de acceso a VRAM y ensamblado de todos los submodulos.
//   Traduccion a Verilog de vdp.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / K.Tsujikawa / A.Wulms / t.hara / KdL /
//                O.Pavan Junior / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp.vhd.
//
//  Nota (traduccion): CLOCKS_PER_LINE es wire local desde VDPR9PALMODE (antes
//  SHARED VARIABLE). La condicion de recarga de PREWINDOW_X usa OFFSET_X+LED_TV_X;
//  como LED_TV_X_NTSC==LED_TV_X_PAL se unifica PAL/NTSC (equivalente).
//-----------------------------------------------------------------------------
`include "vdp_config.vh"

module VDP (
    // VDP CLOCK ... 21.477MHZ
    input  wire        CLK21M,
    input  wire        RESET,
    input  wire        REQ,
    output wire        ACK,
    input  wire        WRT,
    input  wire [15:0] ADR,
    output wire [7:0]  DBI,
    input  wire [7:0]  DBO,

    output wire        INT_N,

    output reg         PRAMOE_N,
    output reg         PRAMWE_N,
    output wire [17:0] PRAMADR,   // 18 bits (VRAM 256K; bit17 gateado por modo V9968)
    input  wire [15:0] PRAMDBI,   // F1 VRAM contigua: par {byte@X+1, byte@X} (memory lo selecciona)
    input  wire [31:0] PRAMDBI32, // F1 VRAM contigua: palabra de 32 bits (para el sprite en F2)
    output reg  [7:0]  PRAMDBO,
    // F3 command cache: escritura de PALABRA con mascara (solo accesos del cache, PRAMWIDE=1)
    output reg  [31:0] PRAMDBO32,
    output reg  [3:0]  PRAMWMASK,   // polaridad DQM: 0=escribe byte, 1=enmascara
    output reg         PRAMWIDE,

    input  wire        VDPSPEEDMODE,
    input  wire [2:0]  RATIOMODE,
    input  wire        CENTERYJK_R25_N,

    // VIDEO OUTPUT
    output wire [5:0]  PVIDEOR,
    output wire [5:0]  PVIDEOG,
    output wire [5:0]  PVIDEOB,

    output wire        PVIDEOHS_N,
    output wire        PVIDEOVS_N,
    output wire        PVIDEOCS_N,

    output wire        PVIDEODHCLK,
    output wire        PVIDEODLCLK,

    output wire        BLANK_O,

    input  wire        DISPRESO,      // 0=15kHz, 1=31kHz

    input  wire        NTSC_PAL_TYPE,
    input  wire        FORCED_V_MODE,
    input  wire        LEGACY_VGA,

    input  wire [4:0]  VDP_ID,
    input  wire [6:0]  OFFSET_Y,

    output wire        HDMI_RESET,
    output wire        PAL_MODE,
    input  wire        SPMAXSPR,
    output wire [10:0] CX,
    output wire [10:0] CY
);

`include "vdp_package.vh"

    // CLOCKS por linea, dependiente de PAL (antes SHARED VARIABLE)
    wire [11:0] CLOCKS_PER_LINE = (VDPR9PALMODE == 1'b1) ? 12'd1728 : 12'd1716;

    localparam [2:0]
        VRAM_ACCESS_IDLE = 3'd0,
        VRAM_ACCESS_DRAW = 3'd1,
        VRAM_ACCESS_CPUW = 3'd2,
        VRAM_ACCESS_CPUR = 3'd3,
        VRAM_ACCESS_SPRT = 3'd4,
        VRAM_ACCESS_VDPW = 3'd5,
        VRAM_ACCESS_VDPR = 3'd6,
        VRAM_ACCESS_VDPS = 3'd7;

    wire [10:0] H_CNT;
    wire [10:0] H_CNT_IN_FIELD;
    wire [10:0] V_CNT;

    wire [1:0]  DOTSTATE;
    wire [2:0]  EIGHTDOTSTATE;

    wire        FIELD;
    wire        HD;
    wire        VD;
    reg         ACTIVE_LINE;
    wire        V_BLANKING_START;

    wire        VSYNCINT_N;
    wire        CLR_VSYNC_INT;
    wire        REQ_VSYNC_INT_N;
    wire        HSYNCINT_N;
    wire        CLR_HSYNC_INT;
    wire        REQ_HSYNC_INT_N;
    // V9968: command-end interrupt
    wire        CMDINT_N;
    wire        CLR_CMD_INT;
    wire        REQ_CMD_INT_N;

    wire        WINDOW;
    wire        WINDOW_X;
    reg         PREWINDOW_X;
    wire        PREWINDOW_Y;
    wire        PREWINDOW_Y_SP;
    wire        PREWINDOW;
    reg         BWINDOW_X;
    reg         BWINDOW_Y;
    reg         BWINDOW;

    wire [8:0]  PREDOTCOUNTER_X;
    wire [8:0]  PREDOTCOUNTER_Y;
    wire [8:0]  PREDOTCOUNTER_YP;

    reg  [17:0] VDPVRAMACCESSADDR;    // 18 bits: A17 (R#14) = acceso CPU a 256K
    wire        DISPMODEVGA;
    reg         VDPVRAMREADINGR;
    reg         VDPVRAMREADINGA;
    wire [7:0]  VDPVRAMACCESSDATA;
    wire [17:0] VDPVRAMACCESSADDRTMP;
    wire        VDPVRAMADDRSETREQ;
    reg         VDPVRAMADDRSETACK;
    wire        VDPVRAMWRREQ;
    reg         VDPVRAMWRACK;
    reg  [7:0]  VDPVRAMRDDATA;
    wire        VDPVRAMRDREQ;
    reg         VDPVRAMRDACK;
    wire        VDPR9PALMODE;

    wire        REG_R0_HSYNC_INT_EN;
    wire        REG_R1_SP_SIZE;
    wire        REG_R1_SP_ZOOM;
    wire        REG_R1_BL_CLKS;
    wire        REG_R1_VSYNC_INT_EN;
    wire        REG_R1_DISP_ON;
    wire [7:0]  REG_R2_PT_NAM_ADDR;   // 8 bits: bit7 = A17 display (VRAM 256K)
    wire [5:0]  REG_R4_PT_GEN_ADDR;
    wire [10:0] REG_R10R3_COL_ADDR;
    wire [10:0] REG_R11R5_SP_ATR_ADDR;   // bit10 = A17 (mode3)
    wire [6:0]  REG_R6_SP_GEN_ADDR;      // bit6  = A17 (mode3)
    wire [7:0]  REG_R7_FRAME_COL;
    wire        REG_R8_SP_OFF;
    wire        REG_R8_COL0_ON;
    wire        REG_R9_PAL_MODE;
    wire        REG_R9_INTERLACE_MODE;
    wire        REG_R9_Y_DOTS;
    wire [7:0]  REG_R12_BLINK_MODE;
    wire [7:0]  REG_R13_BLINK_PERIOD;
    wire [7:0]  REG_R18_ADJ;
    wire [7:0]  REG_R19_HSYNC_INT_LINE;
    wire [7:0]  REG_R23_VSTART_LINE;
    wire        REG_R25_CMD;
    wire        REG_R25_YAE;
    wire        REG_R25_YJK;
    wire        REG_R25_MSK;
    wire        REG_R25_SHUFFLE;
    wire        REG_R25_SP2;
    wire [8:3]  REG_R26_H_SCROLL;
    wire [2:0]  REG_R27_H_SCROLL;

    // V9968 EXTENSIONS
    wire        REG_R20_HS;
    wire        REG_R20_SVNS;
    wire        REG_R20_ILNS;
    wire        REG_R20_EPAL;
    wire        REG_R20_CEIE;
    wire        REG_R20_S16;
    wire        REG_R21_V9958_MODE;
    wire        W_V9968_MODE = ~REG_R21_V9958_MODE;
    // nonR23 efectivos (solo en modo V9968)
    wire        W_SP_NONR23   = REG_R20_SVNS & W_V9968_MODE;
    wire        W_ILINE_NONR23 = REG_R20_ILNS & W_V9968_MODE;
    // sprite priority shuffle efectivo (solo en modo V9968)
    wire        W_SP_SHUFFLE  = REG_R25_SHUFFLE & W_V9968_MODE;
    // extended palette efectivo (solo en modo V9968)
    wire        W_EXT_PALETTE = REG_R20_EPAL & W_V9968_MODE;
    // sprite16 efectivo (solo en modo V9968): 16 sprites por linea
    wire        W_SP16 = REG_R20_S16 & W_V9968_MODE;
    // sprite mode3 efectivo (solo en modo V9968): pipeline paralelo dot-by-dot
    wire        REG_R20_SM3;
    wire        W_SM3 = REG_R20_SM3 & W_V9968_MODE;
    // Interleave G6/G7 del V9938 (SCREEN 7/8/12): byte logico N -> fisico {N&1, N>>1}.
    // Es VISIBLE al software (escribir en G7 y leer/mostrar en otro modo reordena los bytes;
    // F1 Spirit depende de ello). Se implementa como swizzle de direccion sobre la VRAM
    // lineal en TODOS los caminos (CPU, comando, sprite, display), igual que la referencia
    // V9968 (vdp_vram_interface.v:200-202), y como alli se desactiva con sprite mode3
    // (semantica V9968 nueva = lineal; DEVCON no se ve afectado).
    wire        W_VRAM_ILV;
    // señales del pipeline mode3 (VDP_SPRITE_M3)
    wire        M3ACCESSING_YT;
    wire        M3ACCESSING_FT;
    wire [17:0] PRAMADRM3;
    wire        SM3_COLOR_EN;
    wire [7:0]  SM3_COLOR;
    wire [1:0]  SM3_TRANSP;

    wire        TEXT_MODE;
    wire        VDPMODETEXT1;
    wire        VDPMODETEXT1Q;
    wire        VDPMODETEXT2;
    wire        VDPMODEMULTI;
    wire        VDPMODEMULTIQ;
    wire        VDPMODEGRAPHIC1;
    wire        VDPMODEGRAPHIC2;
    wire        VDPMODEGRAPHIC3;
    wire        VDPMODEGRAPHIC4;
    wire        VDPMODEGRAPHIC5;
    wire        VDPMODEGRAPHIC6;
    wire        VDPMODEGRAPHIC7;
    wire        VDPMODEISHIGHRES;
    wire        VDPMODEISVRAMINTERLEAVE;
    assign      W_VRAM_ILV = (VDPMODEGRAPHIC6 | VDPMODEGRAPHIC7) & ~W_SM3;

    wire [16:0] PRAMADRT12;
    wire [3:0]  COLORCODET12;
    wire        TXVRAMREADEN;

    wire [16:0] PRAMADRG123M;
    wire [3:0]  COLORCODEG123M;

    wire [17:0] PRAMADRG4567;   // 18 bits (VRAM 256K, A17 display)
    wire [7:0]  COLORCODEG4567;
    wire [5:0]  YJK_R;
    wire [5:0]  YJK_G;
    wire [5:0]  YJK_B;
    wire        YJK_EN;

    wire        SPMODE2;
    wire        SPVRAMACCESSING;
    wire [16:0] PRAMADRSPRITE;
    wire        SPRITECOLOROUT;
    wire [3:0]  COLORCODESPRITE;
    // Colision: el motor serie (modos 1/2) y el pipeline mode3 (B3) generan cada uno su
    // incidencia+X+Y; se muxan por W_SM3 hacia vdp_register. Overmap (S#0 bit6) no se muxea
    // en B3: en mode3 el motor serie esta apagado, asi que no reporta overmap (gap conocido).
    wire        VDPS0SPCOLLISIONINCIDENCE_S12;   // motor serie
    wire [8:0]  VDPS3S4SPCOLLISIONX_S12;
    wire [8:0]  VDPS5S6SPCOLLISIONY_S12;
    wire        M3_COLL;                          // pipeline mode3
    wire [8:0]  M3_COLL_X;
    wire [8:0]  M3_COLL_Y;
    wire        VDPS0SPCOLLISIONINCIDENCE = W_SM3 ? M3_COLL   : VDPS0SPCOLLISIONINCIDENCE_S12;
    wire [8:0]  VDPS3S4SPCOLLISIONX       = W_SM3 ? M3_COLL_X : VDPS3S4SPCOLLISIONX_S12;
    wire [8:0]  VDPS5S6SPCOLLISIONY       = W_SM3 ? M3_COLL_Y : VDPS5S6SPCOLLISIONY_S12;
    wire        VDPS0SPOVERMAPPED;
    wire [4:0]  VDPS0SPOVERMAPPEDNUM;
    wire        SPVDPS0RESETREQ;
    wire        SPVDPS0RESETACK;
    wire        SPVDPS5RESETREQ;
    wire        SPVDPS5RESETACK;

    wire [7:0]  PALETTEADDR_OUT;   // V9968: 8 bits (256 entradas)
    wire [7:0]  PALETTEDATARB_OUT;
    wire [7:0]  PALETTEDATAG_OUT;
    wire [7:0]  PALETTEADDR_BG;    // mode3 alpha-blend: indice de fondo (2a lectura)
    wire [7:0]  PALETTEDATARB_BG;
    wire [7:0]  PALETTEDATAG_BG;

    wire [7:0]  VDPCMDCLR;
    wire        VDPCMDCE;
    wire        VDPCMDBD;
    wire        VDPCMDTR;
    wire [10:0] VDPCMDSXTMP;

    wire [4:0]  VDPCMDREGNUM;
    wire [7:0]  VDPCMDREGDATA;
    wire        VDPCMDREGWRACK;
    wire        VDPCMDTRCLRACK;
    reg         VDPCMDVRAMWRACK;
    reg         VDPCMDVRAMRDACK;
    reg         VDPCMDVRAMREADINGR;
    reg         VDPCMDVRAMREADINGA;
    reg  [7:0]  VDPCMDVRAMRDDATA;
    wire        VDPCMDREGWRREQ;
    wire        VDPCMDTRCLRREQ;
    wire        VDPCMDVRAMWRREQ;
    wire        VDPCMDVRAMRDREQ;
    wire [17:0] VDPCMDVRAMACCESSADDR;   // 18 bits (motor de comandos con bit17)
    wire [7:0]  VDPCMDVRAMWRDATA;

    reg         VDP_COMMAND_DRIVE;
    wire        VDP_COMMAND_ACTIVE;

    // ================= F3: COMMAND CACHE (Hara V9968) — adaptador shim =================
    // Activo SOLO en modo V9968 (W_CACHE_EN); en modo V9958 bypass total: el motor habla
    // con el arbitro exactamente como siempre (timing legacy identico, riesgo cero).
    // Con cache: el motor conserva su protocolo toggle REQ/ACK y el adaptador lo traduce
    // al valid/ready/rdata_en del cache; el lado VRAM del cache usa los mismos slots del
    // arbitro (VDPW/VDPR) pero con accesos de PALABRA (PRAMWIDE + PRAMDBO32 + PRAMWMASK).
    // start = flanco de subida de CE (limpia el cache); flush = flanco de caida de CE
    // (vuelca lineas sucias; el gate del arbitro se mantiene abierto con W_CC_VVALID).
    // Coherencia: los accesos VRAM del CPU por puerto DURANTE un comando no ven las
    // lineas sucias del cache (igual que el V9968 real); el flush en CE=0 aterriza todo
    // ordenes de magnitud antes de que el Z80 pueda leer resultados.
    // GATING con R#20 HS: el pacing V9958 autentico (vdp_wait_control) actua reteniendo
    // acks via arbitro; el adaptador del cache lo puentearia. Activando el cache SOLO con
    // HS se conserva la semantica del chip: sin HS = ritmo V9958 exacto (bypass), con HS
    // = maxima velocidad (cache + wait_control ya desbloqueado por VDPSPEEDMODE|HS).
    wire        W_CACHE_EN = W_V9968_MODE & REG_R20_HS;

    // lado motor (protocolo toggle replicado)
    reg         FF_CC_WRACK;
    reg         FF_CC_RDACK;
    reg  [7:0]  FF_CC_RDDATA;
    reg         FF_CC_INFLIGHT;    // lectura aceptada por el cache, esperando rdata_en
    reg         FF_CC_CE_D;        // CE retrasado (deteccion de flancos)
    // lado cache <-> arbitro
    wire [17:0] W_CC_VADDR;
    wire        W_CC_VVALID;
    wire        W_CC_VWRITE;
    wire [31:0] W_CC_VWDATA;
    wire [3:0]  W_CC_VWMASK;
    reg         FF_CC_VREADY;      // pulso 1 clk: acceso del cache aceptado por el arbitro
    reg  [31:0] FF_CC_VRDATA32;    // palabra leida para el cache
    reg         FF_CC_VRDATA_EN;   // pulso 1 clk
    // motor -> cache
    wire        w_cc_ready;
    wire [7:0]  w_cc_rdata;
    wire        w_cc_rdata_en;
    wire        w_cc_wr_pend    = W_CACHE_EN & (VDPCMDVRAMWRREQ != FF_CC_WRACK);
    wire        w_cc_rd_pend    = W_CACHE_EN & (VDPCMDVRAMRDREQ != FF_CC_RDACK);
    wire        w_cc_req_valid  = (w_cc_wr_pend | w_cc_rd_pend) & ~FF_CC_INFLIGHT;
    // pendientes hacia el arbitro (mux cache/bypass)
    wire        W_CMD_WR_PEND = W_CACHE_EN ? (W_CC_VVALID &  W_CC_VWRITE)
                                           : (VDPCMDVRAMWRREQ != VDPCMDVRAMWRACK);
    wire        W_CMD_RD_PEND = W_CACHE_EN ? (W_CC_VVALID & ~W_CC_VWRITE)
                                           : (VDPCMDVRAMRDREQ != VDPCMDVRAMRDACK);

    // Solo V9968: sin el define, W_CACHE_EN es constante 0 (bypass total) y el motor de
    // comandos habla directo con el arbitro (timing legacy V9958). Se poda todo el cache.
`ifdef ENABLE_V9968
    vdp_command_cache U_CMD_CACHE (
        .reset_n                 (~RESET),
        .clk                     (CLK21M),
        .start                   (W_CACHE_EN & VDPCMDCE & ~FF_CC_CE_D),
        .cache_vram_address      (VDPCMDVRAMACCESSADDR),
        .cache_vram_valid        (w_cc_req_valid),
        .cache_vram_ready        (w_cc_ready),
        .cache_vram_write        (w_cc_wr_pend),
        .cache_vram_wdata        (VDPCMDVRAMWRDATA),
        .cache_vram_rdata        (w_cc_rdata),
        .cache_vram_rdata_en     (w_cc_rdata_en),
        .cache_flush_start       (W_CACHE_EN & ~VDPCMDCE & FF_CC_CE_D),
        .cache_flush_end         (),
        .command_vram_address    (W_CC_VADDR),
        .command_vram_valid      (W_CC_VVALID),
        .command_vram_ready      (FF_CC_VREADY),
        .command_vram_write      (W_CC_VWRITE),
        .command_vram_wdata      (W_CC_VWDATA),
        .command_vram_wdata_mask (W_CC_VWMASK),
        .command_vram_rdata      (FF_CC_VRDATA32),
        .command_vram_rdata_en   (FF_CC_VRDATA_EN)
    );
`else
    assign w_cc_ready   = 1'b0;
    assign w_cc_rdata   = 8'b0;
    assign w_cc_rdata_en= 1'b0;
    assign W_CC_VADDR   = 18'b0;
    assign W_CC_VVALID  = 1'b0;
    assign W_CC_VWRITE  = 1'b0;
    assign W_CC_VWDATA  = 32'b0;
    assign W_CC_VWMASK  = 4'b0;
`endif

    // adaptador lado motor: traduce toggles REQ/ACK <-> valid/ready/rdata_en
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_CC_WRACK    <= 1'b0;
            FF_CC_RDACK    <= 1'b0;
            FF_CC_RDDATA   <= 8'b0;
            FF_CC_INFLIGHT <= 1'b0;
            FF_CC_CE_D     <= 1'b0;
        end else begin
            FF_CC_CE_D <= VDPCMDCE;
            if (w_cc_req_valid == 1'b1 && w_cc_ready == 1'b1) begin
                if (w_cc_wr_pend == 1'b1)
                    FF_CC_WRACK <= VDPCMDVRAMWRREQ;   // write: aceptado = completado
                else
                    FF_CC_INFLIGHT <= 1'b1;           // read: esperar rdata_en
            end
            if (w_cc_rdata_en == 1'b1) begin
                FF_CC_RDDATA   <= w_cc_rdata;
                FF_CC_RDACK    <= VDPCMDVRAMRDREQ;
                FF_CC_INFLIGHT <= 1'b0;
            end
        end
    end
    // ====================================================================================
    wire [7:4]  CUR_VDP_COMMAND;

    wire [5:0]  IVIDEOR;
    wire [5:0]  IVIDEOG;
    wire [5:0]  IVIDEOB;
    wire [5:0]  IVIDEOR_VDP;
    wire [5:0]  IVIDEOG_VDP;
    wire [5:0]  IVIDEOB_VDP;
    wire        IVIDEOVS_N;
    wire [5:0]  IVIDEOR_NTSC_PAL;
    wire [5:0]  IVIDEOG_NTSC_PAL;
    wire [5:0]  IVIDEOB_NTSC_PAL;
    wire        IVIDEOHS_N_NTSC_PAL;
    wire        IVIDEOVS_N_NTSC_PAL;
    wire [5:0]  IVIDEOR_VGA;
    wire [5:0]  IVIDEOG_VGA;
    wire [5:0]  IVIDEOB_VGA;
    wire        IVIDEOHS_N_VGA;
    wire        IVIDEOVS_N_VGA;

    reg  [17:0] IRAMADR;   // 18 bits (VRAM 256K)
    wire [7:0]  PRAMDAT;
    wire        XRAMSEL;
    wire [7:0]  PRAMDATPAIR;

    wire        HSYNC;
    wire        ENAHSYNC;

    // Variables del proceso arbitro (blocking)
    reg  [17:0] VDPVRAMACCESSADDRV;   // 18 bits: A17 (R#14) = acceso CPU a 256K
    reg  [2:0]  VRAMACCESSSWITCH;

    // Condicion de recarga de PREWINDOW_X (OFFSET_X + LED_TV_X {+4} - {~CENTER,00})
    // 49 + (-20) = 29 ; +4 = 33   (LED_TV_X_NTSC == LED_TV_X_PAL == -20)
    wire [10:0] W_HCMP_C4  = {2'b00, (7'd33 - {2'b00, ~CENTERYJK_R25_N, 2'b00}), 2'b10};
    wire [10:0] W_HCMP_NO4 = {2'b00, (7'd29 - {2'b00, ~CENTERYJK_R25_N, 2'b00}), 2'b10};
    wire        W_PREWIN_HOLD = ((H_CNT == W_HCMP_C4)  && (REG_R25_YJK == 1'b1) && (CENTERYJK_R25_N == 1'b1)) ||
                                ((H_CNT == W_HCMP_NO4) && ((REG_R25_YJK == 1'b0) || (CENTERYJK_R25_N == 1'b0)));

    //---------------------------------------------------------------
    assign CX          = H_CNT;
    assign CY          = V_CNT;
    assign PAL_MODE    = VDPR9PALMODE;

    // bit17 solo activo en modo V9968 (= reg_vram256k_mode). En modo V9958 => 128K intacto.
    assign PRAMADR     = {IRAMADR[17] & W_V9968_MODE, IRAMADR[16:0]};
    assign XRAMSEL     = IRAMADR[16];   // (vestigial tras F1)
    // F1 VRAM contigua: memory.v selecciona en el read-latch (con vram_addr[1:0], estable por diseno)
    // y entrega el par {byte@X+1, byte@X}: PRAMDAT = byte pedido [7:0]; PRAMDATPAIR = byte adyacente
    // [15:8] (el display lo usa en G6/G7 para el par par/impar, que ahora es ADYACENTE, no {X,X+64K}).
    assign PRAMDAT     = PRAMDBI[ 7: 0];
    assign PRAMDATPAIR = PRAMDBI[15: 8];

    //---------------------------------------------------------------
    // DISPLAY COMPONENTS
    //---------------------------------------------------------------
    assign DISPMODEVGA  = DISPRESO;
    assign VDPR9PALMODE = (NTSC_PAL_TYPE == 1'b1) ? REG_R9_PAL_MODE : FORCED_V_MODE;

    assign IVIDEOR = IVIDEOR_VDP;
    assign IVIDEOG = IVIDEOG_VDP;
    assign IVIDEOB = IVIDEOB_VDP;

    VDP_NTSC_PAL U_VDP_NTSC_PAL (
        .CLK21M        (CLK21M),
        .RESET         (RESET),
        .PALMODE       (VDPR9PALMODE),
        .INTERLACEMODE (REG_R9_INTERLACE_MODE),
        .VIDEORIN      (IVIDEOR),
        .VIDEOGIN      (IVIDEOG),
        .VIDEOBIN      (IVIDEOB),
        .VIDEOVSIN_N   (IVIDEOVS_N),
        .HCOUNTERIN    (H_CNT),
        .VCOUNTERIN    (V_CNT),
        .VIDEOROUT     (IVIDEOR_NTSC_PAL),
        .VIDEOGOUT     (IVIDEOG_NTSC_PAL),
        .VIDEOBOUT     (IVIDEOB_NTSC_PAL),
        .VIDEOHSOUT_N  (IVIDEOHS_N_NTSC_PAL),
        .VIDEOVSOUT_N  (IVIDEOVS_N_NTSC_PAL)
    );

    VDP_VGA U_VDP_VGA (
        .CLK21M        (CLK21M),
        .RESET         (RESET),
        .VIDEORIN      (IVIDEOR),
        .VIDEOGIN      (IVIDEOG),
        .VIDEOBIN      (IVIDEOB),
        .VIDEOVSIN_N   (IVIDEOVS_N),
        .HCOUNTERIN    (H_CNT),
        .VCOUNTERIN    (V_CNT),
        .PALMODE       (VDPR9PALMODE),
        .INTERLACEMODE (REG_R9_INTERLACE_MODE),
        .LEGACY_VGA    (LEGACY_VGA),
        .VIDEOROUT     (IVIDEOR_VGA),
        .VIDEOGOUT     (IVIDEOG_VGA),
        .VIDEOBOUT     (IVIDEOB_VGA),
        .VIDEOHSOUT_N  (IVIDEOHS_N_VGA),
        .VIDEOVSOUT_N  (IVIDEOVS_N_VGA),
        .BLANK_O       (BLANK_O),
        .RATIOMODE     (RATIOMODE)
    );

    // CHANGE DISPLAY MODE BY EXTERNAL INPUT PORT
    assign PVIDEOR    = (DISPMODEVGA == 1'b0) ? IVIDEOR_NTSC_PAL : IVIDEOR_VGA;
    assign PVIDEOG    = (DISPMODEVGA == 1'b0) ? IVIDEOG_NTSC_PAL : IVIDEOG_VGA;
    assign PVIDEOB    = (DISPMODEVGA == 1'b0) ? IVIDEOB_NTSC_PAL : IVIDEOB_VGA;
    assign PVIDEOHS_N = (DISPMODEVGA == 1'b0) ? IVIDEOHS_N_NTSC_PAL : IVIDEOHS_N_VGA;
    assign PVIDEOVS_N = (DISPMODEVGA == 1'b0) ? IVIDEOVS_N_NTSC_PAL : IVIDEOVS_N_VGA;
    assign PVIDEOCS_N = ~(IVIDEOHS_N_NTSC_PAL ^ IVIDEOVS_N_NTSC_PAL);

    //---------------------------------------------------------------
    // INTERRUPT
    //---------------------------------------------------------------
    assign VSYNCINT_N = (REG_R1_VSYNC_INT_EN == 1'b0) ? 1'b1 : REQ_VSYNC_INT_N;
    assign HSYNCINT_N = (REG_R0_HSYNC_INT_EN == 1'b0 || ENAHSYNC == 1'b0) ? 1'b1 : REQ_HSYNC_INT_N;
    // V9968: command-end interrupt (solo en modo V9968 y con CEIE=R#20.6)
    // DIAGNOSTICO (revertir): fuerzo CMDINT_N=1 para descartar tormenta de IRQ de fin de comando.
    // Original: (REG_R20_CEIE == 1'b0 || W_V9968_MODE == 1'b0) ? 1'b1 : REQ_CMD_INT_N;
    assign CMDINT_N   = 1'b1;
    assign INT_N      = (VSYNCINT_N == 1'b0 || HSYNCINT_N == 1'b0 || CMDINT_N == 1'b0) ? 1'b0 : 1'b1;

    VDP_INTERRUPT U_INTERRUPT (
        .RESET                  (RESET),
        .CLK21M                 (CLK21M),
        .H_CNT                  (H_CNT),
        .Y_CNT                  (W_ILINE_NONR23 ? PREDOTCOUNTER_YP[7:0] : PREDOTCOUNTER_Y[7:0]),
        .ACTIVE_LINE            (ACTIVE_LINE),
        .V_BLANKING_START       (V_BLANKING_START),
        .CLR_VSYNC_INT          (CLR_VSYNC_INT),
        .CLR_HSYNC_INT          (CLR_HSYNC_INT),
        .REQ_VSYNC_INT_N        (REQ_VSYNC_INT_N),
        .REQ_HSYNC_INT_N        (REQ_HSYNC_INT_N),
        .REG_R19_HSYNC_INT_LINE (REG_R19_HSYNC_INT_LINE),
        .CMD_CE                 (VDPCMDCE),
        .CLR_CMD_INT            (CLR_CMD_INT),
        .REQ_CMD_INT_N          (REQ_CMD_INT_N)
    );

    always @(posedge CLK21M) begin
        if (PREDOTCOUNTER_X == 255+25 || PREDOTCOUNTER_X == 9'b111111111)
            ACTIVE_LINE <= 1'b1;
        else
            ACTIVE_LINE <= 1'b0;
    end

    //---------------------------------------------------------------
    // SYNCHRONOUS SIGNAL GENERATOR
    //---------------------------------------------------------------
    VDP_SSG U_SSG (
        .RESET                 (RESET),
        .CLK21M                (CLK21M),
        .H_CNT                 (H_CNT),
        .H_CNT_IN_FIELD        (H_CNT_IN_FIELD),
        .V_CNT                 (V_CNT),
        .DOTSTATE              (DOTSTATE),
        .EIGHTDOTSTATE         (EIGHTDOTSTATE),
        .PREDOTCOUNTER_X       (PREDOTCOUNTER_X),
        .PREDOTCOUNTER_Y       (PREDOTCOUNTER_Y),
        .PREDOTCOUNTER_YP      (PREDOTCOUNTER_YP),
        .PREWINDOW_Y           (PREWINDOW_Y),
        .PREWINDOW_Y_SP        (PREWINDOW_Y_SP),
        .FIELD                 (FIELD),
        .WINDOW_X              (WINDOW_X),
        .PVIDEODHCLK           (PVIDEODHCLK),
        .PVIDEODLCLK           (PVIDEODLCLK),
        .IVIDEOVS_N            (IVIDEOVS_N),
        .HD                    (HD),
        .VD                    (VD),
        .HSYNC                 (HSYNC),
        .ENAHSYNC              (ENAHSYNC),
        .V_BLANKING_START      (V_BLANKING_START),
        .VDPR9PALMODE          (VDPR9PALMODE),
        .REG_R9_INTERLACE_MODE (REG_R9_INTERLACE_MODE),
        .REG_R9_Y_DOTS         (REG_R9_Y_DOTS),
        .REG_R18_ADJ           (REG_R18_ADJ),
        .REG_R23_VSTART_LINE   (REG_R23_VSTART_LINE),
        .REG_R25_MSK           (REG_R25_MSK),
        .REG_R27_H_SCROLL      (REG_R27_H_SCROLL),
        .REG_R25_YJK           (REG_R25_YJK),
        .CENTERYJK_R25_N       (CENTERYJK_R25_N),
        .OFFSET_Y              (OFFSET_Y),
        .HDMI_RESET            (HDMI_RESET)
    );

    // GENERATE BWINDOW
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            BWINDOW_X <= 1'b0;
        else begin
            if (H_CNT == 200)
                BWINDOW_X <= 1'b1;
            else if (H_CNT == CLOCKS_PER_LINE - 1 - 1)
                BWINDOW_X <= 1'b0;
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            BWINDOW_Y <= 1'b0;
        else begin
            if (REG_R9_INTERLACE_MODE == 1'b0) begin
                // NON-INTERLACE
                if ((V_CNT == 20*2) ||
                    ((V_CNT == 524+20*2) && (VDPR9PALMODE == 1'b0)) ||
                    ((V_CNT == 626+20*2) && (VDPR9PALMODE == 1'b1)))
                    BWINDOW_Y <= 1'b1;
                else if (((V_CNT == 524) && (VDPR9PALMODE == 1'b0)) ||
                         ((V_CNT == 626) && (VDPR9PALMODE == 1'b1)) ||
                          (V_CNT == 0))
                    BWINDOW_Y <= 1'b0;
            end else begin
                // INTERLACE (+1 por el retardo de medio linea del campo impar)
                if ((V_CNT == 20*2) ||
                    ((V_CNT == 525+20*2 + 1) && (VDPR9PALMODE == 1'b0)) ||
                    ((V_CNT == 625+20*2 + 1) && (VDPR9PALMODE == 1'b1)))
                    BWINDOW_Y <= 1'b1;
                else if (((V_CNT == 525) && (VDPR9PALMODE == 1'b0)) ||
                         ((V_CNT == 625) && (VDPR9PALMODE == 1'b1)) ||
                          (V_CNT == 0))
                    BWINDOW_Y <= 1'b0;
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            BWINDOW <= 1'b0;
        else
            BWINDOW <= BWINDOW_X & BWINDOW_Y;
    end

    // GENERATE PREWINDOW, WINDOW
    assign WINDOW    = WINDOW_X    & PREWINDOW_Y;
    assign PREWINDOW = PREWINDOW_X & PREWINDOW_Y;

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            PREWINDOW_X <= 1'b0;
        else begin
            if (W_PREWIN_HOLD) begin
                // HOLD
            end else if (H_CNT[1:0] == 2'b10) begin
                if (PREDOTCOUNTER_X == 9'b111111111)
                    PREWINDOW_X <= 1'b1;
                else if (PREDOTCOUNTER_X == 9'b011111111)
                    PREWINDOW_X <= 1'b0;
            end
        end
    end

    //---------------------------------------------------------------
    // VRAM read data latch
    //---------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            VDPVRAMRDDATA   <= 8'b0;
            VDPVRAMREADINGA <= 1'b0;
        end else begin
            if (DOTSTATE == 2'b01) begin
                if (VDPVRAMREADINGR != VDPVRAMREADINGA) begin
                    VDPVRAMRDDATA   <= PRAMDAT;
                    VDPVRAMREADINGA <= ~VDPVRAMREADINGA;
                end
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            VDPCMDVRAMRDDATA   <= 8'b0;
            VDPCMDVRAMRDACK    <= 1'b0;
            VDPCMDVRAMREADINGA <= 1'b0;
            FF_CC_VRDATA32     <= 32'b0;
            FF_CC_VRDATA_EN    <= 1'b0;
        end else begin
            FF_CC_VRDATA_EN <= 1'b0;   // pulso de 1 clk
            if (DOTSTATE == 2'b01) begin
                if (VDPCMDVRAMREADINGR != VDPCMDVRAMREADINGA) begin
                    VDPCMDVRAMRDDATA   <= PRAMDAT;
                    // F3: la misma lectura entrega la PALABRA completa al cache. Misma
                    // geometria de captura que PRAMDAT (dato en t+6/7, captura t+8):
                    // requiere la cota honesta en el SDC (vram_dout_32 -> FF_CC_VRDATA32).
                    FF_CC_VRDATA32     <= PRAMDBI32;
                    FF_CC_VRDATA_EN    <= W_CACHE_EN;
                    VDPCMDVRAMRDACK    <= ~VDPCMDVRAMRDACK;
                    VDPCMDVRAMREADINGA <= ~VDPCMDVRAMREADINGA;
                end
            end
        end
    end

    assign TEXT_MODE = VDPMODETEXT1 | VDPMODETEXT1Q | VDPMODETEXT2;

    //---------------------------------------------------------------
    // MAIN PROCESS - VRAM ACCESS ARBITER
    //---------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            IRAMADR            <= 18'h3FFFF;
            PRAMDBO            <= 8'bzzzzzzzz;
            PRAMOE_N           <= 1'b1;
            PRAMWE_N           <= 1'b1;
            VDPVRAMREADINGR    <= 1'b0;
            VDPVRAMRDACK       <= 1'b0;
            VDPVRAMWRACK       <= 1'b0;
            VDPVRAMADDRSETACK  <= 1'b0;
            VDPVRAMACCESSADDR  <= 18'b0;
            VDPCMDVRAMWRACK    <= 1'b0;
            VDPCMDVRAMREADINGR <= 1'b0;
            VDP_COMMAND_DRIVE  <= 1'b0;
            PRAMDBO32          <= 32'b0;
            PRAMWMASK          <= 4'b1111;
            PRAMWIDE           <= 1'b0;
            FF_CC_VREADY       <= 1'b0;
        end else begin
            // F3: FF_CC_VREADY es un pulso de 1 clk (solo lo levantan las ramas VDPW/VDPR,
            // que se ejecutan unicamente en el flanco de arbitraje DS10).
            FF_CC_VREADY <= 1'b0;
            // VRAM ACCESS ARBITER (gobernado por EIGHTDOTSTATE)
            if (DOTSTATE == 2'b10) begin
                if ((PREWINDOW == 1'b1) && (REG_R1_DISP_ON == 1'b1) &&
                    ((EIGHTDOTSTATE == 3'b000) || (EIGHTDOTSTATE == 3'b001) || (EIGHTDOTSTATE == 3'b010) ||
                     (EIGHTDOTSTATE == 3'b011) || (EIGHTDOTSTATE == 3'b100)))
                    VRAMACCESSSWITCH = VRAM_ACCESS_DRAW;                       // EIGHTDOTSTATE 0..4, display
                else if ((PREWINDOW == 1'b1) && (REG_R1_DISP_ON == 1'b1) && (TXVRAMREADEN == 1'b1))
                    VRAMACCESSSWITCH = VRAM_ACCESS_DRAW;                       // 5..7, display, text
                else if ((PREWINDOW_X == 1'b1) && (PREWINDOW_Y_SP == 1'b1) && (SPVRAMACCESSING == 1'b1) &&
                         (EIGHTDOTSTATE == 3'b101) && (TEXT_MODE == 1'b0))
                    VRAMACCESSSWITCH = VRAM_ACCESS_SPRT;                       // SPRITE Y-TESTING
                else if ((PREWINDOW_X == 1'b0) && (PREWINDOW_Y_SP == 1'b1) && (SPVRAMACCESSING == 1'b1) &&
                         (TEXT_MODE == 1'b0) &&
                         ((EIGHTDOTSTATE == 3'b000) || (EIGHTDOTSTATE == 3'b001) || (EIGHTDOTSTATE == 3'b010) ||
                          (EIGHTDOTSTATE == 3'b011) || (EIGHTDOTSTATE == 3'b100) || (EIGHTDOTSTATE == 3'b101)))
                    VRAMACCESSSWITCH = VRAM_ACCESS_SPRT;                       // SPRITE PREPARING
                else if ((PREWINDOW_X == 1'b1) && (PREWINDOW_Y_SP == 1'b1) && (M3ACCESSING_YT == 1'b1) &&
                         (TEXT_MODE == 1'b0) &&
                         ((EIGHTDOTSTATE == 3'b101) || (EIGHTDOTSTATE == 3'b110)))
                    VRAMACCESSSWITCH = VRAM_ACCESS_SPRT;                       // MODE3 Y-TEST F2 (slots {5,6}: 1 palabra/plano, 64 planos; el terminador y==216 los devuelve pronto a los comandos)
                else if ((PREWINDOW_X == 1'b0) && (PREWINDOW_Y_SP == 1'b1) && (M3ACCESSING_FT == 1'b1) &&
                         (TEXT_MODE == 1'b0) && (EIGHTDOTSTATE != 3'b111))
                    VRAMACCESSSWITCH = VRAM_ACCESS_SPRT;                       // MODE3 FETCH (slots 0..6)
                else if (VDPVRAMWRREQ != VDPVRAMWRACK)
                    VRAMACCESSSWITCH = VRAM_ACCESS_CPUW;                       // VRAM WRITE BY CPU
                else if (VDPVRAMRDREQ != VDPVRAMRDACK)
                    VRAMACCESSSWITCH = VRAM_ACCESS_CPUR;                       // VRAM READ BY CPU
                else begin
                    // VDP COMMAND
                    // F3: con cache, los pendientes vienen del lado VRAM del cache (accesos de
                    // palabra); el gate se mantiene abierto mientras el cache tenga trabajo
                    // (p.ej. flush de lineas sucias tras caer CE, cuando ACTIVE ya es 0).
                    if (VDP_COMMAND_ACTIVE == 1'b1 || (W_CACHE_EN == 1'b1 && W_CC_VVALID == 1'b1)) begin
                        if (W_CMD_WR_PEND == 1'b1)
                            VRAMACCESSSWITCH = VRAM_ACCESS_VDPW;
                        else if (W_CMD_RD_PEND == 1'b1)
                            VRAMACCESSSWITCH = VRAM_ACCESS_VDPR;
                        else
                            VRAMACCESSSWITCH = VRAM_ACCESS_VDPS;
                    end else
                        VRAMACCESSSWITCH = VRAM_ACCESS_VDPS;
                end
            end else begin
                VRAMACCESSSWITCH = VRAM_ACCESS_DRAW;
            end

            if (VRAMACCESSSWITCH == VRAM_ACCESS_VDPW ||
                VRAMACCESSSWITCH == VRAM_ACCESS_VDPR ||
                VRAMACCESSSWITCH == VRAM_ACCESS_VDPS)
                VDP_COMMAND_DRIVE <= 1'b1;
            else
                VDP_COMMAND_DRIVE <= 1'b0;

            // VRAM ACCESS ADDRESS SWITCH
            if (VRAMACCESSSWITCH == VRAM_ACCESS_CPUW) begin
                // VRAM WRITE BY CPU
                // Interleave V9938 en G6/G7 (swizzle sobre VRAM lineal; visible al software).
                // A17 (bit17, R#14) va en la cima del swizzle -> acceso CPU a 256K.
                IRAMADR <= (W_VRAM_ILV == 1'b1) ? {VDPVRAMACCESSADDR[17], VDPVRAMACCESSADDR[0], VDPVRAMACCESSADDR[16:1]}
                                                : VDPVRAMACCESSADDR;
                if ((VDPMODETEXT1 == 1'b1) || (VDPMODETEXT1Q == 1'b1) || (VDPMODEMULTI == 1'b1) || (VDPMODEMULTIQ == 1'b1) ||
                    (VDPMODEGRAPHIC1 == 1'b1) || (VDPMODEGRAPHIC2 == 1'b1))
                    VDPVRAMACCESSADDR[13:0] <= VDPVRAMACCESSADDR[13:0] + 1'b1;
                else
                    VDPVRAMACCESSADDR <= VDPVRAMACCESSADDR + 1'b1;
                PRAMDBO      <= VDPVRAMACCESSDATA;
                PRAMWIDE     <= 1'b0;   // F3: escritura de BYTE clasica (nunca wide en CPU)
                PRAMOE_N     <= 1'b1;
                PRAMWE_N     <= 1'b0;
                VDPVRAMWRACK <= ~VDPVRAMWRACK;
            end else if (VRAMACCESSSWITCH == VRAM_ACCESS_CPUR) begin
                // VRAM READ BY CPU
                if (VDPVRAMADDRSETREQ != VDPVRAMADDRSETACK) begin
                    VDPVRAMACCESSADDRV = VDPVRAMACCESSADDRTMP;
                    VDPVRAMADDRSETACK <= ~VDPVRAMADDRSETACK;
                end else begin
                    VDPVRAMACCESSADDRV = VDPVRAMACCESSADDR;
                end
                // Interleave V9938 en G6/G7 (swizzle sobre VRAM lineal; visible al software).
                // A17 (bit17, R#14) va en la cima del swizzle -> acceso CPU a 256K.
                IRAMADR <= (W_VRAM_ILV == 1'b1) ? {VDPVRAMACCESSADDRV[17], VDPVRAMACCESSADDRV[0], VDPVRAMACCESSADDRV[16:1]}
                                                : VDPVRAMACCESSADDRV;
                if ((VDPMODETEXT1 == 1'b1) || (VDPMODETEXT1Q == 1'b1) || (VDPMODEMULTI == 1'b1) || (VDPMODEMULTIQ == 1'b1) ||
                    (VDPMODEGRAPHIC1 == 1'b1) || (VDPMODEGRAPHIC2 == 1'b1))
                    VDPVRAMACCESSADDR[13:0] <= VDPVRAMACCESSADDRV[13:0] + 1'b1;
                else
                    VDPVRAMACCESSADDR <= VDPVRAMACCESSADDRV + 1'b1;
                PRAMDBO         <= 8'bzzzzzzzz;
                PRAMOE_N        <= 1'b0;
                PRAMWE_N        <= 1'b1;
                VDPVRAMRDACK    <= ~VDPVRAMRDACK;
                VDPVRAMREADINGR <= ~VDPVRAMREADINGA;
            end else if (VRAMACCESSSWITCH == VRAM_ACCESS_VDPW) begin
                // VRAM WRITE BY VDP COMMAND
                // Interleave V9938 en G6/G7 para el comando clasico. F3: con cache (solo
                // V9968), acceso de PALABRA enmascarada lineal (PRAMWIDE=1).
                IRAMADR <= (W_CACHE_EN == 1'b1) ? W_CC_VADDR :
                           (W_VRAM_ILV == 1'b1) ? {VDPCMDVRAMACCESSADDR[17], VDPCMDVRAMACCESSADDR[0], VDPCMDVRAMACCESSADDR[16:1]}
                                                : VDPCMDVRAMACCESSADDR;
                PRAMDBO         <= VDPCMDVRAMWRDATA;
                PRAMDBO32       <= W_CC_VWDATA;
                PRAMWMASK       <= W_CC_VWMASK;
                PRAMWIDE        <= W_CACHE_EN;
                PRAMOE_N        <= 1'b1;
                PRAMWE_N        <= 1'b0;
                VDPCMDVRAMWRACK <= ~VDPCMDVRAMWRACK;   // legacy (inofensivo con cache)
                FF_CC_VREADY    <= W_CACHE_EN;         // ack de 1 clk hacia el cache
            end else if (VRAMACCESSSWITCH == VRAM_ACCESS_VDPR) begin
                // VRAM READ BY VDP COMMAND
                // Interleave V9938 en G6/G7 para el comando clasico. F3: con cache, lectura
                // de palabra lineal (vuelve por PRAMDBI32 y se captura para el cache).
                IRAMADR <= (W_CACHE_EN == 1'b1) ? W_CC_VADDR :
                           (W_VRAM_ILV == 1'b1) ? {VDPCMDVRAMACCESSADDR[17], VDPCMDVRAMACCESSADDR[0], VDPCMDVRAMACCESSADDR[16:1]}
                                                : VDPCMDVRAMACCESSADDR;
                PRAMDBO            <= 8'bzzzzzzzz;
                PRAMOE_N           <= 1'b0;
                PRAMWE_N           <= 1'b1;
                VDPCMDVRAMREADINGR <= ~VDPCMDVRAMREADINGA;
                FF_CC_VREADY       <= W_CACHE_EN;      // ack de 1 clk hacia el cache
            end else if (VRAMACCESSSWITCH == VRAM_ACCESS_SPRT) begin
                // VRAM READ BY SPRITE MODULE (motor serie o pipeline mode3)
                // Interleave V9938 en G6/G7 tambien para SAT/patrones del motor serie
                // (referencia: vdp_vram_interface.v:201). Mode3 (V9968) siempre lineal.
                IRAMADR  <= (W_SM3 == 1'b1)      ? PRAMADRM3 :
                            (W_VRAM_ILV == 1'b1) ? {1'b0, PRAMADRSPRITE[0], PRAMADRSPRITE[16:1]}
                                                 : {1'b0, PRAMADRSPRITE};
                PRAMOE_N <= 1'b0;
                PRAMWE_N <= 1'b1;
                PRAMDBO  <= 8'bzzzzzzzz;
            end else begin
                // VRAM_ACCESS_DRAW - lectura para construir la imagen
                case (DOTSTATE)
                    2'b10: begin
                        PRAMDBO  <= 8'bzzzzzzzz;
                        PRAMOE_N <= 1'b0;
                        PRAMWE_N <= 1'b1;
                        if (TEXT_MODE == 1'b1)
                            IRAMADR <= PRAMADRT12;
                        else if ((VDPMODEGRAPHIC1 == 1'b1) || (VDPMODEGRAPHIC2 == 1'b1) ||
                                 (VDPMODEGRAPHIC3 == 1'b1) || (VDPMODEMULTI == 1'b1) || (VDPMODEMULTIQ == 1'b1))
                            IRAMADR <= PRAMADRG123M;
                        else if ((VDPMODEGRAPHIC4 == 1'b1) || (VDPMODEGRAPHIC5 == 1'b1) ||
                                 (VDPMODEGRAPHIC6 == 1'b1) || (VDPMODEGRAPHIC7 == 1'b1))
                            IRAMADR <= PRAMADRG4567;
                    end
                    2'b01: begin
                        PRAMDBO  <= 8'bzzzzzzzz;
                        PRAMOE_N <= 1'b0;
                        PRAMWE_N <= 1'b1;
                        if ((VDPMODEGRAPHIC6 == 1'b1) || (VDPMODEGRAPHIC7 == 1'b1))
                            // Reemision historica del mismo PRAMADR (la memoria sirve un
                            // acceso VDP por dot; esta 2a emision no tiene burst propio).
                            IRAMADR <= PRAMADRG4567;
                    end
                    default: ;
                endcase

                if ((DOTSTATE == 2'b11) && (VDPVRAMADDRSETREQ != VDPVRAMADDRSETACK)) begin
                    VDPVRAMACCESSADDR <= VDPVRAMACCESSADDRTMP;
                    VDPVRAMADDRSETACK <= ~VDPVRAMADDRSETACK;
                end
            end
        end
    end

    //---------------------------------------------------------------
    // COLOR DECODING
    //---------------------------------------------------------------
    VDP_COLORDEC U_VDP_COLORDEC (
        .RESET             (RESET),
        .CLK21M            (CLK21M),
        .DOTSTATE          (DOTSTATE),
        .PPALETTEADDR_OUT  (PALETTEADDR_OUT),
        .PALETTEDATARB_OUT (PALETTEDATARB_OUT),
        .PALETTEDATAG_OUT  (PALETTEDATAG_OUT),
        .PPALETTEADDR_BG   (PALETTEADDR_BG),
        .PALETTEDATARB_BG  (PALETTEDATARB_BG),
        .PALETTEDATAG_BG   (PALETTEDATAG_BG),
        .VDPMODETEXT1      (VDPMODETEXT1),
        .VDPMODETEXT1Q     (VDPMODETEXT1Q),
        .VDPMODETEXT2      (VDPMODETEXT2),
        .VDPMODEMULTI      (VDPMODEMULTI),
        .VDPMODEMULTIQ     (VDPMODEMULTIQ),
        .VDPMODEGRAPHIC1   (VDPMODEGRAPHIC1),
        .VDPMODEGRAPHIC2   (VDPMODEGRAPHIC2),
        .VDPMODEGRAPHIC3   (VDPMODEGRAPHIC3),
        .VDPMODEGRAPHIC4   (VDPMODEGRAPHIC4),
        .VDPMODEGRAPHIC5   (VDPMODEGRAPHIC5),
        .VDPMODEGRAPHIC6   (VDPMODEGRAPHIC6),
        .VDPMODEGRAPHIC7   (VDPMODEGRAPHIC7),
        .WINDOW            (WINDOW),
        .SPRITECOLOROUT    (SPRITECOLOROUT),
        .COLORCODET12      (COLORCODET12),
        .COLORCODEG123M    (COLORCODEG123M),
        .COLORCODEG4567    (COLORCODEG4567),
        .COLORCODESPRITE   (COLORCODESPRITE),
        .P_YJK_R           (YJK_R),
        .P_YJK_G           (YJK_G),
        .P_YJK_B           (YJK_B),
        .P_YJK_EN          (YJK_EN),
        .PVIDEOR_VDP       (IVIDEOR_VDP),
        .PVIDEOG_VDP       (IVIDEOG_VDP),
        .PVIDEOB_VDP       (IVIDEOB_VDP),
        .REG_R1_DISP_ON    (REG_R1_DISP_ON),
        .REG_R7_FRAME_COL  (REG_R7_FRAME_COL),
        .REG_R8_COL0_ON    (REG_R8_COL0_ON),
        .REG_R25_YJK       (REG_R25_YJK),
        .EXT_PALETTE       (W_EXT_PALETTE),
        .SM3_COLOR_EN      (SM3_COLOR_EN),
        .SM3_COLOR         (SM3_COLOR),
        .SM3_TRANSP        (SM3_TRANSP)
    );

    //---------------------------------------------------------------
    // MAKE COLOR CODE
    //---------------------------------------------------------------
    VDP_TEXT12 U_VDP_TEXT12 (
        .CLK21M               (CLK21M),
        .RESET                (RESET),
        .DOTSTATE             (DOTSTATE),
        .DOTCOUNTERX          (PREDOTCOUNTER_X),
        .DOTCOUNTERY          (PREDOTCOUNTER_Y),
        .DOTCOUNTERYP         (PREDOTCOUNTER_YP),
        .VDPMODETEXT1         (VDPMODETEXT1),
        .VDPMODETEXT1Q        (VDPMODETEXT1Q),
        .VDPMODETEXT2         (VDPMODETEXT2),
        .REG_R1_BL_CLKS       (REG_R1_BL_CLKS),
        .REG_R7_FRAME_COL     (REG_R7_FRAME_COL),
        .REG_R12_BLINK_MODE   (REG_R12_BLINK_MODE),
        .REG_R13_BLINK_PERIOD (REG_R13_BLINK_PERIOD),
        .REG_R2_PT_NAM_ADDR   (REG_R2_PT_NAM_ADDR[6:0]),   // text: sin A17
        .REG_R4_PT_GEN_ADDR   (REG_R4_PT_GEN_ADDR),
        .REG_R10R3_COL_ADDR   (REG_R10R3_COL_ADDR),
        .PRAMDAT              (PRAMDAT),
        .PRAMADR              (PRAMADRT12),
        .TXVRAMREADEN         (TXVRAMREADEN),
        .PCOLORCODE           (COLORCODET12)
    );

    VDP_GRAPHIC123M U_VDP_GRAPHIC123M (
        .CLK21M             (CLK21M),
        .RESET              (RESET),
        .DOTSTATE           (DOTSTATE),
        .EIGHTDOTSTATE      (EIGHTDOTSTATE),
        .DOTCOUNTERX        (PREDOTCOUNTER_X),
        .DOTCOUNTERY        (PREDOTCOUNTER_Y),
        .VDPMODEMULTI       (VDPMODEMULTI),
        .VDPMODEMULTIQ      (VDPMODEMULTIQ),
        .VDPMODEGRAPHIC1    (VDPMODEGRAPHIC1),
        .VDPMODEGRAPHIC2    (VDPMODEGRAPHIC2),
        .VDPMODEGRAPHIC3    (VDPMODEGRAPHIC3),
        .REG_R2_PT_NAM_ADDR (REG_R2_PT_NAM_ADDR[6:0]),   // G123M: sin A17
        .REG_R4_PT_GEN_ADDR (REG_R4_PT_GEN_ADDR),
        .REG_R10R3_COL_ADDR (REG_R10R3_COL_ADDR),
        .REG_R26_H_SCROLL   (REG_R26_H_SCROLL),
        .REG_R27_H_SCROLL   (REG_R27_H_SCROLL),
        .PRAMDAT            (PRAMDAT),
        .PRAMADR            (PRAMADRG123M),
        .PCOLORCODE         (COLORCODEG123M)
    );

    VDP_GRAPHIC4567 U_VDP_GRAPHIC4567 (
        .CLK21M              (CLK21M),
        .RESET               (RESET),
        .DOTSTATE            (DOTSTATE),
        .EIGHTDOTSTATE       (EIGHTDOTSTATE),
        .DOTCOUNTERX         (PREDOTCOUNTER_X),
        .DOTCOUNTERY         (PREDOTCOUNTER_Y),
        .VDPMODEGRAPHIC4     (VDPMODEGRAPHIC4),
        .VDPMODEGRAPHIC5     (VDPMODEGRAPHIC5),
        .VDPMODEGRAPHIC6     (VDPMODEGRAPHIC6),
        .VDPMODEGRAPHIC7     (VDPMODEGRAPHIC7),
        .VRAM_INTERLEAVE     (W_VRAM_ILV),
        .REG_R1_BL_CLKS      (REG_R1_BL_CLKS),
        .REG_R2_PT_NAM_ADDR  (REG_R2_PT_NAM_ADDR),
        .REG_R13_BLINK_PERIOD(REG_R13_BLINK_PERIOD),
        .REG_R26_H_SCROLL    (REG_R26_H_SCROLL),
        .REG_R27_H_SCROLL    (REG_R27_H_SCROLL),
        .REG_R25_YAE         (REG_R25_YAE),
        .REG_R25_YJK         (REG_R25_YJK),
        .REG_R25_SP2         (REG_R25_SP2),
        .PRAMDAT             (PRAMDAT),
        .PRAMDATPAIR         (PRAMDATPAIR),
        .PRAMADR             (PRAMADRG4567),
        .PCOLORCODE          (COLORCODEG4567),
        .P_YJK_R             (YJK_R),
        .P_YJK_G             (YJK_G),
        .P_YJK_B             (YJK_B),
        .P_YJK_EN            (YJK_EN)
    );

    //---------------------------------------------------------------
    // SPRITE MODULE
    //---------------------------------------------------------------
    VDP_SPRITE U_SPRITE (
        .CLK21M                     (CLK21M),
        .RESET                      (RESET),
        .DOTSTATE                   (DOTSTATE),
        .EIGHTDOTSTATE              (EIGHTDOTSTATE),
        .DOTCOUNTERX                (PREDOTCOUNTER_X),
        .DOTCOUNTERYP               (PREDOTCOUNTER_YP),
        .BWINDOW_Y                  (BWINDOW_Y),
        .PVDPS0SPCOLLISIONINCIDENCE (VDPS0SPCOLLISIONINCIDENCE_S12),
        .PVDPS0SPOVERMAPPED         (VDPS0SPOVERMAPPED),
        .PVDPS0SPOVERMAPPEDNUM      (VDPS0SPOVERMAPPEDNUM),
        .PVDPS3S4SPCOLLISIONX       (VDPS3S4SPCOLLISIONX_S12),
        .PVDPS5S6SPCOLLISIONY       (VDPS5S6SPCOLLISIONY_S12),
        .PVDPS0RESETREQ             (SPVDPS0RESETREQ),
        .PVDPS0RESETACK             (SPVDPS0RESETACK),
        .PVDPS5RESETREQ             (SPVDPS5RESETREQ),
        .PVDPS5RESETACK             (SPVDPS5RESETACK),
        .REG_R1_SP_SIZE             (REG_R1_SP_SIZE),
        .REG_R1_SP_ZOOM             (REG_R1_SP_ZOOM),
        .REG_R11R5_SP_ATR_ADDR      (REG_R11R5_SP_ATR_ADDR[9:0]),   // motor serie: 17 bits (sin A17)
        .REG_R6_SP_GEN_ADDR         (REG_R6_SP_GEN_ADDR[5:0]),
        .REG_R8_COL0_ON             (REG_R8_COL0_ON),
        // DIAGNOSTICO F1-Spirit (REVERTIR al terminar): boton S2 pulsado = motor serie
        // (sprites mode 1/2) APAGADO. Si los glitches desaparecen al pulsar, son sprites.
        .REG_R8_SP_OFF              (REG_R8_SP_OFF | W_SM3),
        .REG_R23_VSTART_LINE        (REG_R23_VSTART_LINE),
        .SP_NONR23                  (W_SP_NONR23),
        .SP_SHUFFLE                 (W_SP_SHUFFLE),
        .SP16                       (W_SP16),
        .REG_R27_H_SCROLL           (REG_R27_H_SCROLL),
        .SPMODE2                    (SPMODE2),
        .VRAMINTERLEAVEMODE         (VDPMODEISVRAMINTERLEAVE),
        .SPVRAMACCESSING            (SPVRAMACCESSING),
        .PRAMDAT                    (PRAMDAT),
        .PRAMADR                    (PRAMADRSPRITE),
        .SPCOLOROUT                 (SPRITECOLOROUT),
        .SPCOLORCODE                (COLORCODESPRITE),
        .REG_R9_Y_DOTS              (REG_R9_Y_DOTS),
        .SPMAXSPR                   (SPMAXSPR)
    );

    //---------------------------------------------------------------
    // V9968 SPRITE MODE3 (pipeline paralelo, gateado por W_SM3)
    // Solo V9968: sin el define se poda por completo (los M3ACCESSING quedan a 0 -> el
    // arbitro nunca concede slots mode3; SM3_COLOR_EN=0 -> colordec usa la ruta V9958).
    //---------------------------------------------------------------
`ifdef ENABLE_V9968
    VDP_SPRITE_M3 #(.SM3_PLANES(16), .SM3_SCAN(32)) U_SPRITE_M3 (   // F2: 16 = V9968 real
        .CLK21M                (CLK21M),
        .RESET                 (RESET),
        .DOTSTATE              (DOTSTATE),
        .EIGHTDOTSTATE         (EIGHTDOTSTATE),
        .DOTCOUNTERX           (PREDOTCOUNTER_X),
        .DOTCOUNTERYP          (PREDOTCOUNTER_YP),
        .BWINDOW_Y             (BWINDOW_Y),
        .SM3                   (W_SM3),
        .REG_R8_SP_OFF         (REG_R8_SP_OFF),
        .SP_NONR23             (W_SP_NONR23),
        .REG_R23_VSTART_LINE   (REG_R23_VSTART_LINE),
        .REG_R27_H_SCROLL      (REG_R27_H_SCROLL),
        .REG_R11R5_SP_ATR_ADDR (REG_R11R5_SP_ATR_ADDR),
        .REG_R6_SP_GEN_ADDR    (REG_R6_SP_GEN_ADDR),
        .PRAMDBI32             (PRAMDBI32),   // F2: palabra completa (word0/word1/patron)
        .M3ACCESSING_YT        (M3ACCESSING_YT),
        .M3ACCESSING_FT        (M3ACCESSING_FT),
        .PRAMADRM3             (PRAMADRM3),
        .SM3_COLOR_EN          (SM3_COLOR_EN),
        .SM3_COLOR             (SM3_COLOR),
        .SM3_TRANSP            (SM3_TRANSP),
        // COLISION mode3 (B3): reset req compartidos con el motor serie; salida muxada arriba
        .M3_S0RST_REQ          (SPVDPS0RESETREQ),
        .M3_S5RST_REQ          (SPVDPS5RESETREQ),
        .M3_COLL               (M3_COLL),
        .M3_COLL_X             (M3_COLL_X),
        .M3_COLL_Y             (M3_COLL_Y)
    );
`else
    assign M3ACCESSING_YT = 1'b0;
    assign M3ACCESSING_FT = 1'b0;
    assign PRAMADRM3      = 18'b0;
    assign SM3_COLOR_EN   = 1'b0;
    assign SM3_COLOR      = 8'b0;
    assign SM3_TRANSP     = 2'b0;
    assign M3_COLL        = 1'b0;   // sin mode3: la colision viene siempre del motor serie
    assign M3_COLL_X      = 9'b0;
    assign M3_COLL_Y      = 9'b0;
`endif

    //---------------------------------------------------------------
    // VDP REGISTER ACCESS
    //---------------------------------------------------------------
    VDP_REGISTER U_VDP_REGISTER (
        .RESET                     (RESET),
        .CLK21M                    (CLK21M),
        .REQ                       (REQ),
        .ACK                       (ACK),
        .WRT                       (WRT),
        .ADR                       (ADR),
        .DBI                       (DBI),
        .DBO                       (DBO),
        .DOTSTATE                  (DOTSTATE),
        .VDPCMDTRCLRACK            (VDPCMDTRCLRACK),
        .VDPCMDREGWRACK            (VDPCMDREGWRACK),
        .HSYNC                     (HSYNC),
        .VDPS0SPCOLLISIONINCIDENCE (VDPS0SPCOLLISIONINCIDENCE),
        .VDPS0SPOVERMAPPED         (VDPS0SPOVERMAPPED),
        .VDPS0SPOVERMAPPEDNUM      (VDPS0SPOVERMAPPEDNUM),
        .SPVDPS0RESETREQ           (SPVDPS0RESETREQ),
        .SPVDPS0RESETACK           (SPVDPS0RESETACK),
        .SPVDPS5RESETREQ           (SPVDPS5RESETREQ),
        .SPVDPS5RESETACK           (SPVDPS5RESETACK),
        .VDPCMDTR                  (VDPCMDTR),
        .VD                        (VD),
        .HD                        (HD),
        .VDPCMDBD                  (VDPCMDBD),
        .FIELD                     (FIELD),
        .VDPCMDCE                  (VDPCMDCE),
        .VDPS3S4SPCOLLISIONX       (VDPS3S4SPCOLLISIONX),
        .VDPS5S6SPCOLLISIONY       (VDPS5S6SPCOLLISIONY),
        .VDPCMDCLR                 (VDPCMDCLR),
        .VDPCMDSXTMP               (VDPCMDSXTMP),
        .VDPVRAMACCESSDATA         (VDPVRAMACCESSDATA),
        .VDPVRAMACCESSADDRTMP      (VDPVRAMACCESSADDRTMP),
        .VDPVRAMADDRSETREQ         (VDPVRAMADDRSETREQ),
        .VDPVRAMADDRSETACK         (VDPVRAMADDRSETACK),
        .VDPVRAMWRREQ              (VDPVRAMWRREQ),
        .VDPVRAMWRACK              (VDPVRAMWRACK),
        .VDPVRAMRDDATA             (VDPVRAMRDDATA),
        .VDPVRAMRDREQ              (VDPVRAMRDREQ),
        .VDPVRAMRDACK              (VDPVRAMRDACK),
        .VDPCMDREGNUM              (VDPCMDREGNUM),
        .VDPCMDREGDATA             (VDPCMDREGDATA),
        .VDPCMDREGWRREQ            (VDPCMDREGWRREQ),
        .VDPCMDTRCLRREQ            (VDPCMDTRCLRREQ),
        .PALETTEADDR_OUT           (PALETTEADDR_OUT),
        .PALETTEDATARB_OUT         (PALETTEDATARB_OUT),
        .PALETTEDATAG_OUT          (PALETTEDATAG_OUT),
        .PALETTEADDR_BG            (PALETTEADDR_BG),
        .PALETTEDATARB_BG          (PALETTEDATARB_BG),
        .PALETTEDATAG_BG           (PALETTEDATAG_BG),
        .CLR_VSYNC_INT             (CLR_VSYNC_INT),
        .CLR_HSYNC_INT             (CLR_HSYNC_INT),
        .REQ_VSYNC_INT_N           (REQ_VSYNC_INT_N),
        .REQ_HSYNC_INT_N           (REQ_HSYNC_INT_N),
        .CLR_CMD_INT               (CLR_CMD_INT),
        .REQ_CMD_INT_N             (REQ_CMD_INT_N),
        .REG_R0_HSYNC_INT_EN       (REG_R0_HSYNC_INT_EN),
        .REG_R1_SP_SIZE            (REG_R1_SP_SIZE),
        .REG_R1_SP_ZOOM            (REG_R1_SP_ZOOM),
        .REG_R1_BL_CLKS            (REG_R1_BL_CLKS),
        .REG_R1_VSYNC_INT_EN       (REG_R1_VSYNC_INT_EN),
        .REG_R1_DISP_ON            (REG_R1_DISP_ON),
        .REG_R2_PT_NAM_ADDR        (REG_R2_PT_NAM_ADDR),
        .REG_R4_PT_GEN_ADDR        (REG_R4_PT_GEN_ADDR),
        .REG_R10R3_COL_ADDR        (REG_R10R3_COL_ADDR),
        .REG_R11R5_SP_ATR_ADDR     (REG_R11R5_SP_ATR_ADDR),
        .REG_R6_SP_GEN_ADDR        (REG_R6_SP_GEN_ADDR),
        .REG_R7_FRAME_COL          (REG_R7_FRAME_COL),
        .REG_R8_SP_OFF             (REG_R8_SP_OFF),
        .REG_R8_COL0_ON            (REG_R8_COL0_ON),
        .REG_R9_PAL_MODE           (REG_R9_PAL_MODE),
        .REG_R9_INTERLACE_MODE     (REG_R9_INTERLACE_MODE),
        .REG_R9_Y_DOTS             (REG_R9_Y_DOTS),
        .REG_R12_BLINK_MODE        (REG_R12_BLINK_MODE),
        .REG_R13_BLINK_PERIOD      (REG_R13_BLINK_PERIOD),
        .REG_R18_ADJ               (REG_R18_ADJ),
        .REG_R19_HSYNC_INT_LINE    (REG_R19_HSYNC_INT_LINE),
        .REG_R23_VSTART_LINE       (REG_R23_VSTART_LINE),
        .REG_R25_CMD               (REG_R25_CMD),
        .REG_R25_YAE               (REG_R25_YAE),
        .REG_R25_YJK               (REG_R25_YJK),
        .REG_R25_MSK               (REG_R25_MSK),
        .REG_R25_SP2               (REG_R25_SP2),
        .REG_R25_SHUFFLE           (REG_R25_SHUFFLE),
        .REG_R26_H_SCROLL          (REG_R26_H_SCROLL),
        .REG_R27_H_SCROLL          (REG_R27_H_SCROLL),
        .REG_R20_HS                (REG_R20_HS),
        .REG_R20_SVNS              (REG_R20_SVNS),
        .REG_R20_ILNS              (REG_R20_ILNS),
        .REG_R20_SM3               (REG_R20_SM3),
        .REG_R20_EPAL              (REG_R20_EPAL),
        .REG_R20_CEIE              (REG_R20_CEIE),
        .REG_R20_S16               (REG_R20_S16),
        .REG_R21_V9958_MODE        (REG_R21_V9958_MODE),
        .VDPMODETEXT1              (VDPMODETEXT1),
        .VDPMODETEXT1Q             (VDPMODETEXT1Q),
        .VDPMODETEXT2              (VDPMODETEXT2),
        .VDPMODEMULTI              (VDPMODEMULTI),
        .VDPMODEMULTIQ             (VDPMODEMULTIQ),
        .VDPMODEGRAPHIC1           (VDPMODEGRAPHIC1),
        .VDPMODEGRAPHIC2           (VDPMODEGRAPHIC2),
        .VDPMODEGRAPHIC3           (VDPMODEGRAPHIC3),
        .VDPMODEGRAPHIC4           (VDPMODEGRAPHIC4),
        .VDPMODEGRAPHIC5           (VDPMODEGRAPHIC5),
        .VDPMODEGRAPHIC6           (VDPMODEGRAPHIC6),
        .VDPMODEGRAPHIC7           (VDPMODEGRAPHIC7),
        .VDPMODEISHIGHRES          (VDPMODEISHIGHRES),
        .SPMODE2                   (SPMODE2),
        .VDPMODEISVRAMINTERLEAVE   (VDPMODEISVRAMINTERLEAVE),
        .FORCED_V_MODE             (FORCED_V_MODE),
        .VDP_ID                    (VDP_ID)
    );

    //---------------------------------------------------------------
    // VDP COMMAND
    //---------------------------------------------------------------
    VDP_COMMAND U_VDP_COMMAND (
        .RESET            (RESET),
        .CLK21M           (CLK21M),
        .VDPMODEGRAPHIC4  (VDPMODEGRAPHIC4),
        .VDPMODEGRAPHIC5  (VDPMODEGRAPHIC5),
        .VDPMODEGRAPHIC6  (VDPMODEGRAPHIC6),
        .VDPMODEGRAPHIC7  (VDPMODEGRAPHIC7),
        .VDPMODEISHIGHRES (VDPMODEISHIGHRES),
        // F3: en modo cache el motor recibe los acks/datos del adaptador (rapidos, a ritmo
        // de hit); en modo V9958 los legacy del arbitro (bit-identico al comportamiento actual).
        .VRAMWRACK        (W_CACHE_EN ? FF_CC_WRACK  : VDPCMDVRAMWRACK),
        .VRAMRDACK        (W_CACHE_EN ? FF_CC_RDACK  : VDPCMDVRAMRDACK),
        .VRAMREADINGR     (VDPCMDVRAMREADINGR),
        .VRAMREADINGA     (VDPCMDVRAMREADINGA),
        .VRAMRDDATA       (W_CACHE_EN ? FF_CC_RDDATA : VDPCMDVRAMRDDATA),
        .REGWRREQ         (VDPCMDREGWRREQ),
        .TRCLRREQ         (VDPCMDTRCLRREQ),
        .REGNUM           (VDPCMDREGNUM),
        .REGDATA          (VDPCMDREGDATA),
        .PREGWRACK        (VDPCMDREGWRACK),
        .PTRCLRACK        (VDPCMDTRCLRACK),
        .PVRAMWRREQ       (VDPCMDVRAMWRREQ),
        .PVRAMRDREQ       (VDPCMDVRAMRDREQ),
        .PVRAMACCESSADDR  (VDPCMDVRAMACCESSADDR),
        .PVRAMWRDATA      (VDPCMDVRAMWRDATA),
        .PCLR             (VDPCMDCLR),
        .PCE              (VDPCMDCE),
        .PBD              (VDPCMDBD),
        .PTR              (VDPCMDTR),
        .PSXTMP           (VDPCMDSXTMP),
        .CUR_VDP_COMMAND  (CUR_VDP_COMMAND),
        .REG_R25_CMD      (REG_R25_CMD),
        .REG_R12          (REG_R12_BLINK_MODE),
        .MODE_V9968       (W_V9968_MODE)
    );

    VDP_WAIT_CONTROL U_VDP_WAIT_CONTROL (
        .RESET          (RESET),
        .CLK21M         (CLK21M),
        .VDP_COMMAND    (CUR_VDP_COMMAND),
        .VDPR9PALMODE   (VDPR9PALMODE),
        .REG_R1_DISP_ON (REG_R1_DISP_ON),
        .REG_R8_SP_OFF  (REG_R8_SP_OFF),
        .REG_R9_Y_DOTS  (REG_R9_Y_DOTS),
        .VDPSPEEDMODE   (VDPSPEEDMODE | (REG_R20_HS & W_V9968_MODE)),
        .DRIVE          (VDP_COMMAND_DRIVE),
        .ACTIVE         (VDP_COMMAND_ACTIVE)
    );

endmodule
