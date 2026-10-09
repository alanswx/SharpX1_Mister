// SPDX-License-Identifier: GPL-2.0-only
// Sub-CPU blink is a held level, not a clock or a short-pulse event queue.
// The independent-X3 path uses the existing destination-local video reset.
module x1_video_blink #(parameter SYNCHRONIZE = 0) (
    input wire video_clk, video_reset,
    input wire sub_blink,
    output wire display_blink
);
    timeunit 1ps;
    timeprecision 1ps;
    generate if (SYNCHRONIZE) begin : crossing
        (* preserve, altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
        reg [1:0] sample_pipe = 2'b00;
        always @(posedge video_clk or posedge video_reset)
            if (video_reset) sample_pipe <= 0;
            else sample_pipe <= {sample_pipe[0], sub_blink};
        assign display_blink = sample_pipe[1];
    end else begin : compatible
        assign display_blink = sub_blink;
    end endgenerate
endmodule
