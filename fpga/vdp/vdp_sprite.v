//
//  vdp_sprite.v
//   Sprite engine (modes 1 & 2): Y-test list-up, prepare, line-buffer draw,
//   collision / overmapped status.
//   Traduccion a Verilog de vdp_sprite.vhd.
//
//  Copyright (C) Kunihiko Ohnaka / ESE-VDP contributors.
//  Licencia completa (redistribucion / disclaimer) en el original vdp_sprite.vhd.
//
//  Nota (traduccion): el proceso "DRAWING TO LINE BUFFER" usa VARIABLES de VHDL
//  (persistentes entre invocaciones). Se modelan como reg de modulo asignados con
//  BLOCKING (=) dentro del always clockeado; las SEÑALES usan non-blocking (<=).
//-----------------------------------------------------------------------------

module VDP_SPRITE (
    // VDP CLOCK ... 21.477MHZ
    input  wire        CLK21M,
    input  wire        RESET,

    input  wire [1:0]  DOTSTATE,
    input  wire [2:0]  EIGHTDOTSTATE,

    input  wire [8:0]  DOTCOUNTERX,
    input  wire [8:0]  DOTCOUNTERYP,
    input  wire        BWINDOW_Y,

    // VDP STATUS REGISTERS OF SPRITE
    output reg         PVDPS0SPCOLLISIONINCIDENCE,
    output wire        PVDPS0SPOVERMAPPED,
    output wire [4:0]  PVDPS0SPOVERMAPPEDNUM,
    output reg  [8:0]  PVDPS3S4SPCOLLISIONX,
    output reg  [8:0]  PVDPS5S6SPCOLLISIONY,
    input  wire        PVDPS0RESETREQ,
    output wire        PVDPS0RESETACK,
    input  wire        PVDPS5RESETREQ,
    output wire        PVDPS5RESETACK,
    // VDP REGISTERS
    input  wire        REG_R1_SP_SIZE,
    input  wire        REG_R1_SP_ZOOM,
    input  wire [9:0]  REG_R11R5_SP_ATR_ADDR,
    input  wire [5:0]  REG_R6_SP_GEN_ADDR,
    input  wire        REG_R8_COL0_ON,
    input  wire        REG_R8_SP_OFF,
    input  wire [7:0]  REG_R23_VSTART_LINE,
    input  wire        SP_NONR23,            // V9968: sprites sin offset R#23 (ya gateado por modo)
    input  wire        SP_SHUFFLE,           // V9968: sprite priority shuffle (ya gateado por modo)
    input  wire        SP16,                 // V9968 sprite16: hasta 10 sprites/linea (ya gateado por modo)
    input  wire [2:0]  REG_R27_H_SCROLL,
    input  wire        SPMODE2,
    input  wire        VRAMINTERLEAVEMODE,

    output reg         SPVRAMACCESSING,

    input  wire [7:0]  PRAMDAT,
    output wire [16:0] PRAMADR,

    output reg         SPCOLOROUT,
    output reg  [3:0]  SPCOLORCODE,
    input  wire        REG_R9_Y_DOTS,
    input  wire        SPMAXSPR
);

    // Estados (enum TYPESPSTATE)
    localparam [1:0] SPSTATE_IDLE       = 2'd0,
                     SPSTATE_YTEST_DRAW = 2'd1,
                     SPSTATE_PREPARE    = 2'd2;

    reg         FF_SP_EN;
    reg  [8:0]  FF_CUR_Y;
    reg  [8:0]  FF_PREV_CUR_Y;
    wire        SPLIT_SCRN;

    reg         FF_VDPS0RESETACK;
    reg         FF_VDPS5RESETACK;

    // FOR SPINFORAM
    wire [3:0]  SPINFORAMADDR;   // V9968 sprite16: 16 entradas
    reg         SPINFORAMWE;
    wire [31:0] SPINFORAMDATA_IN;
    wire [31:0] SPINFORAMDATA_OUT;

    reg  [8:0]  SPINFORAMX_IN;
    reg  [15:0] SPINFORAMPATTERN_IN;
    reg  [3:0]  SPINFORAMCOLOR_IN;
    reg         SPINFORAMCC_IN;
    reg         SPINFORAMIC_IN;
    wire [8:0]  SPINFORAMX_OUT;
    wire [15:0] SPINFORAMPATTERN_OUT;
    wire [3:0]  SPINFORAMCOLOR_OUT;
    wire        SPINFORAMCC_OUT;
    wire        SPINFORAMIC_OUT;

    reg  [1:0]  SPSTATE;

    // Array plano-de-render (0..15; V9968 sprite16 usa hasta 10)
    reg  [4:0]  SPRENDERPLANES [0:15];

    wire [16:0] IRAMADR;
    reg  [16:0] FF_Y_TEST_VRAM_ADDR;
    reg  [16:0] IRAMADRPREPARE;

    reg  [9:0]  SPATTRTBLBASEADDR;
    reg  [5:0]  SPPTNGENETBLBASEADDR;
    wire [16:2] SPATTRIB_ADDR;
    wire [16:0] READVRAMADDRCREAD;
    wire [16:0] READVRAMADDRPTREAD;

    reg  [4:0]  FF_Y_TEST_SP_NUM;
    reg  [4:0]  FF_Y_TEST_LISTUP_ADDR;   // 0 - 16 (sprite16); antes 0 - 8
    reg         FF_Y_TEST_EN;

    // V9968 sprite priority shuffle: offset de plano rotado por frame.
    // El Y-test sigue contando 0..31 (terminacion intacta); el plano REAL = contador + offset (mod 32).
    reg  [4:0]  FF_SP_SHUFFLE_START;
    reg         FF_YP_ZERO_D;             // deteccion de inicio de frame (DOTCOUNTERYP==0, flanco)
    wire [4:0]  W_SP_PLANE = FF_Y_TEST_SP_NUM + FF_SP_SHUFFLE_START;   // wraparound natural mod 32
    reg  [3:0]  SPPREPARELOCALPLANENUM;   // 0-15 (sprite16)
    reg  [4:0]  SPPREPAREPLANENUM;
    reg  [3:0]  SPPREPARELINENUM;
    wire        SPPREPAREXPOS;
    reg  [7:0]  SPPREPAREPATTERNNUM;
    reg         SPPREPAREEND;

    reg  [3:0]  SPPREDRAWLOCALPLANENUM;   // 0 - 15 (sprite16); antes 0 - 7
    reg         SPPREDRAWEND;

    reg  [8:0]  SPDRAWX;                  // -32 - 287
    reg  [15:0] SPDRAWPATTERN;
    reg  [3:0]  SPDRAWCOLOR;

    // Line buffer control
    wire [7:0]  SPLINEBUFADDR_E;
    wire [7:0]  SPLINEBUFADDR_O;
    wire        SPLINEBUFWE_E;
    wire        SPLINEBUFWE_O;
    wire [8:0]  SPLINEBUFDATA_IN_E;    // 9 bits: {valido, plano[3:0], color[3:0]}
    wire [8:0]  SPLINEBUFDATA_IN_O;
    wire [8:0]  SPLINEBUFDATA_OUT_E;
    wire [8:0]  SPLINEBUFDATA_OUT_O;

    reg         SPLINEBUFDISPWE;
    reg         SPLINEBUFDRAWWE;
    reg  [7:0]  SPLINEBUFDISPX;
    reg  [7:0]  SPLINEBUFDRAWX;
    reg  [8:0]  SPLINEBUFDRAWCOLOR;    // 9 bits
    wire [8:0]  SPLINEBUFDISPDATA_OUT;
    wire [8:0]  SPLINEBUFDRAWDATA_OUT;

    reg         SPWINDOWX;

    reg         FF_SP_OVERMAP;
    reg  [4:0]  FF_SP_OVERMAP_NUM;

    wire [7:0]  W_SPLISTUPY;
    wire        W_TARGET_SP_EN;
    wire        W_SP_OFF;
    wire        W_SP_OVERMAP;
    wire        W_ACTIVE;
    reg         SPWINDOW_Y;

    // Variables persistentes del proceso de dibujo (ver nota de cabecera)
    reg         SPCC0FOUNDV;
    reg  [3:0]  LASTCC0LOCALPLANENUMV;   // 0-15 (sprite16)
    reg  [8:0]  SPDRAWXV;
    reg         VDPS0SPCOLLISIONINCIDENCEV;
    reg  [8:0]  VDPS3S4SPCOLLISIONXV;
    reg  [8:0]  VDPS5S6SPCOLLISIONYV;

    assign PVDPS0RESETACK        = FF_VDPS0RESETACK;
    assign PVDPS5RESETACK        = FF_VDPS5RESETACK;
    assign PVDPS0SPOVERMAPPED    = FF_SP_OVERMAP;
    assign PVDPS0SPOVERMAPPEDNUM = FF_SP_OVERMAP_NUM;

    //---------------------------------------------------------------------------
    // Señal de "mostrar sprites"
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            FF_SP_EN <= 1'b0;
        else if (DOTSTATE == 2'b01 && DOTCOUNTERX == 0)
            FF_SP_EN <= (~REG_R8_SP_OFF) & W_ACTIVE;
    end

    //---------------------------------------------------------------------------
    // SPRITE INFORMATION ARRAY
    //---------------------------------------------------------------------------
    VDP_SPINFORAM ISPINFORAM (
        .ADDRESS (SPINFORAMADDR),
        .INCLOCK (CLK21M),
        .WE      (SPINFORAMWE),
        .DATA    (SPINFORAMDATA_IN),
        .Q       (SPINFORAMDATA_OUT)
    );

    assign SPINFORAMDATA_IN = {1'b0, SPINFORAMX_IN, SPINFORAMPATTERN_IN,
                               SPINFORAMCOLOR_IN, SPINFORAMCC_IN, SPINFORAMIC_IN};
    assign SPINFORAMX_OUT       = SPINFORAMDATA_OUT[30:22];
    assign SPINFORAMPATTERN_OUT = SPINFORAMDATA_OUT[21:6];
    assign SPINFORAMCOLOR_OUT   = SPINFORAMDATA_OUT[5:2];
    assign SPINFORAMCC_OUT      = SPINFORAMDATA_OUT[1];
    assign SPINFORAMIC_OUT      = SPINFORAMDATA_OUT[0];

    assign SPINFORAMADDR = (SPSTATE == SPSTATE_PREPARE) ? SPPREPARELOCALPLANENUM :
                                                          SPPREDRAWLOCALPLANENUM;

    //---------------------------------------------------------------------------
    // SPRITE LINE BUFFER
    //---------------------------------------------------------------------------
    assign SPLINEBUFADDR_E       = (DOTCOUNTERYP[0] == 1'b0) ? SPLINEBUFDISPX     : SPLINEBUFDRAWX;
    assign SPLINEBUFDATA_IN_E    = (DOTCOUNTERYP[0] == 1'b0) ? 9'b0               : SPLINEBUFDRAWCOLOR;
    assign SPLINEBUFWE_E         = (DOTCOUNTERYP[0] == 1'b0) ? SPLINEBUFDISPWE    : SPLINEBUFDRAWWE;
    assign SPLINEBUFDISPDATA_OUT = (DOTCOUNTERYP[0] == 1'b0) ? SPLINEBUFDATA_OUT_E: SPLINEBUFDATA_OUT_O;

    ram9 U_EVEN_LINE_BUF (
        .adr (SPLINEBUFADDR_E),
        .clk (CLK21M),
        .we  (SPLINEBUFWE_E),
        .dbo (SPLINEBUFDATA_IN_E),
        .dbi (SPLINEBUFDATA_OUT_E)
    );

    assign SPLINEBUFADDR_O       = (DOTCOUNTERYP[0] == 1'b0) ? SPLINEBUFDRAWX     : SPLINEBUFDISPX;
    assign SPLINEBUFDATA_IN_O    = (DOTCOUNTERYP[0] == 1'b0) ? SPLINEBUFDRAWCOLOR : 9'b0;
    assign SPLINEBUFWE_O         = (DOTCOUNTERYP[0] == 1'b0) ? SPLINEBUFDRAWWE    : SPLINEBUFDISPWE;
    assign SPLINEBUFDRAWDATA_OUT = (DOTCOUNTERYP[0] == 1'b0) ? SPLINEBUFDATA_OUT_O: SPLINEBUFDATA_OUT_E;

    ram9 U_ODD_LINE_BUF (
        .adr (SPLINEBUFADDR_O),
        .clk (CLK21M),
        .we  (SPLINEBUFWE_O),
        .dbo (SPLINEBUFDATA_IN_O),
        .dbi (SPLINEBUFDATA_OUT_O)
    );

    //---------------------------------------------------------------------------
    assign SPPREPAREXPOS = (EIGHTDOTSTATE == 3'b100) ? 1'b1 : 1'b0;

    // Salida de la direccion de acceso a VRAM
    assign IRAMADR = (SPSTATE == SPSTATE_YTEST_DRAW) ? FF_Y_TEST_VRAM_ADDR : IRAMADRPREPARE;
    // F1 VRAM contigua: SIN swizzle G6/G7. La SAT/patrones se escriben ya en lineal (CPU y
    // comando sin swizzle desde F1), asi que el sprite debe leer lineal tambien. Este mux era
    // el ULTIMO resto del interleave {X,X+64K}: en SCREEN 7/8 leia la SAT en {A[0],A[16:1]}
    // (basura) -> sprites fantasma. VRAMINTERLEAVEMODE queda vestigial.
    assign PRAMADR = IRAMADR[16:0];

    //---------------------------------------------------------------------------
    // STATE MACHINE
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SPSTATE <= SPSTATE_IDLE;
        end else begin
            if (DOTSTATE == 2'b10) begin
                case (SPSTATE)
                    SPSTATE_IDLE:
                        if (DOTCOUNTERX == 0)
                            SPSTATE <= SPSTATE_YTEST_DRAW;
                    SPSTATE_YTEST_DRAW:
                        // sprite16: 10 slots de draw (32 dots) -> frontera en 320; normal: 264
                        if (DOTCOUNTERX == (SP16 ? 9'd320 : 9'd264))
                            SPSTATE <= SPSTATE_PREPARE;
                    SPSTATE_PREPARE:
                        if (SPPREPAREEND == 1'b1)
                            SPSTATE <= SPSTATE_IDLE;
                    default:
                        SPSTATE <= SPSTATE_IDLE;
                endcase
            end
        end
    end

    //---------------------------------------------------------------------------
    // Numero de linea actual
    //---------------------------------------------------------------------------
    always @(posedge CLK21M) begin
        if ((DOTSTATE == 2'b01) && (DOTCOUNTERX == 0))
            //   +1 SHOULD BE NEEDED (drawn in the next line)
            //   V9968 SVNS: sin offset R#23 -> sprites en coordenadas de pantalla
            FF_CUR_Y <= DOTCOUNTERYP + (SP_NONR23 ? 9'd0 : {1'b0, REG_R23_VSTART_LINE}) + 1'b1;
    end

    always @(posedge CLK21M) begin
        if ((DOTSTATE == 2'b01) && (DOTCOUNTERX == 0))
            FF_PREV_CUR_Y <= FF_CUR_Y;
    end

    // detect a split screen
    assign SPLIT_SCRN = (FF_CUR_Y == (FF_PREV_CUR_Y + 1'b1)) ? 1'b0 : 1'b1;

    //---------------------------------------------------------------------------
    // VRAM ADDRESS GENERATOR (latch)
    //---------------------------------------------------------------------------
    always @(posedge CLK21M) begin
        if ((DOTSTATE == 2'b01) && (DOTCOUNTERX == 0)) begin
            SPPTNGENETBLBASEADDR <= REG_R6_SP_GEN_ADDR;
            if (SPMODE2 == 1'b0)
                SPATTRTBLBASEADDR <= REG_R11R5_SP_ATR_ADDR[9:0];
            else
                SPATTRTBLBASEADDR <= {REG_R11R5_SP_ATR_ADDR[9:2], 2'b00};
        end
    end

    //---------------------------------------------------------------------------
    // VRAM ACCESS MASK
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SPVRAMACCESSING <= 1'b0;
        end else begin
            if (DOTSTATE == 2'b10) begin
                case (SPSTATE)
                    SPSTATE_IDLE:
                        if (DOTCOUNTERX == 0)
                            SPVRAMACCESSING <= (~REG_R8_SP_OFF) & W_ACTIVE;
                    SPSTATE_YTEST_DRAW:
                        if (DOTCOUNTERX == 256+8)
                            SPVRAMACCESSING <= FF_SP_EN;
                    SPSTATE_PREPARE:
                        if (SPPREPAREEND == 1'b1)
                            SPVRAMACCESSING <= 1'b0;
                    default: ;
                endcase
            end
        end
    end

    //---------------------------------------------------------------------------
    // [Y_TEST]
    //---------------------------------------------------------------------------
    assign W_SPLISTUPY = FF_CUR_Y[7:0] - PRAMDAT;

    assign W_TARGET_SP_EN = ( ((W_SPLISTUPY[7:3] == 5'b00000) && (REG_R1_SP_SIZE == 1'b0) && (REG_R1_SP_ZOOM == 1'b0)) ||
                              ((W_SPLISTUPY[7:4] == 4'b0000)  && (REG_R1_SP_SIZE == 1'b1) && (REG_R1_SP_ZOOM == 1'b0)) ||
                              ((W_SPLISTUPY[7:4] == 4'b0000)  && (REG_R1_SP_SIZE == 1'b0) && (REG_R1_SP_ZOOM == 1'b1)) ||
                              ((W_SPLISTUPY[7:5] == 3'b000)   && (REG_R1_SP_SIZE == 1'b1) && (REG_R1_SP_ZOOM == 1'b1)) ) ? 1'b1 : 1'b0;

    assign W_SP_OFF = (PRAMDAT == {4'b1101, SPMODE2, 3'b000}) ? 1'b1 : 1'b0;

    // sprite16: tope 10/linea. Normal: 4 (modo1 sin maxspr) / 8.
    assign W_SP_OVERMAP = SP16 ? (FF_Y_TEST_LISTUP_ADDR >= 5'd10) :
                          (((FF_Y_TEST_LISTUP_ADDR[2] == 1'b1 && SPMODE2 == 1'b0 && SPMAXSPR == 1'b0) || FF_Y_TEST_LISTUP_ADDR[3] == 1'b1) ? 1'b1 : 1'b0);

    assign W_ACTIVE = BWINDOW_Y;

    //---------------------------------------------------------------------------
    // [SPWINDOW_Y]
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SPWINDOW_Y <= 1'b0;
        end else begin
            if (DOTCOUNTERYP == 0)
                SPWINDOW_Y <= 1'b1;
            else if ((REG_R9_Y_DOTS == 1'b0 && DOTCOUNTERYP == 192) ||
                     (REG_R9_Y_DOTS == 1'b1 && DOTCOUNTERYP == 212))
                SPWINDOW_Y <= 1'b0;
        end
    end

    //---------------------------------------------------------------------------
    // [Y_TEST] enable
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_Y_TEST_EN <= 1'b0;
        end else begin
            if (DOTSTATE == 2'b01) begin
                if (DOTCOUNTERX == 0)
                    FF_Y_TEST_EN <= FF_SP_EN;
                else if (EIGHTDOTSTATE == 3'b110) begin
                    if (W_SP_OFF == 1'b1 || (W_SP_OVERMAP & W_TARGET_SP_EN) == 1'b1 || FF_Y_TEST_SP_NUM == 5'b11111)
                        FF_Y_TEST_EN <= 1'b0;
                end
            end
        end
    end

    //---------------------------------------------------------------------------
    // [Y_TEST] sprite number (0..31)
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_Y_TEST_SP_NUM <= 5'b0;
        end else begin
            if (DOTSTATE == 2'b01) begin
                if (DOTCOUNTERX == 0)
                    FF_Y_TEST_SP_NUM <= 5'b0;
                else if (EIGHTDOTSTATE == 3'b110) begin
                    if (FF_Y_TEST_EN == 1'b1 && FF_Y_TEST_SP_NUM != 5'b11111)
                        FF_Y_TEST_SP_NUM <= FF_Y_TEST_SP_NUM + 1'b1;
                end
            end
        end
    end

    //---------------------------------------------------------------------------
    // [V9968] Sprite priority shuffle: rota el plano inicial una vez por frame.
    //   Sin shuffle -> offset 0 (comportamiento V9958 identico).
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_SP_SHUFFLE_START <= 5'b0;
            FF_YP_ZERO_D        <= 1'b0;
        end else begin
            FF_YP_ZERO_D <= (DOTCOUNTERYP == 0);
            if (SP_SHUFFLE == 1'b0)
                FF_SP_SHUFFLE_START <= 5'b0;
            else if ((DOTCOUNTERYP == 0) && (FF_YP_ZERO_D == 1'b0))
                // flanco de inicio de frame
                FF_SP_SHUFFLE_START <= FF_SP_SHUFFLE_START + 1'b1;
        end
    end

    //---------------------------------------------------------------------------
    // [Y_TEST] listup memory address 0..8
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_Y_TEST_LISTUP_ADDR <= 5'b0;
        end else begin
            if (DOTSTATE == 2'b01) begin
                if (DOTCOUNTERX == 0)
                    FF_Y_TEST_LISTUP_ADDR <= 5'b0;
                else if (EIGHTDOTSTATE == 3'b110) begin
                    if (FF_Y_TEST_EN == 1'b1 && W_TARGET_SP_EN == 1'b1 && W_SP_OVERMAP == 1'b0 && W_SP_OFF == 1'b0)
                        FF_Y_TEST_LISTUP_ADDR <= FF_Y_TEST_LISTUP_ADDR + 1'b1;
                end
            end
        end
    end

    //---------------------------------------------------------------------------
    // [Y_TEST] listup memory write
    //---------------------------------------------------------------------------
    always @(posedge CLK21M) begin
        if (DOTSTATE == 2'b01) begin
            if (DOTCOUNTERX == 0) begin
                // INITIALIZE
            end else if (EIGHTDOTSTATE == 3'b110) begin
                if (FF_Y_TEST_EN == 1'b1 && W_TARGET_SP_EN == 1'b1 && W_SP_OVERMAP == 1'b0 && W_SP_OFF == 1'b0)
                    SPRENDERPLANES[FF_Y_TEST_LISTUP_ADDR[3:0]] <= W_SP_PLANE;
            end
        end
    end

    //---------------------------------------------------------------------------
    // [Y_TEST] overmapped flag
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_SP_OVERMAP <= 1'b0;
        end else begin
            if (PVDPS0RESETREQ == ~FF_VDPS0RESETACK)
                FF_SP_OVERMAP <= 1'b0;
            else if (DOTSTATE == 2'b01) begin
                if (DOTCOUNTERX == 0) begin
                    // INITIALIZE
                end else if (EIGHTDOTSTATE == 3'b110) begin
                    if (SPWINDOW_Y == 1'b1 && FF_Y_TEST_EN == 1'b1 && W_TARGET_SP_EN == 1'b1 && W_SP_OVERMAP == 1'b1 && W_SP_OFF == 1'b0)
                        FF_SP_OVERMAP <= 1'b1;
                end
            end
        end
    end

    //---------------------------------------------------------------------------
    // [Y_TEST] overmapped sprite number
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            FF_SP_OVERMAP_NUM <= 5'b11111;
        end else begin
            if (PVDPS0RESETREQ == ~FF_VDPS0RESETACK)
                FF_SP_OVERMAP_NUM <= 5'b11111;
            else if (DOTSTATE == 2'b01) begin
                if (DOTCOUNTERX == 0) begin
                    // INITIALIZE
                end else if (EIGHTDOTSTATE == 3'b110) begin
                    if (SPWINDOW_Y == 1'b1 && FF_Y_TEST_EN == 1'b1 && W_TARGET_SP_EN == 1'b1 && W_SP_OVERMAP == 1'b1 && W_SP_OFF == 1'b0 && FF_SP_OVERMAP == 1'b0)
                        FF_SP_OVERMAP_NUM <= W_SP_PLANE;
                end
            end
        end
    end

    //---------------------------------------------------------------------------
    // Y-test VRAM read address
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1)
            FF_Y_TEST_VRAM_ADDR <= 17'b0;
        else if (DOTSTATE == 2'b11)
            FF_Y_TEST_VRAM_ADDR <= {SPATTRTBLBASEADDR, W_SP_PLANE, 2'b00};
    end

    //---------------------------------------------------------------------------
    // PREPARE SPRITE
    //---------------------------------------------------------------------------
    assign SPATTRIB_ADDR = {SPATTRTBLBASEADDR, SPPREPAREPLANENUM};
    assign READVRAMADDRPTREAD = (REG_R1_SP_SIZE == 1'b0) ?
        {SPPTNGENETBLBASEADDR, SPPREPAREPATTERNNUM[7:0], SPPREPARELINENUM[2:0]} :    // 8X8
        {SPPTNGENETBLBASEADDR, SPPREPAREPATTERNNUM[7:2], SPPREPAREXPOS, SPPREPARELINENUM[3:0]}; // 16X16
    assign READVRAMADDRCREAD = (SPMODE2 == 1'b0) ?
        {SPATTRIB_ADDR, 2'b11} :
        {SPATTRTBLBASEADDR[9:3], ~SPATTRTBLBASEADDR[2], SPPREPAREPLANENUM, SPPREPARELINENUM};

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            IRAMADRPREPARE <= 17'b0;
        end else begin
            if (DOTSTATE == 2'b11) begin
                case (EIGHTDOTSTATE)
                    3'b000: IRAMADRPREPARE <= {SPATTRIB_ADDR, 2'b00};   // Y READ
                    3'b001: IRAMADRPREPARE <= {SPATTRIB_ADDR, 2'b01};   // X READ
                    3'b010: IRAMADRPREPARE <= {SPATTRIB_ADDR, 2'b10};   // PATTERN NUM READ
                    3'b011, 3'b100: IRAMADRPREPARE <= READVRAMADDRPTREAD; // PATTERN READ
                    3'b101: IRAMADRPREPARE <= READVRAMADDRCREAD;         // COLOR READ
                    default: ;
                endcase
            end
        end
    end

    always @(posedge CLK21M) begin
        case (DOTSTATE)
            2'b11: SPINFORAMWE <= 1'b0;
            2'b01: begin
                if (SPSTATE == SPSTATE_PREPARE) begin
                    if (EIGHTDOTSTATE == 3'b110)
                        SPINFORAMWE <= 1'b1;
                end else
                    SPINFORAMWE <= 1'b0;
            end
            default: ;
        endcase
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SPPREPARELOCALPLANENUM <= 4'b0;
            SPPREPAREEND           <= 1'b0;
        end else begin
            case (DOTSTATE)
                2'b01: begin
                    if (SPSTATE == SPSTATE_PREPARE) begin
                        case (EIGHTDOTSTATE)
                            3'b001: begin                               // Y READ
                                if (REG_R1_SP_ZOOM == 1'b0)
                                    SPPREPARELINENUM <= W_SPLISTUPY[3:0];
                                else
                                    SPPREPARELINENUM <= W_SPLISTUPY[4:1];
                            end
                            3'b010: begin                               // X READ
                                SPINFORAMX_IN <= {1'b0, PRAMDAT};
                            end
                            3'b011: begin                               // PATTERN NUM READ
                                SPPREPAREPATTERNNUM <= PRAMDAT;
                            end
                            3'b100: begin                               // PATTERN READ LEFT
                                SPINFORAMPATTERN_IN[15:8] <= PRAMDAT;
                            end
                            3'b101: begin                               // PATTERN READ RIGHT
                                if (REG_R1_SP_SIZE == 1'b0)
                                    SPINFORAMPATTERN_IN[7:0] <= 8'b0;    // 8X8
                                else
                                    SPINFORAMPATTERN_IN[7:0] <= PRAMDAT; // 16X16
                            end
                            3'b110: begin                               // COLOR READ
                                SPINFORAMCOLOR_IN <= PRAMDAT[3:0];
                                if (SPMODE2 == 1'b1)
                                    SPINFORAMCC_IN <= PRAMDAT[6];
                                else
                                    SPINFORAMCC_IN <= 1'b0;
                                SPINFORAMIC_IN <= PRAMDAT[5] & SPMODE2;
                                if (PRAMDAT[7] == 1'b1)
                                    SPINFORAMX_IN <= SPINFORAMX_IN - 9'd32;

                                // IF ALL LIST-UPED SPRITES ARE READ, THE LEFT SHOULD NOT BE DRAWN.
                                if (SPPREPARELOCALPLANENUM >= FF_Y_TEST_LISTUP_ADDR)
                                    SPINFORAMPATTERN_IN <= 16'b0;
                            end
                            3'b111: begin
                                SPPREPARELOCALPLANENUM <= SPPREPARELOCALPLANENUM + 1'b1;
                                if ((SP16 == 1'b1 && SPPREPARELOCALPLANENUM == 9) ||
                                    (SP16 == 1'b0 && ((SPPREPARELOCALPLANENUM == 7) || (SPMAXSPR == 1'b0 && (SPPREPARELOCALPLANENUM == 3 && SPMODE2 == 1'b0)))))
                                    SPPREPAREEND <= 1'b1;
                            end
                            default: ;
                        endcase
                    end else begin
                        SPPREPARELOCALPLANENUM <= 4'b0;
                        SPPREPAREEND <= 1'b0;
                    end
                end
                default: ;
            endcase
        end
    end

    always @(posedge CLK21M) begin
        if (DOTSTATE == 2'b01) begin
            if (SPSTATE == SPSTATE_PREPARE) begin
                if (EIGHTDOTSTATE == 3'b111)
                    SPPREPAREPLANENUM <= SPRENDERPLANES[SPPREPARELOCALPLANENUM + 4'd1];
            end else
                SPPREPAREPLANENUM <= SPRENDERPLANES[0];
        end
    end

    //---------------------------------------------------------------------------
    // DRAWING TO LINE BUFFER
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SPLINEBUFDRAWWE            <= 1'b0;
            SPPREDRAWEND               <= 1'b0;
            SPDRAWPATTERN              <= 16'b0;
            SPLINEBUFDRAWCOLOR         <= 8'b0;
            SPLINEBUFDRAWX             <= 8'b0;
            SPDRAWCOLOR                <= 4'b0;

            VDPS0SPCOLLISIONINCIDENCEV  = 1'b0;
            VDPS3S4SPCOLLISIONXV        = 9'b0;
            VDPS5S6SPCOLLISIONYV        = 9'b0;
            SPCC0FOUNDV                 = 1'b0;
            LASTCC0LOCALPLANENUMV       = 4'b0;
        end else begin
            if (SPSTATE == SPSTATE_YTEST_DRAW) begin
                case (DOTSTATE)
                    2'b10: SPLINEBUFDRAWWE <= 1'b0;      // inicio de unidad de proceso
                    2'b00: begin
                        if (DOTCOUNTERX[4:0] == 1) begin
                            SPDRAWPATTERN <= SPINFORAMPATTERN_OUT;
                            SPDRAWXV       = SPINFORAMX_OUT;
                        end else begin
                            if ((REG_R1_SP_ZOOM == 1'b0) || (DOTCOUNTERX[0] == 1'b1))
                                SPDRAWPATTERN <= {SPDRAWPATTERN[14:0], 1'b0};
                            SPDRAWXV = SPDRAWX + 1'b1;
                        end
                        SPDRAWX        <= SPDRAWXV;
                        SPLINEBUFDRAWX <= SPDRAWXV[7:0];
                    end
                    2'b01: SPDRAWCOLOR <= SPINFORAMCOLOR_OUT;
                    2'b11: begin
                        if (SPINFORAMCC_OUT == 1'b0) begin
                            LASTCC0LOCALPLANENUMV = SPPREDRAWLOCALPLANENUM;
                            SPCC0FOUNDV = 1'b1;
                        end
                        if ((SPDRAWPATTERN[15] == 1'b1) && (SPDRAWX[8] == 1'b0) && (SPPREDRAWEND == 1'b0) &&
                                ((REG_R8_COL0_ON == 1'b1) || (SPDRAWCOLOR != 0))) begin
                            if ((SPLINEBUFDRAWDATA_OUT[8] == 1'b0) && (SPCC0FOUNDV == 1'b1)) begin
                                SPLINEBUFDRAWCOLOR <= {1'b1, LASTCC0LOCALPLANENUMV, SPDRAWCOLOR};
                                SPLINEBUFDRAWWE <= 1'b1;
                            end else if ((SPLINEBUFDRAWDATA_OUT[8] == 1'b1) && (SPINFORAMCC_OUT == 1'b1) &&
                                         (SPLINEBUFDRAWDATA_OUT[7:4] == LASTCC0LOCALPLANENUMV)) begin
                                SPLINEBUFDRAWCOLOR <= SPLINEBUFDRAWDATA_OUT | {5'b00000, SPDRAWCOLOR};
                                SPLINEBUFDRAWWE <= 1'b1;
                            end else if ((SPLINEBUFDRAWDATA_OUT[8] == 1'b1) && (SPINFORAMIC_OUT == 1'b0)) begin
                                SPLINEBUFDRAWCOLOR <= SPLINEBUFDRAWDATA_OUT;
                                // SPRITE COLLISION OCCURED
                                VDPS0SPCOLLISIONINCIDENCEV = 1'b1;
                                VDPS3S4SPCOLLISIONXV = SPDRAWX + 12;
                                // NOTE: DRAWING LINE IS PREVIOUS LINE.
                                VDPS5S6SPCOLLISIONYV = FF_CUR_Y + 7;
                            end
                        end
                        //
                        if (DOTCOUNTERX == 0) begin
                            SPPREDRAWLOCALPLANENUM <= 4'b0;
                            SPPREDRAWEND <= SPLIT_SCRN | REG_R8_SP_OFF;
                            LASTCC0LOCALPLANENUMV = 4'b0;
                            SPCC0FOUNDV = 1'b0;
                        end else if (DOTCOUNTERX[4:0] == 0) begin
                            SPPREDRAWLOCALPLANENUM <= SPPREDRAWLOCALPLANENUM + 1'b1;
                            if ((SP16 == 1'b1 && SPPREDRAWLOCALPLANENUM == 9) ||
                                (SP16 == 1'b0 && ((SPPREDRAWLOCALPLANENUM == 7) || (SPMAXSPR == 1'b0 && (SPPREDRAWLOCALPLANENUM == 3 && SPMODE2 == 1'b0)))))
                                SPPREDRAWEND <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end

            // STATUS REGISTER
            if (PVDPS0RESETREQ != FF_VDPS0RESETACK) begin
                FF_VDPS0RESETACK <= PVDPS0RESETREQ;
                VDPS0SPCOLLISIONINCIDENCEV = 1'b0;
            end
            if (PVDPS5RESETREQ != FF_VDPS5RESETACK) begin
                FF_VDPS5RESETACK <= PVDPS5RESETREQ;
                VDPS3S4SPCOLLISIONXV = 9'b0;
                VDPS5S6SPCOLLISIONYV = 9'b0;
            end

            PVDPS0SPCOLLISIONINCIDENCE <= VDPS0SPCOLLISIONINCIDENCEV;
            PVDPS3S4SPCOLLISIONX       <= VDPS3S4SPCOLLISIONXV;
            PVDPS5S6SPCOLLISIONY       <= VDPS5S6SPCOLLISIONYV;
        end
    end

    //---------------------------------------------------------------------------
    // RENDER TO SCREEN
    //---------------------------------------------------------------------------
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SPLINEBUFDISPX <= 8'b0;
        end else begin
            if (DOTSTATE == 2'b10) begin
                if (DOTCOUNTERX == 8)
                    SPLINEBUFDISPX <= {5'b00000, REG_R27_H_SCROLL};
                else
                    SPLINEBUFDISPX <= SPLINEBUFDISPX + 1'b1;
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SPWINDOWX <= 1'b0;
        end else begin
            if (DOTSTATE == 2'b10) begin
                if (DOTCOUNTERX == 8)
                    SPWINDOWX <= 1'b1;
                else if (SPLINEBUFDISPX == 8'hFF)
                    SPWINDOWX <= 1'b0;
            end
        end
    end

    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SPLINEBUFDISPWE <= 1'b0;
        end else begin
            if (DOTSTATE == 2'b10)
                SPLINEBUFDISPWE <= 1'b0;
            else if (DOTSTATE == 2'b11 && SPWINDOWX == 1'b1)
                // CLEAR DISPLAYED DOT
                SPLINEBUFDISPWE <= 1'b1;
        end
    end

    // Window cut
    always @(posedge CLK21M or posedge RESET) begin
        if (RESET == 1'b1) begin
            SPCOLOROUT  <= 1'b0;
            SPCOLORCODE <= 4'b0;
        end else begin
            if (DOTSTATE == 2'b01) begin
                if (SPWINDOWX == 1'b1) begin
                    SPCOLOROUT  <= SPLINEBUFDISPDATA_OUT[8];
                    SPCOLORCODE <= SPLINEBUFDISPDATA_OUT[3:0];
                end else begin
                    SPCOLOROUT  <= 1'b0;
                    SPCOLORCODE <= 4'b0;
                end
            end
        end
    end

endmodule
