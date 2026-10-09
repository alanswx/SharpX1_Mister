// SPDX-License-Identifier: GPL-2.0-or-later
// Board-only experimental VSYNC level CDC. Not a short-pulse event queue.
// Only stage 1 may feed SYS consumers; stage 0 must have no other fanout.
// Physical placement/MTBF and supported pulse widths require FPGA review.
module x1_vsync_sys (
    input wire clk_sys,
    input wire async_vsync,
    output wire vsync_sys
);
    timeunit 1ps;
    timeprecision 1ps;
    (* preserve *) reg [1:0] sample_pipe = 2'b00;
    always @(posedge clk_sys)
        sample_pipe <= {sample_pipe[0], async_vsync};
    assign vsync_sys = sample_pipe[1];
endmodule
