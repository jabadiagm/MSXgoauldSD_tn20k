module IKAOPLL_timinggen (
    //chip clock
    input   wire            i_EMUCLK, //emulator master clock
    input   wire            i_phiM_PCEN_n,

    //chip reset
    input   wire            i_IC_n,
    output  wire            o_RST_n,

    //phiM/2
    output  wire            o_phi1_PCEN_n, //internal positive edge clock enable
    output  wire            o_phi1_NCEN_n, //internal negative edge clock enable
    output  wire            o_DAC_EN,

    //rhythm enable
    input   wire            i_RHYTHM_EN,

    //outputs
    output  wire            o_CYCLE_00, o_CYCLE_12, o_CYCLE_17, o_CYCLE_20, o_CYCLE_21,
    output  wire            o_CYCLE_D3_ZZ, o_CYCLE_D4, o_CYCLE_D4_ZZ,
    output  wire            o_MnC_SEL, o_INHIBIT_FDBK,
    output  reg             o_HH_TT_SEL,
    output  wire            o_MO_CTRL, o_RO_CTRL
);

/*
    CLOCKING INFORMATION(ORIGINAL CHIP)
    
    phiM        |¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯|
    ICn         ¯¯¯¯¯¯¯¯¯¯¯¯|___________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    IC          ____________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________________________________________________________________
    ICn_Z       ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    ICn_ZZ      ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    IC neg det  ________________________________________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|________________________________________
    phi1        ¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______________________________________________________|¯¯¯¯¯¯¯¯
*/

///////////////////////////////////////////////////////////
//////  Clock and reset
////

assign          o_RST_n = i_IC_n;
wire            phi1ncen_n = o_phi1_NCEN_n;

///////////////////////////////////////////////////////////
//////  Reset, phi1 and master cycle counter
////

// phi1 clock edge detectors
// phi1 counts 4 phiM cycles

//    ICn    ¯¯¯¯¯\______________________________/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
//    ICn_Z  ¯¯¯¯¯¯¯\_______________________________/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
//    ICn_ZZ ¯¯¯¯¯¯¯¯¯¯¯\_______________________________/¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
// phiM      ¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/¯\_/
//                *** ICn != ICn_Z               **** ICn != ICn_Z
//                  v reset phisr & mc              v reset phisr & mc
// phisr[0]   ?    [1]  0   1   1   1   0   1   1  [1]  0   1   1   1   0   1   1   1   0   1   1   1   0   1 
// phisr[1]   ?    [1]  1   0   1   1   1   0   1  [1]  1   0   1   1   1   0   1   1   1   0   1   1   1   0
// phisr[2]   ?    [1]  1   1   0   1   1   1   0  [1]  1   1   0   1   1   1   0   1   1   1   0   1   1   1
// phisr[3]   ?    [1]  1   1   1   0   1   1   1  [1]  1   1   1   0   1   1   1   0   1   1   1   0   1   1 
// phi1p      ? ... X¯¯¯¯¯¯¯\__/¯¯¯¯¯¯¯¯¯¯¯¯\__/¯¯¯¯X¯¯¯¯¯¯¯\__/¯¯¯¯¯¯¯¯¯¯¯¯\__/¯¯¯¯¯¯¯¯¯¯¯¯\__/¯¯¯¯¯¯¯¯¯¯¯¯\
// phi1n      ? ... X¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\__/¯¯¯¯¯¯¯¯¯¯¯¯X¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯\__/¯¯¯¯¯¯¯¯¯¯¯¯\__/¯¯¯¯¯¯¯¯¯¯¯¯\__/¯¯¯¯¯
// phi1       ? ... X_______/¯¯¯¯¯¯¯\_______/¯¯¯¯¯¯¯X_______/¯¯¯¯¯¯¯\_______/¯¯¯¯¯¯¯\_______/¯¯¯¯¯¯¯\_______/
// mc               X______ 0 ______/¯¯¯¯¯¯¯1¯¯¯¯¯¯¯X______ 0 ______/¯¯¯¯¯¯¯ 1 ¯¯¯¯¯v¯¯¯¯¯¯¯ 2 ¯¯¯¯¯v¯¯¯¯¯¯¯ 3

