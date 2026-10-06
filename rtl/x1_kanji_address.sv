// SPDX-License-Identifier: GPL-2.0-only
// Original model-20/30 physical first-level Kanji ROM address decoder, 2026.
// CZ851_2C_Schematic PDF3: IC92 (2/2), IC106/105/104/103 MB83256.
// ROM A14..12=DKAN2..0; A11..4=DCHA7..0; A3..0=K4Y..K1Y.
// Active-low KAY0..3 select {DKAN6 (half), DKAN3 (bank high)}.
// level1_enable is caller-qualified KACE, NOT an invented DKAN/PCG policy.
// No native dump filename ordering, JIS conversion, CPU latch or Z level-2
// mapping is implied. Flattened bytes are IC106, IC105, IC104, IC103 order.
module x1_kanji_address (
    input wire level1_enable,
    input wire [7:0] dkan, dcha,
    input wire [3:0] raster,
    output wire [14:0] rom_address,
    output wire [3:0] rom_oe_n,
    output wire [16:0] byte_address
);
    wire [1:0] chip={dkan[6],dkan[3]};
    assign rom_address={dkan[2:0],dcha,raster};
    assign rom_oe_n=level1_enable ? ~(4'b0001 << chip) : 4'b1111;
    assign byte_address={chip,rom_address};
endmodule
