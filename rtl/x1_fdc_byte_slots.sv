// Original Sharp X1 bring-up code, GPL-2.0-or-later.
// Functional byte-boundary scheduler, not a flux decoder or drive model.
// MB8877A: 32 CLK periods per MFM byte, 64 per FM byte (2 MHz:
// 16/32 us; 1 MHz: 32/64 us). Board clock routing remains separate.
// Start snapshots density. The caller must obey the native no-DDEN-change
// during BUSY contract; snapshotting is NOT a defined busy-switch policy.
`timescale 1ns/1ps
module x1_fdc_byte_slots (
    input wire clk, reset,
    input wire fdc_ce,
    input wire start, stop,
    input wire fm,
    output wire boundary,
    output reg active = 1'b0
);
    reg [6:0] remaining = 7'd0;
    reg [6:0] period = 7'd32;
    // Consumed on this SYS edge. No CPU bus release or service input can
    // stretch/rephase a byte; do not register this pulse a second time.
    assign boundary = active && fdc_ce && remaining == 7'd1 &&
                      !reset && !stop && !start;
    always @(posedge clk) begin
        if (reset || stop) begin
            active <= 1'b0;
            remaining <= 7'd0;
            period <= 7'd32;
        end else if (start) begin
            active <= 1'b1;
            period <= fm ? 7'd64 : 7'd32;
            remaining <= fm ? 7'd64 : 7'd32;
        end else if (active && fdc_ce) begin
            remaining <= remaining == 7'd1 ? period : remaining - 7'd1;
        end
    end
endmodule
