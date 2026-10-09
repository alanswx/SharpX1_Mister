// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ps/1ps
// Original digital AC-coupling policy for mixing unipolar JT49 with JT51.
// Update on the audio sample enable, never on a derived clock.
// Q16 DC estimate, alpha=1/2048; about 4.86 Hz at 62.5 ksample/s.
// This is NOT a measured X1 resistor/capacitor transfer function or gain.
module x1_psg_signed (
    input logic clk, reset, sample_ce,
    input logic [9:0] psg,
    output logic signed [15:0] sound
);
    logic [31:0] dc;
    wire [15:0] scaled = {1'b0,psg,5'b0};
    wire signed [32:0] delta = $signed({1'b0,scaled,16'b0})
                             - $signed({1'b0,dc});
    wire signed [32:0] next_dc = $signed({1'b0,dc}) + (delta >>> 11);
    wire signed [16:0] centered = $signed({1'b0,scaled})
                                - $signed({1'b0,dc[31:16]});
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            dc <= 0;
            sound <= 0;
        end else if (sample_ce) begin
            dc <= next_dc[31:0];
            sound <= centered[15:0];
        end
    end
endmodule
