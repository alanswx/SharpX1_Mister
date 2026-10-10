// SPDX-License-Identifier: GPL-2.0-only
// Original replacement-controller ROM-capacity experiment, not native MCU or
// Z80 address decoding. No active machine/board profile selects it yet.
// Legacy preserves existing aliases. Extended keeps 0000-0FFF ROM and
// 1000-1FFF RAM, adds ROM at 4000-4FFF, and rejects all other memory aliases.
module x1_mr16_rom_decode #(parameter EXTENDED = 0) (
    input wire [15:0] address,
    input wire memory_cs,
    output wire rom_cs, ram_cs,
    output wire [11:0] rom_word_address
);
    generate if (EXTENDED) begin : extended_map
        assign rom_cs = memory_cs && (address[15:12] == 4'h0 || address[15:12] == 4'h4);
        assign ram_cs = memory_cs && address[15:12] == 4'h1;
        assign rom_word_address = {address[14],address[11:1]};
    end else begin : inherited_map
        assign rom_cs = memory_cs && !address[12];
        assign ram_cs = memory_cs && address[12];
        assign rom_word_address = {1'b0,address[11:1]};
    end endgenerate
endmodule
