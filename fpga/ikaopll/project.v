/*
 * Copyright (c) 2025 ReJ aka Renaldas Zioma
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_rejunity_ym2413_ika_opll (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  // assign uo_out       = { o_D_OE, o_D, o_DAC_EN_MO, o_DAC_EN_RO, o_ikaopll_main[10: 8] };//o_ikaopll_main[15: 8];
  // assign uo_out       = { o_ikaopll_main[15: 8] };
  // assign uio_out[7:3] = { o_ikaopll_main[7 : 3] };
  assign uo_out       = o_dac_9bit[8:1]; 
  assign uio_out[7]   = o_pwm_1bit;
  assign uio_out[6:3] = 4'b0; // unused bits
  assign uio_out[2:0] = 3'b0; // input bits
  assign uio_oe       = 8'b1111_1000; // (active high: 0=input, 1=output)

  ///////////////////////////////////////////////////////////
  //////  Clocking information
  ////

  /*
      XIN  - 72 clocks
      phi1 - 18 clocks   phi1 - every 4th XIN clock
      9 instruments / channels
      
      mc = ( 00 01 02 03 04 05,08 09 10 11 12 13,16 17 18 19 20 21,)
            .^^^cycle_0       .                 .                 .
            .                 .            ^^^cycle_12            .
            .                 .                 .   ^^^cycle_17   .
            .                 .                 .            ^^^cycle_20
            .                 .                 .               ^^^cycle_21
            .                 .       ^--cycle_D3_ZZ--^           .
            .                 .                 .      ^---cycle_D4_ZZ--^
            .                 .                 .^---cycle_D4~~~--^
          ^MO_CTRL^         ^MO_CTRL^         ^MO_CTRL^         ^MO_CTRL^
  */  


  /*

  phiM(XIN)   ¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/
  prescaler   -3-|-0-|-1-|-2-|-3-|-0-|-1-|-2-|-3-|-0-|-1-|-2-|
  phi1p       ¯\_________/¯¯¯¯¯\_________/¯¯¯¯¯\_________/¯¯¯¯
  phi1n       ___/¯¯¯¯¯\_________/¯¯¯¯¯\_________/¯¯¯¯¯\______

  phi1pcen    _______/¯¯¯\___________/¯¯¯\___________/¯¯¯\____
  phi1ncen    ¯¯¯\___________/¯¯¯\___________/¯¯¯\___________/   -> drives d9reg shift
  dacen       ___/¯¯¯\___________/¯¯¯\___________/¯¯¯\________

  mc          ¯_¯X¯_¯_¯_ 00_¯_¯_¯X¯_¯_¯_ 01_¯_¯_¯X¯_¯_¯_ 02_¯_

  -----------------------------------------------------------------

  To process all instruments takes 72 cyles
  72 phiM(XIN) clocks
  18 phi1      clocks

  mc[2:0]     ×00×01×02×03×04×05×00×01×02×03×04×05×00×01×02×03×04×05 ×00×01×02
  mc[4:3]     X¯_¯_¯_¯_00_¯_¯_¯_X¯_¯_¯_¯_01_¯_¯_¯_X¯_¯_¯_¯_02_¯_¯_¯_ X¯_¯_¯_¯_
  mc          ×00×01×02×03×04×05×08×09×10×11×12×13×16×17×18×19×20×21 ×00×01×02
  cycle_00    /¯¯\__________________________________________________ /¯¯\_____
  cycle_12    ______________________________/¯¯\____________________ _________
  cycle_17    _______________________________________/¯¯\___________ _________
  cycle_20    ________________________________________________/¯¯\__ _________
  cycle_21    ___________________________________________________/¯¯ \________
  cycle_D3_ZZ ________________________/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\___________ _________
  cycle_D4    ____________________________________/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯ \________
  cycle_D4_ZZ ¯¯¯¯¯¯\___________________________________/¯¯¯¯¯¯¯¯¯¯¯ ¯¯¯¯¯¯\__
  mc[4:3]     X¯_¯_¯_¯_00_¯_¯_¯_X¯_¯_¯_¯_01_¯_¯_¯_X¯_¯_¯_¯_02_¯_¯_¯_ X¯_¯_¯_¯_
  mc          ×00×01×02×03×04×05×08×09×10×11×12×13×16×17×18×19×20×21 ×00×01×02
  MO_CTRL     ¯¯¯¯¯¯\________/¯¯¯¯¯¯¯¯\________/¯¯¯¯¯¯¯¯\________/¯¯ ¯¯¯¯¯¯\__


  -----------------------------------------------------------------
  Reads from cycling 9 "instrument" register file (d9reg)
  NOTE: i_TAPSEL = {cycle_D4_ZZ, cycle_D3_ZZ}
  TAP0,TAP1,TAP2 hardcoded to 2,5,8

  cycle_D3_ZZ ________________________/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\___________ _________
  cycle_D4_ZZ ¯¯¯¯¯¯\___________________________________/¯¯¯¯¯¯¯¯¯¯¯ ¯¯¯¯¯¯\__
  i_TAPSEL    222222|00000000000000000|11111111111111111|22222222222 222222|00
     .. TAP2(8)-1=7 | TAP0(2)-1=1     | TAP1(5)-1=4     | TAP2(8)-1=7      |  TAP0(2)-1 .. 
  tap          77777|11111111111111111|44444444444444444|77777777777 777777|11
  d9reg@0     . 8  0  1  2  3  4  5  6  7  8  0  1  2  3  4  5  6  7   8  0  1
  d9reg@1     . 7  8 [0--1--2--3--4--5] 6  7  8  0  1  2  3  4  5  6   7  8 [0--
  d9reg@2     . 6  7  8  0  1  2  3  4  5  6  7  8  0  1  2  3  4  5   6  7  8
  d9reg@3     . 5  6  7  8  0  1  2  3  4  5  6  7  8  0  1  2  3  4   5  6  7
  d9reg@4     . 4  5  6  7  8  0  1  2 [3--4--5--6--7--8] 0  1  2  3   4  5  6
  d9reg@5     . 3  4  5  6  7  8  0  1  2  3  4  5  6  7  8  0  1  2   3  4  5
  d9reg@6     . 2  3  4  5  6  7  8  0  1  2  3  4  5  6  7  8  0  1   2  3  4
  d9reg@7     .[1--2] 3  4  5  6  7  8  0  1  2  3  4  5 [6--7--8--0 --1--2] 3
  d9reg@last  . 0  1  2  3  4  5  6  7  8  0  1  2  3  4  5  6  7  8   0  1  2
  d9reg@tap   . 1  2  0  1  2  3  4  5  3  4  5  6  7  8  6  7  8  0   1  2  0
  MO_CTRL     ¯¯¯¯¯¯\________/¯¯¯¯¯¯¯¯\________/¯¯¯¯¯¯¯¯\________/¯¯ ¯¯¯¯¯¯\__

  OP output (mc counter: instrument channel, operator type)
  5:  CH1 CAR
  8:  CH2 CAR
  9:  CH3 CAR
  13: CH4 CAR
  16: CH5 CAR
  17: CH6 CAR

  /FM 3ch
  21: CH7 CAR
  0:  CH8 CAR
  1:  CH9 CAR

  //precussion 5ch
  19: CH8 MOD
  20: CH9 MOD
  21: CH7 CAR
??22: CH8 CAR????
  0:  CH9 CAR

  */

  // BUS IO wires
  wire            IC_n =  rst_n; // chip reset
  wire [7:0]      DIN  =  ui_in;
  wire            A0   =  uio_in[0];
  wire            CS_n =  uio_in[1];
  wire            WR_n =  uio_in[2];

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, 1'b0};


  // outputs
  wire [8:0]     o_dac_9bit = 9'h100 + {o_IMP_NOFLUC_SIGN, o_IMP_NOFLUC_SIGN ? ~o_IMP_NOFLUC_MAG : o_IMP_NOFLUC_MAG};
  wire [15:0]    o_dac_18bit = 16'h8000 + o_ACC_SIGNED;
  wire           o_pwm_1bit;
  
  // pwm #(.VALUE_BITS(9)) pwm_master (
  //       .clk(clk),
  //       .reset(~rst_n),
  //       .value(o_dac_9bit),
  //       .out(o_pwm_1bit)
  // );

  // wire                o_pwm2_1bit;

  // pwm #(.VALUE_BITS(16)) pwm2_master (
  //       .clk(clk),
  //       .reset(~rst_n),
  //       .value(o_dac_18bit),
  //       .out(o_pwm2_1bit)
  // );

  pwm #(.VALUE_BITS(16)) pwm_master (
        .clk(clk),
        .reset(~rst_n),
        .value(o_dac_18bit),
        .out(o_pwm_1bit)
  );

  // main chip
  wire                o_XOUT;
  wire        [1:0]   o_D;
  wire                o_D_OE;
  wire                o_DAC_EN_MO;
  wire                o_DAC_EN_RO;
  wire                o_IMP_NOFLUC_SIGN;
  wire        [7:0]   o_IMP_NOFLUC_MAG;
  wire signed [9:0]   o_IMP_FLUC_SIGNED_MO;
  wire signed [9:0]   o_IMP_FLUC_SIGNED_RO;
  wire                o_ACC_SIGNED_STRB;
  wire signed [15:0]  o_ACC_SIGNED;

