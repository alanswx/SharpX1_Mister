// SPDX-License-Identifier: GPL-2.0-only
// Original read-only Turbo DIP bus. Low-nibble mirrors follow inherited
// decoder/X Millennium; physical ASIC alias qualification remains open.
// Raw pin values are configuration, not detected media/device readiness.
module x1_turbo_dsw #(parameter ENABLED=0) (
    input wire io_read, dam,
    input wire [15:0] address,
    input wire [7:0] switches,
    output wire selected,
    output wire [7:0] data
);
    assign selected=ENABLED && io_read && !dam && address[15:4]==12'h1ff;
    assign data=selected ? switches : 8'hff;
endmodule
