// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ps/1ps
// Original sample-aligned signed audio path. The chip's sample pulse must
// identify valid pre-edge FM outputs. All outputs hold between samples.
// Digital gains/filter are provisional, not a measured native analog model.
module x1_audio_mix (
    input logic clk, reset, sample_ce,
    input logic [9:0] psg,
    input logic signed [15:0] fm_left, fm_right,
    output wire signed [15:0] left, right, mono
);
    logic signed [15:0] saved_left, saved_right;
    wire signed [15:0] signed_psg;
    x1_psg_signed coupling(.clk(clk),.reset(reset),.sample_ce(sample_ce),
                          .psg(psg),.sound(signed_psg));
    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin saved_left<=0; saved_right<=0; end
        else if(sample_ce) begin saved_left<=fm_left; saved_right<=fm_right; end
    end
    x1_fm_mix mixer(.fm_left(saved_left),.fm_right(saved_right),.psg(signed_psg),
                   .left(left),.right(right),.mono(mono));
endmodule
