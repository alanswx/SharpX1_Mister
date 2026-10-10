// SPDX-License-Identifier: GPL-2.0-only
// Original CZ-880 sheet-46 IC65/66 physical Kanji ROM pin decoder, 2026.
// A16..13=DKAN3..0, A12..5=DCHA7..0, A4..1=K4Y..K1Y, A0=L/R.
// Caller supplies separately qualified KACE1/KACE2; no DKAN4/ASIC timing,
// native dump/export conversion, storage, CPU protocol or renderer implied.
module x1_z_kanji_address (
    input wire level1_enable, level2_enable,
    input wire [3:0] bank, raster,
    input wire [7:0] character,
    input wire half,
    output wire [16:0] rom_address,
    output wire [1:0] rom_oe_n,
    output wire [17:0] byte_address,
    output wire address_valid
);
    assign rom_address = {bank, character, raster, half};
    // Preserve the physical selects, including an illegal dual-select caller.
    // A flattened-byte consumer may only use exactly one selected chip.
    assign rom_oe_n = {~level2_enable, ~level1_enable};
    assign byte_address = {level2_enable, rom_address};
    assign address_valid = level1_enable ^ level2_enable;
endmodule
