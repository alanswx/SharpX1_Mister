// SPDX-License-Identifier: GPL-2.0-or-later
// Original SYS-domain completion lease for a CE-gated controller consumer.
// Not a CDC synchronizer. Command cancel/reset discards the lease, not SD ACK
// ownership. Caller must stop the producer and cancel on command replacement.
`timescale 1ns/1ps
module x1_fdc_completion (
    input wire clk, reset, cancel,
    input wire complete, lost, initial_abort, consume,
    output reg valid = 1'b0,
    output reg result_lost = 1'b0,
    output reg result_abort = 1'b0,
    output wire taken
);
    // Consumers use this pre-edge qualifier, not raw valid && consume:
    // an already visible lease cannot be applied on a cancelling edge.
    assign taken = valid && consume && !reset && !cancel;
    always @(posedge clk) begin
        if(reset || cancel) begin
            valid <= 1'b0;
            result_lost <= 1'b0;
            result_abort <= 1'b0;
        end else if(complete) begin
            // Exchange is allowed: the consumer samples the old result on
            // this edge, and the next completion replaces it afterward.
            valid <= 1'b1;
            result_lost <= lost;
            result_abort <= initial_abort;
        end else if(consume) valid <= 1'b0;
    end
`ifndef SYNTHESIS
    always @(posedge clk) if(!reset && !cancel && complete)
        assert(!valid || consume) else $fatal(1,"unconsumed FDC completion overwritten");
`endif
endmodule
