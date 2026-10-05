// SPDX-License-Identifier: GPL-2.0-only
// Original CPU-domain Turbo selector shadow; provisional Xmil 7FF fallback.
// Only accepted writes populate metadata. Like VRAM, it survives warm reset.
// Validity prevents invented power-up contents from becoming glyph writes.
module x1_pcg_selector (
    input clk,
    input text_write, attr_write, kan_write,
    input [10:0] address,
    input [7:0] data,
    input [3:0] nibble,
    input [1:0] plane,
    input font16_mode,
    output reg [10:0] byte_address,
    output reg [11:0] font_address,
    output reg font16_select, unsupported
);
    reg [7:0] text_cell [0:3];
    reg [7:0] attr_cell [0:3];
    reg [7:0] kan_cell [0:3];
    reg [3:0] text_valid = 0, attr_valid = 0, kan_valid = 0;
    integer i;
    always @(posedge clk) begin
        for (integer w = 0; w < 4; w = w + 1) begin
            if (address == (w == 0 ? 11'h7ff : w == 1 ? 11'h3ff :
                            w == 2 ? 11'h5ff : 11'h1ff)) begin
                if (text_write) begin text_cell[w] <= data; text_valid[w] <= 1; end
                if (attr_write) begin attr_cell[w] <= data; attr_valid[w] <= 1; end
                if (kan_write) begin kan_cell[w] <= data; kan_valid[w] <= 1; end
            end
        end
    end
    integer selected;
    reg found;
    reg [7:0] glyph, kan;
    always @* begin
        selected = 0; found = 0;
        for (i = 0; i < 4; i = i + 1) begin
            if (!found && attr_valid[i] && attr_cell[i][5] == (plane != 0)) begin
                selected = i; found = 1;
            end
        end
        glyph = text_cell[selected]; kan = kan_cell[selected];
        unsupported = attr_valid != 4'b1111 || !text_valid[selected] || !kan_valid[selected];
        font16_select = plane == 0 && font16_mode && !kan[7];
        font_address = {glyph, nibble};
        byte_address = {glyph, nibble[3:1]};
        if (plane != 0 && (kan & 8'h90) != 0)
            byte_address = {glyph[7:1], nibble};
        if (plane == 0 && kan[7]) unsupported = 1;
        // Deterministic absent/uninitialized/backend response, not fake glyphs.
        if (unsupported) begin
            byte_address = 0; font_address = 0; font16_select = 0;
        end
    end
endmodule
