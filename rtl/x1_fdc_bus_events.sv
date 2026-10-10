// SPDX-License-Identifier: GPL-2.0-or-later
// Original functional bus adapter for the separate FDC timing experiment.
// Accept once at the first eligible SYS edge of a held transaction, not on
// strobe release. This is a digital interface policy, not native RE/WE timing.
`timescale 1ns/1ps
module x1_fdc_bus_events (
    input wire clk, reset, bus_ce, selected, rd, wr,
    input wire [7:0] response, write_value,
    output wire read_accept, write_accept,
    output wire [7:0] read_value,
    output reg [7:0] captured_write = 8'd0,
    output wire [7:0] accepted_write_value
);
    reg read_seen = 1'b0, write_seen = 1'b0;
    reg [7:0] held_response = 8'd0;
    assign read_accept = !reset && bus_ce && selected && rd && !wr && !read_seen;
    assign write_accept = !reset && bus_ce && selected && wr && !rd && !write_seen;
    // Before the acceptance edge the live register supplies the response;
    // after it, the captured generation stays stable for the whole read.
    assign read_value = read_seen ? held_response : response;
    // A same-edge consumer needs current DIN, not the preceding transaction's
    // post-edge captured register. Both settle before its sampling edge.
    assign accepted_write_value = write_accept ? write_value : captured_write;
    always @(posedge clk) begin
        if(reset) begin
            read_seen <= 1'b0;
            write_seen <= 1'b0;
            held_response <= 8'd0;
            captured_write <= 8'd0;
        end else begin
            // Raw release must be observed even while bus_ce is stopped.
            if(!rd) read_seen <= 1'b0;
            else if(read_accept) begin
                read_seen <= 1'b1;
                held_response <= response;
            end
            if(!wr) write_seen <= 1'b0;
            else if(write_accept) begin
                write_seen <= 1'b1;
                captured_write <= write_value;
            end
        end
    end
endmodule
