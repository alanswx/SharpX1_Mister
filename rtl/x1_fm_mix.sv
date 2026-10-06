// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ps/1ps
// Original signed digital mixer. PSG is centered/scaled by its caller.
// Unity gains are a functional policy, not measured X1 analog resistor gains.
module x1_fm_mix (
    input logic signed [15:0] fm_left, fm_right, psg,
    output logic signed [15:0] left, right, mono
);
    wire signed [17:0] lsum = {{2{fm_left[15]}},fm_left} + {{2{psg[15]}},psg};
    wire signed [17:0] rsum = {{2{fm_right[15]}},fm_right} + {{2{psg[15]}},psg};
    // Separate internal-speaker sum: PSG once, rather than summing two
    // already-PSG-mixed stereo outputs and doubling the PSG component.
    wire signed [17:0] msum = {{2{fm_left[15]}},fm_left}
                           + {{2{fm_right[15]}},fm_right} + {{2{psg[15]}},psg};
    function automatic logic signed [15:0] clip(input logic signed [17:0] value);
        if (value > 18'sd32767) clip = 16'sh7fff;
        else if (value < -18'sd32768) clip = 16'sh8000;
        else clip = value[15:0];
    endfunction
    assign left = clip(lsum);
    assign right = clip(rsum);
    assign mono = clip(msum);
endmodule
