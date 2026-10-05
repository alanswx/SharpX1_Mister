// SPDX-License-Identifier: GPL-2.0-only
// Original Sharp X1 GRAM display-address integration. Raster contract follows
// inspected X Millennium make24.c's 200h/400h paths (not its timing model).
// Mode 01 uses fixed even/odd pages regardless of SCRN display-page bit 3.
// ASIC electrical/live-switch equivalence remains a hardware-review gate.
`timescale 1ns/1ps
module x1_gram_address #(parameter TURBO = 0) (
    input [7:0] scrn,
    input [4:0] raster,
    input [10:0] text_address,
    output [14:0] graphics_address
);
    wire high_scan = TURBO && scrn[0];
    wire interleaved = high_scan && !scrn[1];
    wire page = TURBO && (interleaved ? raster[0] : scrn[3]);
    wire [2:0] graphics_raster = high_scan ? raster[3:1] : raster[2:0];
    assign graphics_address = {page, graphics_raster, text_address};
endmodule
