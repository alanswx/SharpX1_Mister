// SPDX-License-Identifier: GPL-2.0-only
// Original combinational model of CZ851_2C_Schematic PDF3 IC92/IC91.
// IC92 (1/2): /G is caller-qualified; A=DATT5, B=DKAN7.
// Y0 enables ANK, Y2 is /KACE. IC91's bubbled NAND is an OR:
// IC92 (2/2) /G = /KACE | DKAN4. Level-2 storage is NOT provided.
// The caller must supply the actual decoder phase and K4Y..K1Y raster;
// this component does not infer ASIC timing, underline or row progression.
module x1_kanji_decode (
    input wire decode_enable,
    input wire [7:0] attribute, dkan, dcha,
    input wire [3:0] raster,
    output wire [3:0] glyph_oe_n,
    output wire kace_n,
    output wire level1_select, level2_select,
    output wire [14:0] rom_address,
    output wire [3:0] rom_oe_n,
    output wire [16:0] byte_address
);
    wire [1:0] source={dkan[7],attribute[5]};
    assign glyph_oe_n=decode_enable ? ~(4'b0001 << source) : 4'b1111;
    assign kace_n=glyph_oe_n[2];
    assign level1_select=!kace_n && !dkan[4];
    assign level2_select=!kace_n && dkan[4];
    x1_kanji_address address_decode (
        .level1_enable(level1_select), .dkan(dkan), .dcha(dcha), .raster(raster),
        .rom_address(rom_address), .rom_oe_n(rom_oe_n), .byte_address(byte_address)
    );
endmodule
