//
// kanji.v
//   Kanji ROM controller
//   Revision 1.00
//
// Copyright (c) 2006 Kazuhiro Tsujikawa (ESE Artists' factory)
// All rights reserved.
//
// Redistribution and use of this source code or any derivative works, are
// permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. Redistributions may not be sold, nor may they be used in a commercial
//    product or activity without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//-----------------------------------------------------------------------------
// 2025 Javier Abadía
// adapted to goa'uld
//
// 16th,August,2017 modified by KdL
// Fixed kanjiptr2 counter
//
// 05th,April,2008 modified by t.hara
// リファクタリング。
//

module kanji (
    input  wire        clk21m,
    input  wire        reset,       // async, active-high
    input  wire        req,
    input  wire        wrt,
    input  wire [15:0] adr,
    input  wire [7:0]  dbo,

    output wire        ramreq,
    output wire [17:0] ramadr
);

    // Internal signals
    reg        updatereq;
    reg        updateack;
    reg        kanjisel;
    reg [16:0] kanjiptr1;
    reg [16:0] kanjiptr2;

    // ------------------------------------------------------------
    // RAM access (combinational)
    // ------------------------------------------------------------
    assign ramreq = (wrt == 1'b0 && adr[0] == 1'b1) ? req : 1'b0;
    assign ramadr = (kanjisel == 1'b0) ? {1'b0, kanjiptr1} : {1'b1, kanjiptr2};


    // ------------------------------------------------------------
    // Select and request update handshake
    // ------------------------------------------------------------
    always @(posedge clk21m or posedge reset) begin
        if (reset) begin
            kanjisel  <= 1'b0;
            updatereq <= 1'b0;
        end else begin
            if (req == 1'b1 && wrt == 1'b0 && adr[0] == 1'b1) begin
                kanjisel  <= adr[1];
                updatereq <= ~updateack;
            end
        end
    end

    // ------------------------------------------------------------
    // Update acknowledge toggle
    // ------------------------------------------------------------
    always @(posedge clk21m or posedge reset) begin
        if (reset) begin
            updateack <= 1'b0;
        end else begin
            if (req == 1'b0 && (updatereq != updateack)) begin
                updateack <= ~updateack;
            end
        end
    end

    // ------------------------------------------------------------
    // JIS1 decoding and pointer update
    // ------------------------------------------------------------
    always @(posedge clk21m or posedge reset) begin
        if (reset) begin
            kanjiptr1 <= 17'd0;
        end else begin
            if (req == 1'b1 && wrt == 1'b1 && adr[1] == 1'b0) begin
                if (adr[0] == 1'b0) begin
                    kanjiptr1[10:5] <= dbo[5:0];
                end else begin
                    kanjiptr1[16:11] <= dbo[5:0];
                end
                kanjiptr1[4:0] <= 5'b00000;
            end else if (req == 1'b0 && (updatereq != updateack) && kanjisel == 1'b0) begin
                kanjiptr1[4:0] <= kanjiptr1[4:0] + 5'd1;
            end
        end
    end

    // ------------------------------------------------------------
    // JIS2 decoding and pointer update
    // ------------------------------------------------------------
    always @(posedge clk21m or posedge reset) begin
        if (reset) begin
            kanjiptr2 <= 17'd0;
        end else begin
            if (req == 1'b1 && wrt == 1'b1 && adr[1] == 1'b1) begin
                if (adr[0] == 1'b0) begin
                    kanjiptr2[10:5] <= dbo[5:0];
                end else begin
                    kanjiptr2[16:11] <= dbo[5:0];
                end
                kanjiptr2[4:0] <= 5'b00000;
            end else if (req == 1'b0 && (updatereq != updateack) && kanjisel == 1'b1) begin
                kanjiptr2[4:0] <= kanjiptr2[4:0] + 5'd1;
            end
        end
    end


endmodule
