// SPDX-License-Identifier: GPL-2.0-or-later
// Original asynchronous assertion / destination-clock reset release.
// This does not establish metastability/placement or external-pin signoff.
module x1_reset_release (
    input wire clk, async_reset,
    output wire reset
);
    (* preserve *) reg [1:0] release_pipe;
    always @(posedge clk or posedge async_reset)
        if (async_reset) release_pipe <= 2'b11;
        else release_pipe <= {release_pipe[0],1'b0};
    assign reset = release_pipe[1];
endmodule
