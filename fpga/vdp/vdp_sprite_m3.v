//
//  vdp_sprite_m3.v
//  V9968 sprite mode3: pipeline paralelo dot-by-dot (puerto adaptado del V9968
//  de Takayuki Hara: vdp_sprite_select_visible_planes / info_collect / makeup_pixel).
//
//  Arquitectura F2 (timing de 4 fases DOTSTATE a 27 MHz, bus VRAM de PALABRA
//  de 32 bits via PRAMDBI32, VRAM contigua F1):
//   - Y-TEST (linea activa, slots EIGHTDOTSTATE {5,6}): 1 lectura de PALABRA por
//     plano = word0 completo: y[9:0] REAL (10 bits, como el V9968), bit_shift,
//     mgy y flags de un golpe; se guardan en la lista y el fetch no los relee.
//     visible = offset10 < (mgy==0 ? 256 : mgy); terminador y==216 exacto.
//     Escanea SM3_SCAN=64 planos (V9968 real): 2 planos por grupo de 8 dots en
//     slots {5,6}; el terminador y==216 corta el scan (tipico: mucho antes).
//     Con terminador el scan acaba pronto y los slots vuelven a los comandos.
//   - FETCH (blanking-X, slots {0..6}): 3 lecturas de PALABRA por sprite:
//     word1 (x[9:0]+page+mgx+patron#) y patron en 2 palabras (16 px x 4bpp).
//     Divisor secuencial solapado con las lecturas: div1 (sample_y) arranca al
//     emitir word1 con datos de la lista; div2 (coeff=4096/mgx) tras word1.
//     ~9 dots/sprite -> 16 sprites en ~144 dots (ventana ~165). V9968 completo.
//   - RENDER (linea activa): slots evaluados EN PARALELO por dot;
//     sample_x = (offset_x * coeff) >> 8 (DSP por slot); nibble del patron;
//     dot=0 transparente; prioridad = slot de indice menor (orden de plano).
//     Salida {palette_set, dot} = indice de 8 bits a la paleta 256 (EPAL).
//
//  Limitaciones restantes:
//   - Modos interleave (G6/G7) no ajustados: direcciones lineales (DEVCON = G4).
//
module VDP_SPRITE_M3 #(
    parameter SM3_PLANES = 16,  // sprites por linea (F2: fetch de palabra, 3 lecturas/sprite -> caben 16 = V9968 real)
    parameter SM3_SCAN   = 64   // planos SAT escaneados (V9968 real; 1 palabra/plano, slots {5,6})
)(
    input  wire        CLK21M,           // en esta plataforma: 27 MHz
    input  wire        RESET,

    input  wire [1:0]  DOTSTATE,         // 00 -> 01 -> 11 -> 10
    input  wire [2:0]  EIGHTDOTSTATE,
    input  wire [8:0]  DOTCOUNTERX,
    input  wire [8:0]  DOTCOUNTERYP,
    input  wire        BWINDOW_Y,

    input  wire        SM3,              // gate: R#20.3 & modo V9968
    input  wire        REG_R8_SP_OFF,
    input  wire        SP_NONR23,
    input  wire [7:0]  REG_R23_VSTART_LINE,
    input  wire [2:0]  REG_R27_H_SCROLL,
    input  wire [10:0] REG_R11R5_SP_ATR_ADDR,  // SAT base = A17..A7
    input  wire [6:0]  REG_R6_SP_GEN_ADDR,     // patrones base = A17..A11

    // VRAM (a traves del arbitro, slots SPRT). F2: consumo de PALABRA completa.
    input  wire [31:0] PRAMDBI32,
    output wire        M3ACCESSING_YT,   // pide slots {5,6} en linea activa
    output wire        M3ACCESSING_FT,   // pide slots {0..6} en blanking
    output reg  [17:0] PRAMADRM3,

    // salida de video (fase identica a SPCOLOROUT del motor serie: reg en DOTSTATE 01)
    output reg         SM3_COLOR_EN,
    output reg  [7:0]  SM3_COLOR,
    output reg  [1:0]  SM3_TRANSP,       // 2 bits de transparencia (byte3[7:6]): 0/25/50/75%

    // COLISION mode3 (B3). El V9968 fuerza IC=CC=0 en mode3 (makeup_pixel:875-876), asi que
    // la colision es simplemente "2+ sprites con pixel opaco en el mismo dot". Se calcula en
    // el arbol de prioridad paralelo. Los req de reset (S#0/S#5) llegan de vdp_register via el
    // mismo toggle que consume el motor serie; aqui solo se OBSERVAN (el ack externo lo sigue
    // dando el motor serie, que tambien procesa el status en mode3).
    input  wire        M3_S0RST_REQ,     // toggle al leer S#0 -> limpia la incidencia
    input  wire        M3_S5RST_REQ,     // toggle al leer S#5 -> limpia X/Y
    output wire        M3_COLL,
    output wire [8:0]  M3_COLL_X,
    output wire [8:0]  M3_COLL_Y
);

    //-----------------------------------------------------------------------
    // Linea actual (identico al motor serie)
    //-----------------------------------------------------------------------
    reg  [8:0]  FF_CUR_Y;
    always @(posedge CLK21M) begin
        if ((DOTSTATE == 2'b01) && (DOTCOUNTERX == 0))
            FF_CUR_Y <= DOTCOUNTERYP + (SP_NONR23 ? 9'd0 : {1'b0, REG_R23_VSTART_LINE}) + 1'b1;
    end

    //-----------------------------------------------------------------------
    // Bases (latch por linea, como el motor serie)
    //-----------------------------------------------------------------------
    reg  [10:0] FF_ATRBASE;   // A17..A7
    reg  [6:0]  FF_GENBASE;   // A17..A11
    always @(posedge CLK21M) begin
        if ((DOTSTATE == 2'b01) && (DOTCOUNTERX == 0)) begin
            FF_ATRBASE <= REG_R11R5_SP_ATR_ADDR;
            FF_GENBASE <= REG_R6_SP_GEN_ADDR;
        end
    end

    // Direccion de atributo mode3 (formula EXACTA del V9968, select_visible_planes:136):
    //   {base[17:9], base[8:7] & plane[5:4], plane[3:0], idx[2:0]}  -> SAT de 64 planos x 8B
    function [17:0] F_ATTR_ADDR(input [5:0] plane, input [2:0] idx);
        F_ATTR_ADDR = {FF_ATRBASE[10:2], (FF_ATRBASE[1] & plane[5]),
                       (FF_ATRBASE[0] & plane[4]), plane[3:0], idx};
    endfunction

    //-----------------------------------------------------------------------
    // Y-TEST F2: SM3_SCAN=64 planos (V9968 real), 1 lectura de PALABRA por plano
    // (word0 completo) sobre los slots {5,6} (2 planos/grupo -> 64 en los 32
    // grupos de la linea; sin robar el slot {7} al motor de comandos). El
    // terminador y==216 corta el scan y devuelve los slots a los comandos.
    // La logica vive en el bloque grande (junto a PRAMADRM3/fetch).
    //-----------------------------------------------------------------------
    reg         FF_YT_ACT;                 // escaneo en curso
    reg  [6:0]  FF_YT_PLANE;               // plano 0..SM3_SCAN-1 (hasta 64)
    reg         FF_YT_PEND;                // lectura emitida pendiente de capturar
    reg  [5:0]  FF_LIST_COUNT;             // sprites listados (0..SM3_PLANES, hasta 16)

    // Lista de seleccionados (F2: word0 completo capturado en el Y-test; el fetch no
    // relee mgy/bit_shift/flags)
    reg  [5:0]  LIST_PLANE  [0:SM3_PLANES-1];   // plano 0..63
    reg  [7:0]  LIST_OFFS   [0:SM3_PLANES-1];   // offset_y (<256 garantizado por el test)
    reg  [1:0]  LIST_BSH    [0:SM3_PLANES-1];   // bit_shift (word0[15:14])
    reg  [7:0]  LIST_MGY    [0:SM3_PLANES-1];   // mgy (word0[23:16])
    reg  [7:0]  LIST_FLG    [0:SM3_PLANES-1];   // flags/palette_set (word0[31:24])

    // F2: test de visibilidad con word0 completo (Y de 10 bits REALES, como el V9968):
    //   offset10 = (linea - y) mod 1024 ; visible = offset10 < (mgy==0 ? 256 : mgy)
    wire [9:0]  w_yt_y      = PRAMDBI32[9:0];
    wire [1:0]  w_yt_bsh    = PRAMDBI32[15:14];
    wire [7:0]  w_yt_mgy    = PRAMDBI32[23:16];
    wire [7:0]  w_yt_flg    = PRAMDBI32[31:24];
    wire [9:0]  w_yt_offs10 = {1'b0, FF_CUR_Y} - w_yt_y;
    wire        w_yt_vis    = (w_yt_offs10 < ((w_yt_mgy == 8'd0) ? 10'd256 : {2'b00, w_yt_mgy}));

    assign M3ACCESSING_YT = FF_YT_ACT;

    //-----------------------------------------------------------------------
    // Divisor secuencial (restoring): NUM[15:0] / DEN[7:0] -> Q[15:0]
    //  div1: sample_y = (offset << (4+bshift)) / mgy   (mgy=0 -> shift, ver fetch)
    //  div2: coeff    = 4096 / mgx
    //  NUM de 16 bits: offset(8b)<<(4+bs) llega a 255<<7 = 32640
    //-----------------------------------------------------------------------
    reg         DIV_RUN;
    reg  [3:0]  DIV_CNT;
    reg  [15:0] DIV_Q;
    reg  [23:0] DIV_REM;      // {resto[7:0], num<<}
    reg  [7:0]  DIV_DEN;

    // arranque del divisor (pulso de 1 ciclo generado por la FSM de fetch)
    reg         W_DIV_START;
    reg  [15:0] W_DIV_NUM;
    reg  [7:0]  W_DIV_DEN;

    wire [23:0] W_DIV_SH  = {DIV_REM[22:0], 1'b0};
    wire [8:0]  W_DIV_SUB = {1'b0, W_DIV_SH[23:16]} - {1'b0, DIV_DEN};

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            DIV_RUN  <= 1'b0;
            DIV_CNT  <= 4'b0;
            DIV_Q    <= 16'b0;
            DIV_REM  <= 24'b0;
            DIV_DEN  <= 8'b0;
        end else begin
            if (W_DIV_START == 1'b1) begin
                DIV_RUN  <= 1'b1;
                DIV_CNT  <= 4'b0;
                DIV_Q    <= 16'b0;
                DIV_REM  <= {8'b0, W_DIV_NUM};
                DIV_DEN  <= W_DIV_DEN;
            end else if (DIV_RUN == 1'b1) begin
                if (W_DIV_SUB[8] == 1'b0) begin
                    DIV_REM <= {W_DIV_SUB[7:0], W_DIV_SH[15:0]};
                    DIV_Q   <= {DIV_Q[14:0], 1'b1};
                end else begin
                    DIV_REM <= W_DIV_SH;
                    DIV_Q   <= {DIV_Q[14:0], 1'b0};
                end
                if (DIV_CNT == 4'd15)
                    DIV_RUN <= 1'b0;
                DIV_CNT <= DIV_CNT + 1'b1;
            end
        end
    end

    //-----------------------------------------------------------------------
    // FETCH F2: 3 lecturas de PALABRA por sprite en blanking (slots EDS 0..6),
    // divisor solapado. mgy/bit_shift/flags vienen de la LISTA (Y-test).
    //-----------------------------------------------------------------------
    localparam [2:0] FP_W1    = 3'd0,   // word1 (x/page/mgx/patron#) + arranque div1
                     FP_WDIV1 = 3'd1,   // espera div1, cosecha sample_y, lanza div2
                     FP_PT0   = 3'd2,   // patron: palabra baja (bytes 0-3)
                     FP_PT1   = 3'd3,   // patron: palabra alta (bytes 4-7)
                     FP_LOAD  = 3'd4;   // espera div2, carga el slot, siguiente sprite

    reg         FF_FT_ACT;
    reg  [4:0]  FF_FT_SPR;       // indice de lista en curso
    reg  [2:0]  FF_FT_PH;        // fase FP_*
    reg         FF_FT_PEND;      // lectura emitida pendiente de capturar

    // registros temporales del sprite en curso (capturados de word1)
    reg  [9:0]  FT_X;
    reg  [2:0]  FT_PAGE;
    reg  [7:0]  FT_MGX;
    reg  [7:0]  FT_PNUM;
    reg  [6:0]  FT_SAMPLE_Y;     // resultado div1

    // datos del sprite en curso desde la LISTA (capturados en el Y-test)
    wire [7:0]  W_FT_OFFS   = LIST_OFFS  [FF_FT_SPR];
    wire [5:0]  W_FT_PLANE  = LIST_PLANE [FF_FT_SPR];
    wire [1:0]  W_FT_BSH    = LIST_BSH   [FF_FT_SPR];
    wire [7:0]  W_FT_MGY    = LIST_MGY   [FF_FT_SPR];
    wire [7:0]  W_FT_FLG    = LIST_FLG   [FF_FT_SPR];

    // sample_y con RVY y mascara por bit_shift (de la lista)
    wire [6:0]  W_YSEL  = W_FT_FLG[5] ? ~FT_SAMPLE_Y : FT_SAMPLE_Y;   // RVY = byte3 bit5
    wire [6:0]  W_YMASK = (W_FT_BSH == 2'd0) ? {3'b000, W_YSEL[3:0]} :
                          (W_FT_BSH == 2'd1) ? {2'b00,  W_YSEL[4:0]} :
                          (W_FT_BSH == 2'd2) ? {1'b0,   W_YSEL[5:0]} : W_YSEL;

    // DIAGNOSTICO de pagina de patron. font.bin (caracteres) esta en page 1;
    // usa.SC5 (fondo) en page 0. Deja UNA activa:
    //   SM3_FORCE_PAGE1: fuerza page 1 -> si los CONEJOS pasan a mostrar glifos de
    //     la fuente, esta ES legible en page 1 y el bug esta en el bit de pagina
    //     del SAT de los caracteres (o en el formato).
    //   SM3_FORCE_PAGE0: fuerza page 0 (leer usa.SC5).
//`define SM3_FORCE_PAGE2
//`define SM3_FORCE_PAGE1
//`define SM3_FORCE_PAGE0
`ifdef SM3_FORCE_PAGE2
    wire [2:0]  W_FT_PAGE = 3'd2;   // gen_base + 2*0x8000 = 0x18000 (font.bin ?)
`elsif SM3_FORCE_PAGE1
    wire [2:0]  W_FT_PAGE = 3'd1;   // 0x10000
`elsif SM3_FORCE_PAGE0
    wire [2:0]  W_FT_PAGE = 3'd0;   // 0x8000 (usa.SC5)
`else
    wire [2:0]  W_FT_PAGE = FT_PAGE;
`endif

    // DIAGNOSTICO de formato de patron. Descomenta para leer la fuente LINEAL
    // (glifo = 128 bytes consecutivos, filas de 8 bytes) en vez del empaquetado
    // entrelazado del V9968. Si con esto los CARACTERES salen como glifos legibles
    // (aunque los CONEJOS se rompan), font.bin es lineal -> ese es el formato.
//`define SM3_LINEAR_FONT
    // direccion del patron: {gen_base,11'0} + {patt_a, k[2:0]}
`ifdef SM3_LINEAR_FONT
    wire [14:0] W_PATT_A = {W_FT_PAGE, FT_PNUM, W_YMASK[3:0]};   // lineal: page*0x8000 + pnum*128 + y*8
`else
    wire [14:0] W_PATT_A = {FT_PNUM[7:4], 4'd0, FT_PNUM[3:0]} + {W_FT_PAGE, 1'b0, W_YMASK, 4'd0};
`endif
    // direccion de las 2 palabras del patron (16 px x 4bpp = 8 bytes, alineadas)
    wire [17:0] W_PT_ADDR = {FF_GENBASE, 11'd0} + {W_PATT_A, (FF_FT_PH == FP_PT1) ? 3'd4 : 3'd0};

    assign M3ACCESSING_FT = FF_FT_ACT;

    // slots de render (cargados al final del fetch de cada sprite)
    reg          SL_EN     [0:SM3_PLANES-1];
    reg  [9:0]   SL_X      [0:SM3_PLANES-1];
    reg  [7:0]   SL_MGX    [0:SM3_PLANES-1];
    reg  [12:0]  SL_COEF   [0:SM3_PLANES-1];
    reg  [3:0]   SL_PSET   [0:SM3_PLANES-1];
    reg          SL_RVX    [0:SM3_PLANES-1];
    reg  [1:0]   SL_TRANSP [0:SM3_PLANES-1];   // byte3[7:6]
    reg  [63:0]  SL_PAT    [0:SM3_PLANES-1];

    integer i;

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_YT_ACT     <= 1'b0;
            FF_YT_PLANE   <= 6'b0;
            FF_YT_PEND    <= 1'b0;
            FF_LIST_COUNT <= 6'b0;
            FF_FT_ACT   <= 1'b0;
            FF_FT_SPR   <= 5'b0;
            FF_FT_PH    <= FP_W1;
            FF_FT_PEND  <= 1'b0;
            W_DIV_START <= 1'b0;
            W_DIV_NUM   <= 16'b0;
            W_DIV_DEN   <= 8'b0;
            PRAMADRM3   <= 18'b0;
            for (i = 0; i < SM3_PLANES; i = i + 1)
                SL_EN[i] <= 1'b0;
        end else begin
            W_DIV_START <= 1'b0;   // pulso de 1 ciclo

            //================ Y-TEST F2 (linea activa, slot {5}) =============
            // 1 lectura de PALABRA por plano (word0 completo); el slot {6} queda
            // libre para el motor de comandos.
            // arranque de la linea
            if ((DOTSTATE == 2'b01) && (DOTCOUNTERX == 0)) begin
                FF_YT_ACT     <= SM3 & (~REG_R8_SP_OFF) & BWINDOW_Y;
                FF_YT_PLANE   <= 6'b0;
                FF_YT_PEND    <= 1'b0;
                FF_LIST_COUNT <= 6'b0;
            end else if (FF_YT_ACT == 1'b1) begin
                //---- emision (DOTSTATE 11, slot EDS 5, si no hay pendiente)
                if ((DOTSTATE == 2'b11) &&
                    ((EIGHTDOTSTATE == 3'b101) || (EIGHTDOTSTATE == 3'b110)) &&
                    (FF_YT_PLANE < SM3_SCAN) && (FF_YT_PEND == 1'b0)) begin
                    PRAMADRM3  <= F_ATTR_ADDR(FF_YT_PLANE[5:0], 3'd0);   // word0 (alineada)
                    FF_YT_PEND <= 1'b1;
                end
                //---- captura de word0 (DOTSTATE 01 del dot siguiente)
                if ((DOTSTATE == 2'b01) && (FF_YT_PEND == 1'b1)) begin
                    FF_YT_PEND <= 1'b0;
                    if (w_yt_y == 10'd216) begin
                        // Terminador de lista mode-3 (Y==216): oculta los planos restantes,
                        // como el V9968 real (w_finish_line, vdp_sprite_select_visible_planes).
                        // F2: comparacion EXACTA de 10 bits (Y=472/-40 ya no alias a 216).
                        FF_YT_ACT <= 1'b0;
                    end else begin
                        if (w_yt_vis == 1'b1 && FF_LIST_COUNT < SM3_PLANES) begin
                            LIST_PLANE [FF_LIST_COUNT[4:0]] <= FF_YT_PLANE[5:0];
                            LIST_OFFS  [FF_LIST_COUNT[4:0]] <= w_yt_offs10[7:0];  // <256 por el test
                            LIST_BSH   [FF_LIST_COUNT[4:0]] <= w_yt_bsh;
                            LIST_MGY   [FF_LIST_COUNT[4:0]] <= w_yt_mgy;
                            LIST_FLG   [FF_LIST_COUNT[4:0]] <= w_yt_flg;
                            FF_LIST_COUNT <= FF_LIST_COUNT + 1'b1;
                        end
                        if (FF_YT_PLANE == SM3_SCAN-1 ||
                            (w_yt_vis == 1'b1 && FF_LIST_COUNT == SM3_PLANES-1))
                            FF_YT_ACT <= 1'b0;   // fin (SM3_SCAN planos o lista llena)
                        FF_YT_PLANE <= FF_YT_PLANE + 1'b1;
                    end
                end
            end

            //---- arranque / fin de la fase de fetch --------------------------
            if ((DOTSTATE == 2'b10) && (DOTCOUNTERX == 256+8)) begin
                FF_FT_ACT  <= SM3 & (~REG_R8_SP_OFF) & BWINDOW_Y;
                FF_FT_SPR  <= 5'b0;
                FF_FT_PH   <= FP_W1;
                FF_FT_PEND <= 1'b0;
                // limpia los slots: los que no se carguen no se pintan
                for (i = 0; i < SM3_PLANES; i = i + 1)
                    SL_EN[i] <= 1'b0;
            end else if ((DOTSTATE == 2'b10) && (DOTCOUNTERX == 0)) begin
                FF_FT_ACT <= 1'b0;   // fuera de tiempo: fin de blanking
            end else if (FF_FT_ACT == 1'b1) begin
                if (FF_FT_SPR >= FF_LIST_COUNT || FF_FT_SPR == SM3_PLANES) begin
                    FF_FT_ACT <= 1'b0;   // todos los sprites listados procesados
                end

                case (FF_FT_PH)
                    //---- word1: x/page/mgx/patron# + arranque de div1 ---------
                    FP_W1: begin
                        if ((DOTSTATE == 2'b11) && (EIGHTDOTSTATE != 3'b111) &&
                            (FF_FT_SPR < FF_LIST_COUNT) && (FF_FT_PEND == 1'b0)) begin
                            PRAMADRM3  <= F_ATTR_ADDR(W_FT_PLANE, 3'd4);   // word1 (alineada)
                            FF_FT_PEND <= 1'b1;
                            // div1: sample_y = (offset << (4+bshift)) / mgy, con datos de la LISTA
                            if (W_FT_MGY == 8'd0)
                                // mgy=0 -> altura 256 (pot. de 2): sample_y = offset >> (4-bs)
                                FT_SAMPLE_Y <= W_FT_OFFS >> (3'd4 - {1'b0, W_FT_BSH});
                            else begin
                                W_DIV_START <= 1'b1;
                                W_DIV_NUM   <= {8'b0, W_FT_OFFS} << (4 + W_FT_BSH);
                                W_DIV_DEN   <= W_FT_MGY;
                            end
                        end
                        if ((DOTSTATE == 2'b01) && (FF_FT_PEND == 1'b1)) begin
                            FF_FT_PEND <= 1'b0;
                            FT_X    <= PRAMDBI32[9:0];
                            FT_PAGE <= PRAMDBI32[14:12];
                            FT_MGX  <= PRAMDBI32[23:16];
                            FT_PNUM <= PRAMDBI32[31:24];
                            if (PRAMDBI32[23:16] == 8'd0)
                                // mgx=0: sprite sin anchura -> saltar al siguiente
                                FF_FT_SPR <= FF_FT_SPR + 1'b1;
                            else
                                FF_FT_PH <= FP_WDIV1;
                        end
                    end
                    //---- espera div1, cosecha sample_y, lanza div2 ------------
                    FP_WDIV1: begin
                        if (DIV_RUN == 1'b0 && W_DIV_START == 1'b0) begin
                            if (W_FT_MGY != 8'd0)
                                FT_SAMPLE_Y <= (DIV_Q > 16'd127) ? 7'd127 : DIV_Q[6:0];
                            W_DIV_START <= 1'b1;   // div2 = 4096/mgx
                            W_DIV_NUM   <= 16'd4096;
                            W_DIV_DEN   <= FT_MGX;
                            FF_FT_PH    <= FP_PT0;
                        end
                    end
                    //---- patron: 2 palabras (bytes 0-3 y 4-7) -----------------
                    FP_PT0, FP_PT1: begin
                        if ((DOTSTATE == 2'b11) && (EIGHTDOTSTATE != 3'b111) &&
                            (FF_FT_PEND == 1'b0)) begin
                            PRAMADRM3  <= W_PT_ADDR;   // selecciona +0/+4 por FF_FT_PH
                            FF_FT_PEND <= 1'b1;
                        end
                        if ((DOTSTATE == 2'b01) && (FF_FT_PEND == 1'b1)) begin
                            FF_FT_PEND <= 1'b0;
                            // byte k del patron -> PAT[8k+7:8k]: palabra directa (little-endian)
                            if (FF_FT_PH == FP_PT0) begin
                                SL_PAT[FF_FT_SPR][31:0] <= PRAMDBI32;
                                FF_FT_PH <= FP_PT1;
                            end else begin
                                SL_PAT[FF_FT_SPR][63:32] <= PRAMDBI32;
                                FF_FT_PH <= FP_LOAD;
                            end
                        end
                    end
                    //---- espera div2 y carga el slot completo -----------------
                    FP_LOAD: begin
                        if (DIV_RUN == 1'b0 && W_DIV_START == 1'b0) begin
                            SL_EN    [FF_FT_SPR] <= 1'b1;
                            SL_X     [FF_FT_SPR] <= FT_X;
                            SL_MGX   [FF_FT_SPR] <= FT_MGX;
                            SL_COEF  [FF_FT_SPR] <= (DIV_Q > 16'd8191) ? 13'h1FFF : DIV_Q[12:0];
                            SL_PSET  [FF_FT_SPR] <= W_FT_FLG[3:0];
                            SL_RVX   [FF_FT_SPR] <= W_FT_FLG[4];
                            SL_TRANSP[FF_FT_SPR] <= W_FT_FLG[7:6];
                            FF_FT_SPR <= FF_FT_SPR + 1'b1;
                            FF_FT_PH  <= FP_W1;
                        end
                    end
                    default: FF_FT_PH <= FP_W1;
                endcase
            end
        end
    end

    //-----------------------------------------------------------------------
    // RENDER paralelo
    //  - contador X de display identico al motor serie (arranca en DCX==8 con R27)
    //  - etapa A (DOTSTATE 00): offset, enable, sample_x (multiplicacion) por slot
    //  - etapa B (DOTSTATE 01): nibble + prioridad + registro de salida
    //-----------------------------------------------------------------------
    reg  [7:0]  FF_DISP_X;
    reg         FF_WINX;
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_DISP_X <= 8'b0;
            FF_WINX   <= 1'b0;
        end else begin
            if (DOTSTATE == 2'b10) begin
                if (DOTCOUNTERX == 8) begin
                    FF_DISP_X <= {5'b00000, REG_R27_H_SCROLL};
                    FF_WINX   <= 1'b1;
                end else begin
                    FF_DISP_X <= FF_DISP_X + 1'b1;
                    if (FF_DISP_X == 8'hFF)
                        FF_WINX <= 1'b0;
                end
            end
        end
    end

    // nibble del patron: nibble alto primero dentro de cada byte (V9968 func_nibble_sel)
    function [3:0] F_NIBBLE(input [3:0] s, input [63:0] pat);
        F_NIBBLE = pat[{s[3:1], ~s[0], 2'b00} +: 4];
    endfunction

    // etapa A: registrada en DOTSTATE 00
    reg              ST_VIS [0:SM3_PLANES-1];
    reg  [3:0]       ST_SMP [0:SM3_PLANES-1];

    genvar g;
    generate
        for (g = 0; g < SM3_PLANES; g = g + 1) begin : g_slot
            wire [9:0]  w_off    = {2'b00, FF_DISP_X} - SL_X[g];
            wire        w_env    = SL_EN[g] & (w_off < {2'b00, SL_MGX[g]});
            wire [20:0] w_mul    = w_off[7:0] * SL_COEF[g];        // 8x13 -> DSP
            wire [12:0] w_smpraw = w_mul[20:8];
            wire [3:0]  w_smp    = (w_smpraw > 13'd15) ? 4'd15 : w_smpraw[3:0];
            wire [3:0]  w_smpx   = SL_RVX[g] ? ~w_smp : w_smp;

            always @(posedge CLK21M) begin
                if (DOTSTATE == 2'b00) begin
                    ST_VIS[g] <= w_env;
                    ST_SMP[g] <= w_smpx;
                end
            end
        end
    endgenerate

    // etapa B: prioridad (slot de indice menor gana) y salida en DOTSTATE 01.
    // w_two = 2+ slots con pixel opaco en este dot = colision mode3 (B3): cada plano es un
    // sprite distinto, asi que dos opacos solapados = dos sprites solapados.
    reg        w_any;
    reg        w_two;
    reg [7:0]  w_col;
    reg [1:0]  w_transp;
    always @(*) begin
        w_any    = 1'b0;
        w_two    = 1'b0;
        w_col    = 8'b0;
        w_transp = 2'b0;
        for (i = SM3_PLANES-1; i >= 0; i = i - 1) begin
            if (ST_VIS[i] == 1'b1 && F_NIBBLE(ST_SMP[i], SL_PAT[i]) != 4'b0000) begin
                if (w_any == 1'b1) w_two = 1'b1;   // ya habia uno -> este es el segundo
                w_any    = 1'b1;
                w_col    = {SL_PSET[i], F_NIBBLE(ST_SMP[i], SL_PAT[i])};
                w_transp = SL_TRANSP[i];
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SM3_COLOR_EN <= 1'b0;
            SM3_COLOR    <= 8'b0;
            SM3_TRANSP   <= 2'b0;
        end else begin
            if (DOTSTATE == 2'b01) begin
                SM3_COLOR_EN <= w_any & FF_WINX & SM3;
                SM3_COLOR    <= w_col;
                SM3_TRANSP   <= w_transp;
            end
        end
    end

    //-----------------------------------------------------------------------
    // COLISION mode3 (B3): incidencia + coordenada de la PRIMERA colision.
    // Convencion identica al motor serie (vdp_sprite.v:660-664): X = dot+12, Y = linea+7,
    // ambos [8:0] (Y truncada a 9 bits, desviacion documentada del plan). El set va antes
    // que el reset para que, en el empate rarisimo (lectura de S#0 en el mismo ciclo que una
    // colision nueva), gane el borrado -- igual que el motor serie.
    //-----------------------------------------------------------------------
    reg        FF_M3_COLL;
    reg [8:0]  FF_M3_COLL_X;
    reg [8:0]  FF_M3_COLL_Y;
    reg        FF_M3_S0ACK;
    reg        FF_M3_S5ACK;
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_M3_COLL   <= 1'b0;
            FF_M3_COLL_X <= 9'b0;
            FF_M3_COLL_Y <= 9'b0;
            FF_M3_S0ACK  <= 1'b0;
            FF_M3_S5ACK  <= 1'b0;
        end else begin
            // set: primera colision del frame (se congela hasta que S#0 la borre)
            if ((DOTSTATE == 2'b01) && (w_two == 1'b1) && (FF_WINX == 1'b1) &&
                (SM3 == 1'b1) && (FF_M3_COLL == 1'b0)) begin
                FF_M3_COLL   <= 1'b1;
                FF_M3_COLL_X <= {1'b0, FF_DISP_X} + 9'd12;
                FF_M3_COLL_Y <= FF_CUR_Y + 9'd7;
            end
            // reset (despues del set -> gana en empate)
            if (M3_S0RST_REQ != FF_M3_S0ACK) begin
                FF_M3_S0ACK <= M3_S0RST_REQ;
                FF_M3_COLL  <= 1'b0;
            end
            if (M3_S5RST_REQ != FF_M3_S5ACK) begin
                FF_M3_S5ACK  <= M3_S5RST_REQ;
                FF_M3_COLL_X <= 9'b0;
                FF_M3_COLL_Y <= 9'b0;
            end
        end
    end

    assign M3_COLL   = FF_M3_COLL;
    assign M3_COLL_X = FF_M3_COLL_X;
    assign M3_COLL_Y = FF_M3_COLL_Y;

endmodule
