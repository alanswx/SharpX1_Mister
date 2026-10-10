// SPDX-License-Identifier: GPL-2.0-only
// Original CPU-side capacity latch, based on X1 Techknow Appendix A p275.
// IN 0FFE selects 1.6M/2HD; IN 0FFF selects 500K/1M (2D/2DD).
// These are capacity classes, not data rates. Global class follows the local
// X Millennium and Common Source X1 implementations. Reset to 2D/2DD is a
// provisional startup policy, not a measured CZ-880 latch/reset contract.
// No BUSY deferral is invented; this latch is not yet connected to FDCCLK,
// medium matching or mechanical controls. A future consumer must separately
// qualify changing selection while a command owns the controller.
module x1_disk_capacity_select (
    input wire clk, reset, io_read,
    input wire [15:0] address,
    output logic hd_selected
);
    always @(posedge clk or posedge reset) begin
        if(reset) hd_selected <= 1'b0;
        else if(io_read && address == 16'h0ffe) hd_selected <= 1'b1;
        else if(io_read && address == 16'h0fff) hd_selected <= 1'b0;
    end
endmodule
