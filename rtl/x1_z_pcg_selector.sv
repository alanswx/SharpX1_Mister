// SPDX-License-Identifier: GPL-2.0-only
// Original Turbo Z highest-cell CPU selector, Techknow printed 148/151.
// Only accepted writes to 37FF/27FF/3FFF qualify the three metadata bytes.
// The emulator-derived 7FF/3FF/5FF/1FF fallback is deliberately EXCLUDED.
// Validity/storage survive warm reset, like the corresponding VRAM cells.
// Functional source/address selection, not ASIC KACE pulse timing.
`timescale 1ps/1ps
module x1_z_pcg_selector (
    input wire clk,
    input wire text_write, attr_write, kan_write,
    input wire [10:0] address,
    input wire [7:0] data,
    input wire [3:0] nibble,
    input wire [1:0] plane,
    input wire font16_mode,
    output reg [10:0] byte_address,
    output reg [11:0] font_address,
    output reg font16_select, unsupported, kanji_select,
    output wire [17:0] kanji_address
);
    reg [7:0] text_cell;
    reg attr_pcg, kan_level, kan_half, kan_rom;
    reg [3:0] kan_bank;
    reg text_valid, attr_valid, kan_valid;
    initial begin text_valid=0; attr_valid=0; kan_valid=0; end
    always @(posedge clk) begin
        if(address == 11'h7ff) begin
            if(text_write) begin text_cell<=data; text_valid<=1; end
            if(attr_write) begin attr_pcg<=data[5]; attr_valid<=1; end
            if(kan_write) begin
                kan_bank<=data[3:0]; kan_level<=data[4];
                kan_half<=data[6]; kan_rom<=data[7]; kan_valid<=1;
            end
        end
    end
    // IC65 then IC66: level, bank, character, raster, left/right byte.
    assign kanji_address = kanji_select
        ? {kan_level,kan_bank,text_cell,nibble,kan_half} : 18'd0;
    always @* begin
        unsupported=!(text_valid && attr_valid && kan_valid) ||
                    attr_pcg != (plane != 0);
        kanji_select=!unsupported && plane==0 && kan_rom;
        font16_select=!unsupported && plane==0 && !kan_rom && font16_mode;
        font_address={text_cell,nibble};
        // Ordinary PCG ignores CPU AB0; gaiji uses an even-code pair.
        byte_address={text_cell,nibble[3:1]};
        if(plane!=0 && (kan_rom || kan_level))
            byte_address={text_cell[7:1],nibble};
        if(unsupported) begin byte_address=0; font_address=0; end
    end
endmodule
