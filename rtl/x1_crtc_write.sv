// SPDX-License-Identifier: GPL-2.0-only
// Held RS/data packet, one destination write per bus cycle. The target samples
// video_write/data on a rising video edge; only that edge acknowledges it.
// WAIT is transaction transport latency, not a native CRTC scanline trap.
module x1_crtc_write (
    input wire cpu_clk, reset, video_clk, video_reset,
    input wire select, rs,
    input wire [7:0] data,
    output wire wait_n,
    output wire video_write,
    output reg video_rs,
    output reg [7:0] video_data
);
    timeunit 1ps;
    timeprecision 1ps;
    reg request, busy, done, acknowledgement, seen;
    reg pending_write;
    reg [8:0] held_packet;
    (* preserve, async_reg = "true" *) reg request_meta, request_sync;
    (* preserve, async_reg = "true" *) reg acknowledgement_meta, acknowledgement_sync;
    assign wait_n = !select || done;
    assign video_write = pending_write && !video_reset;
    always @(posedge cpu_clk or posedge reset) begin
        if (reset) begin
            request <= 0; busy <= 0; done <= 0; held_packet <= 0;
            acknowledgement_meta <= 0; acknowledgement_sync <= 0;
        end else begin
            acknowledgement_meta <= acknowledgement;
            acknowledgement_sync <= acknowledgement_meta;
            if (!select) done <= 0;
            if (select && !busy && !done) begin
                held_packet <= {rs, data};
                request <= !request;
                busy <= 1;
            end
            if (busy && acknowledgement_sync == request) begin
                busy <= 0;
                done <= select;
            end
        end
    end
    always @(posedge video_clk or posedge video_reset) begin
        if (video_reset) begin
            request_meta <= 0; request_sync <= 0; seen <= 0;
            acknowledgement <= 0; pending_write <= 0;
            video_rs <= 0; video_data <= 0;
        end else begin
            request_meta <= request;
            request_sync <= request_meta;
            pending_write <= 0;
            if (pending_write) begin
                // Target consumes the OLD registered write/data on this edge.
                acknowledgement <= seen;
            end else if (request_sync != seen) begin
                {video_rs, video_data} <= held_packet;
                seen <= request_sync;
                pending_write <= 1;
            end
        end
    end
endmodule