// (mc) master cycle counter, counts 18(=3×6) phi1 cycles
//      0  1  2  3  4  5  <-subcycles
//      8  9 10 11 12 13
//     16 17 18 19 20 21

reg             last_ic_n;
reg     [3:0]   phisr;
wire            phi1p = phisr[1];
wire            phi1n = phisr[3];

reg     [2:0]   mcyccntr_lo;
reg     [1:0]   mcyccntr_hi;
wire    [4:0]   mc = {mcyccntr_hi, mcyccntr_lo};

always @(posedge i_EMUCLK) begin
    if (last_ic_n != i_IC_n) begin
        phisr <= 4'b1111; // reset
        mcyccntr_lo <= 3'd0;
        mcyccntr_hi <= 2'd0;
    end else begin
        if (!i_phiM_PCEN_n) begin
            phisr[3:1] <= phisr[2:0]; phisr[0] <= ~&{phisr} & phisr[3]; // shift
        end
        if (!phi1ncen_n) begin // we could just use !phisr[3] here
            mcyccntr_lo <= (mcyccntr_lo == 3'd5) ? 3'd0 : mcyccntr_lo + 3'd1;
            if (mcyccntr_lo == 3'd5) mcyccntr_hi <= (mcyccntr_hi == 2'd2) ? 2'd0 : mcyccntr_hi + 2'd1;
        end
    end
    last_ic_n <= i_IC_n;
end

assign          o_DAC_EN = phisr[0];

//phi1 cen(internal)
assign  o_phi1_PCEN_n = phi1p | i_phiM_PCEN_n; //ORed signal
assign  o_phi1_NCEN_n = phi1n | i_phiM_PCEN_n;


//simple cycles
assign  o_CYCLE_21 = mc == 5'd21;
assign  o_CYCLE_20 = mc == 5'd20;
assign  o_CYCLE_17 = mc == 5'd17;
assign  o_CYCLE_12 = mc == 5'd12;
assign  o_CYCLE_00 = mc == 5'd0;

//delayed counter bits
reg     [1:0]   mc_d4_dly, mc_d3_dly;
assign  o_CYCLE_D4 = mc[4];
assign  o_CYCLE_D4_ZZ = mc_d4_dly[1];
assign  o_CYCLE_D3_ZZ = mc_d3_dly[1];
always @(posedge i_EMUCLK) if(!phi1ncen_n) begin
    mc_d4_dly[1] <= mc_d4_dly[0];
    mc_d4_dly[0] <= mc[4];
    mc_d3_dly[1] <= mc_d3_dly[0];
    mc_d3_dly[0] <= mc[3];
end

//composite timings
assign  o_MnC_SEL       =  &{(~mc[2] | mc[0]), (mc[2] | ~mc[1])}; //de morgan
assign  o_INHIBIT_FDBK  = ~|{o_MnC_SEL, ((mc == 5'd20) & i_RHYTHM_EN), ((mc == 5'd19) & i_RHYTHM_EN)};
assign  o_MO_CTRL       = ~|{(i_RHYTHM_EN & o_CYCLE_D4_ZZ), ~o_MnC_SEL};
assign  o_RO_CTRL       =  &{(~o_MnC_SEL | o_CYCLE_D4_ZZ), ~(mc == 5'd18), ~(mc == 5'd12), i_RHYTHM_EN}; //de morgan
always @(posedge i_EMUCLK) if(!phi1ncen_n) o_HH_TT_SEL <= &{o_MnC_SEL, ~((mc[4:1] == 4'b1000) & i_RHYTHM_EN)};

endmodule