IKAOPLL #(
    .FULLY_SYNCHRONOUS          (1                          ),
    .FAST_RESET                 (0                          ),
    .ALTPATCH_CONFIG_MODE       (0                          ), // VRC7 patch enable
    .USE_PIPELINED_MULTIPLIER   (1                          )
) main (
    .i_XIN_EMUCLK               (clk                        ),
    .o_XOUT                                                  ,

    .i_phiM_PCEN_n              (1'b0                       ),

    .i_IC_n                     (IC_n                       ),

    .i_ALTPATCH_EN              (1'b0                       ),

    .i_CS_n                     (CS_n                       ),
    .i_WR_n                     (WR_n                       ),
    .i_A0                       (A0                         ),

    .i_D                        (DIN                        ),
    .o_D                                                     ,
    .o_D_OE                                                  ,

    .o_DAC_EN_MO                                             ,
    .o_DAC_EN_RO                                             ,
    .o_IMP_NOFLUC_SIGN                                       ,
    .o_IMP_NOFLUC_MAG                                        ,
    .o_IMP_FLUC_SIGNED_MO                                    ,
    .o_IMP_FLUC_SIGNED_RO                                    ,
    .i_ACC_SIGNED_MOVOL         (5'sd10                     ),
    .i_ACC_SIGNED_ROVOL         (5'sd15                     ),
    .o_ACC_SIGNED_STRB                                       ,
    .o_ACC_SIGNED
);


endmodule
