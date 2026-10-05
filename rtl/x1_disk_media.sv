// SPDX-License-Identifier: GPL-2.0-only
// Original X1 two-image transport glue. One FDC/index table is retained;
// switching images serializes a rescan behind completion of the old request.
// Caller retains per-drive descriptors across reset; mount pulses invalidate
// the active index before their updated descriptors are used for a rescan.
module x1_disk_media (
    input clk,
    input [1:0] selected,
    input [1:0] mounted, present, readonly,
    input [23:0] size_a, size_b,
    input transport_idle,
    output reg [1:0] active,
    output changing,
    output ready, wp,
    output [23:0] size
);
    reg pending;
    initial begin active = 0; pending = 1; end
    wire valid = active < 2;
    assign changing = pending || selected != active || (valid && mounted[active[0]]);
    assign ready = valid && !changing && present[active[0]];
    // Protection is a live host policy (OSD can disable writes without a mount).
    assign wp = !valid || readonly[active[0]];
    assign size = valid && present[active[0]] ? (active[0] ? size_b : size_a) : 24'd0;
    always @(posedge clk) begin
        if (changing) begin
            pending <= 1;
            // Keep the request owner until the FDC's ACK shift register and
            // published request have drained. Mount pulses must also end.
            if (transport_idle && !(|mounted)) begin
                active <= selected;
                pending <= 0;
            end
        end
    end
endmodule
